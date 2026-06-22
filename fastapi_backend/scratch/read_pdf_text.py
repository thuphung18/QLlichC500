import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Add the parent directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.gemini_service import parse_pdf_to_text

def save_pdf_text():
    pdf_path = "e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/LichTuan.24.2026. (1).pdf"
    print("Reading PDF...")
    text = parse_pdf_to_text(pdf_path)
    output_path = "e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/fastapi_backend/scratch/pdf_text.txt"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"Saved PDF text to {output_path}")

if __name__ == "__main__":
    save_pdf_text()
