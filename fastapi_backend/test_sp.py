import pyodbc

conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=weekly_schedule_db;Trusted_Connection=yes;')
cursor = conn.cursor()

cursor.execute("EXEC dbo.sp_GetSchedulesForUser @UserId='admin001', @DayIndex=2")
rows = cursor.fetchall()
out = 'Schedules returned for DayIndex 2:\n'
for row in rows:
    out += f"ID: {row.id}, Title: {row.title}, DateLabel: {row.dateLabel}\n"

cursor.execute("SELECT id, title, date_label, schedule_date, status, day_index FROM dbo.schedules")
all_rows = cursor.fetchall()
out += '\nAll Schedules in DB:\n'
for r in all_rows:
    out += str(r) + '\n'

with open('test_sp_out.txt', 'w', encoding='utf-8') as f:
    f.write(out)
