import urllib.request

url = 'https://upload.wikimedia.org/wikipedia/vi/a/ae/Logo_hoc_vien_ANND.png'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        with open('assets/images/logo.png', 'wb') as out_file:
            out_file.write(response.read())
    print("Download success")
except Exception as e:
    print("Download failed:", e)
