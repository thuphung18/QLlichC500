# routers/auth.py – Phân hệ Xác thực & Cấp quyền (Authentication & Authorization).
#
# Các chức năng chính:
#   - Đăng nhập hệ thống (Sinh Access Token & Refresh Token bằng JWT).
#   - Đăng xuất hoặc Làm mới phiên đăng nhập (Refresh Token).
#   - Đảm bảo Single Session (Mỗi tài khoản chỉ hoạt động trên một thiết bị tại một thời điểm).
#   - Quên mật khẩu & Đặt lại mật khẩu qua email xác thực OTP 6 số.
#   - Cập nhật Firebase Cloud Messaging (FCM) Token cho thiết bị nhận thông báo đẩy.

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
import random
import uuid
from datetime import datetime, timedelta
from email_service import send_otp_email, send_admin_notification_email
from pydantic import BaseModel
import pyodbc
from database import get_db
from schemas import (
    LoginRequest, LoginResponse, UserProfile,
    SendResetCodeRequest, SendResetCodeResponse,
    VerifyResetCodeRequest, VerifyResetCodeResponse,
    ResetPasswordRequest, ResetPasswordResponse,
    FcmTokenRequest, RefreshTokenRequest, TokenResponse,
    RegisterRequest, GoogleLoginRequest
)
from dependencies import verify_session_token
from core.security import create_access_token, create_refresh_token, SECRET_KEY, ALGORITHM
from jose import jwt, JWTError

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


def row_to_dict(cursor, row):
    """
    Chuyển đổi kết quả một hàng (row) trả về từ thư viện pyodbc thành cấu trúc dictionary.
    Giúp ánh xạ dữ liệu cột từ cơ sở dữ liệu sang dạng khóa-giá trị dễ xử lý.
    """
    if row is None:
        return None
    # Lấy tên các cột từ mô tả của cursor
    columns = [column[0] for column in cursor.description]
    return dict(zip(columns, row))


