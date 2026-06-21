# services/gemini_service.py – Dịch vụ tích hợp Trí tuệ nhân tạo Gemini AI (Google GenAI SDK)
#
# Chức năng:
#   - Hỗ trợ tải tệp PDF/Word/Excel, trích xuất văn bản thô kèm giữ cấu trúc bảng biểu bằng Markdown.
#   - Tối ưu hóa hiệu năng và quota (Free Tier rate limit):
#     • Chia nhỏ tài liệu thành 3 nhóm ngày trong tuần (T2-T3, T4-T5, T6-CN).
#     • Sử dụng model 'gemini-2.5-flash-lite' để phân tích song song đa luồng (bằng asyncio & ThreadPoolExecutor).
#     • Tự động khớp và ánh xạ tên viết tắt phòng ban được AI tìm thấy sang UUID của cơ sở dữ liệu.

import os
import json
import re
import asyncio
import pdfplumber
import pymupdf4llm
from dotenv import load_dotenv

# Tải API key từ môi trường
load_dotenv()

# ─────────────────────────────────────────────
# Hàm hỗ trợ dọn dẹp API Key nếu bị dính tên biến hoặc dấu nháy khi copy-paste
# ─────────────────────────────────────────────
def get_clean_gemini_api_key() -> str:
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        return ""
    key = key.strip()
    # Trường hợp người dùng copy nguyên dòng từ file .env: GEMINI_API_KEY="key"
    if key.startswith("GEMINI_API_KEY="):
        key = key.split("GEMINI_API_KEY=")[1].strip()
    # Loại bỏ dấu nháy kép hoặc nháy đơn bao quanh key
    if (key.startswith('"') and key.endswith('"')) or (key.startswith("'") and key.endswith("'")):
        key = key[1:-1].strip()
    return key


# ─────────────────────────────────────────────
# Cấu hình Gemini SDK Client (Hỗ trợ cả SDK mới và cũ)
# ─────────────────────────────────────────────
_API_KEY = get_clean_gemini_api_key()

try:
    from google import genai as _genai_new
    # Khởi tạo client theo SDK 'google-genai' mới (khuyên dùng)
    _client = _genai_new.Client(api_key=_API_KEY)
    _USE_NEW_SDK = True
except ImportError:
    # Cơ chế dự phòng (fallback) nếu hệ thống chỉ cài SDK 'google-generativeai' cũ
    import google.generativeai as genai
    genai.configure(api_key=_API_KEY)
    _USE_NEW_SDK = False



def _generate_content(model_name: str, prompt: str) -> str:
    """
    Thực hiện gửi yêu cầu tạo nội dung (generate content) đến Gemini API,
    tự động chọn cú pháp phù hợp với phiên bản SDK đang chạy.
    """
    if _USE_NEW_SDK:
        response = _client.models.generate_content(model=model_name, contents=prompt)
        return response.text
    else:
        model = genai.GenerativeModel(model_name)
        return model.generate_content(prompt).text


def parse_pdf_to_text(file_path: str) -> str:
    """
    [Legacy] Trích xuất văn bản thô từ file PDF sử dụng thư viện pdfplumber.
    (Không giữ được định dạng bảng tốt bằng các cơ chế chuyển sang Markdown mới).
    """
    text = ""
    try:
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
    except Exception as e:
        print(f"[Gemini Service] Lỗi đọc PDF sang Text: {e}")
    return text


