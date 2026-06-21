from fastapi import APIRouter, Depends, HTTPException
import uuid
from database import get_db
from schemas import Department
from cache import department_cache

router = APIRouter(prefix="/api/departments", tags=["Departments"])

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def _get_user_role_and_dept(user_id: str, db) -> tuple[str, str]:
    """Trả về (role lowercase, department_id) của user."""
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
    return role in ["admin", "quản trị viên"]

def _is_manager(role: str) -> bool:
    return role in ["trưởng phòng", "manager", "trưởng khoa"]

def _require_admin(role: str):
    """Chỉ Admin mới được thực hiện thao tác ghi (tạo/sửa/xóa) phòng ban."""
    if not _is_admin(role):
        raise HTTPException(
            status_code=403,
            detail="Chỉ Quản trị viên mới có quyền thực hiện thao tác này"
        )


# ─────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────

@router.get("", response_model=list[Department])
def get_departments(user_id: str, db=Depends(get_db)):
    """
    GET /api/departments?user_id=...
    Lấy danh sách phòng ban (có cache 10 phút).
    - Admin  : thấy TẤT CẢ phòng ban
    - Manager: chỉ thấy phòng ban CỦA MÌNH
    - User   : bị từ chối 403
    """
    role, dept_id = _get_user_role_and_dept(user_id, db)

    if not _is_admin(role) and not _is_manager(role):
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền truy cập danh sách phòng ban"
        )

    # Manager chỉ trả về đúng phòng ban của mình
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

    # Admin: trả về tất cả phòng ban (có cache)
    cache_key = "departments:all"
    cached = department_cache.get(cache_key)
    if cached is not None:
        return cached

    cursor = db.cursor()
    try:
        cursor.execute("SELECT id, name FROM dbo.departments ORDER BY name")
        rows = cursor.fetchall()
        result = [Department(id=row[0], name=row[1]) for row in rows]
        department_cache.set(cache_key, result)
        return result
    finally:
        cursor.close()


@router.post("", response_model=dict)
def create_department(name: str, user_id: str, db=Depends(get_db)):
    """
    POST /api/departments?name=...&user_id=...
    Thêm phòng ban mới – Chỉ Admin.
    """
    role, _ = _get_user_role_and_dept(user_id, db)
    _require_admin(role)

    cursor = db.cursor()
    try:
        cursor.execute(
            "SELECT id FROM dbo.departments WHERE LOWER(name) = LOWER(?)",
            (name.strip(),)
        )
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Tên phòng ban đã tồn tại")

        dept_id = str(uuid.uuid4())[:20]
        cursor.execute(
            "INSERT INTO dbo.departments (id, name) VALUES (?, ?)",
            (dept_id, name.strip())
        )
        db.commit()
        department_cache.clear()    # Invalidate cache
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
    PUT /api/departments/{dept_id}?name=...&user_id=...
    Đổi tên phòng ban – Chỉ Admin.
    """
    role, _ = _get_user_role_and_dept(user_id, db)
    _require_admin(role)

    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.departments WHERE id = ?", (dept_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Phòng ban không tồn tại")

        cursor.execute(
            "UPDATE dbo.departments SET name = ? WHERE id = ?",
            (name.strip(), dept_id)
        )
        db.commit()
        department_cache.clear()    # Invalidate cache
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
    DELETE /api/departments/{dept_id}?user_id=...
    Xóa phòng ban – Chỉ Admin. Chỉ xóa được nếu không còn nhân sự nào.
    """
    role, _ = _get_user_role_and_dept(user_id, db)
    _require_admin(role)

    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.departments WHERE id = ?", (dept_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Phòng ban không tồn tại")

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

        cursor.execute("DELETE FROM dbo.departments WHERE id = ?", (dept_id,))
        db.commit()
        department_cache.clear()    # Invalidate cache
        return {"success": True, "message": "Xóa phòng ban thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()
