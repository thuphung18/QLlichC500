import pyodbc

conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=weekly_schedule_db;Trusted_Connection=yes;')
cursor = conn.cursor()

cursor.execute("SELECT id, fcm_token FROM dbo.users")
rows = cursor.fetchall()
out = ''
for r in rows:
    out += str(r) + '\n'

with open('test_tokens.txt', 'w', encoding='utf-8') as f:
    f.write(out)