def extract_schedules_from_text(text: str, departments: list) -> list:
    """
    [Legacy/Đồng bộ] Gửi trực tiếp toàn bộ văn bản thô lên Gemini để bóc tách lịch dạng JSON.
    (Ít dùng hơn phương pháp xử lý song song phân chia theo nhóm ngày mới).
    """
    dept_info = json.dumps(departments, ensure_ascii=False)
    prompt = f"""
Bạn là một trợ lý AI phân tích lịch công tác. Nhiệm vụ của bạn là đọc nội dung lịch (dạng text được trích xuất từ PDF) và trích xuất thành một mảng (array) các object JSON.

DANH SÁCH PHÒNG BAN TRONG HỆ THỐNG:
{dept_info}

Quy tắc trích xuất cho mỗi lịch (trả về đúng định dạng JSON này, không có markdown formatting bên ngoài, CHỈ TRẢ VỀ JSON ARRAY TRỰC TIẾP `[...]`):
[
  {{
    "title": "Nội dung công việc (chuỗi)",
    "teacher": "Người chủ trì (tên người, ví dụ: Đ/c Vũ (PGĐ))",
    "room": "Địa điểm (nếu có, không có để chuỗi rỗng)",
    "scheduleDate": "Ngày diễn ra (định dạng YYYY-MM-DD). Hãy tự suy luận ngày dựa vào tiêu đề Lịch tuần hoặc các dấu hiệu ngày tháng.",
    "startTime": "Giờ bắt đầu (định dạng HH:MM, nếu không có để 08:00)",
    "endTime": "Giờ kết thúc (định dạng HH:MM, nếu không có để 11:30)",
    "note": "Thành phần dự hoặc ghi chú (chuỗi)",
    "unit": "Học viện ANND",
    "departmentId": "Mã UUID của phòng ban liên quan nhất (Dựa vào chữ viết tắt trong Nội dung hoặc Thành phần dự. Ví dụ: QLĐT, HC, NV1... Đối chiếu với DANH SÁCH PHÒNG BAN ở trên để lấy ra id chính xác. Nếu không xác định được, hãy lấy id của phòng Quản lý đào tạo (QLĐT) hoặc Hành chính (HC) hoặc để chuỗi rỗng).",
    "category": "ToanTruong",
    "participantUserIds": []
  }}
]

NỘI DUNG LỊCH CÔNG TÁC:
{text}
"""
    try:
        result_text = _generate_content('gemini-2.5-flash', prompt).strip()
        # Dọn dẹp thẻ bao bọc markdown ```json ... ```
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
        result_text = result_text.strip()
        parsed_json = json.loads(result_text)
        if isinstance(parsed_json, list):
            return parsed_json
        return []
    except Exception as e:
        print(f"[Gemini Service] Lỗi gọi API Gemini: {e}")
        return []


# ─────────────────────────────────────────────────────────────────
# Tối ưu hóa xử lý song song & Chuyển đổi Markdown nâng cao
# ─────────────────────────────────────────────────────────────────

def find_matching_department_id(dept_keyword: str, departments: list) -> str:
    """
    Thuật toán ánh xạ thông minh:
    Nhận diện từ khóa viết tắt phòng ban do AI trích xuất (ví dụ: "QLĐT", "HC", "NV1") 
    và khớp nó với danh sách phòng ban trong hệ thống để lấy đúng mã UUID.
    """
    if not dept_keyword or not isinstance(dept_keyword, str):
        return ""
    clean_kw = dept_keyword.strip().lower()
    
    # 1. So khớp trực tiếp (Ví dụ: "qldt" có nằm trong "Phòng Quản lý đào tạo (QLĐT)")
    for dept in departments:
        dept_name = dept["name"].lower()
        if clean_kw in dept_name:
            return dept["id"]
            
    # 2. So khớp ký tự đầu viết tắt (Ví dụ: "hc" -> "hành chính")
    for dept in departments:
        dept_name = dept["name"].lower()
        words = dept_name.split()
        initials = "".join([w[0] for w in words if w])
        if clean_kw == initials:
            return dept["id"]
            
    # 3. So khớp ngược từ hoặc chứa từ khóa
    for dept in departments:
        dept_name = dept["name"].lower()
        if clean_kw in dept_name or dept_name in clean_kw:
            return dept["id"]
            
    # 4. Cơ chế dự phòng mặc định (Fallback)
    for dept in departments:
        name_lower = dept["name"].lower()
        if "đào tạo" in name_lower or "qldt" in name_lower:
            return dept["id"]
    for dept in departments:
        name_lower = dept["name"].lower()
        if "hành chính" in name_lower or "hc" in name_lower:
            return dept["id"]
            
    # Trả về ID đầu tiên nếu không khớp được bất kỳ quy tắc nào
    return departments[0]["id"] if departments else ""


