# routers/departments.py – Phân hệ Quản lý Phòng ban / Khoa (Departments Management).
#
# Quyền hạn thao tác (RBAC):
#   - Xem danh sách phòng ban: Admin thấy toàn bộ phòng ban (có cache), Manager chỉ thấy thông tin phòng ban của mình, User bị chặn (403).
#   - Thêm / Sửa / Xóa phòng ban: Chỉ có Admin có quyền thực hiện. Khi thực hiện thay đổi thành công, hệ thống tự động xóa Cache phòng ban.
#   - Ràng buộc an toàn: Không cho phép xóa phòng ban nếu còn nhân sự đang hoạt động thuộc phòng ban đó.

from fastapi import APIRouter, Depends, HTTPException
import uuid
from database import get_db
from schemas import Department
from cache import department_cache

router = APIRouter(prefix="/api/departments", tags=["Departments"])

# ─────────────────────────────────────────────
# 1. Các hàm hỗ trợ phân quyền & xác thực (Helpers)
# ─────────────────────────────────────────────

def _get_user_role_and_dept(user_id: str, db) -> tuple[str, str]:
    """
    Truy vấn và trả về cặp giá trị: (Role chữ thường đã chuẩn hóa, department_id dạng chuỗi) của User.
    Ném lỗi 404 nếu tài khoản bị khóa hoặc không tồn tại.
    """
    cursor = db.cursor()
    cursor.execute(
        "SELECT role, department_id FROM dbo.users WHERE id = ? AND is_active = 1",
        (user_id,)
    )
    row = cursor.fetchone()
    cursor.close()
    if not row:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại hoặc đã bị khóa")
    return row[0].lower().strip(), str(row[1]) if row[1] else ""


def _is_admin(role: str) -> bool:
    """Kiểm tra xem Role có phải là Quản trị viên (Admin) không."""
    return role in ["admin", "quản trị viên"]


def _is_manager(role: str) -> bool:
    """Kiểm tra xem Role có phải là Trưởng phòng / Trưởng khoa không."""
    return role in ["trưởng phòng", "manager", "trưởng khoa"]


def _require_admin(role: str):
    """Bắt buộc Role phải là Admin, nếu không ném lỗi 403 Forbidden."""
    if not _is_admin(role):
        raise HTTPException(
            status_code=403,
            detail="Chỉ Quản trị viên mới có quyền thực hiện thao tác này"
        )


# ─────────────────────────────────────────────
# 2. Các Endpoint điều hướng (Controllers)
# ─────────────────────────────────────────────

@router.get("/public", response_model=list[Department])
def get_departments_public(db=Depends(get_db)):
    """
    API Công khai: Lấy danh sách các phòng ban/khoa để hiển thị ở màn hình Đăng ký.
    Không yêu cầu xác thực Token. Sử dụng Cache để tối ưu hiệu năng.
    """
    cache_key = "departments:all"
    cached = department_cache.get(cache_key)
    if cached is not None:
        return cached

    cursor = db.cursor()
    try:
        cursor.execute("SELECT id, name FROM dbo.departments ORDER BY name")
        rows = cursor.fetchall()
        result = [Department(id=str(row[0]), name=str(row[1])) for row in rows]
        department_cache.set(cache_key, result)
        return result
    finally:
        cursor.close()


@router.get("", response_model=list[Department])
def get_departments(user_id: str, db=Depends(get_db)):
    """
    Lấy danh sách các phòng ban/khoa có trong hệ thống.
    
    Phân quyền:
      - Admin: Thấy đầy đủ tất cả phòng ban. Sử dụng cache 10 phút để giảm tải truy vấn DB.
      - Manager: Chỉ thấy đúng thông tin phòng ban của chính mình.
      - User khác: Ném lỗi 403.
    """
    role, dept_id = _get_user_role_and_dept(user_id, db)

    if not _is_admin(role) and not _is_manager(role):
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền truy cập danh sách phòng ban"
        )

    # Manager: Chỉ trả về thông tin phòng ban của họ
    if _is_manager(role):
        cursor = db.cursor()
        try:
            cursor.execute("SELECT id, name FROM dbo.departments WHERE id = ?", (dept_id,))
            row = cursor.fetchone()
            if not row:
                return []
            return [Department(id=row[0], name=row[1])]
        finally:
            cursor.close()

    # Admin: Trả về toàn bộ danh sách phòng ban (Có sử dụng TTLCache)
    cache_key = "departments:all"
    cached = department_cache.get(cache_key)
    if cached is not None:
        return cached

    cursor = db.cursor()
    try:
        cursor.execute("SELECT id, name FROM dbo.departments ORDER BY name")
        rows = cursor.fetchall()
        result = [Department(id=row[0], name=row[1]) for row in rows]
        # Lưu vào cache để tái sử dụng
        department_cache.set(cache_key, result)
        return result
    finally:
        cursor.close()


