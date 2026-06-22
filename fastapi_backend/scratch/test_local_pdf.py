import asyncio
import os
import sys
import json
import time
from dotenv import load_dotenv

load_dotenv()

# Setup path to import backend modules
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
from services.gemini_service import get_clean_gemini_api_key, find_matching_department_id

# We will implement the optimized single request here directly to test
import google.generativeai as genai
_API_KEY = get_clean_gemini_api_key()
genai.configure(api_key=_API_KEY)

pdf_path = "E:\\Cong_Viec_Chuyen_mon\\Flutter_project\\QlLich\\LichTuan.24.2026. (1).pdf"
import pdfplumber

async def test_optimized_single_request():
    print("1. Extracting text with pdfplumber...")
    t0 = time.time()
    text = ""
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
    t1 = time.time()
    print(f"pdfplumber took {t1-t0:.2f} seconds. Text length: {len(text)}")
    
    print("\n2. Calling Gemini 2.5 Flash with optimized compact prompt (Single Request)...")
    prompt = f"""
Bạn là một trợ lý AI bóc tách lịch công tác. Hãy đọc văn bản lịch dưới đây và trích xuất thành một JSON array chứa các objects viết tắt gọn nhẹ sau:
Quy tắc viết tắt:
t: Tiêu đề công việc (title)
tc: Người chủ trì (teacher)
r: Địa điểm (room)
d: Ngày (scheduleDate dưới dạng YYYY-MM-DD, suy luận từ văn bản)
st: Giờ bắt đầu (startTime dưới dạng HH:MM, mặc định 08:00)
et: Giờ kết thúc (endTime dưới dạng HH:MM, mặc định 11:30)
n: Ghi chú/Thành phần tham gia (note)
dp: Từ khóa phòng ban liên quan nhất (department, ví dụ: QLĐT, HC, NV1...)

CHỈ trả về JSON array thô `[...]` không bọc markdown.

VĂN BẢN LỊCH CÔNG TÁC:
{text}
"""
    t0 = time.time()
    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(
            prompt,
            generation_config={"response_mime_type": "application/json", "temperature": 0.1}
        )
        res_text = response.text.strip()
        t1 = time.time()
        print(f"Gemini API took {t1-t0:.2f} seconds. Response length: {len(res_text)}")
        
        parsed = json.loads(res_text)
        print("Schedules count extracted:", len(parsed))
        if parsed:
            print("First extracted item:")
            print(json.dumps(parsed[0], indent=2, ensure_ascii=False))
            
    except Exception as e:
        print("Failed:", e)

asyncio.run(test_optimized_single_request())
