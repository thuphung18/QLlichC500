from fastapi import APIRouter, Depends, HTTPException
import uuid

from database import get_db
from schemas import CreateUserRequest, UpdateProfileRequest, UpdatePasswordRequest, UserProfile

router = APIRouter(
    prefix="/api/users",
    tags=["Users"]
)

@router.post("/")
def create_user(request: CreateUserRequest, db=Depends(get_db)):
    """
    API Endpoint: POST /api/users/
    Mục đích: Xử lý yêu cầu tạo tài khoản người dùng mới (Dành riêng cho Admin sử dụng trên App).
    Đầu vào: Thông tin user mới (Tên đăng nhập, Họ tên, Vai trò, Đơn vị, Phòng ban, Email, SĐT)
    Đầu ra: Thông báo thành công kèm theo userId vừa tạo.
    """
    # Mở một con trỏ tới DB để thực thi truy vấn SQL
    cursor = db.cursor()
    try:
        # BƯỚC 1: Kiểm tra chống trùng lặp tên đăng nhập (Username)
        # Để đảm bảo mỗi username là duy nhất trong hệ thống
        cursor.execute("SELECT id FROM dbo.users WHERE username = ?", (request.username,))
        existing = cursor.fetchone()
        if existing:
            # Nếu đã có người dùng tên này, trả về mã lỗi 400 Bad Request cho App
            raise HTTPException(status_code=400, detail="Tên đăng nhập đã tồn tại")
        
        # BƯỚC 2: Sinh UUID cho user mới
        # Hệ thống dùng chuỗi định danh ngẫu nhiên (UUID v4) làm khóa chính thay vì số thứ tự
        user_id = str(uuid.uuid4())
        
        # BƯỚC 3: Cài đặt mật khẩu mặc định ban đầu là '123456'
        # Trong thực tế, chuỗi này nên được băm (hash) qua bcrypt trước khi lưu, 
        # nhưng ở đây đang lưu chuỗi gốc (plain-text) để phục vụ cho mục đích Demo/App đồ án
        default_password = '123456'

        # BƯỚC 4: Chèn thông tin tài khoản mới vào cơ sở dữ liệu
        # Sử dụng tham số hóa (?) để chống tấn công SQL Injection
        cursor.execute("""
            INSERT INTO dbo.users (
                id, username, password_hash, full_name, role, unit, department_id, email, phone, is_active
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        """, (
            user_id,
            request.username,
            default_password,
            request.fullName,
            request.role,
            request.unit,
            request.departmentId,
            request.email,
            request.phone
        ))
        
        # BƯỚC 5: Xác nhận thay đổi vào Database (Commit Transaction)
        db.commit()
        return {"success": True, "message": "Tạo tài khoản thành công", "userId": user_id}
        
    except HTTPException:
        # Giữ nguyên các lỗi nghiệp vụ chủ động ném ra ở trên (ví dụ: Trùng tên đăng nhập)
        raise
    except Exception as e:
        # Hủy bỏ mọi thay đổi nếu có lỗi rớt mạng hoặc lỗi SQL hệ thống xảy ra
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")

@router.put("/{user_id}/profile", response_model=UserProfile)
def update_profile(user_id: str, request: UpdateProfileRequest, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.users WHERE id = ?", (user_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Người dùng không tồn tại")
            
        cursor.execute('''
            UPDATE dbo.users 
            SET full_name = ?, email = ?, phone = ?
            WHERE id = ?
        ''', (request.fullName, request.email, request.phone, user_id))
        db.commit()
        
        # Lấy lại thông tin user để trả về
        cursor.execute('''
            SELECT u.id, u.username, u.full_name AS fullName, u.role, u.unit, 
                   d.name AS departmentName, u.department_id AS departmentId,
                   u.email, u.phone, u.avatar_url AS avatarUrl
            FROM dbo.users u
            LEFT JOIN dbo.departments d ON u.department_id = d.id
            WHERE u.id = ?
        ''', (user_id,))
        
        row = cursor.fetchone()
        columns = [column[0] for column in cursor.description]
        user_dict = dict(zip(columns, row))
        
        return UserProfile(**user_dict)
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")

@router.put("/{user_id}/password")
def update_password(user_id: str, request: UpdatePasswordRequest, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.execute("SELECT password_hash FROM dbo.users WHERE id = ?", (user_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Người dùng không tồn tại")
            
        current_password = row[0]
        if current_password != request.oldPassword:
            raise HTTPException(status_code=400, detail="Mật khẩu cũ không chính xác")
            
        cursor.execute('''
            UPDATE dbo.users 
            SET password_hash = ?
            WHERE id = ?
        ''', (request.newPassword, user_id))
        db.commit()
        
        return {"success": True, "message": "Cập nhật mật khẩu thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
