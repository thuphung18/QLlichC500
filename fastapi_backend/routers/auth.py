from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
import random
import uuid
from datetime import datetime, timedelta
from email_service import send_otp_email
from pydantic import BaseModel
import pyodbc
from database import get_db
from schemas import (
    LoginRequest, LoginResponse, UserProfile,
    SendResetCodeRequest, SendResetCodeResponse,
    VerifyResetCodeRequest, VerifyResetCodeResponse,
    ResetPasswordRequest, ResetPasswordResponse,
    FcmTokenRequest, RefreshTokenRequest, TokenResponse
)
from dependencies import verify_session_token
from core.security import create_access_token, create_refresh_token, SECRET_KEY, ALGORITHM
from jose import jwt, JWTError

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

def row_to_dict(cursor, row):
    """
    Chuyá»ƒn Ä‘á»•i má»™t row cá»§a pyodbc thÃ nh dictionary
    """
    if row is None:
        return None
    columns = [column[0] for column in cursor.description]
    return dict(zip(columns, row))

@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    ÄÄƒng nháº­p ngÆ°á»i dÃ¹ng.
    Gá»i stored procedure sp_LoginUser.
    """
    cursor = db.cursor()
    try:
        # Gá»i Stored Procedure
        cursor.execute("EXEC dbo.sp_LoginUser @Username=?, @Password=?", (request.username, request.password))
        row = cursor.fetchone()
        
        if not row:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="TÃ i khoáº£n hoáº·c máº­t kháº©u khÃ´ng chÃ­nh xÃ¡c"
            )
            
        user_dict = row_to_dict(cursor, row)
        
        # Mapping cÃ¡c trÆ°á» ng cho phÃ¹ há»£p vá»›i UserProfile schema
        # LÆ°u Ã½: Náº¿u SP khÃ´ng tráº£ vá»  avatarUrl, ta gÃ¡n None
        if 'avatarUrl' not in user_dict:
            user_dict['avatarUrl'] = None
            
        # Táº¡o jwt tokens
        user_id = str(user_dict['id'])
        access_token = create_access_token(data={"sub": user_id, "role": user_dict.get('role', '')})
        refresh_token = create_refresh_token(data={"sub": user_id})
        
        # Save refresh_token into db (single session)
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
    BƯỚC 1: Gửi mã OTP xác nhận quên mật khẩu đến email của người dùng.
    """
    cursor = db.cursor()
    try:
        # 1. Tìm kiếm người dùng trong cơ sở dữ liệu dựa trên email hoặc số điện thoại (contact)
        # Sử dụng Stored Procedure sp_FindUserByContact để tìm chính xác tài khoản.
        cursor.execute("EXEC dbo.sp_FindUserByContact @Contact=?", (request.contact,))
        row = cursor.fetchone()
        
        # Nếu không có dòng nào được trả về, nghĩa là email chưa được đăng ký trong hệ thống
        if not row:
             return SendResetCodeResponse(
                 success=False,
                 message="Không tìm thấy tài khoản với thông tin liên lạc này"
             )
        
        # Lấy ID của người dùng từ kết quả truy vấn
        user_id = row[0]
        
        # 2. Tạo mã OTP ngẫu nhiên gồm 6 chữ số
        otp_code = str(random.randint(100000, 999999))
        code_id = str(uuid.uuid4())
        
        # 3. Lưu trữ mã OTP này vào bảng password_reset_codes
        # Đặt thời gian hết hạn là 5 phút (DATEADD(minute, 5, GETDATE()))
        # Trạng thái ban đầu: chưa xác thực (is_verified = 0) và chưa sử dụng (is_used = 0)
        cursor.execute('''
            INSERT INTO dbo.password_reset_codes 
            (id, user_id, contact, otp_code, expires_at, created_at, is_verified, is_used)
            VALUES (?, ?, ?, ?, DATEADD(minute, 5, GETDATE()), GETDATE(), 0, 0)
        ''', (code_id, user_id, request.contact, otp_code))
        db.commit() # Xác nhận lưu vào Database

        # 4. Che bớt một phần email để hiển thị an toàn trên màn hình (Ví dụ: thup***com)
        masked = request.contact[:4] + "***" + request.contact[-3:] if len(request.contact) > 6 else "***"
        
        # 5. Gửi email chứa mã OTP ở dưới nền (background_tasks)
        # Việc này giúp API phản hồi ngay lập tức mà không phải chờ quá trình gửi mail (thường mất vài giây)
        background_tasks.add_task(send_otp_email, request.contact, otp_code)
        
        return SendResetCodeResponse(
            success=True,
            message="Mã xác thực đã được gửi về email của bạn",
            maskedContact=masked
        )
    except Exception as e:
        db.rollback() # Hoàn tác nếu có lỗi
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()

