import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

def delete_all_schedules():
    db = next(get_db())
    cursor = db.cursor()
    try:
        cursor.execute("DELETE FROM dbo.schedule_participants")
        cursor.execute("DELETE FROM dbo.schedules")
        db.commit()
        print("Success")
    except Exception as e:
        db.rollback()
        print(repr(e))

delete_all_schedules()
