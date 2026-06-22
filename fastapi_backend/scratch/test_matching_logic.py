import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_connection
from services.gemini_service import match_participant_to_user

def test_offline_matching():
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        # Load departments
        cursor.execute("SELECT id, name FROM dbo.departments")
        departments = [{"id": str(row[0]), "name": row[1]} for row in cursor.fetchall()]
        
        # Load users
        cursor.execute("SELECT id, username, full_name, department_id FROM dbo.users WHERE is_active = 1")
        users = [{"id": str(row[0]), "username": row[1], "full_name": row[2], "department_id": str(row[3]) if row[3] else None} for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        
        print(f"Loaded {len(users)} users and {len(departments)} departments for matching test.")
        
        # Define test cases: (raw_name, expected_username_or_fullname)
        test_cases = [
            ("Nghĩa (NV7)", "Nguyễn Đình Nghĩa"),
            ("Vũ (PGĐ)", "Nguyễn Văn Thiết SĐ"), # Wait, let's see what it maps to, or if Vũ maps to something
            ("Toàn (NV7)", "Nguyễn Ngọc Toàn"),
            ("Kiều Văn Nam (NV7)", "Kiều Văn Nam"),
            ("Lưu Thị Thu Thuỷ (NV6)", "Lưu Thị Thu Thuỷ"),
            ("Thanh (QLĐT)", None), # Check what it maps to or if it matches
            ("Dũng (NV1)", None),
            ("Sái Hưng (NV8)", "Sái Hưng"),
            ("Linh (A09)", "Linh (Ngiệp vụ 8)"), # Wait, linh.nv8
            ("Vũ Chí Quang (NV7)", "Vũ Chí Quang"),
        ]
        
        print("\n--- RUNNING MATCHING TESTS ---")
        for raw_name, expected in test_cases:
            uid = match_participant_to_user(raw_name, users, departments)
            matched_user = None
            if uid:
                matched_user = next((u for u in users if u["id"] == uid), None)
                
            match_status = "FAIL"
            if matched_user:
                matched_name = matched_user["full_name"]
                if expected is None or expected.lower() in matched_name.lower():
                    match_status = "SUCCESS"
            else:
                if expected is None:
                    match_status = "SUCCESS"
                    
            print(f"Input: '{raw_name}'")
            if matched_user:
                print(f"  Matched -> FullName: '{matched_user['full_name']}' | Username: '{matched_user['username']}' | ID: {matched_user['id']}")
            else:
                print(f"  Matched -> None")
            print(f"  Expected: '{expected}' | Status: {match_status}\n")
            
    except Exception as e:
        print("Error during test:", e)

if __name__ == "__main__":
    test_offline_matching()