@router.post("/forgot-password/verify", response_model=VerifyResetCodeResponse)
def verify_reset_code(request: VerifyResetCodeRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    BƯỚC 2: Kiểm tra tính hợp lệ của mã OTP mà người dùng nhập vào.
    """
    cursor = db.cursor()
    try:
        # 1. Truy vấn mã OTP trong Database để kiểm tra các điều kiện:
        # - Đúng địa chỉ liên hệ (contact) và đúng mã OTP người dùng nhập.
        # - Mã chưa từng được xác thực (is_verified = 0) và chưa được dùng để đổi pass (is_used = 0).
        # - Thời gian hiện tại chưa vượt quá thời gian hết hạn của mã (expires_at > GETDATE()).
        cursor.execute('''
            SELECT id, user_id 
            FROM dbo.password_reset_codes 
            WHERE contact = ? AND otp_code = ? 
              AND is_verified = 0 AND is_used = 0 
              AND expires_at > GETDATE()
        ''', (request.contact, request.code))
        row = cursor.fetchone()
        
        # Nếu không tìm thấy hoặc sai điều kiện (VD: quá hạn), báo lỗi
        if not row:
            return VerifyResetCodeResponse(
                success=False,
                message="Mã xác thực không đúng hoặc đã hết hạn"
            )
            
        code_id = row[0]
        # 2. Sinh ra một "chìa khóa tạm thời" (reset_token) để dùng cho bước đổi mật khẩu tiếp theo
        reset_token = str(uuid.uuid4())
        
        # 3. Cập nhật trạng thái của mã OTP này thành "đã xác thực" (is_verified = 1) 
        # và lưu lại thời gian xác thực cùng với chìa khóa tạm (reset_token)
        cursor.execute('''
            UPDATE dbo.password_reset_codes 
            SET is_verified = 1, verified_at = GETDATE(), reset_token = ?
            WHERE id = ?
        ''', (reset_token, code_id))
        db.commit()
        
        # 4. Trả về resetToken cho ứng dụng. App sẽ giữ token này để tiến hành đổi pass ở bước 3.
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
    BƯỚC 3: Đặt lại mật khẩu mới dựa trên khóa (reset_token) lấy từ bước 2.
    """
    cursor = db.cursor()
    try:
        # 1. Tra cứu lại bản ghi chứa reset_token để tìm user_id tương ứng
        # Cần phải đảm bảo token hợp lệ, đã xác thực OTP (is_verified = 1) và CHƯA SỬ DỤNG (is_used = 0)
        # Token này cũng cần phải chưa hết hạn theo thời gian được cấu hình (expires_at)
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
        
        # 2. Cập nhật mật khẩu mới của người dùng vào bảng users
        # Ở đây đang dùng mật khẩu plain text (tuy nhiên thực tế nên hash mật khẩu trước khi lưu)
        cursor.execute('''
            UPDATE dbo.users 
            SET password_hash = ?
            WHERE id = ?
        ''', (request.newPassword, user_id))
        
        # 3. Đánh dấu bản ghi OTP này đã hoàn tất quá trình đổi mật khẩu (is_used = 1)
        # Việc này đảm bảo reset_token không thể bị tái sử dụng (chống tấn công Replay Attack)
        cursor.execute('''
            UPDATE dbo.password_reset_codes 
            SET is_used = 1, used_at = GETDATE()
            WHERE id = ?
        ''', (code_id,))
        
        db.commit() # Xác nhận toàn bộ tiến trình và lưu lại
        
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
    Cáº­p nháº­t FCM Token cho user
    """
    cursor = db.cursor()
    try:
        cursor.execute("UPDATE dbo.users SET fcm_token = ? WHERE id = ?", (req.fcm_token, req.user_id))
        db.commit()
        return {"success": True, "message": "Cáº­p nháº­t token thÃ nh cÃ´ng"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()

@router.post("/refresh-token", response_model=LoginResponse)
def refresh_token(request: RefreshTokenRequest, db: pyodbc.Connection = Depends(get_db)):
    """
    Sử dụng Refresh Token để lấy Access Token và Refresh Token mới, kèm theo thông tin UserProfile.
    Đảm bảo tính năng Single Session: Refresh token truyền lên phải trùng với trong DB.
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
            
        # Single Session Check
        db_refresh_token = row.refresh_token
        if db_refresh_token != request.refresh_token:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Bạn đã đăng nhập ở thiết bị khác")
            
        # Generate new tokens
        role = row.role
        new_access_token = create_access_token(data={"sub": user_id, "role": role})
        new_refresh_token = create_refresh_token(data={"sub": user_id})
        
        # Save new refresh token
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
