import urllib.request
import urllib.error
import json

API_KEY = "sk-bee-1d8aeac1b8cc98034970fb41d5084422b3973cffd4211db05b5a7897c96f1eb9"

# 1. Test OpenAI format
try:
    print("Testing OpenAI format...")
    req = urllib.request.Request(
        "https://api.beeknoee.com/v1/chat/completions",
        headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
        data=json.dumps({
            "model": "gemini-2.5-flash-lite",
            "messages": [{"role": "user", "content": "Hello"}]
        }).encode("utf-8")
    )
    with urllib.request.urlopen(req) as response:
        print("OpenAI status:", response.status)
        print(response.read().decode("utf-8")[:200])
except urllib.error.HTTPError as e:
    print("OpenAI HTTP Error:", e.code, e.read().decode("utf-8")[:200])
except Exception as e:
    print("OpenAI error:", e)

# 2. Test Google format
try:
    print("\nTesting Google format...")
    req = urllib.request.Request(
        f"https://api.beeknoee.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={API_KEY}",
        headers={"Content-Type": "application/json"},
        data=json.dumps({
            "contents": [{"parts": [{"text": "Hello"}]}]
        }).encode("utf-8")
    )
    with urllib.request.urlopen(req) as response:
        print("Google status:", response.status)
        print(response.read().decode("utf-8")[:200])
except urllib.error.HTTPError as e:
    print("Google HTTP Error:", e.code, e.read().decode("utf-8")[:200])
except Exception as e:
    print("Google error:", e)
