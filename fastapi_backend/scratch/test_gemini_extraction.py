import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Add the parent directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.gemini_service import _client, _USE_NEW_SDK, parse_pdf_to_text

def extract_people():
    pdf_path = "e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/LichTuan.24.2026. (1).pdf"
    print("Extracting text from PDF...")
    text = parse_pdf_to_text(pdf_path)
    print(f"Extracted {len(text)} characters.")
    
    prompt = f"""
Bạn là một chuyên gia bóc tách thông tin nhân sự. Hãy đọc văn bản lịch công tác dưới đây và trích xuất tất cả những người (Đồng chí, Giáo sư, Phó giám đốc, Giảng viên...) được nhắc tên trong lịch.
Loại bỏ các từ chung chung như "BGĐ Học viện", "Thành viên Ban Coi thi", "đại diện lãnh đạo các đơn vị", "đơn vị tư vấn thiết kế", "LTTV", "cử cán bộ", "Êkip VTV".
Chỉ bóc tách những cá nhân cụ thể có tên (có thể đi kèm phòng ban viết tắt trong ngoặc đơn, ví dụ: 'Nghĩa (NV7)', 'Vũ (PGĐ)', 'Thanh (QLĐT)').

Yêu cầu trả về một JSON array duy nhất dạng:
[
  {{
    "raw_name": "Tên gốc trong văn bản (ví dụ: Vũ (PGĐ), Kiều Văn Nam (NV7), Thanh (QLĐT), Ban (BCA))",
    "name": "Họ và tên hoặc Tên riêng không chứa từ chỉ chức vụ như Đ/c, GS. TS (ví dụ: Vũ, Kiều Văn Nam, Thanh, Ban)",
    "dept_abbrev": "Chữ viết tắt đơn vị trong ngoặc nếu có, viết thường hoặc viết hoa (ví dụ: pgd, nv7, qldt, bca, nếu không ghi đơn vị thì để null)",
    "role_title": "Chức vụ đi kèm nếu có như PGĐ, Giám đốc, Trưởng khoa, Phó giám đốc (nếu không có để null)"
  }}
]

VĂN BẢN LỊCH CÔNG TÁC:
{text}
"""
    print("Calling Gemini API...")
    try:
        if _USE_NEW_SDK:
            from google.genai import types
            config = types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1
            )
            response = _client.models.generate_content(
                model='gemini-2.5-flash',
                contents=prompt,
                config=config
            )
            response_text = response.text
        else:
            import google.generativeai as genai
            model = genai.GenerativeModel('gemini-2.5-flash')
            response = model.generate_content(
                prompt,
                generation_config={"response_mime_type": "application/json", "temperature": 0.1}
            )
            response_text = response.text
            
        print("--- GEMINI RESPONSE ---")
        print(response_text)
    except Exception as e:
        print("Error calling Gemini API:", e)

if __name__ == "__main__":
    extract_people()
