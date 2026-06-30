import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

def delete_manager_schedules():
    db = next(get_db())
    cursor = db.cursor()
    try:
        user_dept_id = 'test'
        cursor.execute("""
            DELETE p FROM dbo.schedule_participants p
            INNER JOIN dbo.schedules s ON p.schedule_id = s.id
            WHERE s.department_id = ?
        """, (user_dept_id,))
        
        cursor.execute("DELETE FROM dbo.schedules WHERE department_id = ?", (user_dept_id,))
        db.commit()
        print("Success")
    except Exception as e:
        db.rollback()
        print(repr(e))

delete_manager_schedules()
