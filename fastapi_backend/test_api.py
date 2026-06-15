import requests

url = 'http://localhost:8000/api/schedules/day/2?user_id=admin001'
try:
    response = requests.get(url)
    print(response.json())
except Exception as e:
    print('Failed to connect to API:', e)
