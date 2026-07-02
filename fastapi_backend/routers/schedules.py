# routers/schedules.py – Phân hệ Quản lý Lịch công tác/Lịch tuần (Schedules Management).
#
# Phân quyền & Bảo mật (RBAC):
#   - Đọc lịch (GET): Trả về lịch dựa trên Stored Procedure sp_GetSchedulesForUser.
#     • Admin thấy toàn bộ lịch toàn trường + lịch phòng ban.
#     • Manager thấy lịch toàn trường + lịch phòng ban của mình.
#     • User thấy lịch toàn trường + lịch phòng ban của mình + lịch cá nhân có tham gia.
#     • Sử dụng TTLCache (5 phút) để tăng tốc độ phản hồi đáng kể khi có lượng tải lớn.
#   - Ghi lịch (POST/DELETE): 
#     • Chỉ Admin và Manager được phép tạo/xóa lịch.
#     • Manager chỉ được quản lý lịch của phòng ban mình và không thể tác động phòng ban khác.
#     • Sau khi thao tác ghi thành công, toàn bộ Cache lịch liên quan sẽ bị xóa (invalidate) lập tức.
#   - Nhập lịch (Import): Sử dụng Gemini AI trích xuất thông tin lịch từ file PDF/Word/Excel tải lên.

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
import pyodbc
from typing import List, Optional
import uuid
from datetime import datetime
import re
from database import get_db
from schemas import ScheduleItem, ScheduleListResponse, CreateScheduleRequest, FormDataResponse, Department, UserCompact
from cache import schedule_cache, department_cache, make_schedule_key, invalidate_schedules
from scheduler import send_import_notifications_bg

router = APIRouter(prefix="/api/schedules", tags=["Schedules"])

# ─────────────────────────────────────────────
# 1. Các hàm hỗ trợ xử lý dữ liệu (Helpers)
# ─────────────────────────────────────────────

def normalize_text(text: str) -> str:
    """
    Chuẩn hóa tiếng Việt, loại bỏ dấu để tìm kiếm gần đúng (giống logic Flutter).
    """
    if not text:
        return ""
    text = text.lower().strip()
    text = re.sub(r'[àáạảãâầấậẩẫăằắặẳẵ]', 'a', text)
    text = re.sub(r'[èéẹẻẽêềếệểễ]', 'e', text)
    text = re.sub(r'[ìíịỉĩ]', 'i', text)
    text = re.sub(r'[òóọỏõôồốộổỗơờớợởỡ]', 'o', text)
    text = re.sub(r'[ùúụủũưừứựửữ]', 'u', text)
    text = re.sub(r'[ỳýỵỷỹ]', 'y', text)
    text = re.sub(r'đ', 'd', text)
    return text

def row_to_dict(cursor, row):
    """Chuyển đổi một hàng (row) pyodbc thành dictionary."""
    if row is None:
        return None
    columns = [column[0] for column in cursor.description]
    return dict(zip(columns, row))


def map_schedule_row(row_dict: dict) -> dict:
    """
    Chuẩn hóa dữ liệu trả về từ Stored Procedure SQL Server để khớp cấu trúc Schema ScheduleItem.
    - Giới hạn chuỗi thời gian HH:MM (cắt bỏ phần giây :00).
    - Phân tách chuỗi người tham gia gộp dạng "A|B|C" thành List ["A", "B", "C"].
    """
    if 'startTime' in row_dict and row_dict['startTime']:
        row_dict['startTime'] = str(row_dict['startTime'])[:5]
    if 'endTime' in row_dict and row_dict['endTime']:
        row_dict['endTime'] = str(row_dict['endTime'])[:5]

    # Xử lý chuỗi tên người tham gia được gộp bằng ký tự '|' ở SP
    participants_text = row_dict.get('participantsText', '') or ''
    row_dict['participants'] = [p for p in participants_text.split('|') if p]

    # Xử lý chuỗi UUID người tham gia được gộp bằng ký tự '|'
    ids_text = row_dict.get('participantUserIdsText', '') or ''
    row_dict['participantUserIds'] = [i for i in ids_text.split('|') if i]

    # Xóa các trường tạm khỏi dict trước khi map sang Pydantic Model
    row_dict.pop('participantsText', None)
    row_dict.pop('participantUserIdsText', None)

    return row_dict


def _get_user_info(user_id: str, db) -> dict:
    """Truy vấn thông tin vai trò (role) và phòng ban (departmentId) của User."""
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
    """Kiểm tra vai trò Admin."""
    return role in ["admin", "quản trị viên"]


