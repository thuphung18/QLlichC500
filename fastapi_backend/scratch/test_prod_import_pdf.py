import os
import sys
import json
import urllib.request
import ssl
import time

pdf_path = "E:\\Cong_Viec_Chuyen_mon\\Flutter_project\\QlLich\\LichTuan.24.2026. (1).pdf"

if not os.path.exists(pdf_path):
    print("PDF file not found at:", pdf_path)
    sys.exit(1)

ctx = ssl._create_unverified_context()

try:
    # 1. Login
    print("Logging in to production...")
    login_url = "https://qllichc500-1.onrender.com/api/auth/login"
    login_data = json.dumps({"username": "thupv", "password": "123456"}).encode('utf-8')

    req = urllib.request.Request(
        login_url,
        data=login_data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, context=ctx) as response:
        login_res = json.loads(response.read().decode('utf-8'))
        token = login_res["access_token"]
        print("Login successful.")

    # 2. Upload PDF
    print("Uploading real PDF to production...")
    import_url = "https://qllichc500-1.onrender.com/api/schedules/import"
    
    with open(pdf_path, "rb") as f:
        file_content = f.read()
        
    boundary = b"----WebKitFormBoundary7MA4YWxkTrZu0gW"
    body = []
    body.append(b"--" + boundary)
    body.append(b'Content-Disposition: form-data; name="file"; filename="LichTuan.pdf"')
    body.append(b'Content-Type: application/pdf')
    body.append(b'')
    body.append(file_content)
    body.append(b"--" + boundary + b"--")
    body.append(b'')
    
    encoded_body = b"\r\n".join(body)
    
    req_upload = urllib.request.Request(
        import_url,
        data=encoded_body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary.decode('utf-8')}",
            "Authorization": f"Bearer {token}"
        }
    )
    
    start_time = time.time()
    try:
        with urllib.request.urlopen(req_upload, context=ctx) as upload_res:
            res_content = upload_res.read().decode('utf-8')
            elapsed = time.time() - start_time
            print(f"Import response status: 200 OK (took {elapsed:.2f} seconds)")
            res_json = json.loads(res_content)
            print("Extracted schedules count:", len(res_json))
    except urllib.error.HTTPError as e:
        elapsed = time.time() - start_time
        print(f"Upload failed after {elapsed:.2f} seconds with status: {e.code}")
        print("Response body:", e.read().decode('utf-8'))

except Exception as e:
    print("Test failed with exception:", e)
