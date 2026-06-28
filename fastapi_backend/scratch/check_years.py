import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

def list_dates():
    db = next(get_db())
    cursor = db.cursor()
    try:
        cursor.execute("SELECT DISTINCT YEAR(schedule_date) FROM dbo.schedules")
        years = cursor.fetchall()
        print("Years in DB:", [y[0] for y in years])
        
        cursor.execute("SELECT COUNT(*) FROM dbo.schedules")
        print("Total count:", cursor.fetchone()[0])
    except Exception as e:
        print(f"Error: {e}")

list_dates()
