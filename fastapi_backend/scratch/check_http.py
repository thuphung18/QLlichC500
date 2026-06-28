import sys
try:
    import requests
    print("requests is available")
except ImportError:
    print("requests is NOT available")

try:
    import httpx
    print("httpx is available")
except ImportError:
    print("httpx is NOT available")
