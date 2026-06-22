import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_connection

def find_vu_tho():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, username, full_name, role, department_id FROM dbo.users WHERE full_name LIKE '%Vũ%' OR full_name LIKE '%Thọ%' OR username LIKE '%vu%' OR username LIKE '%tho%'")
    for row in cursor.fetchall():
        print(f"ID: {row[0]} | Username: {row[1]} | FullName: {row[2]} | Role: {row[3]} | DeptID: {row[4]}")
    cursor.close()
    conn.close()

if __name__ == "__main__":
    find_vu_tho()