def parse_pdf_to_markdown(file_path: str) -> str:
    """
    Chuyển đổi tệp PDF sang định dạng Text thô sử dụng pdfplumber.
    pdfplumber nhẹ và nhanh hơn rất nhiều so với pymupdf4llm, giúp giảm tải CPU trên Render Free Tier.
    """
    return parse_pdf_to_text(file_path)


def split_markdown_by_days(md_text: str) -> dict:
    """
    Phân tích văn bản lịch và chia nhỏ thành từng đoạn văn bản tương ứng với từng Thứ trong tuần.
    Trả về: dict {"Thứ Hai": "nội dung...", "Thứ Ba": "nội dung..."}
    """
    days = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật", 
            "Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật"]
    
    # Sử dụng Regex tìm kiếm mốc biên giới là các tiêu đề Thứ
    pattern = r"(?i)(" + "|".join([re.escape(day) for day in days]) + r")"
    matches = list(re.finditer(pattern, md_text))
    
    if not matches:
        return {"Toàn bộ lịch": md_text}
    
    chunks = {}
    for i in range(len(matches)):
        start = matches[i].start()
        end = matches[i+1].start() if i + 1 < len(matches) else len(md_text)
        day_name = matches[i].group(0)
        chunks[day_name] = md_text[start:end]
        
    return chunks


def split_markdown_into_groups(md_text: str) -> dict:
    """
    Gộp các ngày lại thành 3 nhóm xử lý chính nhằm tránh chạm giới hạn Rate Limit (5 RPM) của API Key miễn phí:
      - Nhóm 1: Thứ 2 và Thứ 3.
      - Nhóm 2: Thứ 4 và Thứ 5.
      - Nhóm 3: Thứ 6, 7 và Chủ Nhật.
    """
    chunks = split_markdown_by_days(md_text)
    
    group_mapping = {
        "thứ hai": "Nhóm 1 (Thứ 2 - Thứ 3)",
        "thứ 2": "Nhóm 1 (Thứ 2 - Thứ 3)",
        "thứ ba": "Nhóm 1 (Thứ 2 - Thứ 3)",
        "thứ 3": "Nhóm 1 (Thứ 2 - Thứ 3)",
        
        "thứ tư": "Nhóm 2 (Thứ 4 - Thứ 5)",
        "thứ 4": "Nhóm 2 (Thứ 4 - Thứ 5)",
        "thứ năm": "Nhóm 2 (Thứ 4 - Thứ 5)",
        "thứ 5": "Nhóm 2 (Thứ 4 - Thứ 5)",
        
        "thứ sáu": "Nhóm 3 (Thứ 6 - Chủ Nhật)",
        "thứ 6": "Nhóm 3 (Thứ 6 - Chủ Nhật)",
        "thứ bảy": "Nhóm 3 (Thứ 6 - Chủ Nhật)",
        "thứ 7": "Nhóm 3 (Thứ 6 - Chủ Nhật)",
        "chủ nhật": "Nhóm 3 (Thứ 6 - Chủ Nhật)"
    }
    
    groups = {
        "Nhóm 1 (Thứ 2 - Thứ 3)": "",
        "Nhóm 2 (Thứ 4 - Thứ 5)": "",
        "Nhóm 3 (Thứ 6 - Chủ Nhật)": ""
    }
    
    for day_name, content in chunks.items():
        matched_group = None
        for key, group_name in group_mapping.items():
            if key in day_name.lower():
                matched_group = group_name
                break
        if matched_group:
            groups[matched_group] += content + "\n"
        else:
            # Nếu không tìm thấy thứ hợp lệ, gộp tạm vào Nhóm 1
            groups["Nhóm 1 (Thứ 2 - Thứ 3)"] += content + "\n"
            
    # Lọc bỏ các nhóm rỗng
    return {k: v for k, v in groups.items() if v.strip()}


