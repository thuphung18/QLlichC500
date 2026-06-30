import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db
from routers.schedules import clear_all_schedules, _is_admin, _is_manager

def test_clear_all():
    db = next(get_db())
    # Find an admin user
    cursor = db.cursor()
    cursor.execute("SELECT id FROM dbo.users WHERE role IN ('admin', 'quản trị viên', 'manager', 'trưởng phòng')")
    row = cursor.fetchone()
    if not row:
        print("No admin/manager user found.")
        return
    user_id = str(row[0])
    print(f"Testing with user_id: {user_id}")
    try:
        res = clear_all_schedules(user_id=user_id, db=db)
        print("Result:", res)
    except Exception as e:
        print("Error:", repr(e))

test_clear_all()
