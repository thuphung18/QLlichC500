import pyodbc
from e.Cong_Viec_Chuyen_mon.Flutter_project.QlLich.fastapi_backend.database import get_db

try:
    db = next(get_db())
    cursor = db.cursor()
    cursor.execute("""
        SELECT definition 
        FROM sys.check_constraints 
        WHERE name = 'CK_schedules_time_range'
    """)
    row = cursor.fetchone()
    if row:
        print("Constraint Definition:", row[0])
    else:
        print("Constraint not found")
except Exception as e:
    print("Error:", e)
