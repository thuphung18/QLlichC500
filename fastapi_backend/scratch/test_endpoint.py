import sys
sys.path.append(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\fastapi_backend')
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)
response = client.delete("/api/schedules/clear-all?user_id=admin_user_id_here")
print(response.status_code, response.json())