async def extract_single_chunk(group_name: str, chunk_text: str, departments: list) -> list:
    """
    Gửi một nhóm văn bản lên Gemini xử lý.
    Sử dụng model 'gemini-2.5-flash-lite' để có tốc độ phản hồi nhanh nhất và hạn mức gọi API tốt nhất.
    Chạy bất đồng bộ thông qua run_in_executor để tránh block thread xử lý chính.
    """
    prompt = f"""
Bạn là một trợ lý AI phân tích lịch công tác. Nhiệm vụ của bạn là đọc nội dung lịch dưới đây (dạng Markdown) và trích xuất thành danh sách các object JSON rút gọn.

Quy tắc trích xuất (CHỈ trả về JSON array trực tiếp `[...]`):
[
  {{
    "title": "Nội dung công việc (chuỗi)",
    "teacher": "Người chủ trì (tên người, ví dụ: Đ/c Vũ (PGĐ))",
    "room": "Địa điểm (nếu có, không có để chuỗi rỗng)",
    "scheduleDate": "Ngày diễn ra (định dạng YYYY-MM-DD). Hãy suy luận ngày dựa vào mốc thời gian trong văn bản của từng công việc.",
    "startTime": "Giờ bắt đầu (định dạng HH:MM, mặc định 08:00)",
    "endTime": "Giờ kết thúc (định dạng HH:MM, mặc định 11:30)",
    "note": "Thành phần dự hoặc ghi chú (chuỗi)",
    "department": "Tên viết tắt hoặc từ khóa của phòng ban liên quan nhất (ví dụ: QLĐT, HC, NV1... để trống nếu không rõ)"
  }}
]

NỘI DUNG LỊCH CÔNG TÁC CỦA {group_name}:
{chunk_text}
"""
    try:
        loop = asyncio.get_event_loop()
        
        def _call_api():
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
                return response.text
            else:
                model = genai.GenerativeModel('gemini-2.5-flash')
                response = model.generate_content(
                    prompt,
                    generation_config={"response_mime_type": "application/json", "temperature": 0.1}
                )
                return response.text

        response_text = await loop.run_in_executor(None, _call_api)
        result_text = response_text.strip() if isinstance(response_text, str) else response_text
        
        # Dọn dẹp thẻ code block phòng hờ trường hợp API không tuân thủ hoàn toàn JSON mode
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
            
        result_text = result_text.strip()
        parsed_json = json.loads(result_text)
        
        if isinstance(parsed_json, list):
            for item in parsed_json:
                item["unit"] = "Học viện ANND"
                item["category"] = "ToanTruong"
                item["participantUserIds"] = []
                
                dept_name = item.pop("department", "")
                item["departmentId"] = find_matching_department_id(dept_name, departments)
                
            return parsed_json
        return []
    except Exception as e:
        print(f"[Gemini Service] Lỗi xử lý nhóm {group_name}: {e}")
        return []


