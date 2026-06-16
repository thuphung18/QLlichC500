"""
Script cập nhật Stored Procedure sp_GetSchedulesForUser theo RBAC:
- Admin (quản trị viên): Chỉ thấy Lịch Toàn Trường
  (schedules được tạo bởi một Admin - category hoặc department đặc biệt)
  Thực tế: Admin thấy TẤT CẢ lịch để quản lý, nhưng lịch hiển thị trên app
  của Admin tab 1 là "Lịch toàn trường" - tức là lịch mà ai cũng thấy.
  Trong thiết kế này: Admin thấy TẤT CẢ lịch (cần để quản trị).
- Manager (trưởng phòng): Thấy Lịch toàn trường + toàn bộ lịch phòng mình
  (kể cả lịch cá nhân của các thành viên trong phòng).
- User thường: Thấy Lịch toàn trường + Lịch phòng ban chung + Lịch cá nhân
  (chỉ các lịch mà họ được gán tham dự).

Định nghĩa "Lịch toàn trường":
  - Là lịch được tạo bởi Admin (role = 'quản trị viên' / 'admin')
  - HOẶC category của lịch là 'Lịch toàn trường'

Định nghĩa "Lịch phòng ban chung" (User xem được):
  - Lịch thuộc phòng của User VÀ không có participant nào được gán cụ thể
    (IS NOT EXISTS trong schedule_participants)
  - HOẶC lịch thuộc phòng VÀ User có tên trong danh sách tham dự

Mode 'department' theo RBAC:
  - Manager: thấy tất cả lịch thuộc phòng mình (kể cả có participants cụ thể)
  - User: chỉ thấy lịch phòng không có participants cụ thể
    OR lịch phòng mà user là 1 trong số participants
"""
import pyodbc

conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=weekly_schedule_db;Trusted_Connection=yes;')
cursor = conn.cursor()