def _is_manager(role: str) -> bool:
    """Kiểm tra vai trò Manager."""
    return role in ["trưởng phòng", "manager", "trưởng khoa"]


def _can_create_schedule(role: str) -> bool:
    """Kiểm tra quyền hạn tạo lịch (Chỉ chấp nhận Admin và Manager)."""
    return _is_admin(role) or _is_manager(role)


def _fetch_schedules(user_id: str, db, mode: str = "all",
                      day_index: Optional[int] = None,
                      keyword: Optional[str] = None) -> List[ScheduleItem]:
    """
    Thực thi Stored Procedure dbo.sp_GetSchedulesForUser với các tùy chọn tương ứng
    để lọc lịch công tác từ cơ sở dữ liệu.
    """
    cursor = db.cursor()
    try:
        if day_index is not None:
            # Lọc theo thứ trong tuần
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?, @DayIndex=?",
                (user_id, day_index)
            )
        elif keyword:
            # Tìm kiếm theo từ khóa
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?, @Keyword=?",
                (user_id, keyword)
            )
        elif mode != "all":
            # Lọc theo chế độ: 'my' (lịch cá nhân) hoặc 'department' (lịch phòng ban)
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?, @Mode=?",
                (user_id, mode)
            )
        else:
            # Mặc định lấy tất cả lịch được quyền xem
            cursor.execute(
                "EXEC dbo.sp_GetSchedulesForUser @UserId=?",
                (user_id,)
            )
        rows = cursor.fetchall()
        return [ScheduleItem(**map_schedule_row(row_to_dict(cursor, row))) for row in rows]
    finally:
        cursor.close()

# ─────────────────────────────────────────────
# 2. Các Endpoint lấy dữ liệu lịch (Có TTLCache)
# ─────────────────────────────────────────────

@router.get("", response_model=List[ScheduleItem])
def get_all_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy toàn bộ danh sách lịch tuần được quyền xem (Có cache 5 phút).
    """
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
    """
    Lấy danh sách lịch theo thứ trong tuần (Thứ 2 = 2 ... Chủ nhật = 8) (Có cache 5 phút).
    """
    cache_key = make_schedule_key(user_id, "day", day_index)
    cached = schedule_cache.get(cache_key)
    if cached is not None:
        return cached

    result = _fetch_schedules(user_id, db, day_index=day_index)
    schedule_cache.set(cache_key, result)
    return result


@router.get("/my", response_model=List[ScheduleItem])
def get_my_schedules(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy danh sách lịch cá nhân (Lịch mà người dùng có mặt trong danh sách tham gia) (Có cache 5 phút).
    """
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
    """
    Lấy danh sách lịch riêng của Khoa / Phòng ban người dùng (Có cache 5 phút).
    """
    cache_key = make_schedule_key(user_id, "department")
    cached = schedule_cache.get(cache_key)
    if cached is not None:
        return cached

    result = _fetch_schedules(user_id, db, mode="department")
    schedule_cache.set(cache_key, result)
    return result


@router.get("/search", response_model=List[ScheduleItem])
def search_schedules(
    keyword: str = Query("", description="Từ khoá tìm kiếm"),
    search_type: str = Query("all", description="Kiểu tìm kiếm: all, teacher, title, department, participant"),
    user_id: str = "u001",
    db: pyodbc.Connection = Depends(get_db)
):
    """
    Tìm kiếm lịch công tác, hỗ trợ loại bỏ dấu tiếng Việt và lọc theo nhiều phạm vi (giống hệt logic Flutter).
    Sử dụng get_all_schedules để tận dụng cache, sau đó filter trên RAM.
    """
    all_schedules = get_all_schedules(user_id, db)
    
    if not keyword:
        return all_schedules

    norm_keyword = normalize_text(keyword)
    results = []
    
    for item in all_schedules:
        title = normalize_text(item.title) if item.title else ""
        teacher = normalize_text(item.teacher) if item.teacher else ""
        unit = normalize_text(item.unit) if item.unit else ""
        dept_name = normalize_text(item.department_name) if item.department_name else ""
        participants = normalize_text(" ".join(item.participants)) if item.participants else ""
        
        match = False
        if search_type == "teacher":
            match = norm_keyword in teacher
        elif search_type == "title":
            match = norm_keyword in title
        elif search_type == "department":
            match = norm_keyword in unit or norm_keyword in dept_name
        elif search_type == "participant":
            match = norm_keyword in participants
        else: # all
            match = (norm_keyword in title or 
                     norm_keyword in teacher or 
                     norm_keyword in unit or 
                     norm_keyword in dept_name or 
                     norm_keyword in participants)
                     
        if match:
            results.append(item)
            
    return results


