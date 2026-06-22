import re
import sys
import os
import uuid
import openpyxl
import pyodbc
sys.stdout.reconfigure(encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_connection

# 1. Load user.md mappings
abbrev_map = {}
def load_abbrev_map():
    global abbrev_map
    path = "e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/user.md"
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                if ":" in line:
                    parts = line.split(":", 1)
                    key = parts[0].strip().lower()
                    val = parts[1].strip()
                    abbrev_map[key] = val
    # Add common fallbacks
    if "pcd" not in abbrev_map: abbrev_map["pcd"] = "Phó giám đốc"
    if "pgd" not in abbrev_map: abbrev_map["pgd"] = "Phó giám đốc"
    if "bgd" not in abbrev_map: abbrev_map["bgd"] = "Ban Giám đốc"
    print(f"Loaded {len(abbrev_map)} abbreviation mappings from user.md")

# Helper to remove accents for matching
def remove_vietnamese_accents(s: str) -> str:
    s = s.lower()
    s = re.sub('[áàảãạăắằẳẵặâấầẩẫậ]', 'a', s)
    s = re.sub('[éèẻẽẹêếềểễệ]', 'e', s)
    s = re.sub('[íìỉĩị]', 'i', s)
    s = re.sub('[óòỏõọôốồổỗộơớờởỡợ]', 'o', s)
    s = re.sub('[úùủũụưứừửữự]', 'u', s)
    s = re.sub('[ýỳỷỹỵ]', 'y', s)
    s = re.sub('[đ]', 'd', s)
    return s

def clean_title(name: str) -> str:
    # Clean titles like Đ/c, GS. TS, PGS. TS, Trung tướng, Thượng tướng, đ/c
    name = re.sub(r'^(?:đ/c|Đ/c|các đ/c|Các đ/c|đồng chí|đồng chí:|GS\.\s*TS|PGS\.\s*TS|PGS,\s*TS|Trung tướng|Thượng tướng)\s+', '', name, flags=re.IGNORECASE)
    # Clean trailing titles in parentheses e.g. "Vũ (PGĐ)" -> "Vũ"
    name = re.sub(r'\s*\([^)]+\)$', '', name)
    return name.strip()

# Load all accounts from danh_sach_tai_khoan.xlsx
def load_xlsx_users():
    path = "e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/danh_sach_tai_khoan.xlsx"
    xlsx_users = []
    if not os.path.exists(path):
        print(f"Warning: {path} not found.")
        return xlsx_users
        
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    sheet = wb["Danh sách tài khoản"]
    for r_idx, row in enumerate(sheet.iter_rows(values_only=True)):
        if r_idx < 3: # Skip headers
            continue
        if not row or not row[0]:
            continue
        xlsx_users.append({
            "id": str(row[0]).strip(),
            "username": str(row[1]).strip() if row[1] else "",
            "password": str(row[2]).strip() if row[2] else "123456",
            "fullName": str(row[3]).strip() if row[3] else "",
            "role": str(row[4]).strip() if row[4] else "Giảng viên",
            "departmentName": str(row[5]).strip() if row[5] else ""
        })
    wb.close()
    print(f"Loaded {len(xlsx_users)} users from master spreadsheet.")
    return xlsx_users

# Find or create department in DB
def get_or_create_dept(abbrev: str, cursor) -> str:
    abbrev_clean = abbrev.lower().strip()
    full_name = abbrev_map.get(abbrev_clean, abbrev)
    
    # Check in DB
    cursor.execute("SELECT id, name FROM dbo.departments")
    depts = cursor.fetchall()
    
    # Match by ID or Name containing abbrev
    for d_id, d_name in depts:
        d_id_clean = d_id.lower().strip()
        d_name_clean = d_name.lower().strip()
        if abbrev_clean == d_id_clean or abbrev_clean == d_name_clean or abbrev_clean in d_name_clean:
            return d_id
        if full_name.lower() in d_name_clean:
            return d_id
            
    # If not found, create new department
    # Using abbrev_clean as ID (e.g. 'nv3', 'hc')
    cursor.execute("INSERT INTO dbo.departments (id, name) VALUES (?, ?)", (abbrev_clean, full_name))
    print(f"[Department] Created missing department in DB: ID='{abbrev_clean}', Name='{full_name}'")
    return abbrev_clean

# Generate username based on full name and department
def generate_username(full_name: str, dept_code: str, cursor) -> str:
    # E.g. "Nguyễn Đình Nghĩa" -> "nghiand"
    # E.g. "Thanh" -> "thanh.nv3"
    name_clean = remove_vietnamese_accents(full_name).lower().strip()
    words = name_clean.split()
    if not words:
        return f"user_{uuid.uuid4().hex[:6]}"
        
    if len(words) == 1:
        base = words[0]
        if dept_code:
            base = f"{base}.{dept_code.lower()}"
    else:
        # Last name + initials of first and middle names
        last_name = words[-1]
        initials = "".join([w[0] for w in words[:-1]])
        base = f"{last_name}{initials}"
        
    # Check if exists in DB, if so, append number
    candidate = base
    counter = 1
    while True:
        cursor.execute("SELECT id FROM dbo.users WHERE username = ?", (candidate,))
        if not cursor.fetchone():
            return candidate
        candidate = f"{base}{counter}"
        counter += 1

def sync_all():
    load_abbrev_map()
    xlsx_users = load_xlsx_users()
    
    conn = get_connection()
    cursor = conn.cursor()
    
    # Load existing users from DB
    cursor.execute("SELECT id, username, full_name, department_id FROM dbo.users")
    db_users = []
    for row in cursor.fetchall():
        db_users.append({
            "id": str(row[0]),
            "username": str(row[1]).strip(),
            "fullName": str(row[2]).strip(),
            "departmentId": str(row[3]).strip() if row[3] else None
        })
    print(f"Loaded {len(db_users)} users from database.")
    
    # Read PDF text
    pdf_text_path = "e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/fastapi_backend/scratch/pdf_text.txt"
    if not os.path.exists(pdf_text_path):
        print(f"Error: {pdf_text_path} does not exist. Run read_pdf_text.py first.")
        return
        
    with open(pdf_text_path, "r", encoding="utf-8") as f:
        text = f.read()
        
    # Regex extract Name and Dept pairs
    extracted = []
    lines = text.split('\n')
    for idx, line in enumerate(lines):
        # Exclude header lines
        if "HỌC VIỆN ANND LỊCH TUẦN" in line or "Thời gian, địa điểm" in line:
            continue
        # Match e.g. "Vũ (PGĐ)" or "Thanh, Thủy, Duy (QLĐT)"
        matches = re.finditer(r'([A-ZÀ-ỹ][A-Za-zÀ-ỹ\s,]+)\s*\(([^)]+)\)', line)
        for m in matches:
            names_str = m.group(1).strip()
            dept = m.group(2).strip()
            
            # Filter out false dept abbreviations
            if dept.lower() in ["từ 08/6 - 17/6/2026", "lần 1", "đã ký"]:
                continue
                
            names_str = re.sub(r'\b(?:đ/c|Đ/c|các đ/c|Các đ/c|đồng chí|đồng chí:|GS\.\s*TS|PGS\.\s*TS|PGS,\s*TS|Trung tướng|Thượng tướng)\b', '', names_str, flags=re.IGNORECASE).strip()
            names = [n.strip() for n in re.split(r'[,;]|\band\b', names_str) if n.strip()]
            for name in names:
                name_cleaned = clean_title(name)
                # Filter out false names
                if name_cleaned.lower() in ["trung quốc", "k", "họp hội đồng", "bgđ học viện", "thành viên", "đại diện", "lãnh đạo", "chủ biên"]:
                    continue
                if len(name_cleaned) < 2:
                    continue
                extracted.append((name_cleaned, dept))
                
        # Also parse Trực ban HV line explicitly
        # E.g. "Trực ban HV: Kiều Văn Nam (NV7); YTE: Đỗ Văn Thắng... QLHV: Vương Hồng Phúc"
        if "Trực ban HV:" in line:
            tb_match = re.search(r'Trực ban HV:\s*([^;(\n]+)\s*\(([^)]+)\)', line)
            if tb_match:
                extracted.append((clean_title(tb_match.group(1)), tb_match.group(2)))
            yt_match = re.search(r'YTE:\s*([^;,\n\t]+)', line)
            if yt_match:
                extracted.append((clean_title(yt_match.group(1)), "yte"))
            ql_match = re.search(r'QLHV:\s*([^;,\n\t\d]+)', line)
            if ql_match:
                extracted.append((clean_title(ql_match.group(1)), "qlhv"))
                
        # Also parse Trực BGĐ Học viện line
        # E.g. "Trực BGĐ Học viện: (Tuần từ 08/6 - 14/6/2026) Đ/c Nguyễn Văn Thiết"
        if "Trực BGĐ Học viện:" in line:
            bgd_match = re.search(r'Đ/c\s+([A-ZÀ-ỹ][a-zà-ỹ]+(?:\s+[A-ZÀ-ỹ][a-zà-ỹ]+)+)', line)
            if bgd_match:
                extracted.append((clean_title(bgd_match.group(1)), "bgd"))

    # Remove duplicates from extracted list
    unique_people = []
    seen = set()
    for name, dept in extracted:
        key = (name.lower(), dept.lower())
        if key not in seen:
            seen.add(key)
            unique_people.append((name, dept))
            
    print(f"\nFound {len(unique_people)} distinct people in schedule:")
    for name, dept in unique_people:
        print(f" - {name} ({dept})")
        
    print("\n--- SYNCHRONIZATION PROCESS ---")
    created_count = 0
    mapped_count = 0
    
    for name, dept_code in unique_people:
        dept_id = get_or_create_dept(dept_code, cursor)
        
        # Try to map to an existing user in DB
        mapped_user = None
        name_clean = remove_vietnamese_accents(name)
        
        # Priority 1: Exact full name or username matching in the department
        for u in db_users:
            u_name_clean = remove_vietnamese_accents(u["fullName"])
            if u_name_clean == name_clean and u["departmentId"] == dept_id:
                mapped_user = u
                break
                
        # Priority 2: Substring matching in the department (e.g. "Nghĩa" matches "Nguyễn Đình Nghĩa")
        if not mapped_user:
            for u in db_users:
                u_name_clean = remove_vietnamese_accents(u["fullName"])
                if u["departmentId"] == dept_id:
                    # Check if the extracted name is a sub-word (usually last name)
                    u_words = u_name_clean.split()
                    if u_words and u_words[-1] == name_clean:
                        mapped_user = u
                        break
                    if name_clean in u_name_clean:
                        mapped_user = u
                        break
                        
        # Priority 3: Match across other departments if not found in specific department
        if not mapped_user:
            for u in db_users:
                u_name_clean = remove_vietnamese_accents(u["fullName"])
                u_words = u_name_clean.split()
                if u_words and u_words[-1] == name_clean:
                    mapped_user = u
                    break
                if name_clean in u_name_clean:
                    mapped_user = u
                    break
                    
        if mapped_user:
            print(f"[Mapped] {name} ({dept_code}) -> DB User: '{mapped_user['fullName']}' (ID: {mapped_user['id']}, Username: {mapped_user['username']})")
            mapped_count += 1
        else:
            # Need to create account!
            # 1. Search in master spreadsheet first to get correct fullName, username, role, etc.
            spreadsheet_match = None
            for xu in xlsx_users:
                xu_name_clean = remove_vietnamese_accents(xu["fullName"])
                xu_words = xu_name_clean.split()
                if xu_name_clean == name_clean or (xu_words and xu_words[-1] == name_clean):
                    spreadsheet_match = xu
                    break
            
            if spreadsheet_match:
                new_id = spreadsheet_match["id"]
                username = spreadsheet_match["username"]
                full_name = spreadsheet_match["fullName"]
                role = spreadsheet_match["role"]
                password = spreadsheet_match["password"]
                print(f"[Create from Excel] Found details for {name} in Excel: FullName='{full_name}', Username='{username}'")
            else:
                # Generate new details
                new_id = str(uuid.uuid4())
                # If we don't have full name, e.g. "Thanh", we use that name
                full_name = name
                # If the department name is known, e.g. "Nghiệp vụ 3", we format it nicely
                dept_name = abbrev_map.get(dept_code.lower(), dept_code)
                # E.g. "Thanh (Nghiệp vụ 3)"
                if len(full_name.split()) == 1:
                    full_name = f"{full_name} ({dept_name})"
                username = generate_username(name, dept_code, cursor)
                role = "Giảng viên"
                password = "123456"
                print(f"[Create new] No Excel match for {name}. Generating Username='{username}', FullName='{full_name}'")
                
            # Double check if username exists in DB (just in case ID changed but username is duplicate)
            cursor.execute("SELECT id FROM dbo.users WHERE username = ?", (username,))
            if cursor.fetchone():
                username = generate_username(full_name, dept_code, cursor)
                
            # Create user in database
            cursor.execute("""
                INSERT INTO dbo.users (
                    id, username, password_hash, full_name, role, unit, department_id, is_active
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 1)
            """, (
                new_id, username, password, full_name, role, "Học viện ANND", dept_id
            ))
            
            # Register in local cache list so subsequent people can map to it
            db_users.append({
                "id": new_id,
                "username": username,
                "fullName": full_name,
                "departmentId": dept_id
            })
            
            print(f"[Created User] Added to DB: '{full_name}' (ID: {new_id}, Username: {username})")
            created_count += 1
            
    conn.commit()
    cursor.close()
    conn.close()
    
    print("\n--- SYNCHRONIZATION SUMMARY ---")
    print(f"Total people processed: {len(unique_people)}")
    print(f"Mapped to existing accounts: {mapped_count}")
    print(f"Created new accounts: {created_count}")

if __name__ == "__main__":
    sync_all()
