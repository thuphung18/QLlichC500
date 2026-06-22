import sys
import openpyxl
import pyodbc
sys.stdout.reconfigure(encoding='utf-8')

from database import get_connection

def check_accounts_sync():
    try:
        # Load from XLSX
        wb = openpyxl.load_workbook("e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/danh_sach_tai_khoan.xlsx", read_only=True, data_only=True)
        sheet = wb["Danh sách tài khoản"]
        xlsx_users = []
        for r_idx, row in enumerate(sheet.iter_rows(values_only=True)):
            if r_idx < 3: # Skip header
                continue
            if not row or not row[0]:
                continue
            xlsx_users.append({
                "id": str(row[0]).strip(),
                "username": str(row[1]).strip() if row[1] else "",
                "password": str(row[2]).strip() if row[2] else "",
                "fullName": str(row[3]).strip() if row[3] else "",
                "role": str(row[4]).strip() if row[4] else "Giảng viên",
                "departmentName": str(row[5]).strip() if row[5] else ""
            })
        wb.close()
        print(f"Loaded {len(xlsx_users)} users from XLSX.")
        
        # Load from DB
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, username, full_name FROM dbo.users")
        db_users = {str(row[0]): {"username": row[1], "full_name": row[2]} for row in cursor.fetchall()}
        
        missing = []
        for xu in xlsx_users:
            if xu["id"] not in db_users:
                missing.append(xu)
                
        print(f"Found {len(missing)} users in XLSX that are MISSING in the database:")
        for idx, m in enumerate(missing[:15]):
            print(f"{idx+1}. ID: {m['id']} | Username: {m['username']} | FullName: {m['fullName']} | Dept: {m['departmentName']}")
        if len(missing) > 15:
            print("...")
            
        cursor.close()
        conn.close()
    except Exception as e:
        print("Error checking sync:", e)

check_accounts_sync()