@router.get("/metadata/form-data", response_model=FormDataResponse)
def get_form_data(user_id: str = "u001", db: pyodbc.Connection = Depends(get_db)):
    """
    Lấy dữ liệu phụ trợ (danh sách phòng ban + danh sách người dùng)
    hiển thị trên các dropdown khi Admin/Manager soạn thảo lịch công tác.
    
    Phân quyền:
      - Admin: Thấy tất cả phòng ban và tất cả người dùng trong hệ thống (Sử dụng cache cho phòng ban).
      - Manager: Chỉ thấy phòng ban của chính mình và nhân viên thuộc cùng khoa của họ.
    """
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền tạo lịch")

    # Xử lý danh sách Departments
    if _is_manager(role):
        # Trưởng phòng chỉ thấy phòng của mình
        cursor = db.cursor()
        cursor.execute("SELECT id, name FROM dbo.departments WHERE id = ?", (dept_id,))
        row = cursor.fetchone()
        cursor.close()
        departments = [Department(id=row[0], name=row[1])] if row else []
    else:
        # Admin thấy toàn trường (Đọc từ cache)
        dept_cache_key = "departments:all"
        departments = department_cache.get(dept_cache_key)
        if departments is None:
            cursor = db.cursor()
            cursor.execute("SELECT id, name FROM dbo.departments ORDER BY name")
            departments = [Department(id=row[0], name=row[1]) for row in cursor.fetchall()]
            cursor.close()
            department_cache.set(dept_cache_key, departments)

    # Xử lý danh sách Users (Không cache vì số lượng thay đổi thường xuyên)
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
    """Lấy thông tin chi tiết của một lịch cụ thể (Có cache)."""
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
# 3. Các Endpoint Ghi/Xóa lịch (Hủy cache)
# ─────────────────────────────────────────────

