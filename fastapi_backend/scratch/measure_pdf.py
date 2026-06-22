import time
import os
import sys
import json
import asyncio
import pymupdf4llm
import pdfplumber
from dotenv import load_dotenv

load_dotenv()

# Setup path to import gemini_service
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
from services.gemini_service import extract_full_text_async, extract_single_chunk

pdf_path = "E:\\Cong_Viec_Chuyen_mon\\Flutter_project\\QlLich\\LichTuan.24.2026. (1).pdf"

if not os.path.exists(pdf_path):
    print("File not found:", pdf_path)
    exit(1)

departments = [{"id": "qldt", "name": "Phòng Quản lý đào tạo (QLĐT)"}]

async def main():
    print("Starting comprehensive measurement...")
    
    # 1. Measure pymupdf4llm
    print("\n1. Measuring pymupdf4llm...")
    t0 = time.time()
    md_text = pymupdf4llm.to_markdown(pdf_path)
    t1 = time.time()
    print(f"pymupdf4llm took {t1-t0:.2f} seconds. Length: {len(md_text)}")
    
    # 2. Measure Gemini with gemini-2.5-flash (single request)
    print("\n2. Measuring Gemini 2.5 Flash (Single Request)...")
    t0 = time.time()
    schedules = await extract_full_text_async(md_text, departments)
    t1 = time.time()
    print(f"Gemini 2.5 Flash (Single Request) took {t1-t0:.2f} seconds. Extracted {len(schedules)} schedules.")
    
    # 3. Measure Gemini with gemini-2.5-flash-lite (using chunking just to compare)
    print("\n3. Measuring Gemini 2.5 Flash Lite (Chunk 1)...")
    t0 = time.time()
    schedules_lite = await extract_single_chunk("Nhóm 1", md_text[:5000], departments)
    t1 = time.time()
    print(f"Gemini 2.5 Flash Lite (Chunk) took {t1-t0:.2f} seconds. Extracted {len(schedules_lite)} schedules.")

asyncio.run(main())