sql = """
CREATE OR ALTER PROCEDURE dbo.sp_GetSchedulesForUser
    @UserId     NVARCHAR(50),
    @DayIndex   INT          = NULL,
    @Mode       NVARCHAR(50) = N'all',
    @Keyword    NVARCHAR(255)= NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Lấy thông tin người dùng: phòng ban và role
    DECLARE @UserDepartmentId NVARCHAR(50);
    DECLARE @UserRole         NVARCHAR(50);

    SELECT
        @UserDepartmentId = department_id,
        @UserRole         = LOWER(LTRIM(RTRIM(role)))
    FROM dbo.users
    WHERE id = @UserId AND is_active = 1;

    -- Xác định loại người dùng
    DECLARE @IsAdmin   BIT = 0;
    DECLARE @IsManager BIT = 0;

    IF @UserRole IN (N'admin', N'quản trị viên')
        SET @IsAdmin = 1;
    ELSE IF @UserRole IN (N'trưởng phòng', N'manager')
        SET @IsManager = 1;

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
                SELECT 1 FROM dbo.schedule_participants p
                WHERE p.schedule_id = v.id AND p.user_id = @UserId
            ) THEN 1 ELSE 0
        END AS BIT) AS isMine,
        CAST(CASE
            WHEN v.departmentId = @UserDepartmentId THEN 1 ELSE 0
        END AS BIT) AS isDepartment
    FROM dbo.v_schedule_api v
    WHERE
        v.status = N'active'

        -- Loại bỏ lịch user đã ẩn
        AND NOT EXISTS (
            SELECT 1 FROM dbo.user_hidden_schedules uh
            WHERE uh.schedule_id = v.id AND uh.user_id = @UserId
        )

        -- ===== RBAC VISIBILITY FILTER =====
        AND (
            -- Admin: thấy tất cả lịch (để quản trị tổng thể)
            @IsAdmin = 1

            -- Manager: thấy lịch toàn trường + toàn bộ lịch phòng mình
            OR (
                @IsManager = 1
                AND (
                    -- Lịch toàn trường (do Admin tạo hoặc category là Lịch toàn trường)
                    EXISTS (
                        SELECT 1 FROM dbo.users creator
                        WHERE creator.id = v.createdByUserId
                          AND LOWER(LTRIM(RTRIM(creator.role))) IN (N'admin', N'quản trị viên')
                    )
                    OR LOWER(LTRIM(RTRIM(v.category))) = N'lịch toàn trường'

                    -- Lịch thuộc phòng mình (kể cả lịch cá nhân members)
                    OR v.departmentId = @UserDepartmentId
                )
            )

            -- User thường: thấy lịch toàn trường + lịch phòng chung + lịch cá nhân
            OR (
                @IsAdmin = 0 AND @IsManager = 0
                AND (
                    -- Lịch toàn trường
                    EXISTS (
                        SELECT 1 FROM dbo.users creator
                        WHERE creator.id = v.createdByUserId
                          AND LOWER(LTRIM(RTRIM(creator.role))) IN (N'admin', N'quản trị viên')
                    )
                    OR LOWER(LTRIM(RTRIM(v.category))) = N'lịch toàn trường'

                    -- Lịch phòng ban KHÔNG có participant cụ thể nào (lịch chung toàn phòng)
                    OR (
                        v.departmentId = @UserDepartmentId
                        AND NOT EXISTS (
                            SELECT 1 FROM dbo.schedule_participants p
                            WHERE p.schedule_id = v.id
                        )
                    )

                    -- Lịch phòng ban mà user được gán tham dự
                    OR (
                        v.departmentId = @UserDepartmentId
                        AND EXISTS (
                            SELECT 1 FROM dbo.schedule_participants p
                            WHERE p.schedule_id = v.id AND p.user_id = @UserId
                        )
                    )
                )
            )
        )

        -- Lọc theo ngày (thứ)
        AND (@DayIndex IS NULL OR v.dayIndex = @DayIndex)

        -- Lọc từ khóa tìm kiếm
        AND (
            @Keyword IS NULL OR LTRIM(RTRIM(@Keyword)) = N''
            OR LOWER(v.title)           LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.teacher)         LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.room)            LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.note)            LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.unit)            LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.departmentName)  LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.category)        LIKE N'%' + LOWER(@Keyword) + N'%'
            OR LOWER(v.participantsText)LIKE N'%' + LOWER(@Keyword) + N'%'
        )

        -- Lọc theo Mode
        AND (
            @Mode = N'all'

            -- Mode 'my': chỉ lịch user có tên trong danh sách tham dự
            OR (@Mode = N'my' AND EXISTS (
                SELECT 1 FROM dbo.schedule_participants p
                WHERE p.schedule_id = v.id AND p.user_id = @UserId
            ))

            -- Mode 'department': theo role
            OR (@Mode = N'department' AND (
                -- Admin & Manager: thấy tất cả lịch phòng mình
                ((@IsAdmin = 1 OR @IsManager = 1) AND v.departmentId = @UserDepartmentId)

                -- User: chỉ thấy lịch phòng chung (không có participant cụ thể)
                --       HOẶC lịch phòng mà user là participant
                OR (
                    @IsAdmin = 0 AND @IsManager = 0
                    AND v.departmentId = @UserDepartmentId
                    AND (
                        NOT EXISTS (
                            SELECT 1 FROM dbo.schedule_participants p
                            WHERE p.schedule_id = v.id
                        )
                        OR EXISTS (
                            SELECT 1 FROM dbo.schedule_participants p
                            WHERE p.schedule_id = v.id AND p.user_id = @UserId
                        )
                    )
                )
            ))
        )

    ORDER BY v.dayIndex, v.startTime;
END
"""

# Cập nhật view để thêm createdByUserId (cần thiết cho filter RBAC)
sql_view = """
CREATE OR ALTER VIEW dbo.v_schedule_api
AS
SELECT
    s.id,
    s.title,
    s.teacher,
    s.room,
    s.date_label AS dateLabel,
    CONVERT(VARCHAR(5), s.start_time, 108) AS startTime,
    CONVERT(VARCHAR(5), s.end_time, 108)   AS endTime,
    s.session,
    ISNULL(s.note, N'') AS note,
    s.unit,
    s.department_id   AS departmentId,
    d.name            AS departmentName,
    s.category,
    s.day_index       AS dayIndex,
    s.schedule_date   AS scheduleDate,
    s.created_by_user_id AS createdByUserId,
    ISNULL(pa.participants,      N'') AS participantsText,
    ISNULL(pa.participantUserIds, N'') AS participantUserIdsText,
    s.status
FROM dbo.schedules s
INNER JOIN dbo.departments d ON d.id = s.department_id
OUTER APPLY (
    SELECT
        STRING_AGG(CAST(p.participant_name AS NVARCHAR(MAX)), N'|')
            WITHIN GROUP (ORDER BY p.id) AS participants,
        STRING_AGG(CAST(p.user_id AS NVARCHAR(MAX)), N'|')
            WITHIN GROUP (ORDER BY p.id) AS participantUserIds
    FROM dbo.schedule_participants p
    WHERE p.schedule_id = s.id
) pa;
"""

print("Updating view dbo.v_schedule_api...")
cursor.execute(sql_view)
conn.commit()
print("View updated successfully!")

print("Updating dbo.sp_GetSchedulesForUser with RBAC...")
cursor.execute(sql)
conn.commit()
print("Stored Procedure updated successfully!")

cursor.close()
conn.close()