@router.post("", response_model=dict)
def create_schedule(req: CreateScheduleRequest, user_id: str = "u001",
                    db: pyodbc.Connection = Depends(get_db)):
    """
    Tạo mới một lịch công tác.
    Sau khi thêm dữ liệu thành công vào DB, tiến hành xóa sạch Cache lịch công tác để đồng bộ dữ liệu mới.
    """
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    user_dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền tạo lịch")

    # Manager chỉ được tạo lịch thuộc khoa của mình
    if _is_manager(role) and req.departmentId != user_dept_id:
        raise HTTPException(status_code=403,
                            detail="Trưởng phòng chỉ được tạo lịch cho phòng ban của mình")

    cursor = db.cursor()
    try:
        new_id = str(uuid.uuid4())
        dt = datetime.strptime(req.scheduleDate, "%Y-%m-%d")
        
        # Tính toán Thứ tự trong tuần (weekday: 0=Thứ 2 ... 6=Chủ nhật -> day_index: 2 ... 8)
        day_index = dt.weekday() + 2
        if day_index == 9:
            day_index = 8  # Quy đổi Chủ Nhật là 8

        h = int(req.startTime.split(":")[0])
        # Tự động gán Ca học/làm việc dựa theo giờ bắt đầu
        session = "morning" if h < 12 else ("afternoon" if h < 18 else "evening")

        days_str = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"]
        date_label = f"{days_str[dt.weekday()]}, {dt.strftime('%d/%m')}"
        dept_id = req.departmentId if req.departmentId and req.departmentId.strip() else None

        # 1. Thêm lịch chính
        cursor.execute('''
            INSERT INTO dbo.schedules
            (id, title, teacher, room, schedule_date, date_label, day_index,
             start_time, end_time, session, note, unit, department_id, category, created_by_user_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (new_id, req.title, req.teacher, req.room, req.scheduleDate, date_label,
              day_index, req.startTime, None, session, req.note, req.unit,
              dept_id, req.category, user_id))

        # 2. Thêm danh sách người tham gia
        for p_uid in req.participantUserIds:
            cursor.execute("SELECT full_name FROM dbo.users WHERE id = ?", (p_uid,))
            u_row = cursor.fetchone()
            if u_row:
                cursor.execute('''
                    INSERT INTO dbo.schedule_participants (schedule_id, participant_name, user_id)
                    VALUES (?, ?, ?)
                ''', (new_id, u_row[0], p_uid))

        db.commit()
        
        # Đồng bộ hóa cache: xóa toàn bộ cache lịch
        invalidate_schedules(req.departmentId)
        return {"success": True, "message": "Thêm lịch thành công", "id": new_id}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


@router.delete("/clear-all", response_model=dict)
def clear_all_schedules(user_id: str, db: pyodbc.Connection = Depends(get_db)):
    """
    Xóa toàn bộ lịch trên hệ thống.
    - Admin: Xóa sạch toàn bộ lịch (xóa cứng).
    - Manager: Xóa toàn bộ lịch thuộc khoa/phòng ban của mình.
    """
    user_info = _get_user_info(user_id, db)
    role = user_info["role"]
    user_dept_id = user_info["departmentId"]

    if not _can_create_schedule(role):
        raise HTTPException(status_code=403, detail="Bạn không có quyền xóa lịch")

    cursor = db.cursor()
    try:
        if _is_admin(role):
            # Xóa cứng toàn bộ tham gia, lịch ẩn và lịch
            cursor.execute("DELETE FROM dbo.user_hidden_schedules")
            cursor.execute("DELETE FROM dbo.schedule_participants")
            cursor.execute("DELETE FROM dbo.schedules")
            db.commit()
            invalidate_schedules()
            return {"success": True, "message": "Đã xóa toàn bộ lịch trên hệ thống"}
        elif _is_manager(role):
            if not user_dept_id:
                raise HTTPException(status_code=400, detail="Không xác định được phòng ban của bạn")
            
            # Xóa lịch của khoa/phòng
            cursor.execute("""
                DELETE uhs FROM dbo.user_hidden_schedules uhs
                INNER JOIN dbo.schedules s ON uhs.schedule_id = s.id
                WHERE s.department_id = ?
            """, (user_dept_id,))

            cursor.execute("""
                DELETE p FROM dbo.schedule_participants p
                INNER JOIN dbo.schedules s ON p.schedule_id = s.id
                WHERE s.department_id = ?
            """, (user_dept_id,))
            
            cursor.execute("DELETE FROM dbo.schedules WHERE department_id = ?", (user_dept_id,))
            db.commit()
            invalidate_schedules(user_dept_id)
            return {"success": True, "message": "Đã xóa toàn bộ lịch của đơn vị bạn"}
        else:
            raise HTTPException(status_code=403, detail="Bạn không có quyền thực hiện chức năng này")
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
    """
    Xóa mềm lịch công tác bằng cách chuyển trạng thái 'status' thành 'delete_by_admin'.
    
    Quy định:
      - Admin được quyền xóa bất kỳ lịch nào.
      - Manager chỉ được quyền xóa lịch thuộc phòng ban của mình.
      - Xóa thành công sẽ thực hiện Invalidate Cache lịch.
    """
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

        # Manager chỉ được xóa lịch của phòng mình
        if _is_manager(role) and schedule_dept_id != user_dept_id:
            raise HTTPException(status_code=403,
                                detail="Trưởng phòng chỉ được xóa lịch của phòng mình")

        # Xóa cứng khỏi CSDL
        cursor.execute("DELETE FROM dbo.user_hidden_schedules WHERE schedule_id = ?", (schedule_id,))
        cursor.execute("DELETE FROM dbo.schedule_participants WHERE schedule_id = ?", (schedule_id,))
        cursor.execute("DELETE FROM dbo.schedules WHERE id = ?", (schedule_id,))
        db.commit()
        
        # Xóa cache lịch cũ
        invalidate_schedules(schedule_dept_id)
        return {"success": True, "message": "Xoá lịch công tác thành công"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()


# ─────────────────────────────────────────────
# 4. Các Endpoint tích hợp AI (Gemini AI Parser)
# ─────────────────────────────────────────────

import os
import shutil
from fastapi import UploadFile, File

@router.post("/import")
async def import_schedules(file: UploadFile = File(...)):
    """
    Nhận file (PDF, Word, Excel), trích xuất text và dùng Gemini AI phân tích → trả về JSON preview.
    
    Chống lỗi 08S01 (TCP Provider reset):
      - fetch_with_retry() tạo TCP connection MỚI hoàn toàn (pyodbc.pooling=False), retry tối đa 3 lần.
      - Kết nối được trả về NGAY sau khi fetch data, không giữ idle trong 19 giây chờ AI.
    """
    from database import fetch_with_retry
    from services.gemini_service import extract_schedules_from_file_async, match_participant_to_user

    allowed_exts = ['.pdf', '.docx', '.xlsx']
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in allowed_exts:
        raise HTTPException(
            status_code=400,
            detail=f"Hệ thống chỉ hỗ trợ các định dạng: {', '.join(allowed_exts)}"
        )

    temp_file_path = f"temp_{uuid.uuid4()}{file_ext}"
    try:
        # Lưu file tạm vào server
        with open(temp_file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # ── BƯỚC 1: Fetch DB data, trả kết nối ngay, retry tự động nếu TCP reset ──
        (departments, users) = fetch_with_retry([
            (
                "SELECT id, name FROM dbo.departments",
                lambda r: {"id": str(r[0]), "name": r[1]}
            ),
            (
                "SELECT id, username, full_name, department_id FROM dbo.users WHERE is_active = 1",
                lambda r: {"id": str(r[0]), "username": r[1], "full_name": r[2],
                           "department_id": str(r[3]) if r[3] else None}
            ),
        ])

        # ── BƯỚC 2: Gọi AI (~15-20 giây) — KHÔNG có DB connection nào bị giữ ──
        schedules_json = await extract_schedules_from_file_async(
            temp_file_path, file_ext, departments
        )

        if not schedules_json:
            raise HTTPException(
                status_code=400,
                detail="Không thể trích xuất lịch công tác từ file hoặc file trống."
            )

        # ── BƯỚC 3: Ánh xạ người tham gia từ data đã fetch (không cần DB thêm) ──
        for item in schedules_json:
            matched_set = set()

            # 3a. Ánh xạ từng người tham dự trong participants_raw
            # Hỗ trợ cả format mới (dict {name, dept}) và format cũ (str thô)
            for participant in item.get("participants_raw", []):
                uid = match_participant_to_user(participant, users, departments)
                if uid:
                    matched_set.add(uid)

            # 3b. Ánh xạ người chủ trì (teacher)
            teacher_name = item.get("teacher", "")
            teacher_dept = item.get("teacher_dept", "")
            if teacher_name:
                teacher_input = {"name": teacher_name, "dept": teacher_dept} if teacher_dept else teacher_name
                uid = match_participant_to_user(teacher_input, users, departments)
                if uid:
                    matched_set.add(uid)

            item["participantUserIds"] = list(matched_set)
            # Xóa trường nội bộ không cần trả về client
            item.pop("participants_raw", None)
            item.pop("teacher_dept", None)

        return schedules_json

    except HTTPException:
        raise
    except Exception as e:
        error_msg = str(e)
        import traceback
        traceback.print_exc()
        print(f"Import Error: {error_msg}")
        if "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg:
            raise HTTPException(status_code=429,
                detail="Tài khoản AI Gemini đã hết hạn mức sử dụng trong ngày. Vui lòng tạo API Key mới.")
        elif "503" in error_msg or "UNAVAILABLE" in error_msg:
            raise HTTPException(status_code=503,
                detail="Dịch vụ AI Gemini đang bị quá tải. Vui lòng thử lại sau ít phút.")
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý trích xuất AI: {error_msg}")
    finally:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)


@router.post("/bulk", response_model=dict)
def bulk_create_schedules(request: List[CreateScheduleRequest],
                           background_tasks: BackgroundTasks,
                           user_id: str = "u001",
                           db: pyodbc.Connection = Depends(get_db)):
    """
    Lưu hàng loạt các lịch công tác (sau khi người dùng xem Preview và bấm xác nhận).
    Sau khi lưu thành công, tiến hành xóa sạch Cache lịch để cập nhật.
    """
    user_info = _get_user_info(user_id, db)
    if not _can_create_schedule(user_info["role"]):
        raise HTTPException(status_code=403, detail="Không có quyền thêm lịch")

    cursor = db.cursor()
    success_count = 0
    skip_count = 0
    
    # Biến cờ (flags) để xác định đối tượng nhận thông báo
    has_toantruong = False
    dept_ids_to_notify = set()
    
    try:
        # Lấy danh sách phòng ban để fallback khi AI không nhận ra department
        cursor.execute("SELECT TOP 1 id FROM dbo.departments ORDER BY name")
        default_dept_row = cursor.fetchone()
        default_dept_id = str(default_dept_row[0]) if default_dept_row else None
        # Lấy trước toàn bộ danh sách users để lookup siêu tốc, tránh N+1 Query
        cursor.execute("SELECT id, full_name FROM dbo.users")
        users_dict = {row[0]: row[1] for row in cursor.fetchall()}

        schedules_to_insert = []
        participants_to_insert = []

        for sched in request:
            cat = sched.category
            # Lịch toàn trường thì chỉ Admin mới được phép lưu
            if cat == "ToanTruong" and not _is_admin(user_info["role"]):
                continue

            new_id = str(uuid.uuid4())
            dt = datetime.strptime(sched.scheduleDate, "%Y-%m-%d")
            day_index = dt.weekday() + 2
            if day_index == 9:
                day_index = 8

            # Chuẩn hóa chuỗi thời gian HH:MM bằng regex để loại bỏ khoảng trắng hoặc lỗi format
            import re
            def norm_time(t: str, default_h="08", default_m="00"):
                m = re.search(r"(\d{1,2})[^\d](\d{2})", str(t))
                if m:
                    return f"{int(m.group(1)):02d}:{m.group(2)}"
                return f"{default_h}:{default_m}"
            
            sched.startTime = norm_time(sched.startTime, "08", "00")
            
            # Cập nhật lại session
            h = int(sched.startTime.split(":")[0])
            session = "morning" if h < 12 else ("afternoon" if h < 18 else "evening")

            days_str = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"]
            date_label = f"{days_str[dt.weekday()]}, {dt.strftime('%d/%m')}"
            dept_id = sched.departmentId if sched.departmentId and sched.departmentId.strip() else default_dept_id

            # Bỏ qua lịch nếu vẫn không có department_id (trường hợp DB rỗng)
            if not dept_id:
                print(f"[Bulk] Bỏ qua lịch '{sched.title}' do không xác định được phòng ban")
                skip_count += 1
                continue

            # Thu thập dữ liệu để chuẩn bị gửi Push Notification
            if cat == "ToanTruong":
                has_toantruong = True
            else:
                dept_ids_to_notify.add(dept_id)

            # Thu thập data insert
            schedules_to_insert.append((
                new_id, sched.title, sched.teacher, sched.room, sched.scheduleDate,
                date_label, day_index, sched.startTime, None, session,
                sched.note, sched.unit, dept_id, cat, user_id
            ))

            # Lookup người tham gia siêu tốc từ dictionary
            if sched.participantUserIds:
                for p_id in sched.participantUserIds:
                    full_name = users_dict.get(p_id)
                    if full_name:
                        participants_to_insert.append((new_id, full_name, p_id))

            success_count += 1

        # Thực thi Insert hàng loạt tự build (Multi-row Insert) để siêu tốc mà không bị lỗi Cast của pyodbc
        if schedules_to_insert:
            # Batch size khoảng 100 rows mỗi lần để tránh vượt quá 2100 parameters của SQL Server
            batch_size = 100
            for i in range(0, len(schedules_to_insert), batch_size):
                batch = schedules_to_insert[i:i + batch_size]
                placeholders = ",".join(["(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"] * len(batch))
                flat_params = [item for sublist in batch for item in sublist]
                cursor.execute(f"""
                    INSERT INTO dbo.schedules (
                        id, title, teacher, room, schedule_date, date_label, day_index,
                        start_time, end_time, session, note, unit, department_id, category, created_by_user_id
                    ) VALUES {placeholders}
                """, flat_params)

        if participants_to_insert:
            batch_size = 500
            for i in range(0, len(participants_to_insert), batch_size):
                batch = participants_to_insert[i:i + batch_size]
                placeholders = ",".join(["(?, ?, ?)"] * len(batch))
                flat_params = [item for sublist in batch for item in sublist]
                cursor.execute(f"""
                    INSERT INTO dbo.schedule_participants (schedule_id, participant_name, user_id)
                    VALUES {placeholders}
                """, flat_params)

        db.commit()
        # Xóa toàn bộ cache sau khi lưu dữ liệu hàng loạt
        invalidate_schedules()
        
        # Nếu có chèn thành công ít nhất 1 lịch thì đẩy tác vụ gửi thông báo xuống nền
        if success_count > 0 and (has_toantruong or len(dept_ids_to_notify) > 0):
            background_tasks.add_task(send_import_notifications_bg, has_toantruong, dept_ids_to_notify)

        msg = f"Đã thêm thành công {success_count} lịch."
        if skip_count > 0:
            msg += f" ({skip_count} lịch bỏ qua do không xác định được phòng ban.)"
        return {"success": True, "message": msg}
    except Exception as e:
        db.rollback()
        print(f"Bulk insert error: {e}")
        raise HTTPException(status_code=500, detail="Có lỗi xảy ra khi lưu lịch.")
    finally:
        cursor.close()

