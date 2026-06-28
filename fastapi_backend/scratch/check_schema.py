import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

db = next(get_db())
cursor = db.cursor()
for row in cursor.columns(table='schedules'):
    print(f"{row.column_name}: {row.type_name}({row.column_size})")
