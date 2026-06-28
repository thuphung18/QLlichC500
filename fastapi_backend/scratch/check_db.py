import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

def check_schedules():
    db = next(get_db())
    cursor = db.cursor()
    try:
        # Check total schedules
        cursor.execute("SELECT COUNT(*) FROM dbo.schedules")
        total = cursor.fetchone()[0]
        print(f"Total schedules in DB: {total}")

        # Check latest 5 schedules inserted
        cursor.execute("SELECT TOP 5 id, start_time, end_time, schedule_date, created_at, teacher, created_by_user_id FROM dbo.schedules ORDER BY created_at DESC")
        rows = cursor.fetchall()
        print("\nLatest 5 schedules:")
        for row in rows:
            print(f"ID: {row.id}, Date: {row.schedule_date}, Time: {row.start_time}-{row.end_time}, Teacher: {row.teacher.encode('utf-8')}, CreatedBy: {row.created_by_user_id}")
    except Exception as e:
        print(f"Error: {e}")

check_schedules()
