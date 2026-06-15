import pyodbc

conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=weekly_schedule_db;Trusted_Connection=yes;')
cursor = conn.cursor()
cursor.execute("SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.v_schedule_api'))")
v_schedule_api = cursor.fetchone()[0]

cursor.execute("SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.sp_GetSchedulesForUser'))")
sp = cursor.fetchone()[0]

with open('db_out.txt', 'w', encoding='utf-8') as f:
    f.write('v_schedule_api:\n' + str(v_schedule_api) + '\n\nsp_GetSchedulesForUser:\n' + str(sp))