async def extract_full_text_async(text: str, departments: list) -> list:
    """
    Gửi toàn bộ văn bản lên Gemini để trích xuất trong 1 request duy nhất.
    Sử dụng Prompt viết tắt cực kỳ gọn nhẹ nhằm tối ưu số lượng output token sinh ra,
    giúp tăng tốc độ phản hồi của API lên gấp nhiều lần và tiết kiệm tối đa hạn mức quota (1 request/lần).
    """
    dept_info = json.dumps(departments, ensure_ascii=False)
    prompt = f"""
Bạn là một trợ lý AI bóc tách lịch công tác chuyên nghiệp. Hãy đọc văn bản lịch dưới đây và trích xuất thành một JSON array chứa các objects viết tắt gọn nhẹ sau:

DANH SÁCH PHÒNG BAN TRONG HỆ THỐNG:
{dept_info}

Quy tắc cấu trúc viết tắt (CHỈ trả về JSON array thô `[...]` không bọc markdown):
[
  {{
    "t": "Tiêu đề công việc (chuỗi)",
    "tc": "Người chủ trì (tên người, ví dụ: Đ/c Vũ (PGĐ))",
    "r": "Địa điểm (nếu có, không có để chuỗi rỗng)",
    "d": "Ngày (scheduleDate dưới dạng YYYY-MM-DD, hãy tự suy luận dựa vào tiêu đề tuần hoặc các mốc thời gian của cả tuần)",
    "st": "Giờ bắt đầu (startTime dưới dạng HH:MM, mặc định 08:00)",
    "et": "Giờ kết thúc (endTime dưới dạng HH:MM, mặc định 11:30)",
    "n": "Ghi chú/Thành phần tham gia (note)",
    "dp": "Tên viết tắt hoặc từ khóa của phòng ban liên quan nhất (ví dụ: QLĐT, HC, NV1... để trống nếu không rõ)"
  }}
]

VĂN BẢN LỊCH CÔNG TÁC:
{text}
"""
    try:
        loop = asyncio.get_event_loop()
        
        def _call_api():
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
                return response.text
            else:
                model = genai.GenerativeModel('gemini-2.5-flash')
                response = model.generate_content(
                    prompt,
                    generation_config={"response_mime_type": "application/json", "temperature": 0.1}
                )
                return response.text

        response_text = await loop.run_in_executor(None, _call_api)
        result_text = response_text.strip() if isinstance(response_text, str) else response_text
        
        # Dọn dẹp thẻ code block phòng hờ trường hợp API không tuân thủ hoàn toàn JSON mode
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
            
        result_text = result_text.strip()
        parsed_json = json.loads(result_text)
        
        schedules = []
        if isinstance(parsed_json, list):
            for item in parsed_json:
                # Ánh xạ từ các key viết tắt sang định dạng chuẩn của DB
                schedule_item = {
                    "title": item.get("t", ""),
                    "teacher": item.get("tc", ""),
                    "room": item.get("r", ""),
                    "scheduleDate": item.get("d", ""),
                    "startTime": item.get("st", "08:00"),
                    "endTime": item.get("et", "11:30"),
                    "note": item.get("n", ""),
                    "unit": "Học viện ANND",
                    "category": "ToanTruong",
                    "participantUserIds": [],
                    "departmentId": ""
                }
                
                # Ánh xạ ID phòng ban
                dept_name = item.get("dp", "")
                schedule_item["departmentId"] = find_matching_department_id(dept_name, departments)
                schedules.append(schedule_item)
                
            return schedules
        return []
    except Exception as e:
        print(f"[Gemini Service] Lỗi trích xuất toàn bộ text: {e}")
        return []



def parse_docx_to_markdown(file_path: str) -> str:
    """
    Chuyển đổi tệp Word (.docx) sang văn bản định dạng Markdown.
    Duyệt tuần tự qua các Paragraph và Table để chuyển sang cú pháp Markdown lưới.
    """
    try:
        import docx
        doc = docx.Document(file_path)
        content = []
        
        # Duyệt qua cây tài liệu XML
        for block in doc.element.body:
            name = block.tag.split('}')[-1]
            if name == 'p':
                # Xử lý đoạn văn
                p = docx.text.paragraph.Paragraph(block, doc)
                if p.text.strip():
                    content.append(p.text.strip())
            elif name == 'tbl':
                # Xử lý bảng biểu
                table = docx.table.Table(block, doc)
                table_md = []
                for r_idx, row in enumerate(table.rows):
                    row_cells = [cell.text.strip().replace("\n", " ") for cell in row.cells]
                    table_md.append(f"| {' | '.join(row_cells)} |")
                    if r_idx == 0:
                        # Thêm hàng gạch ngăn cách đầu bảng
                        separators = ["---"] * len(row_cells)
                        table_md.append(f"| {' | '.join(separators)} |")
                content.append("\n".join(table_md) + "\n")
        return "\n".join(content)
    except Exception as e:
        print(f"[Gemini Service] Lỗi chuyển Word (.docx) sang Markdown: {e}")
        return ""


