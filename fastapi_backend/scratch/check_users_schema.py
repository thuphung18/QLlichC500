import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from database import get_db

def get_table_schema():
    db = next(get_db())
    cursor = db.cursor()
    try:
        cursor.execute("""
            SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'users'
        """)
        print("Users Table Schema:")
        for row in cursor.fetchall():
            print(f"- {row.COLUMN_NAME}: {row.DATA_TYPE} ({row.CHARACTER_MAXIMUM_LENGTH}), Nullable: {row.IS_NULLABLE}")
    except Exception as e:
        print(f"Error: {e}")

get_table_schema()
