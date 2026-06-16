from fastapi import APIRouter, Depends, HTTPException
import uuid
from database import get_db
from schemas import Department

router = APIRouter(prefix="/api/departments", tags=["Departments"])

def _get_user_role(user_id: str, db) -> str:
    """Truy vấn role của user từ DB, trả về chuỗi lowercase."""
    cursor = db.cursor()
    cursor.execute("SELECT role FROM dbo.users WHERE id = ? AND is_active = 1", (user_id,))
    row = cursor.fetchone()
    cursor.close()
    if not row:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại hoặc đã bị khóa")
    return row[0].lower().strip()

def _require_admin(user_id: str, db):
    """Bắt buộc user phải là Admin, nếu không trả 403."""
    role = _get_user_role(user_id, db)
    if role not in ["admin", "quản trị viên"]:
        raise HTTPException(status_code=403, detail="Chỉ Quản trị viên mới có quyền thực hiện thao tác này")


@router.get("", response_model=list[Department])
def get_departments(user_id: str, db=Depends(get_db)):
    """
    GET /api/departments?user_id=...
    Lấy danh sách tất cả phòng ban - Chỉ Admin.
    """
    _require_admin(user_id, db)
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id, name FROM dbo.departments ORDER BY name")
        rows = cursor.fetchall()
        return [Department(id=row[0], name=row[1]) for row in rows]
    finally:
        cursor.close()


@router.post("", response_model=dict)
def create_department(name: str, user_id: str, db=Depends(get_db)):
    """
    POST /api/departments?name=...&user_id=...
    Thêm phòng ban mới - Chỉ Admin.
    """
    _require_admin(user_id, db)
    cursor = db.cursor()
    try:
        # Kiểm tra tên phòng ban đã tồn tại chưa
        cursor.execute("SELECT id FROM dbo.departments WHERE LOWER(name) = LOWER(?)", (name.strip(),))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Tên phòng ban đã tồn tại")

        dept_id = str(uuid.uuid4())[:20]  # Dùng ID ngắn cho phòng ban
        cursor.execute(
            "INSERT INTO dbo.departments (id, name) VALUES (?, ?)",
            (dept_id, name.strip())
        )
        db.commit()
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
    Đổi tên phòng ban - Chỉ Admin.
    """
    _require_admin(user_id, db)
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.departments WHERE id = ?", (dept_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Phòng ban không tồn tại")

        cursor.execute("UPDATE dbo.departments SET name = ? WHERE id = ?", (name.strip(), dept_id))
        db.commit()
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
    Xóa phòng ban - Chỉ Admin. Chỉ xóa được nếu không còn nhân sự nào.
    """
    _require_admin(user_id, db)
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.departments WHERE id = ?", (dept_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Phòng ban không tồn tại")

        # Kiểm tra còn nhân sự nào thuộc phòng ban không
        cursor.execute("SELECT COUNT(*) FROM dbo.users WHERE department_id = ? AND is_active = 1", (dept_id,))
        count = cursor.fetchone()[0]
        if count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Không thể xóa: Phòng ban này còn {count} nhân sự đang hoạt động. Vui lòng chuyển họ sang phòng khác trước."
            )

        cursor.execute("DELETE FROM dbo.departments WHERE id = ?", (dept_id,))
        db.commit()
        return {"success": True, "message": "Xóa phòng ban thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi database: {str(e)}")
    finally:
        cursor.close()
