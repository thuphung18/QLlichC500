# add_indexes.py – Thiết lập các chỉ mục cơ sở dữ liệu (Database Indexes) trên SQL Server
#
# Chức năng:
#   - Tối ưu hóa hiệu năng truy vấn của SQL Server khi ứng dụng hoạt động dưới mức tải cao (500 - 1000 người dùng).
#   - Thêm các Index trên các trường được tìm kiếm và so khớp thường xuyên (status, department_id, schedule_date, username,...).
#   - Sử dụng cú pháp an toàn "IF NOT EXISTS" giúp script có thể chạy nhiều lần mà không gây lỗi hoặc tạo trùng lặp index.
#
# CÁCH CHẠY:
#   python add_indexes.py

import database

# Danh sách cấu trúc các chỉ mục cần tạo
INDEXES = [
    # ─── Bảng dbo.schedules (Lịch công tác) ───────────────────────────────────
    {
        "name": "IX_schedules_status_dept",
        "table": "dbo.schedules",
        "columns": "[status], [department_id]",
        "desc": "Tăng tốc truy vấn lọc lịch theo trạng thái hoạt động và theo phòng ban (Query phổ biến nhất từ App mobile)"
    },
    {
        "name": "IX_schedules_status_dayindex",
        "table": "dbo.schedules",
        "columns": "[status], [day_index]",
        "desc": "Tối ưu truy vấn lọc lịch theo trạng thái hoạt động và thứ trong tuần"
    },
    {
        "name": "IX_schedules_scheduledate",
        "table": "dbo.schedules",
        "columns": "[schedule_date]",
        "desc": "Tăng tốc tìm kiếm và lọc lịch học/làm việc theo ngày tháng"
    },
    {
        "name": "IX_schedules_created_by",
        "table": "dbo.schedules",
        "columns": "[created_by_user_id]",
        "desc": "Tối ưu hóa bộ lọc lịch do chính Quản trị viên/Trưởng phòng tạo ra (RBAC views)"
    },

    # ─── Bảng dbo.users (Người dùng) ──────────────────────────────────────────
    {
        "name": "IX_users_username_active",
        "table": "dbo.users",
        "columns": "[username], [is_active]",
        "desc": "Tối ưu hóa tốc độ đăng nhập hệ thống: tìm kiếm nhanh theo username và trạng thái hoạt động"
    },
    {
        "name": "IX_users_dept_active",
        "table": "dbo.users",
        "columns": "[department_id], [is_active]",
        "desc": "Tăng tốc hiển thị danh sách thành viên cùng phòng ban (Phục vụ Manager quản lý nhân sự)"
    },

    # ─── Bảng dbo.schedule_participants (Thành phần tham gia lịch) ────────────
    {
        "name": "IX_schedule_participants_schedule",
        "table": "dbo.schedule_participants",
        "columns": "[schedule_id]",
        "desc": "Tối ưu hóa các câu lệnh JOIN từ bảng schedules sang bảng participants để lấy tên người tham gia"
    },
    {
        "name": "IX_schedule_participants_user",
        "table": "dbo.schedule_participants",
        "columns": "[user_id]",
        "desc": "Tăng tốc độ tìm kiếm lịch cá nhân của User hiện tại (Mode=my)"
    },
    {
        "name": "IX_schedule_participants_composite",
        "table": "dbo.schedule_participants",
        "columns": "[schedule_id], [user_id]",
        "desc": "Tối ưu hóa phép kiểm tra EXISTS trong Stored Procedure để gán cờ isMine (Xác định lịch của bản thân)"
    },

    # ─── Bảng dbo.password_reset_codes (Mã xác thực OTP) ──────────────────────
    {
        "name": "IX_prc_contact_status",
        "table": "dbo.password_reset_codes",
        "columns": "[contact], [is_verified], [is_used]",
        "desc": "Tối ưu hóa tra cứu mã OTP trong tiến trình Quên mật khẩu"
    },
    {
        "name": "IX_prc_reset_token",
        "table": "dbo.password_reset_codes",
        "columns": "[reset_token]",
        "desc": "Tăng tốc tra cứu thông tin đặt lại mật khẩu theo resetToken tạm thời ở Bước 3"
    },

    # ─── Bảng dbo.user_hidden_schedules (Lịch ẩn của người dùng) ──────────────
    {
        "name": "IX_uhs_composite",
        "table": "dbo.user_hidden_schedules",
        "columns": "[user_id], [schedule_id]",
        "desc": "Tối ưu hóa phép kiểm tra để loại bỏ các lịch mà người dùng đã bấm ẩn trên ứng dụng"
    },
]


def create_indexes():
    """
    Kết nối cơ sở dữ liệu và duyệt qua danh sách các index để tạo.
    Sử dụng mệnh đề kiểm tra sự tồn tại sys.indexes trước khi chạy lệnh CREATE INDEX.
    """
    # Mượn kết nối DB từ Connection Pool
    conn = database.get_connection()
    cursor = conn.cursor()

    print("=" * 60)
    print("Bắt đầu khởi tạo và tối ưu hóa Database Indexes...")
    print("=" * 60)

    success = 0
    skipped = 0
    failed  = 0

    for idx in INDEXES:
        idx_name = idx["name"]
        table    = idx["table"]
        columns  = idx["columns"]
        desc     = idx["desc"]

        # Cú pháp SQL Server kiểm tra sự tồn tại của index trên bảng tương ứng
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
            conn.commit()  # Xác nhận lưu thay đổi cấu trúc bảng
            print(f"  ✅ [Hoàn thành] {idx_name}")
            print(f"     → Mô tả: {desc}")
            success += 1
        except Exception as e:
            print(f"  ❌ [Lỗi] {idx_name} – Chi tiết lỗi: {e}")
            failed += 1

    cursor.close()
    conn.close()

    print()
    print("=" * 60)
    print(f"Hoàn thành thiết lập! Thành công: {success} | Lỗi: {failed}")
    print("=" * 60)


if __name__ == "__main__":
    create_indexes()

