import requests

API_KEY = "sk-bee-1d8aeac1b8cc98034970fb41d5084422b3973cffd4211db05b5a7897c96f1eb9"
BASE_URL = "https://platform.beeknoee.com/api/v1/chat/completions"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

payload = {
    "model": "gemini-2.5-flash-lite",
    "messages": [
        {"role": "user", "content": "Hello. Please respond in JSON format with a single key 'message'."}
    ],
    "response_format": {"type": "json_object"},
    "temperature": 0.1
}

resp = requests.post(BASE_URL, headers=headers, json=payload)
print(resp.status_code)
print(resp.text)
