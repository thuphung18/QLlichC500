import pyodbc

conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=weekly_schedule_db;Trusted_Connection=yes;')
cursor = conn.cursor()

cursor.execute("SELECT TOP 5 id, start_time, end_time FROM dbo.schedules")
rows = cursor.fetchall()
out = ''
for r in rows:
    out += str(r) + '\n'

with open('test_times.txt', 'w', encoding='utf-8') as f:
    f.write(out)