@router.post("", response_model=dict)
def create_department(name: str, user_id: str, db=Depends(get_db)):
    """
    Tạo mới một phòng ban - Chỉ chấp nhận quyền Admin.
    
    Quy trình:
      1. Xác thực quyền Admin.
      2. Kiểm tra tên phòng ban xem đã tồn tại chưa (không phân biệt hoa thường).
      3. Sinh ID ngẫu nhiên, lưu vào DB và tiến hành xóa Cache để đồng bộ dữ liệu mới.
    """
    role, _ = _get_user_role_and_dept(user_id, db)
    _require_admin(role)

    cursor = db.cursor()
    try:
        # Kiểm tra trùng tên phòng ban
        cursor.execute(
            "SELECT id FROM dbo.departments WHERE LOWER(name) = LOWER(?)",
            (name.strip(),)
        )
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Tên phòng ban đã tồn tại")

        # Sinh mã ID độ dài tối đa 20 ký tự
        dept_id = str(uuid.uuid4())[:20]
        cursor.execute(
            "INSERT INTO dbo.departments (id, name) VALUES (?, ?)",
            (dept_id, name.strip())
        )
        db.commit()
        
        # Xóa cache danh sách phòng ban cũ
        department_cache.clear()
        return {"success": True, "message": "Tạo phòng ban thành công", "id": dept_id}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()


@router.put("/{dept_id}", response_model=dict)
def update_department(dept_id: str, name: str, user_id: str, db=Depends(get_db)):
    """
    Thay đổi tên của một phòng ban hiện tại - Chỉ chấp nhận quyền Admin.
    Sau khi cập nhật thành công, xóa Cache phòng ban.
    """
    role, _ = _get_user_role_and_dept(user_id, db)
    _require_admin(role)

    cursor = db.cursor()
    try:
        # Kiểm tra phòng ban đích có tồn tại không
        cursor.execute("SELECT id FROM dbo.departments WHERE id = ?", (dept_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Phòng ban không tồn tại")

        # Cập nhật tên mới
        cursor.execute(
            "UPDATE dbo.departments SET name = ? WHERE id = ?",
            (name.strip(), dept_id)
        )
        db.commit()
        
        # Đồng bộ hóa cache bằng cách xóa dữ liệu đệm cũ
        department_cache.clear()
        return {"success": True, "message": "Cập nhật tên phòng ban thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()


@router.delete("/{dept_id}", response_model=dict)
def delete_department(dept_id: str, user_id: str, db=Depends(get_db)):
    """
    Xóa một phòng ban khỏi hệ thống - Chỉ chấp nhận quyền Admin.
    
    Ràng buộc bảo vệ:
      - Kiểm tra xem phòng ban này có nhân sự nào đang hoạt động không (isActive = 1).
      - Nếu có, từ chối xóa để tránh gây mâu thuẫn dữ liệu (Foreign Key Constraint).
    """
    role, _ = _get_user_role_and_dept(user_id, db)
    _require_admin(role)

    cursor = db.cursor()
    try:
        # Kiểm tra sự tồn tại của phòng ban
        cursor.execute("SELECT id FROM dbo.departments WHERE id = ?", (dept_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Phòng ban không tồn tại")

        # Kiểm tra nhân sự hoạt động trong phòng ban
        cursor.execute(
            "SELECT COUNT(*) FROM dbo.users WHERE department_id = ? AND is_active = 1",
            (dept_id,)
        )
        count = cursor.fetchone()[0]
        if count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Không thể xóa: Phòng ban này còn {count} nhân sự đang hoạt động. Vui lòng chuyển họ sang phòng khác trước."
            )

        # Tiến hành xóa phòng ban
        cursor.execute("DELETE FROM dbo.departments WHERE id = ?", (dept_id,))
        db.commit()
        
        # Xóa bộ nhớ đệm
        department_cache.clear()
        return {"success": True, "message": "Xóa phòng ban thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()

