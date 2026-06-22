import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_connection

def find_pgd_users():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, username, full_name, department_id FROM dbo.users WHERE department_id IN ('pgđ', 'pgd', 'bgd')")
    for row in cursor.fetchall():
        print(f"ID: {row[0]} | Username: {row[1]} | FullName: {row[2]} | DeptID: {row[3]}")
    cursor.close()
    conn.close()

if __name__ == "__main__":
    find_pgd_users()
