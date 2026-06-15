import pyodbc
conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=weekly_schedule_db;Trusted_Connection=yes;')
cursor = conn.cursor()
cursor.execute("EXEC dbo.sp_GetSchedulesForUser @UserId='admin001'")
rows = cursor.fetchall()
print('Success')
