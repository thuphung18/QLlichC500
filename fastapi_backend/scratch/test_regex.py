import re
import sys
sys.stdout.reconfigure(encoding='utf-8')

def test_regex_extraction():
    with open("e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/fastapi_backend/scratch/pdf_text.txt", "r", encoding="utf-8") as f:
        text = f.read()
        
    print("--- TESTING NAME MATCHING REGEX ---")
    # Matches names with uppercase first letters, potentially multiple words, followed by an abbreviation in parentheses
    # E.g. "Kiều Văn Nam (NV7)", "Vũ (PGĐ)", "Thanh, Thủy, Duy (QLĐT)"
    
    # Let's find all parenthesized abbreviations first to see what's inside them
    parentheses = re.findall(r'\(([^)]+)\)', text)
    print("Parenthesized blocks found:", set(parentheses))
    
    # Let's extract pattern like "Name (Dept)" or "Name1, Name2 (Dept)"
    # We can split text by lines, and search for parts
    lines = text.split('\n')
    extracted = []
    
    for idx, line in enumerate(lines):
        # Match pattern: list of names followed by (DEPT)
        # E.g. "Thanh, Thủy, Duy (QLĐT)" or "Vũ (PGĐ)"
        matches = re.finditer(r'([A-ZÀ-ỹ][A-Za-zÀ-ỹ\s,]+)\s*\(([^)]+)\)', line)
        for m in matches:
            names_str = m.group(1).strip()
            dept = m.group(2).strip()
            # Clean names_str
            names_str = re.sub(r'\b(?:đ/c|Đ/c|các đ/c|Các đ/c|đồng chí|đồng chí:)\b', '', names_str, flags=re.IGNORECASE).strip()
            names = [n.strip() for n in re.split(r'[,;]|\band\b', names_str) if n.strip()]
            for name in names:
                # Remove extra spaces
                name = re.sub(r'\s+', ' ', name)
                extracted.append((name, dept, idx+1))
                
    print(f"\nExtracted {len(extracted)} name-dept pairs:")
    for name, dept, line_num in sorted(list(set(extracted)), key=lambda x: x[1]):
        print(f"Line {line_num}: Name: '{name}' | Dept: '{dept}'")

test_regex_extraction()
