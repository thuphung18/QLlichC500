import time
import urllib.request
import ssl
import json
import sys

ctx = ssl._create_unverified_context()
url = "https://qllichc500-1.onrender.com/"
health_url = "https://qllichc500-1.onrender.com/health"

print("Starting to poll Render server for version '2.0.10 - friendly errors'...")

deployed = False
for i in range(40):
    try:
        with urllib.request.urlopen(url, context=ctx) as res:
            data = json.loads(res.read().decode('utf-8'))
            version = data.get("version", "")
            print(f"[{i+1}/40] Current version on Render: {version}")
            if "2.0.10" in version:
                deployed = True
                print("New version deployed successfully!")
                break
    except Exception as e:
        print(f"[{i+1}/40] Error polling server: {e}")
    time.sleep(15)

if not deployed:
    print("New version was not deployed within 5 minutes.")
    sys.exit(1)

# Now check health and print the key
print("\nChecking Render gemini_key value from health check...")
try:
    with urllib.request.urlopen(health_url, context=ctx) as res:
        data = json.loads(res.read().decode('utf-8'))
        print("Health check response:")
        print(json.dumps(data, indent=2, ensure_ascii=False))
except Exception as e:
    print("Failed to get health response:", e)
