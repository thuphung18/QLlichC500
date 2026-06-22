import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from main import app
from dependencies import verify_session_token

# Override dependency to mock authentication
app.dependency_overrides[verify_session_token] = lambda: "8601"

def test_import_endpoint():
    client = TestClient(app)
    pdf_path = "e:/Cong_Viec_Chuyen_mon/Flutter_project/QlLich/LichTuan.24.2026. (1).pdf"
    
    if not os.path.exists(pdf_path):
        print(f"Error: {pdf_path} not found.")
        return
        
    print(f"Sending POST /api/schedules/import with file: {pdf_path}...")
    try:
        with open(pdf_path, "rb") as f:
            files = {"file": (os.path.basename(pdf_path), f, "application/pdf")}
            response = client.post("/api/schedules/import", headers={"Authorization": "Bearer mocked-token"}, files=files)
            
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            schedules = response.json()
            print(f"Successfully parsed {len(schedules)} schedules!")
            
            # Check a few items for participantUserIds
            mapped_count = 0
            for idx, item in enumerate(schedules):
                title = item.get("title", "")
                teacher = item.get("teacher", "")
                p_ids = item.get("participantUserIds", [])
                p_raw = item.get("participants_raw", [])
                
                if p_ids:
                    mapped_count += 1
                if idx < 10: # Print first 10 items
                    print(f"\nItem {idx+1}:")
                    print(f"  Title: {title}")
                    print(f"  Teacher: {teacher}")
                    print(f"  Raw participants: {p_raw}")
                    print(f"  Mapped User IDs: {p_ids}")
                    
            print(f"\nSummary: {mapped_count} out of {len(schedules)} items have mapped participantUserIds.")
        else:
            print("Response error:", response.text)
            
    except Exception as e:
        print("Exception during request:", e)

if __name__ == "__main__":
    test_import_endpoint()
