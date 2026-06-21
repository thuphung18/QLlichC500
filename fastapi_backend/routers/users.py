# routers/users.py – Phân hệ Quản lý Người dùng (Users Management).
#
# Phân quyền truy cập (RBAC):
#   - Xem danh sách người dùng: Admin được xem tất cả, Manager chỉ được xem nhân viên cùng phòng ban.
#   - Tạo tài khoản người dùng mới: Admin tạo cho bất kỳ ai, Manager chỉ được tạo cho phòng ban của mình (mật khẩu mặc định là '123456').
#   - Sửa thông tin tài khoản: Admin sửa bất kỳ ai, Manager sửa người cùng phòng và không thể tự đổi vai trò của họ lên Admin. Không cho phép tự khóa tài khoản của chính mình.
#   - Xóa tài khoản: Admin/Manager được quyền xóa tài khoản nhân sự cấp dưới sau khi xóa hết các liên kết khóa ngoại.
#   - Tự chỉnh sửa Profile/Đổi mật khẩu: Tất cả người dùng đều có thể tự thực hiện.

from fastapi import APIRouter, Depends, HTTPException
import uuid

from database import get_db
from schemas import (
    CreateUserRequest, UpdateProfileRequest, UpdatePasswordRequest,
    UserProfile, AdminUpdateUserRequest, UserDetail
)

router = APIRouter(
    prefix="/api/users",
    tags=["Users"]
)

# ─────────────────────────────────────────────
# 1. Các hàm hỗ trợ phân quyền & xác thực (Helpers)
# ─────────────────────────────────────────────

def _get_role(user_id: str, db) -> str:
    """Truy vấn lấy vai trò (role) của user và đưa về dạng chữ thường. Ném 404 nếu không tìm thấy."""
    cursor = db.cursor()
    cursor.execute("SELECT role FROM dbo.users WHERE id = ? AND is_active = 1", (user_id,))
    row = cursor.fetchone()
    cursor.close()
    if not row:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại hoặc đã bị khóa")
    return row[0].lower().strip()


def _is_admin(role: str) -> bool:
    """Kiểm tra vai trò Admin."""
    return role in ["admin", "quản trị viên"]


def _is_manager(role: str) -> bool:
    """Kiểm tra vai trò Trưởng phòng / Trưởng khoa."""
    return role in ["trưởng phòng", "manager", "trưởng khoa"]


def _require_admin(user_id: str, db):
    """Yêu cầu quyền Admin, nếu không ném 403."""
    role = _get_role(user_id, db)
    if not _is_admin(role):
        raise HTTPException(status_code=403, detail="Chỉ Quản trị viên mới có quyền thực hiện thao tác này")


