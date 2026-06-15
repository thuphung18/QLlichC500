import pyodbc

conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=weekly_schedule_db;Trusted_Connection=yes;')
cursor = conn.cursor()

sql = """
CREATE OR ALTER PROCEDURE dbo.sp_GetSchedulesForUser
    @UserId NVARCHAR(50),
    @DayIndex INT = NULL,
    @Mode NVARCHAR(50) = N'all',
    @Keyword NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserDepartmentId NVARCHAR(50);
    DECLARE @UserRole NVARCHAR(50);
    
    SELECT @UserDepartmentId = department_id, @UserRole = LOWER(role)
    FROM dbo.users
    WHERE id = @UserId AND is_active = 1;

    SELECT
        v.id,
        v.title,
        v.teacher,
        v.room,
        v.dateLabel,
        v.startTime,
        v.endTime,
        v.session,
        v.note,
        v.unit,
        v.departmentId,
        v.departmentName,
        v.category,
        v.dayIndex,
        v.participantsText,
        v.participantUserIdsText,
        CAST(CASE
            WHEN EXISTS (
                SELECT 1
                FROM dbo.schedule_participants p
                WHERE p.schedule_id = v.id
                  AND p.user_id = @UserId
            ) THEN 1 ELSE 0
        END AS BIT) AS isMine,
        CAST(CASE
            WHEN v.departmentId = @UserDepartmentId THEN 1 ELSE 0
        END AS BIT) AS isDepartment
    FROM dbo.v_schedule_api v
    WHERE v.status = N'active'
      AND NOT EXISTS (
          SELECT 1 FROM dbo.user_hidden_schedules uh 
          WHERE uh.schedule_id = v.id AND uh.user_id = @UserId
      )
      AND (
            @UserRole = N'quản trị viên' 
            OR @UserRole = N'admin'
            OR v.departmentId = @UserDepartmentId
            OR EXISTS (
                SELECT 1
                FROM dbo.schedule_participants p
                WHERE p.schedule_id = v.id
                  AND p.user_id = @UserId
            )
          )
      AND (@DayIndex IS NULL OR v.dayIndex = @DayIndex)
      AND (
            @Keyword IS NULL OR LTRIM(RTRIM(@Keyword)) = N''
            OR LOWER(v.title) LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.teacher) LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.room) LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.note) LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.unit) LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.departmentName) LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.category) LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.participantsText) LIKE N'%' + LOWER(@Keyword) + N'%'
          )
      AND (
            @Mode = N'all'
            OR (@Mode = N'my' AND EXISTS (
                SELECT 1 FROM dbo.schedule_participants p
                WHERE p.schedule_id = v.id AND p.user_id = @UserId
            ))
            OR (@Mode = N'department' AND v.departmentId = @UserDepartmentId)
          )
    ORDER BY v.dayIndex, v.startTime;
END
"""

cursor.execute(sql)
conn.commit()
print("Updated sp_GetSchedulesForUser successfully!")
