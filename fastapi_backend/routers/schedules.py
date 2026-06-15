from fastapi import APIRouter, Depends, HTTPException, Query
import pyodbc
from typing import List, Optional
import uuid
from datetime import datetime
from database import get_db
from schemas import ScheduleItem, ScheduleListResponse, CreateScheduleRequest, FormDataResponse, Department, UserCompact

router = APIRouter(prefix="/api/schedules", tags=["Schedules"])

def row_to_dict(cursor, row):
    if row is None:
        return None
    columns = [column[0] for column in cursor.description]
    return dict(zip(columns, row))

def map_schedule_row(row_dict: dict) -> dict:
    """
    Map một row của SP thành dictionary chuẩn bị cho Schema ScheduleItem.
    Xử lý việc split chuỗi participants và thời gian.
    """
    # Xử lý startTime và endTime (chuyển từ timedelta/time object thành string dạng HH:MM)
    if 'startTime' in row_dict and row_dict['startTime']:
        row_dict['startTime'] = str(row_dict['startTime'])[:5] # "07:00"
    if 'endTime' in row_dict and row_dict['endTime']:
        row_dict['endTime'] = str(row_dict['endTime'])[:5]
        
    # Split participants bằng dấu '|'
    participants_text = row_dict.get('participantsText', '') or ''
    row_dict['participants'] = [p for p in participants_text.split('|') if p]
    
    ids_text = row_dict.get('participantUserIdsText', '') or ''
    row_dict['participantUserIds'] = [i for i in ids_text.split('|') if i]
    
    # Xoá 2 trường text để phù hợp Pydantic model
    row_dict.pop('participantsText', None)
    row_dict.pop('participantUserIdsText', None)
    
    return row_dict

@router.get("", response_model=List[ScheduleItem])
def get_all_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy toàn bộ lịch.
    Lưu ý: Để test dễ dàng, mặc định user_id là u001. Trong thực tế lấy từ JWT Token.
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
    """
    Lấy lịch theo thứ.
    """
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
    """
    Lấy lịch cá nhân của người dùng.
    """
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
    Lấy lịch của khoa / phòng ban.
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
def search_schedules(keyword: str = Query(..., description="Từ khoá tìm kiếm"), user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Tìm kiếm lịch theo từ khoá.
    """
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

@router.get("/{schedule_id}", response_model=ScheduleItem)
def get_schedule_detail(schedule_id: str, user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy chi tiết một lịch cụ thể.
    """
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

@router.get("/metadata/form-data", response_model=FormDataResponse)
def get_form_data(db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy danh sách Khoa và Users để hiển thị trên Dropdown / Checkbox.
    """
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id, name FROM dbo.departments")
        depts = cursor.fetchall()
        departments = [Department(id=row.id, name=row.name) for row in depts]
        
        cursor.execute("SELECT id, full_name, department_id FROM dbo.users WHERE is_active = 1")
        usr_rows = cursor.fetchall()
        users = [UserCompact(id=row.id, fullName=row.full_name, departmentId=row.department_id) for row in usr_rows]
        
        return FormDataResponse(departments=departments, users=users)
    finally:
        cursor.close()

@router.post("", response_model=dict)
def create_schedule(req: CreateScheduleRequest, user_id: str = "admin001", db: pyodbc.Connection = Depends(get_db)):
    """
    Tạo lịch mới.
    """
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
        
        cursor.execute('''
            INSERT INTO dbo.schedules 
            (id, title, teacher, room, schedule_date, date_label, day_index, start_time, end_time, session, note, unit, department_id, category, created_by_user_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (new_id, req.title, req.teacher, req.room, req.scheduleDate, date_label, day_index, req.startTime, req.endTime, session, req.note, req.unit, req.departmentId, req.category, user_id))
        
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
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()

@router.delete("/{schedule_id}", response_model=dict)
def delete_schedule(schedule_id: str, user_id: str, db: pyodbc.Connection = Depends(get_db)):
    """
    Xoá lịch.
    - Admin: Cập nhật status = 'deleted' (xóa với mọi người).
    - User: Thêm vào bảng user_hidden_schedules (chỉ ẩn với user đó).
    """
    cursor = db.cursor()
    try:
        # Kiểm tra user_id là role gì
        cursor.execute("SELECT role FROM dbo.users WHERE id = ?", (user_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        
        role = row[0].lower()
        if role in ["admin", "quản trị viên"]:
            # Đánh dấu trong db là delete_by_admin
            cursor.execute("UPDATE dbo.schedules SET status = 'delete_by_admin' WHERE id = ?", (schedule_id,))
        else:
            # Nếu user xóa thì làm tương tự (đánh dấu delete_by_user)
            cursor.execute("UPDATE dbo.schedules SET status = 'delete_by_user' WHERE id = ?", (schedule_id,))
                
        db.commit()
        return {"success": True, "message": "Xoá lịch thành công"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