@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    Đăng nhập người dùng bằng tài khoản và mật khẩu.
    
    Quy trình hoạt động:
      1. Gọi Stored Procedure dbo.sp_LoginUser với tham số Username và Password.
      2. Nếu không tìm thấy kết quả khớp, ném lỗi 401 Unauthorized.
      3. Sinh cặp Token JWT mới: Access Token (hạn ngắn) và Refresh Token (hạn dài).
      4. Lưu trữ Refresh Token mới xuống cơ sở dữ liệu để thực thi cơ chế Single Session.
      5. Trả về Token và Thông tin cá nhân của người dùng.
    """
    cursor = db.cursor()
    try:
        # Thực hiện gọi Stored Procedure để xác thực thông tin đăng nhập
        cursor.execute("EXEC dbo.sp_LoginUser @Username=?, @Password=?", (request.username, request.password))
        row = cursor.fetchone()
        
        if not row:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Tài khoản hoặc mật khẩu không chính xác"
            )
            
        user_dict = row_to_dict(cursor, row)
        
        # Đảm bảo trường avatarUrl tồn tại trong dictionary (gán None nếu SP không trả về)
        if 'avatarUrl' not in user_dict:
            user_dict['avatarUrl'] = None
            
        user_id = str(user_dict['id'])
        
        # Tạo mã Access Token (chứa Sub và Role) và Refresh Token
        access_token = create_access_token(data={"sub": user_id, "role": user_dict.get('role', '')})
        refresh_token = create_refresh_token(data={"sub": user_id})
        
        # Cập nhật Refresh Token vào bảng users trong DB.
        # Phục vụ cho cơ chế Single Session: Khi đăng nhập ở thiết bị mới, thiết bị cũ sẽ bị đăng xuất do Refresh Token trong DB thay đổi.
        cursor.execute("UPDATE dbo.users SET refresh_token = ? WHERE id = ?", (refresh_token, user_id))
        db.commit()
            
        user_profile = UserProfile(**user_dict)
        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=user_profile
        )
    except pyodbc.Error as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        cursor.close()


@router.post("/forgot-password/send", response_model=SendResetCodeResponse)
def send_reset_code(request: SendResetCodeRequest, background_tasks: BackgroundTasks, db: pyodbc.Connection = Depends(get_db)):
    """
    BƯỚC 1: Quên mật khẩu - Gửi mã xác thực OTP qua email.
    
    Quy trình hoạt động:
      1. Tìm kiếm người dùng dựa trên thông tin liên lạc (email) qua Stored Procedure sp_FindUserByContact.
      2. Nếu tài khoản không tồn tại, trả về kết quả thất bại.
      3. Sinh mã OTP ngẫu nhiên gồm 6 chữ số và mã UUID định danh phiên gửi.
      4. Lưu thông tin OTP vào bảng password_reset_codes (có thời gian hết hạn là 5 phút).
      5. Che bớt ký tự email để đảm bảo bảo mật khi hiển thị trên ứng dụng.
      6. Đẩy tác vụ gửi email chứa OTP vào BackgroundTask để tối ưu phản hồi API.
    """
    cursor = db.cursor()
    try:
        # Tìm kiếm người dùng dựa trên thông tin email liên hệ
        cursor.execute("EXEC dbo.sp_FindUserByContact @Contact=?", (request.contact,))
        row = cursor.fetchone()
        
        if not row:
             return SendResetCodeResponse(
                 success=False,
                 message="Không tìm thấy tài khoản với thông tin liên lạc này"
             )
        
        user_id = row[0]
        
        # Tạo mã OTP ngẫu nhiên 6 chữ số
        otp_code = str(random.randint(100000, 999999))
        code_id = str(uuid.uuid4())
        
        # Lưu thông tin mã xác thực vào cơ sở dữ liệu (thời hạn 5 phút kể từ thời điểm tạo)
        cursor.execute('''
            INSERT INTO dbo.password_reset_codes 
            (id, user_id, contact, otp_code, expires_at, created_at, is_verified, is_used)
            VALUES (?, ?, ?, ?, DATEADD(minute, 5, GETDATE()), GETDATE(), 0, 0)
        ''', (code_id, user_id, request.contact, otp_code))
        db.commit()

        # Tạo chuỗi masked email để phản hồi bảo mật cho client (Ví dụ: exam***.com)
        masked = request.contact[:4] + "***" + request.contact[-3:] if len(request.contact) > 6 else "***"
        
        # Đăng ký tác vụ gửi email chạy ngầm, tránh block luồng phản hồi của API chính
        background_tasks.add_task(send_otp_email, request.contact, otp_code)
        
        return SendResetCodeResponse(
            success=True,
            message="Mã xác thực đã được gửi về email của bạn",
            maskedContact=masked
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.post("/forgot-password/verify", response_model=VerifyResetCodeResponse)
def verify_reset_code(request: VerifyResetCodeRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    BƯỚC 2: Quên mật khẩu - Xác thực mã OTP người dùng nhập vào.
    
    Quy trình hoạt động:
      1. Truy vấn mã xác thực trong database khớp với thông tin: email, mã OTP, chưa được xác thực, chưa sử dụng và chưa hết hạn.
      2. Nếu không tìm thấy bản ghi hợp lệ, trả về thông báo lỗi.
      3. Sinh một token dùng một lần (reset_token) đại diện cho quyền đặt lại mật khẩu.
      4. Cập nhật trạng thái của mã OTP thành đã xác thực (is_verified = 1) và gắn kèm reset_token.
      5. Trả về reset_token cho ứng dụng client để chuyển tiếp sang Bước 3.
    """
    cursor = db.cursor()
    try:
        # Kiểm tra tính hợp lệ của mã OTP
        cursor.execute('''
            SELECT id, user_id 
            FROM dbo.password_reset_codes 
            WHERE contact = ? AND otp_code = ? 
              AND is_verified = 0 AND is_used = 0 
              AND expires_at > GETDATE()
        ''', (request.contact, request.code))
        row = cursor.fetchone()
        
        if not row:
            return VerifyResetCodeResponse(
                success=False,
                message="Mã xác thực không đúng hoặc đã hết hạn"
            )
            
        code_id = row[0]
        # Tạo khóa tạm thời reset_token cho bước đặt lại mật khẩu tiếp theo
        reset_token = str(uuid.uuid4())
        
        # Cập nhật trạng thái bản ghi OTP
        cursor.execute('''
            UPDATE dbo.password_reset_codes 
            SET is_verified = 1, verified_at = GETDATE(), reset_token = ?
            WHERE id = ?
        ''', (reset_token, code_id))
        db.commit()
        
        return VerifyResetCodeResponse(
            success=True,
            message="Xác thực thành công",
            resetToken=reset_token
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.post("/forgot-password/reset", response_model=ResetPasswordResponse)
def reset_password(request: ResetPasswordRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    BƯỚC 3: Quên mật khẩu - Cập nhật mật khẩu mới bằng reset_token.
    
    Quy trình hoạt động:
      1. Truy vấn bản ghi OTP theo reset_token (kiểm tra token còn hạn, đã được xác thực nhưng chưa từng sử dụng).
      2. Cập nhật mật khẩu mới vào bảng users.
      3. Đánh dấu reset_token này đã sử dụng (is_used = 1) để tránh việc tấn công replay attack (sử dụng lại token).
    """
    cursor = db.cursor()
    try:
        # Kiểm tra sự hợp lệ của reset_token
        cursor.execute('''
            SELECT id, user_id 
            FROM dbo.password_reset_codes 
            WHERE reset_token = ? 
              AND is_verified = 1 AND is_used = 0
              AND expires_at > GETDATE()
        ''', (request.resetToken,))
        row = cursor.fetchone()
        
        if not row:
            return ResetPasswordResponse(
                success=False,
                message="Token không hợp lệ hoặc đã hết hạn"
            )
            
        code_id = row[0]
        user_id = row[1]
        
        # Cập nhật mật khẩu mới cho người dùng
        cursor.execute('''
            UPDATE dbo.users 
            SET password_hash = ?
            WHERE id = ?
        ''', (request.newPassword, user_id))
        
        # Hủy hiệu lực của reset_token sau khi dùng xong
        cursor.execute('''
            UPDATE dbo.password_reset_codes 
            SET is_used = 1, used_at = GETDATE()
            WHERE id = ?
        ''', (code_id,))
        
        db.commit()
        
        return ResetPasswordResponse(
            success=True,
            message="Đổi mật khẩu thành công"
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.post("/fcm-token", response_model=dict)
def update_fcm_token(req: FcmTokenRequest, db: pyodbc.Connection = Depends(get_db), current_user_id: str = Depends(verify_session_token)):
    """
    Cập nhật Firebase Cloud Messaging (FCM) Token cho tài khoản người dùng hiện tại.
    FCM Token này được ứng dụng Flutter thu thập khi khởi chạy và gửi lên nhằm nhận thông báo nhắc lịch công tác.
    """
    cursor = db.cursor()
    try:
        # Cập nhật FCM token mới vào DB
        cursor.execute("UPDATE dbo.users SET fcm_token = ? WHERE id = ?", (req.fcm_token, req.user_id))
        db.commit()
        return {"success": True, "message": "Cập nhật token thành công"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.post("/refresh-token", response_model=LoginResponse)
def refresh_token(request: RefreshTokenRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    Làm mới Access Token khi hết hạn mà không bắt người dùng phải nhập lại tài khoản/mật khẩu.
    
    Quy trình hoạt động:
      1. Giải mã Refresh Token truyền lên và kiểm tra tính hợp lệ.
      2. Truy vấn người dùng trong cơ sở dữ liệu, kiểm tra trạng thái tài khoản có đang hoạt động không.
      3. Thực thi Single Session: So sánh Refresh Token gửi lên có trùng khớp với token lưu trong DB không.
         Nếu không khớp, tức là người dùng đã đăng nhập trên một thiết bị khác (làm cập nhật token mới trong DB),
         ném lỗi thông báo thiết bị hiện tại đã bị đăng xuất.
      4. Sinh cặp Access Token & Refresh Token mới, lưu Refresh Token mới vào DB và trả về cho client.
    """
    try:
        payload = jwt.decode(request.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None or payload.get("type") != "refresh":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Phiên đăng nhập đã hết hạn")
        
    cursor = db.cursor()
    try:
        cursor.execute("""
            SELECT 
                u.id, u.username, u.full_name, u.role, u.unit, u.department_id,
                d.name as departmentName, u.email, u.phone, u.avatar_url, u.refresh_token, u.is_active
            FROM dbo.users u
            LEFT JOIN dbo.departments d ON u.department_id = d.id
            WHERE u.id = ?
        """, (user_id,))
        row = cursor.fetchone()
        
        if not row or row.is_active == 0:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Tài khoản không tồn tại hoặc đã bị khóa")
            
        # Kiểm tra tính đồng bộ của Refresh Token (Single Session check)
        db_refresh_token = row.refresh_token
        if db_refresh_token != request.refresh_token:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Bạn đã đăng nhập ở thiết bị khác")
            
        # Khởi tạo cặp token mới
        role = row.role
        new_access_token = create_access_token(data={"sub": user_id, "role": role})
        new_refresh_token = create_refresh_token(data={"sub": user_id})
        
        # Cập nhật Refresh Token mới vào Database
        cursor.execute("UPDATE dbo.users SET refresh_token = ? WHERE id = ?", (new_refresh_token, user_id))
        db.commit()
        
        user_profile = UserProfile(
            id=str(row.id),
            username=row.username,
            fullName=row.full_name,
            role=row.role,
            unit=row.unit,
            departmentId=str(row.department_id) if row.department_id else "",
            departmentName=row.departmentName if row.departmentName else "",
            email=row.email,
            phone=row.phone,
            avatarUrl=row.avatar_url
        )
        
        return LoginResponse(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
            user=user_profile
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.post("/register", response_model=dict)
def register(request: RegisterRequest, background_tasks: BackgroundTasks, db: pyodbc.Connection = Depends(get_db)):
    """
    API Đăng ký tài khoản (dành cho người dùng mới sử dụng Gmail/Google).
    Tài khoản được tạo sẽ ở trạng thái chờ duyệt (is_active = 0) và có email thông báo cho Admin.
    """
    if not request.email.endswith("@gmail.com"):
        raise HTTPException(status_code=400, detail="Vui lòng sử dụng tài khoản Gmail (@gmail.com)")
    
    cursor = db.cursor()
    try:
        # Kiểm tra xem email đã được đăng ký chưa
        cursor.execute("SELECT id FROM dbo.users WHERE email = ?", (request.email,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Email này đã được đăng ký trên hệ thống")
        
        # Lấy tên phòng ban để gửi email
        cursor.execute("SELECT name FROM dbo.departments WHERE id = ?", (request.departmentId,))
        dept_row = cursor.fetchone()
        if not dept_row:
            raise HTTPException(status_code=400, detail="Phòng ban không hợp lệ")
        dept_name = dept_row[0]

        # Tự động tạo username từ phần đầu của email
        base_username = request.email.split("@")[0]
        username = base_username
        
        # Nếu username trùng, thêm một số ngẫu nhiên vào sau
        while True:
            cursor.execute("SELECT id FROM dbo.users WHERE username = ?", (username,))
            if not cursor.fetchone():
                break
            username = f"{base_username}{random.randint(100, 9999)}"

        user_id = str(uuid.uuid4())
        password_hash = "GOOGLE_AUTH"
        
        cursor.execute("""
            INSERT INTO dbo.users (
                id, username, password_hash, full_name, role, unit, department_id, email, phone, is_active
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        """, (
            user_id, username, password_hash,
            request.fullName, 'nhân viên', 'Học viện ANND',
            request.departmentId, request.email, None
        ))
        db.commit()

        # Bắn thông báo ngầm cho Admin
        background_tasks.add_task(send_admin_notification_email, request.email, request.fullName, dept_name)
        
        return {"success": True, "message": "Đăng ký thành công. Vui lòng chờ Quản trị viên phê duyệt tài khoản!"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.post("/google-login", response_model=LoginResponse)
def google_login(request: GoogleLoginRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    API xác thực khi ấn nút Google Sign-In.
    - Nếu email chưa tồn tại: Báo lỗi 404 (để App chuyển sang màn hình Register).
    - Nếu tồn tại nhưng chưa duyệt: Báo lỗi 403.
    - Nếu tồn tại và đã duyệt: Trả về Access Token.
    """
    cursor = db.cursor()
    try:
        # Lấy thông tin user dựa trên email (bất kể password là gì vì đã xác thực Google trên Frontend)
        cursor.execute("""
            SELECT 
                u.id, u.username, u.full_name, u.role, u.unit, u.department_id,
                d.name as departmentName, u.email, u.phone, u.avatar_url, u.is_active
            FROM dbo.users u
            LEFT JOIN dbo.departments d ON u.department_id = d.id
            WHERE u.email = ?
        """, (request.email,))
        row = cursor.fetchone()
        
        if not row:
            raise HTTPException(status_code=404, detail="Tài khoản chưa tồn tại, vui lòng đăng ký")
            
        if not row.is_active:
            raise HTTPException(status_code=403, detail="Tài khoản đang chờ Quản trị viên phê duyệt")
            
        user_id = str(row.id)
        role = row.role
        
        # Sinh Token
        access_token = create_access_token(data={"sub": user_id, "role": role})
        refresh_token = create_refresh_token(data={"sub": user_id})
        
        cursor.execute("UPDATE dbo.users SET refresh_token = ? WHERE id = ?", (refresh_token, user_id))
        db.commit()
        
        user_profile = UserProfile(
            id=user_id,
            username=row.username,
            fullName=row.full_name,
            role=role,
            unit=row.unit if row.unit else "",
            departmentId=str(row.department_id) if row.department_id else "",
            departmentName=str(row.departmentName) if row.departmentName else "",
            email=row.email,
            phone=row.phone,
            avatarUrl=row.avatar_url
        )
        
        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=user_profile
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


