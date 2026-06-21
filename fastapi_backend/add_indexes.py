"""
add_indexes.py  –  Tạo các index quan trọng trên SQL Server để tăng tốc truy vấn
                   dưới tải 500-1000 users.

CÁCH CHẠY:
    python add_indexes.py

Lưu ý: Script này an toàn để chạy nhiều lần (dùng IF NOT EXISTS).
"""

import database

INDEXES = [
    # ─── Bảng schedules ───────────────────────────────────────────────────────
    {
        "name": "IX_schedules_status_dept",
        "table": "dbo.schedules",
        "columns": "[status], [department_id]",
        "desc": "Lọc lịch theo status + phòng ban (query phổ biến nhất)"
    },
    {
        "name": "IX_schedules_status_dayindex",
        "table": "dbo.schedules",
        "columns": "[status], [day_index]",
        "desc": "Lọc lịch theo status + thứ trong tuần"
    },
    {
        "name": "IX_schedules_scheduledate",
        "table": "dbo.schedules",
        "columns": "[schedule_date]",
        "desc": "Tìm kiếm lịch theo ngày"
    },
    {
        "name": "IX_schedules_created_by",
        "table": "dbo.schedules",
        "columns": "[created_by_user_id]",
        "desc": "Lọc lịch do Admin/Manager tạo (dùng trong RBAC view)"
    },

    # ─── Bảng users ───────────────────────────────────────────────────────────
    {
        "name": "IX_users_username_active",
        "table": "dbo.users",
        "columns": "[username], [is_active]",
        "desc": "Đăng nhập: tìm user theo username + is_active"
    },
    {
        "name": "IX_users_dept_active",
        "table": "dbo.users",
        "columns": "[department_id], [is_active]",
        "desc": "Lọc user theo phòng ban (quản lý thành viên)"
    },

    # ─── Bảng schedule_participants ───────────────────────────────────────────
    {
        "name": "IX_schedule_participants_schedule",
        "table": "dbo.schedule_participants",
        "columns": "[schedule_id]",
        "desc": "JOIN từ schedules → participants"
    },
    {
        "name": "IX_schedule_participants_user",
        "table": "dbo.schedule_participants",
        "columns": "[user_id]",
        "desc": "Tìm lịch cá nhân của user (Mode=my)"
    },
    {
        "name": "IX_schedule_participants_composite",
        "table": "dbo.schedule_participants",
        "columns": "[schedule_id], [user_id]",
        "desc": "EXISTS check trong Stored Procedure (isMine flag)"
    },

    # ─── Bảng password_reset_codes ────────────────────────────────────────────
    {
        "name": "IX_prc_contact_status",
        "table": "dbo.password_reset_codes",
        "columns": "[contact], [is_verified], [is_used]",
        "desc": "Tra cứu mã OTP (Forgot Password flow)"
    },
    {
        "name": "IX_prc_reset_token",
        "table": "dbo.password_reset_codes",
        "columns": "[reset_token]",
        "desc": "Tìm mã theo reset_token (bước 3 forgot password)"
    },

    # ─── Bảng user_hidden_schedules ───────────────────────────────────────────
    {
        "name": "IX_uhs_composite",
        "table": "dbo.user_hidden_schedules",
        "columns": "[user_id], [schedule_id]",
        "desc": "EXISTS check trong SP để loại bỏ lịch đã ẩn"
    },
]


def create_indexes():
    conn = database.get_connection()
    cursor = conn.cursor()

    print("=" * 60)
    print("Bắt đầu tạo Database Indexes...")
    print("=" * 60)

    success = 0
    skipped = 0
    failed  = 0

    for idx in INDEXES:
        idx_name = idx["name"]
        table    = idx["table"]
        columns  = idx["columns"]
        desc     = idx["desc"]

        sql = f"""
        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes
            WHERE name = N'{idx_name}'
              AND object_id = OBJECT_ID(N'{table}')
        )
        BEGIN
            CREATE INDEX [{idx_name}]
            ON {table} ({columns});
            PRINT 'Created: {idx_name}';
        END
        ELSE
        BEGIN
            PRINT 'Skipped (already exists): {idx_name}';
        END
        """
        try:
            cursor.execute(sql)
            conn.commit()
            print(f"  ✅ {idx_name}")
            print(f"     → {desc}")
            success += 1
        except Exception as e:
            print(f"  ❌ {idx_name} – LỖI: {e}")
            failed += 1

    cursor.close()
    conn.close()

    print()
    print("=" * 60)
    print(f"Hoàn thành! Thành công: {success} | Thất bại: {failed}")
    print("=" * 60)


if __name__ == "__main__":
    create_indexes()
