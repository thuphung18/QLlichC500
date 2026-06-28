import httpx
import json

API_KEY = "sk-bee-1d8aeac1b8cc98034970fb41d5084422b3973cffd4211db05b5a7897c96f1eb9"

# 1. Test OpenAI format
try:
    print("Testing OpenAI format...")
    resp = httpx.post(
        "https://api.beeknoee.com/v1/chat/completions",
        headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
        json={
            "model": "gemini-2.5-flash-lite",
            "messages": [{"role": "user", "content": "Hello"}]
        },
        timeout=10
    )
    print("OpenAI status:", resp.status_code)
    print(resp.text[:200])
except Exception as e:
    print("OpenAI error:", e)

# 2. Test Google format
try:
    print("\nTesting Google format...")
    resp = httpx.post(
        f"https://api.beeknoee.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={API_KEY}",
        headers={"Content-Type": "application/json"},
        json={
            "contents": [{"parts": [{"text": "Hello"}]}]
        },
        timeout=10
    )
    print("Google status:", resp.status_code)
    print(resp.text[:200])
except Exception as e:
    print("Google error:", e)
