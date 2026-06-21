from fastapi import APIRouter, Depends, HTTPException, Query
import pyodbc
from typing import List, Optional
import uuid
from datetime import datetime
from database import get_db
from schemas import ScheduleItem, ScheduleListResponse, CreateScheduleRequest, FormDataResponse, Department, UserCompact
from cache import schedule_cache, department_cache, make_schedule_key, invalidate_schedules

router = APIRouter(prefix="/api/schedules", tags=["Schedules"])

# ─────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────

def row_to_dict(cursor, row):
    if row is None:
        return None
    columns = [column[0] for column in cursor.description]
    return dict(zip(columns, row))

def map_schedule_row(row_dict: dict) -> dict:
    """Map một row của SP thành dictionary chuẩn bị cho Schema ScheduleItem."""
    if 'startTime' in row_dict and row_dict['startTime']:
        row_dict['startTime'] = str(row_dict['startTime'])[:5]
    if 'endTime' in row_dict and row_dict['endTime']:
        row_dict['endTime'] = str(row_dict['endTime'])[:5]

    participants_text = row_dict.get('participantsText', '') or ''
    row_dict['participants'] = [p for p in participants_text.split('|') if p]

    ids_text = row_dict.get('participantUserIdsText', '') or ''
    row_dict['participantUserIds'] = [i for i in ids_text.split('|') if i]

    row_dict.pop('participantsText', None)
    row_dict.pop('participantUserIdsText', None)

    return row_dict

def _get_user_info(user_id: str, db) -> dict:
    """Trả về dict chứa role và department_id của user."""
    cursor = db.cursor()
    cursor.execute(
        "SELECT role, department_id FROM dbo.users WHERE id = ? AND is_active = 1",
        (user_id,)
    )
    row = cursor.fetchone()
    cursor.close()
    if not row:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại hoặc đã bị khóa")
    return {"role": row[0].lower().strip(), "departmentId": str(row[1]) if row[1] else ""}

def _is_admin(role: str) -> bool:
    return role in ["admin", "quản trị viên"]

def _is_manager(role: str) -> bool:
    return role in ["trưởng phòng", "manager", "trưởng khoa"]

def _can_create_schedule(role: str) -> bool:
    return _is_admin(role) or _is_manager(role)

def _fetch_schedules(user_id: str, db, mode: str = "all",
                     day_index: Optional[int] = None,
                     keyword: Optional[str] = None) -> List[ScheduleItem]:
    """Thực hiện truy vấn SP và trả về danh sách lịch."""
    cursor = db.cursor()
    try:
        if day_index is not None:
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?, @DayIndex=?",
                (user_id, day_index)
            )
        elif keyword:
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?, @Keyword=?",
                (user_id, keyword)
            )
        elif mode != "all":
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?, @Mode=?",
                (user_id, mode)
            )
        else:
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?",
                (user_id,)
            )
        rows = cursor.fetchall()
        return [ScheduleItem(**map_schedule_row(row_to_dict(cursor, row))) for row in rows]
    finally:
        cursor.close()

# ─────────────────────────────────────────────
# GET Endpoints (với Cache)
# ─────────────────────────────────────────────

@router.get("", response_model=List[ScheduleItem])
def get_all_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """Lấy toàn bộ lịch theo phân quyền RBAC (có cache 5 phút)."""
    cache_key = make_schedule_key(user_id, "all")
    cached = schedule_cache.get(cache_key)
    if cached is not None:
        return cached

    result = _fetch_schedules(user_id, db)
    schedule_cache.set(cache_key, result)
    return result


@router.get("/day/{day_index}", response_model=List[ScheduleItem])
def get_schedules_by_day(day_index: int, user_id: str = "u001",
                         db: pyodbc.Connection = Depends(get_db)):
    """Lấy lịch theo thứ - có phân quyền RBAC (có cache 5 phút)."""
    cache_key = make_schedule_key(user_id, "day", day_index)
    cached = schedule_cache.get(cache_key)
    if cached is not None:
        return cached

    result = _fetch_schedules(user_id, db, day_index=day_index)
    schedule_cache.set(cache_key, result)
    return result


@router.get("/my", response_model=List[ScheduleItem])
def get_my_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """Lấy lịch cá nhân (có cache 5 phút)."""
    cache_key = make_schedule_key(user_id, "my")
    cached = schedule_cache.get(cache_key)
    if cached is not None:
        return cached

    result = _fetch_schedules(user_id, db, mode="my")
    schedule_cache.set(cache_key, result)
    return result


@router.get("/department", response_model=List[ScheduleItem])
def get_department_schedules(user_id: str = "u001",
                             db: pyodbc.Connection = Depends(get_db)):
    """Lấy lịch phòng ban (có cache 5 phút)."""
    cache_key = make_schedule_key(user_id, "department")
    cached = schedule_cache.get(cache_key)
    if cached is not None:
        return cached

    result = _fetch_schedules(user_id, db, mode="department")
    schedule_cache.set(cache_key, result)
    return result


