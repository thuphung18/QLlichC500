import pyodbc
from database import get_connection

def seed_data():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        print("Starting users...")
        # Thêm user 'hoang' và 'linh'
        users_data = [
            ('u005', 'hoang', '123456', 'Nguyễn Văn Hoàng', 'Sinh viên', 'Khoa Công nghệ thông tin', 'cntt', 'hoang@student.edu.vn', '0955555555'),
            ('u006', 'linh', '123456', 'Trần Phương Linh', 'Giảng viên', 'Khoa Kinh tế', 'kt', 'linh@academy.edu.vn', '0966666666')
        ]
        
        for user in users_data:
            cursor.execute("""
                IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE id = ?)
                BEGIN
                    INSERT INTO dbo.users (id, username, password_hash, full_name, role, unit, department_id, email, phone)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                END
            """, (user[0], user[0], user[1], user[2], user[3], user[4], user[5], user[6], user[7], user[8]))
        
        print("Starting schedules...")
        # Thêm lịch trình
        schedules_data = [
            ('12', 'Học môn Cơ sở dữ liệu', 'GV. Thành', 'Phòng 201', '2026-06-12', 'Thứ 6, 12/6', 6, '07:30', '09:30', 'morning', 'Chuẩn bị bài tập lớn', 'Khoa CNTT', 'cntt', 'Lịch học', 'u005'),
            ('13', 'Họp bộ môn Kinh tế học', 'Trưởng bộ môn', 'Phòng họp khoa KT', '2026-06-12', 'Thứ 6, 12/6', 6, '14:00', '16:00', 'afternoon', 'Thống nhất chương trình giảng dạy', 'Khoa Kinh tế', 'kt', 'Lịch khoa', 'u006')
        ]
        
        for sched in schedules_data:
            cursor.execute("""
                IF NOT EXISTS (SELECT 1 FROM dbo.schedules WHERE id = ?)
                BEGIN
                    INSERT INTO dbo.schedules (id, title, teacher, room, schedule_date, date_label, day_index, start_time, end_time, session, note, unit, department_id, category, created_by_user_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                END
            """, (sched[0], sched[0], sched[1], sched[2], sched[3], sched[4], sched[5], sched[6], sched[7], sched[8], sched[9], sched[10], sched[11], sched[12], sched[13], sched[14]))

        print("Starting participants...")
        participants_data = [
            ('12', 'Hoàng', 'u005'),
            ('13', 'Linh', 'u006')
        ]
        
        for part in participants_data:
            cursor.execute("""
                IF NOT EXISTS (SELECT 1 FROM dbo.schedule_participants WHERE schedule_id = ? AND user_id = ?)
                BEGIN
                    INSERT INTO dbo.schedule_participants (schedule_id, participant_name, user_id)
                    VALUES (?, ?, ?)
                END
            """, (part[0], part[2], part[0], part[1], part[2]))

        conn.commit()
        print("Done!")
        
    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    seed_data()