def parse_xlsx_to_markdown(file_path: str) -> str:
    """
    Chuyển đổi bảng tính Excel (.xlsx) sang Markdown Table để gửi cho AI.
    """
    try:
        import openpyxl
        wb = openpyxl.load_workbook(file_path, read_only=True, data_only=True)
        sheet = wb.active
        content = []
        
        table_md = []
        for r_idx, row in enumerate(sheet.iter_rows(values_only=True)):
            # Chuyển đổi dữ liệu các cell sang String và dọn dẹp ký tự xuống dòng
            row_cells = [str(cell).strip().replace("\n", " ") if cell is not None else "" for cell in row]
            
            # Bỏ qua dòng trống hoàn toàn
            if not any(row_cells):
                continue
                
            table_md.append(f"| {' | '.join(row_cells)} |")
            if r_idx == 0:
                separators = ["---"] * len(row_cells)
                table_md.append(f"| {' | '.join(separators)} |")
                
        content.append("\n".join(table_md))
        wb.close()
        return "\n".join(content)
    except Exception as e:
        print(f"[Gemini Service] Lỗi chuyển Excel (.xlsx) sang Markdown: {e}")
        return ""


async def extract_schedules_from_file_async(file_path: str, file_ext: str, departments: list) -> list:
    """
    HÀM ĐIỀU PHỐI CHÍNH (Đã tối ưu hóa tốc độ cao bằng cách chia nhỏ song song):
      1. Nhận diện định dạng tệp và chuyển đổi cấu trúc sang văn bản (pdfplumber/docx/xlsx).
      2. Phân chia nội dung thành các nhóm ngày để giảm tải lượng output token sinh ra trong mỗi request,
         giúp Gemini 2.5 Flash phản hồi siêu nhanh dưới 15 giây (tránh timeout của Render).
      3. Kích hoạt xử lý song song đồng thời (asyncio.gather) gửi các yêu cầu lên Gemini API bằng model gemini-2.5-flash.
      4. Thu thập và hợp nhất danh sách lịch công tác trả về.
    """
    # 1. Chuyển đổi định dạng tệp sang văn bản
    if file_ext == '.pdf':
        md_text = parse_pdf_to_markdown(file_path)
    elif file_ext == '.docx':
        md_text = parse_docx_to_markdown(file_path)
    elif file_ext == '.xlsx':
        md_text = parse_xlsx_to_markdown(file_path)
    else:
        print(f"[Gemini Service] Định dạng file không hỗ trợ: {file_ext}")
        return []
        
    if not md_text or not md_text.strip():
        print("[Gemini Service] Không trích xuất được nội dung chữ từ file.")
        return []
        
    # Luôn sử dụng cơ chế chia nhóm ngày để xử lý song song tốc độ cao (tránh nghẽn output token của Gemini và tránh timeout Render)
    groups = split_markdown_into_groups(md_text)
    
    # Tạo danh sách các task xử lý đồng thời bất đồng bộ bằng gemini-2.5-flash
    tasks = []
    for group_name, chunk_content in groups.items():
        if chunk_content.strip():
            tasks.append(extract_single_chunk(group_name, chunk_content, departments))
        
    # Kích hoạt thực thi đồng thời và chờ đợi kết quả
    if not tasks:
        return []
        
    results = await asyncio.gather(*tasks)
    
    # Hợp nhất kết quả từ các luồng gửi về
    all_schedules = []
    for group_schedules in results:
        all_schedules.extend(group_schedules)
        
    return all_schedules


