import sys
import pyodbc
sys.stdout.reconfigure(encoding='utf-8')

from database import get_connection

try:
    conn = get_connection()
    cursor = conn.cursor()
    
    print("--- DEPARTMENTS ---")
    cursor.execute("SELECT id, name FROM dbo.departments")
    for row in cursor.fetchall():
        print(f"ID: {row[0]} | Name: {row[1]}")
        
    print("\n--- USERS ---")
    cursor.execute("SELECT id, username, full_name, role, department_id, is_active FROM dbo.users")
    for row in cursor.fetchall():
        print(f"ID: {row[0]} | Username: {row[1]} | FullName: {row[2]} | Role: {row[3]} | DeptID: {row[4]} | Active: {row[5]}")
        
    cursor.close()
    conn.close()
except Exception as e:
    print("Error querying database:", e)
