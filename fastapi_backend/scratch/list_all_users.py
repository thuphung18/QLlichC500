import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_connection

def list_all():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, username, full_name, department_id FROM dbo.users")
    for idx, row in enumerate(cursor.fetchall(), 1):
        print(f"{idx}. ID: {row[0]} | Username: {row[1]} | FullName: {row[2]} | DeptID: {row[3]}")
    cursor.close()
    conn.close()

if __name__ == "__main__":
    list_all()
