from fastapi import APIRouter, Depends, HTTPException, Query
import pyodbc
from typing import List, Optional
import uuid
from datetime import datetime
from database import get_db
from schemas import ScheduleItem, ScheduleListResponse, CreateScheduleRequest, FormDataResponse, Department, UserCompact

router = APIRouter(prefix="/api/schedules", tags=["Schedules"])

# ---------- Helper functions ----------

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
    return role in ["trưởng phòng", "manager"]

def _can_create_schedule(role: str) -> bool:
    return _is_admin(role) or _is_manager(role)

# ---------- GET Endpoints ----------

@router.get("", response_model=List[ScheduleItem])
def get_all_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy toàn bộ lịch theo phân quyền RBAC.
    - Admin: chỉ thấy Lịch Toàn Trường
    - Manager: thấy Lịch Toàn Trường + Lịch Phòng ban + Lịch cá nhân phòng mình
    - User: thấy Lịch Toàn Trường + Lịch Phòng ban mình + Lịch cá nhân của bản thân
    """
    cursor = db.cursor()
    try:
        cursor.execute("EXEC dbo.sp_GetSchedulesForUser @UserId=?", (user_id,))
        rows = cursor.fetchall()
        result = []
        for row in rows:
            d = row_to_dict(cursor, row)
            result.append(ScheduleItem(**map_schedule_row(d)))
        return result
    finally:
        cursor.close()

@router.get("/day/{day_index}", response_model=List[ScheduleItem])
def get_schedules_by_day(day_index: int, user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """Lấy lịch theo thứ - có phân quyền RBAC."""
    cursor = db.cursor()
    try:
        cursor.execute("EXEC dbo.sp_GetSchedulesForUser @UserId=?, @DayIndex=?", (user_id, day_index))
        rows = cursor.fetchall()
        result = []
        for row in rows:
            d = row_to_dict(cursor, row)
            result.append(ScheduleItem(**map_schedule_row(d)))
        return result
    finally:
        cursor.close()

@router.get("/my", response_model=List[ScheduleItem])
def get_my_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """Lấy lịch cá nhân - các lịch có tên người dùng trong danh sách tham dự."""
    cursor = db.cursor()
    try:
        cursor.execute("EXEC dbo.sp_GetSchedulesForUser @UserId=?, @Mode=?", (user_id, 'my'))
        rows = cursor.fetchall()
        result = []
        for row in rows:
            d = row_to_dict(cursor, row)
            result.append(ScheduleItem(**map_schedule_row(d)))
        return result
    finally:
        cursor.close()

@router.get("/department", response_model=List[ScheduleItem])
def get_department_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy lịch phòng ban.
    - Manager: thấy toàn bộ lịch phòng ban (kể cả lịch cá nhân các thành viên)
    - User: chỉ thấy lịch phòng ban chung (không thấy lịch cá nhân của đồng nghiệp)
    """
    cursor = db.cursor()
    try:
        cursor.execute("EXEC dbo.sp_GetSchedulesForUser @UserId=?, @Mode=?", (user_id, 'department'))
        rows = cursor.fetchall()
        result = []
        for row in rows:
            d = row_to_dict(cursor, row)
            result.append(ScheduleItem(**map_schedule_row(d)))
        return result
    finally:
        cursor.close()

@router.get("/search", response_model=List[ScheduleItem])
def search_schedules(
    keyword: str = Query(..., description="Từ khoá tìm kiếm"),
    user_id: str = "u001",
    db: pyodbc.Connection = Depends(get_db)
):
    """Tìm kiếm lịch theo từ khoá - có phân quyền RBAC."""
    cursor = db.cursor()
    try:
        cursor.execute("EXEC dbo.sp_GetSchedulesForUser @UserId=?, @Keyword=?", (user_id, keyword))
        rows = cursor.fetchall()
        result = []
        for row in rows:
            d = row_to_dict(cursor, row)
            result.append(ScheduleItem(**map_schedule_row(d)))
        return result
    finally:
        cursor.close()