def _require_admin_or_manager(user_id: str, db) -> tuple[str, str]:
    """
    Xác thực quyền Admin hoặc Manager.
    Trả về: tuple (role chữ thường, department_id của người gọi).
    """
    cursor = db.cursor()
    cursor.execute("SELECT role, department_id FROM dbo.users WHERE id = ? AND is_active = 1", (user_id,))
    row = cursor.fetchone()
    cursor.close()
    if not row:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại hoặc đã bị khóa")
    role = row[0].lower().strip()
    dept_id = str(row[1]) if row[1] else ""
    if not _is_admin(role) and not _is_manager(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền thực hiện thao tác này")
    return role, dept_id


# ─────────────────────────────────────────────
# 2. Các Endpoint điều hướng (Controllers)
# ─────────────────────────────────────────────

@router.get("/", response_model=list[UserDetail])
def get_all_users(admin_id: str, db=Depends(get_db)):
    """
    Lấy danh sách người dùng trong hệ thống.
    
    Phân quyền:
      - Admin: Thấy đầy đủ thông tin của toàn bộ người dùng trong hệ thống.
      - Manager: Chỉ thấy thông tin của các nhân viên thuộc cùng khoa/phòng ban với mình.
    """
    role, dept_id = _require_admin_or_manager(admin_id, db)
    cursor = db.cursor()
    try:
        if _is_admin(role):
            # Admin truy vấn toàn bộ
            cursor.execute("""
                SELECT u.id, u.username, u.full_name, u.role, u.unit,
                       u.department_id, ISNULL(d.name, ''), u.email, u.phone, u.is_active
                FROM dbo.users u
                LEFT JOIN dbo.departments d ON u.department_id = d.id
                ORDER BY u.full_name
            """)
        else:
            # Manager chỉ lấy nhân sự cùng phòng
            cursor.execute("""
                SELECT u.id, u.username, u.full_name, u.role, u.unit,
                       u.department_id, ISNULL(d.name, ''), u.email, u.phone, u.is_active
                FROM dbo.users u
                LEFT JOIN dbo.departments d ON u.department_id = d.id
                WHERE u.department_id = ?
                ORDER BY u.full_name
            """, (dept_id,))
        rows = cursor.fetchall()
        result = []
        for row in rows:
            result.append(UserDetail(
                id=str(row[0]),
                username=str(row[1]),
                fullName=str(row[2]),
                role=str(row[3]),
                unit=str(row[4]) if row[4] else '',
                departmentId=str(row[5]) if row[5] else '',
                departmentName=str(row[6]),
                email=str(row[7]) if row[7] else None,
                phone=str(row[8]) if row[8] else None,
                isActive=bool(row[9]),
            ))
        return result
    finally:
        cursor.close()


@router.post("/")
def create_user(request: CreateUserRequest, admin_id: str, db=Depends(get_db)):
    """
    Tạo tài khoản người dùng mới.
    
    Quy trình:
      1. Xác thực quyền tạo tài khoản (Admin hoặc Manager).
      2. Kiểm tra tên đăng nhập (username) có bị trùng lặp không.
      3. Gán mật khẩu mặc định khởi tạo ban đầu là '123456'.
      4. Manager chỉ được tạo tài khoản thuộc khoa của họ, Admin có thể tạo ở bất kỳ khoa nào.
    """
    role, dept_id = _require_admin_or_manager(admin_id, db)
    
    # Manager bị ép buộc gán phòng ban của user mới là phòng ban của Manager
    final_dept_id = request.departmentId
    if not _is_admin(role):
        final_dept_id = dept_id

    cursor = db.cursor()
    try:
        # Kiểm tra trùng tên đăng nhập
        cursor.execute("SELECT id FROM dbo.users WHERE username = ?", (request.username,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Tên đăng nhập đã tồn tại")

        user_id = str(uuid.uuid4())
        default_password = '123456'  # Mật khẩu mặc định

        cursor.execute("""
            INSERT INTO dbo.users (
                id, username, password_hash, full_name, role, unit, department_id, email, phone, is_active
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        """, (
            user_id, request.username, default_password,
            request.fullName, request.role, request.unit,
            final_dept_id, request.email, request.phone
        ))
        db.commit()
        return {"success": True, "message": "Tạo tài khoản thành công", "userId": user_id}

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()


@router.put("/{user_id}/admin", response_model=dict)
def admin_update_user(user_id: str, request: AdminUpdateUserRequest, admin_id: str, db=Depends(get_db)):
    """
    Chỉnh sửa thông tin tài khoản người dùng (FullName, Role, Phòng ban, Trạng thái hoạt động).
    
    Ràng buộc an toàn:
      - Admin được quyền chỉnh sửa bất kỳ ai.
      - Manager chỉ được sửa thông tin người thuộc cùng khoa và không thể nâng quyền của nhân viên lên Admin.
      - Không cho phép Admin/Manager tự khóa tài khoản của chính bản thân họ.
    """
    role, dept_id = _require_admin_or_manager(admin_id, db)
    cursor = db.cursor()
    try:
        cursor.execute("SELECT department_id, role FROM dbo.users WHERE id = ?", (user_id,))
        target_user = cursor.fetchone()
        if not target_user:
            raise HTTPException(status_code=404, detail="Người dùng không tồn tại")
            
        target_dept_id = str(target_user[0]) if target_user[0] else ""
        
        # Ràng buộc bảo mật của Manager
        if not _is_admin(role):
            if target_dept_id != dept_id or request.departmentId != dept_id:
                raise HTTPException(status_code=403, detail="Bạn chỉ có quyền chỉnh sửa thành viên trong khoa của mình")
            # Chặn Manager cấp quyền Admin cho người khác
            if request.role.lower().strip() in ["admin", "quản trị viên"]:
                 raise HTTPException(status_code=403, detail="Không thể gán quyền Quản trị viên")

        # Chặn tự khóa tài khoản bản thân
        if user_id == admin_id and not request.isActive:
            raise HTTPException(status_code=400, detail="Không thể tự khóa tài khoản của chính mình")

        cursor.execute("""
            UPDATE dbo.users
            SET full_name = ?, role = ?, unit = ?, department_id = ?,
                email = ?, phone = ?, is_active = ?
            WHERE id = ?
        """, (
            request.fullName, request.role, request.unit, request.departmentId,
            request.email, request.phone, 1 if request.isActive else 0, user_id
        ))
        db.commit()
        return {"success": True, "message": "Cập nhật thông tin người dùng thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()


@router.delete("/{user_id}", response_model=dict)
def delete_user(user_id: str, admin_id: str, db=Depends(get_db)):
    """
    Xóa tài khoản người dùng khỏi hệ thống.
    
    Quy trình dọn dẹp liên kết (Foreign Keys):
      1. Không cho phép tự xóa tài khoản chính mình.
      2. Manager chỉ được xóa nhân sự thuộc khoa của mình.
      3. Trước khi xóa user trong bảng users, tiến hành xóa sạch dữ liệu liên quan ở các bảng khóa ngoại:
         - personal_notifications
         - password_reset_codes
         - fcm_tokens (hoặc cập nhật token = null ở bảng users)
         - schedule_participants
         - schedules (các lịch do user này tạo ra)
    """
    role, dept_id = _require_admin_or_manager(admin_id, db)
    if user_id == admin_id:
        raise HTTPException(status_code=400, detail="Không thể xóa tài khoản của chính mình")

    cursor = db.cursor()
    try:
        cursor.execute("SELECT department_id FROM dbo.users WHERE id = ?", (user_id,))
        target_user = cursor.fetchone()
        if not target_user:
            raise HTTPException(status_code=404, detail="Người dùng không tồn tại")
            
        target_dept_id = str(target_user[0]) if target_user[0] else ""
        if not _is_admin(role) and target_dept_id != dept_id:
            raise HTTPException(status_code=403, detail="Bạn chỉ có thể xóa thành viên thuộc khoa của mình")

        # Giải phóng các bảng khóa ngoại trước để tránh lỗi ràng buộc toàn vẹn cơ sở dữ liệu
        cursor.execute("DELETE FROM dbo.personal_notifications WHERE user_id = ?", (user_id,))
        cursor.execute("DELETE FROM dbo.password_reset_codes WHERE user_id = ?", (user_id,))
        cursor.execute("DELETE FROM dbo.fcm_tokens WHERE user_id = ?", (user_id,))
        cursor.execute("DELETE FROM dbo.schedule_participants WHERE user_id = ?", (user_id,))
        cursor.execute("DELETE FROM dbo.schedules WHERE created_by_user_id = ?", (user_id,))
        
        # Tiến hành xóa User
        cursor.execute("DELETE FROM dbo.users WHERE id = ?", (user_id,))
        db.commit()
        return {"success": True, "message": "Đã xóa tài khoản người dùng"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()


@router.put("/{user_id}/profile", response_model=UserProfile)
def update_profile(user_id: str, request: UpdateProfileRequest, db=Depends(get_db)):
    """
    Người dùng tự cập nhật hồ sơ cá nhân (FullName, Email, Phone).
    Trả về thông tin UserProfile mới cập nhật để đồng bộ ở client.
    """
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

        # Truy vấn thông tin mới kèm JOIN tên phòng ban để phản hồi về client
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
    finally:
        cursor.close()


@router.put("/{user_id}/password")
def update_password(user_id: str, request: UpdatePasswordRequest, db=Depends(get_db)):
    """
    Người dùng tự thay đổi mật khẩu của mình từ bên trong ứng dụng.
    Yêu cầu mật khẩu cũ phải khớp chính xác với mật khẩu hiện tại trong DB.
    """
    cursor = db.cursor()
    try:
        cursor.execute("SELECT password_hash FROM dbo.users WHERE id = ?", (user_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Người dùng không tồn tại")

        current_password = row[0]
        if current_password != request.oldPassword:
            raise HTTPException(status_code=400, detail="Mật khẩu cũ không chính xác")

        # Cập nhật mật khẩu mới
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
    finally:
        cursor.close()