@router.get("/search", response_model=List[ScheduleItem])
def search_schedules(
    keyword: str = Query(..., description="Từ khoá tìm kiếm"),
    user_id: str = "u001",
    db: pyodbc.Connection = Depends(get_db)
):
    """Tìm kiếm lịch theo từ khoá – không cache (kết quả thay đổi liên tục)."""
    return _fetch_schedules(user_id, db, keyword=keyword)


@router.get("/metadata/form-data", response_model=FormDataResponse)
def get_form_data(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy danh sách Khoa và Users để hiển thị trên Dropdown khi tạo lịch.
    Có cache 10 phút cho danh sách phòng ban.
    """
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền tạo lịch")

    # Departments: Admin thấy tất cả, Manager chỉ thấy phòng của mình
    if _is_manager(role):
        cursor = db.cursor()
        cursor.execute("SELECT id, name FROM dbo.departments WHERE id = ?", (dept_id,))
        row = cursor.fetchone()
        cursor.close()
        departments = [Department(id=row[0], name=row[1])] if row else []
    else:
        # Admin: cache tất cả phòng ban
        dept_cache_key = "departments:all"
        departments = department_cache.get(dept_cache_key)
        if departments is None:
            cursor = db.cursor()
            cursor.execute("SELECT id, name FROM dbo.departments ORDER BY name")
            departments = [Department(id=row[0], name=row[1]) for row in cursor.fetchall()]
            cursor.close()
            department_cache.set(dept_cache_key, departments)

    # Users (không cache vì phân quyền phức tạp theo dept)
    cursor = db.cursor()
    try:
        if _is_manager(role):
            cursor.execute(
                "SELECT id, full_name, department_id FROM dbo.users WHERE is_active = 1 AND department_id = ?",
                (dept_id,)
            )
        else:
            cursor.execute("SELECT id, full_name, department_id FROM dbo.users WHERE is_active = 1")
        usr_rows = cursor.fetchall()
        users = [UserCompact(id=row[0], fullName=row[1], departmentId=row[2]) for row in usr_rows]
        return FormDataResponse(departments=departments, users=users)
    finally:
        cursor.close()


@router.get("/{schedule_id}", response_model=ScheduleItem)
def get_schedule_detail(schedule_id: str, user_id: str = "u001",
                        db: pyodbc.Connection = Depends(get_db)):
    """Lấy chi tiết một lịch cụ thể."""
    cache_key = f"sched_detail:{schedule_id}:{user_id}"
    cached = schedule_cache.get(cache_key)
    if cached is not None:
        return cached

    cursor = db.cursor()
    try:
        cursor.execute("EXEC dbo.sp_GetScheduleDetail @ScheduleId=?, @UserId=?",
                       (schedule_id, user_id))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Không tìm thấy lịch")
        result = ScheduleItem(**map_schedule_row(row_to_dict(cursor, row)))
        schedule_cache.set(cache_key, result)
        return result
    finally:
        cursor.close()


# ─────────────────────────────────────────────
# POST / DELETE Endpoints (ghi + invalidate cache)
# ─────────────────────────────────────────────

@router.post("", response_model=dict)
def create_schedule(req: CreateScheduleRequest, user_id: str = "u001",
                    db: pyodbc.Connection = Depends(get_db)):
    """Tạo lịch mới. Sau khi thành công, xóa toàn bộ schedule cache."""
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    user_dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền tạo lịch")

    if _is_manager(role) and req.departmentId != user_dept_id:
        raise HTTPException(status_code=403,
                            detail="Trưởng phòng chỉ được tạo lịch cho phòng ban của mình")

    cursor = db.cursor()
    try:
        new_id = str(uuid.uuid4())
        dt = datetime.strptime(req.scheduleDate, "%Y-%m-%d")
        day_index = dt.weekday() + 2
        if day_index == 9:
            day_index = 8

        h = int(req.startTime.split(":")[0])
        session = "morning" if h < 12 else ("afternoon" if h < 18 else "evening")

        days_str = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"]
        date_label = f"{days_str[dt.weekday()]}, {dt.strftime('%d/%m')}"
        dept_id = req.departmentId if req.departmentId and req.departmentId.strip() else None

        cursor.execute('''
            INSERT INTO dbo.schedules
            (id, title, teacher, room, schedule_date, date_label, day_index,
             start_time, end_time, session, note, unit, department_id, category, created_by_user_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (new_id, req.title, req.teacher, req.room, req.scheduleDate, date_label,
              day_index, req.startTime, req.endTime, session, req.note, req.unit,
              dept_id, req.category, user_id))

        for p_uid in req.participantUserIds:
            cursor.execute("SELECT full_name FROM dbo.users WHERE id = ?", (p_uid,))
            u_row = cursor.fetchone()
            if u_row:
                cursor.execute('''
                    INSERT INTO dbo.schedule_participants (schedule_id, participant_name, user_id)
                    VALUES (?, ?, ?)
                ''', (new_id, u_row[0], p_uid))

        db.commit()
        # Xóa cache sau khi ghi thành công
        invalidate_schedules(req.departmentId)
        return {"success": True, "message": "Thêm lịch thành công", "id": new_id}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.delete("/{schedule_id}", response_model=dict)
def delete_schedule(schedule_id: str, user_id: str,
                    db: pyodbc.Connection = Depends(get_db)):
    """Xoá lịch với phân quyền RBAC. Sau khi thành công, xóa toàn bộ schedule cache."""
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    user_dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền xóa lịch")

    cursor = db.cursor()
    try:
        cursor.execute(
            "SELECT department_id, created_by_user_id FROM dbo.schedules WHERE id = ?",
            (schedule_id,)
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Không tìm thấy lịch")

        schedule_dept_id = str(row[0]) if row[0] else ""

        if _is_manager(role) and schedule_dept_id != user_dept_id:
            raise HTTPException(status_code=403,
                                detail="Trưởng phòng chỉ được xóa lịch của phòng mình")

        cursor.execute(
            "UPDATE dbo.schedules SET status = 'delete_by_admin' WHERE id = ?",
            (schedule_id,)
        )
        db.commit()
        # Xóa cache sau khi ghi thành công
        invalidate_schedules(schedule_dept_id)
        return {"success": True, "message": "Xoá lịch thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


import os
import shutil
from fastapi import UploadFile, File

@router.post("/import")
async def import_schedules(file: UploadFile = File(...),
                           db: pyodbc.Connection = Depends(get_db)):
    """
    Nhận file (PDF, Word, Excel), trích xuất text và dùng Gemini AI để tạo danh sách lịch.
    Chỉ trả về JSON preview, chưa lưu vào DB.
    """
    allowed_exts = ['.pdf', '.docx', '.xlsx']
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in allowed_exts:
        raise HTTPException(
            status_code=400,
            detail=f"Hệ thống chỉ hỗ trợ các định dạng: {', '.join(allowed_exts)}"
        )

    try:
        temp_file_path = f"temp_{uuid.uuid4()}{file_ext}"
        with open(temp_file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        cursor = db.cursor()
        cursor.execute("SELECT id, name FROM dbo.departments")
        departments = [{"id": str(row[0]), "name": row[1]} for row in cursor.fetchall()]
        cursor.close()

        from services.gemini_service import extract_schedules_from_file_async
        schedules_json = await extract_schedules_from_file_async(
            temp_file_path, file_ext, departments
        )

        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)

        if not schedules_json:
            raise HTTPException(
                status_code=400,
                detail="Không thể trích xuất lịch công tác từ file hoặc file trống."
            )
        return schedules_json
    except HTTPException:
        raise
    except Exception as e:
        print(f"Import Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/bulk", response_model=dict)
def bulk_create_schedules(request: List[CreateScheduleRequest],
                          user_id: str = "u001",
                          db: pyodbc.Connection = Depends(get_db)):
    """Lưu hàng loạt các lịch sau khi Admin đã xem và xác nhận (invalidate cache)."""
    user_info = _get_user_info(user_id, db)
    if not _can_create_schedule(user_info["role"]):
        raise HTTPException(status_code=403, detail="Không có quyền thêm lịch")

    cursor = db.cursor()
    success_count = 0
    try:
        for sched in request:
            cat = sched.category
            if cat == "ToanTruong" and not _is_admin(user_info["role"]):
                continue

            new_id = str(uuid.uuid4())
            dt = datetime.strptime(sched.scheduleDate, "%Y-%m-%d")
            day_index = dt.weekday() + 2
            if day_index == 9:
                day_index = 8

            h = int(sched.startTime.split(":")[0])
            session = "morning" if h < 12 else ("afternoon" if h < 18 else "evening")

            days_str = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"]
            date_label = f"{days_str[dt.weekday()]}, {dt.strftime('%d/%m')}"
            dept_id = sched.departmentId if sched.departmentId and sched.departmentId.strip() else None

            cursor.execute("""
                INSERT INTO dbo.schedules (
                    id, title, teacher, room, schedule_date, date_label, day_index,
                    start_time, end_time, session, note, unit, department_id, category, created_by_user_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                new_id, sched.title, sched.teacher, sched.room, sched.scheduleDate,
                date_label, day_index, sched.startTime, sched.endTime, session,
                sched.note, sched.unit, dept_id, cat, user_id
            ))

            if sched.participantUserIds:
                for p_id in sched.participantUserIds:
                    cursor.execute("""
                        INSERT INTO dbo.schedule_participants (schedule_id, user_id)
                        VALUES (?, ?)
                    """, (new_id, p_id))
            success_count += 1

        db.commit()
        # Xóa toàn bộ cache sau khi bulk insert
        invalidate_schedules()
        return {"success": True, "message": f"Đã thêm thành công {success_count} lịch."}
    except Exception as e:
        db.rollback()
        print(f"Bulk insert error: {e}")
        raise HTTPException(status_code=500, detail="Có lỗi xảy ra khi lưu lịch.")
    finally:
        cursor.close()
