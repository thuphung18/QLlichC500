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

# ---------- Helper functions ----------

def _get_role(user_id: str, db) -> str:
    """Trả về role của user (lowercase), ném 404 nếu không tìm thấy."""
    cursor = db.cursor()
    cursor.execute("SELECT role FROM dbo.users WHERE id = ? AND is_active = 1", (user_id,))
    row = cursor.fetchone()
    cursor.close()
    if not row:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại hoặc đã bị khóa")
    return row[0].lower().strip()

def _is_admin(role: str) -> bool:
    return role in ["admin", "quản trị viên"]

def _require_admin(user_id: str, db):
    role = _get_role(user_id, db)
    if not _is_admin(role):
        raise HTTPException(status_code=403, detail="Chỉ Quản trị viên mới có quyền thực hiện thao tác này")

# ---------- Endpoints ----------

@router.get("/", response_model=list[UserDetail])
def get_all_users(admin_id: str, db=Depends(get_db)):
    """
    GET /api/users/?admin_id=...
    Lấy danh sách tất cả người dùng - Chỉ Admin.
    """
    _require_admin(admin_id, db)
    cursor = db.cursor()
    try:
        cursor.execute("""
            SELECT u.id, u.username, u.full_name, u.role, u.unit,
                   u.department_id, ISNULL(d.name, ''), u.email, u.phone, u.is_active
            FROM dbo.users u
            LEFT JOIN dbo.departments d ON u.department_id = d.id
            ORDER BY u.full_name
        """)
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
    POST /api/users/?admin_id=...
    Tạo tài khoản người dùng mới - Chỉ Admin.
    """
    _require_admin(admin_id, db)
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.users WHERE username = ?", (request.username,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Tên đăng nhập đã tồn tại")

        user_id = str(uuid.uuid4())
        default_password = '123456'

        cursor.execute("""
            INSERT INTO dbo.users (
                id, username, password_hash, full_name, role, unit, department_id, email, phone, is_active
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        """, (
            user_id, request.username, default_password,
            request.fullName, request.role, request.unit,
            request.departmentId, request.email, request.phone
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
    PUT /api/users/{user_id}/admin?admin_id=...
    Admin chỉnh sửa thông tin, role, phòng ban, trạng thái tài khoản của bất kỳ user nào.
    """
    _require_admin(admin_id, db)
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.users WHERE id = ?", (user_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Người dùng không tồn tại")

        # Không cho phép Admin tự khóa tài khoản của chính mình
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
    DELETE /api/users/{user_id}?admin_id=...
    Admin xóa tài khoản người dùng. Không thể xóa chính mình.
    """
    _require_admin(admin_id, db)
    if user_id == admin_id:
        raise HTTPException(status_code=400, detail="Không thể xóa tài khoản của chính mình")

    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.users WHERE id = ?", (user_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Người dùng không tồn tại")

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
    PUT /api/users/{user_id}/profile
    Người dùng tự cập nhật thông tin cá nhân (Họ tên, SĐT, Email).
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
    PUT /api/users/{user_id}/password
    Người dùng tự đổi mật khẩu.
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
