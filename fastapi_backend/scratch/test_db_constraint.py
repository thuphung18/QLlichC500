import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

def test_insert(start_time, end_time):
    db = next(get_db())
    cursor = db.cursor()
    try:
        cursor.execute("BEGIN TRAN")
        cursor.execute("""
            INSERT INTO dbo.schedules (id, title, teacher, room, schedule_date, date_label, day_index, start_time, end_time, session, note, unit, department_id, category, created_by_user_id)
            VALUES (NEWID(), 'Test', 'Test', 'Test', '2026-06-28', 'Test', 8, ?, ?, 'morning', 'test', 'test', '3278dfb9-d352-4467-bc22-3860bbdd5549', 'Test', 'user1')
        """, (start_time, end_time))
        print(f"Success: {start_time} - {end_time}")
    except Exception as e:
        print(f"FAILED: {start_time} - {end_time} -> {e}")
    finally:
        cursor.execute("ROLLBACK")

test_insert("08:00", "11:30")
test_insert("14:00", "17:00")
test_insert("08:00", "08:00")
test_insert("17:00", "14:00")
test_insert(" 08:00 ", "11:30")
test_insert("08:00", "08:15")
