import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

db = next(get_db())
cursor = db.cursor()
cursor.execute("SELECT definition FROM sys.check_constraints WHERE name = 'CK_schedules_time_range'")
row = cursor.fetchone()
print('Constraint:', row[0] if row else 'Not found')