@router.get("/metadata/form-data", response_model=FormDataResponse)
def get_form_data(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy danh sách Khoa và Users để hiển thị trên Dropdown / Checkbox khi tạo lịch.
    - Admin: thấy tất cả phòng ban và tất cả users
    - Manager: thấy tất cả phòng ban, nhưng chỉ thấy users trong phòng mình
    - User thường: trả về danh sách rỗng (không có quyền tạo lịch)
    """
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền tạo lịch")

    cursor = db.cursor()
    try:
        cursor.execute("SELECT id, name FROM dbo.departments ORDER BY name")
        depts = cursor.fetchall()
        departments = [Department(id=row[0], name=row[1]) for row in depts]

        # Manager chỉ thấy users trong phòng mình để gán công việc
        if _is_manager(role):
            cursor.execute(
                "SELECT id, full_name, department_id FROM dbo.users WHERE is_active = 1 AND department_id = ?",
                (dept_id,)
            )
        else:
            # Admin thấy tất cả users
            cursor.execute("SELECT id, full_name, department_id FROM dbo.users WHERE is_active = 1")

        usr_rows = cursor.fetchall()
        users = [UserCompact(id=row[0], fullName=row[1], departmentId=row[2]) for row in usr_rows]

        return FormDataResponse(departments=departments, users=users)
    finally:
        cursor.close()

@router.get("/{schedule_id}", response_model=ScheduleItem)
def get_schedule_detail(schedule_id: str, user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """Lấy chi tiết một lịch cụ thể."""
    cursor = db.cursor()
    try:
        cursor.execute("EXEC dbo.sp_GetScheduleDetail @ScheduleId=?, @UserId=?", (schedule_id, user_id))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Không tìm thấy lịch")

        d = row_to_dict(cursor, row)
        return ScheduleItem(**map_schedule_row(d))
    finally:
        cursor.close()

# ---------- POST / DELETE Endpoints (RBAC enforced) ----------

@router.post("", response_model=dict)
def create_schedule(req: CreateScheduleRequest, user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Tạo lịch mới.
    - Admin: tạo Lịch Toàn Trường (category phải là 'Lịch toàn trường' hoặc bất kỳ khoa)
    - Manager: tạo Lịch Phòng ban hoặc Lịch cá nhân (chỉ trong phòng mình)
    - User thường: bị từ chối (403)
    """
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    user_dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền tạo lịch")

    # Manager chỉ được tạo lịch thuộc phòng mình
    if _is_manager(role) and req.departmentId != user_dept_id:
        raise HTTPException(status_code=403, detail="Trưởng phòng chỉ được tạo lịch cho phòng ban của mình")

    cursor = db.cursor()
    try:
        new_id = str(uuid.uuid4())

        dt = datetime.strptime(req.scheduleDate, "%Y-%m-%d")
        day_index = dt.weekday() + 2
        if day_index == 9:
            day_index = 8

        h = int(req.startTime.split(":")[0])
        if h < 12:
            session = "morning"
        elif h < 18:
            session = "afternoon"
        else:
            session = "evening"

        days_str = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"]
        date_label = f"{days_str[dt.weekday()]}, {dt.strftime('%d/%m')}"

        dept_id = req.departmentId if req.departmentId and req.departmentId.strip() else None

        cursor.execute('''
            INSERT INTO dbo.schedules
            (id, title, teacher, room, schedule_date, date_label, day_index, start_time, end_time, session, note, unit, department_id, category, created_by_user_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (new_id, req.title, req.teacher, req.room, req.scheduleDate, date_label, day_index,
              req.startTime, req.endTime, session, req.note, req.unit, dept_id, req.category, user_id))

        for p_uid in req.participantUserIds:
            cursor.execute("SELECT full_name FROM dbo.users WHERE id = ?", (p_uid,))
            u_row = cursor.fetchone()
            if u_row:
                p_name = u_row[0]
                cursor.execute('''
                    INSERT INTO dbo.schedule_participants (schedule_id, participant_name, user_id)
                    VALUES (?, ?, ?)
                ''', (new_id, p_name, p_uid))

        db.commit()
        return {"success": True, "message": "Thêm lịch thành công", "id": new_id}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.delete("/{schedule_id}", response_model=dict)
def delete_schedule(schedule_id: str, user_id: str, db: pyodbc.Connection = Depends(get_db)):
    """
    Xoá lịch với phân quyền RBAC:
    - Admin: chỉ có thể xóa Lịch Toàn Trường (do Admin tạo)
    - Manager: chỉ có thể xóa lịch thuộc phòng mình (do Manager tạo)
    - User thường: bị từ chối (403)
    """
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    user_dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền xóa lịch")

    cursor = db.cursor()
    try:
        # Lấy thông tin lịch cần xóa
        cursor.execute(
            "SELECT department_id, created_by_user_id FROM dbo.schedules WHERE id = ?",
            (schedule_id,)
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Không tìm thấy lịch")

        schedule_dept_id = str(row[0]) if row[0] else ""

        # Manager chỉ được xóa lịch phòng mình
        if _is_manager(role) and schedule_dept_id != user_dept_id:
            raise HTTPException(status_code=403, detail="Trưởng phòng chỉ được xóa lịch của phòng mình")

        cursor.execute("UPDATE dbo.schedules SET status = 'delete_by_admin' WHERE id = ?", (schedule_id,))
        db.commit()
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
async def import_schedules(file: UploadFile = File(...), db: pyodbc.Connection = Depends(get_db)):
    """
    Nhận file (PDF), trích xuất text, và dùng Gemini AI để tạo danh sách lịch (JSON).
    Chỉ trả về JSON, chưa lưu vào DB.
    """
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Hiện tại hệ thống chỉ hỗ trợ import từ file PDF.")
        
    try:
        # Lưu file tạm
        temp_file_path = f"temp_{uuid.uuid4()}.pdf"
        with open(temp_file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # Lấy danh sách phòng ban từ DB để AI map
        cursor = db.cursor()
        cursor.execute("SELECT id, name FROM dbo.departments")
        departments = [{"id": str(row[0]), "name": row[1]} for row in cursor.fetchall()]
        cursor.close()
        
        # Gọi Gemini AI xử lý song song bất đồng bộ
        from services.gemini_service import extract_schedules_from_pdf_async
        schedules_json = await extract_schedules_from_pdf_async(temp_file_path, departments)
        
        # Xóa file tạm sau khi hoàn tất xử lý
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)
            
        if not schedules_json:
            raise HTTPException(status_code=400, detail="Không thể trích xuất lịch công tác từ file PDF hoặc file trống.")
            
        return schedules_json
    except Exception as e:
        print(f"Import Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/bulk", response_model=dict)
def bulk_create_schedules(request: List[CreateScheduleRequest], user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lưu hàng loạt các lịch sau khi Admin đã xem và xác nhận.
    """
    user_info = _get_user_info(user_id, db)
    if not _can_create_schedule(user_info["role"]):
        raise HTTPException(status_code=403, detail="Không có quyền thêm lịch")
        
    cursor = db.cursor()
    success_count = 0
    try:
        for sched in request:
            # Check quyền tạo lịch ToanTruong
            cat = sched.category
            if cat == "ToanTruong" and not _is_admin(user_info["role"]):
                continue # Skip những lịch không đủ quyền
                
            new_id = str(uuid.uuid4())
            
            from datetime import datetime
            dt = datetime.strptime(sched.scheduleDate, "%Y-%m-%d")
            day_index = dt.weekday() + 2
            if day_index == 9:
                day_index = 8

            h = int(sched.startTime.split(":")[0])
            if h < 12:
                session = "morning"
            elif h < 18:
                session = "afternoon"
            else:
                session = "evening"

            days_str = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"]
            date_label = f"{days_str[dt.weekday()]}, {dt.strftime('%d/%m')}"
            
            # Xử lý trường hợp AI trả về departmentId là chuỗi rỗng
            dept_id = sched.departmentId if sched.departmentId and sched.departmentId.strip() else None

            cursor.execute("""
                INSERT INTO dbo.schedules (id, title, teacher, room, schedule_date, date_label, day_index, start_time, end_time, session, note, unit, department_id, category, created_by_user_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                new_id, sched.title, sched.teacher, sched.room, sched.scheduleDate, date_label, day_index, sched.startTime, sched.endTime, session, sched.note, sched.unit, dept_id, cat, user_id
            ))
            
            if sched.participantUserIds:
                for p_id in sched.participantUserIds:
                    cursor.execute("""
                        INSERT INTO dbo.schedule_participants (schedule_id, user_id)
                        VALUES (?, ?)
                    """, (new_id, p_id))
            success_count += 1
            
        db.commit()
        return {"success": True, "message": f"Đã thêm thành công {success_count} lịch."}
    except Exception as e:
        db.rollback()
        print(f"Bulk insert error: {e}")
        raise HTTPException(status_code=500, detail="Có lỗi xảy ra khi lưu lịch.")
    finally:
        cursor.close()
