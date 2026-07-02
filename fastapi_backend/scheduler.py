# scheduler.py – Bộ đếm thời gian chạy ngầm (Background Job Scheduler) gửi thông báo đẩy (Push Notifications) qua Firebase.
#
# Chức năng:
#   - Tự động quét cơ sở dữ liệu định kỳ mỗi phút một lần.
#   - Phát hiện các lịch sắp bắt đầu (trong vòng 5 phút tiếp theo).
#   - Lấy danh sách mã định danh thiết bị (FCM Tokens) của những người dùng tham gia lịch đó.
#   - Thực hiện gửi thông báo nhắc lịch hàng loạt thông qua Firebase Cloud Messaging (FCM) ở dưới nền.

import os
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
import firebase_admin
from firebase_admin import credentials, messaging
from database import get_connection, return_connection
from cache import invalidate_schedules


def init_firebase():
    """
    Khởi tạo kết nối với Firebase Cloud Messaging (FCM) sử dụng tệp serviceAccountKey.json.
    Tệp này chứa khóa bảo mật được tải từ Firebase Console.
    Chỉ khởi tạo một lần duy nhất trong vòng đời của ứng dụng.
    """
    try:
        if not firebase_admin._apps:
            # File cấu hình tải từ Firebase Console (Project Settings -> Service Accounts)
            cred = credentials.Certificate('serviceAccountKey.json')
            firebase_admin.initialize_app(cred)
            print("[Firebase] Dịch vụ Firebase đã được khởi tạo thành công.")
    except Exception as e:
        print(f"[Firebase] Lỗi khởi tạo Firebase: {e}")


def check_schedules_and_notify():
    """
    Tác vụ chạy ngầm định kỳ:
      1. Tính toán mốc thời gian diễn ra lịch: 5 phút tính từ thời điểm hiện tại.
      2. Thực hiện truy vấn DB để tìm các lịch đang ở trạng thái hoạt động ('active') bắt đầu đúng vào phút đó.
      3. Tìm tất cả người tham gia lịch và trích xuất FCM Token của họ.
      4. Tạo và gửi thông báo nhắc nhở đẩy (Push Notification) đến các thiết bị di động.
    """
    # Lấy một kết nối DB độc lập cho luồng chạy ngầm để tránh xung đột với luồng API chính
    conn = get_connection()
    cursor = conn.cursor()
    try:
        now = datetime.now()
        # Xác định mốc thời gian đích: 5 phút tới (ví dụ: bây giờ 07:55 -> target_time là 08:00)
        target_time = now + timedelta(minutes=5)
        
        # Định dạng ngày (YYYY-MM-DD) và giờ (HH:MM:00) để khớp với kiểu dữ liệu trong SQL Server
        target_date_str = target_time.strftime("%Y-%m-%d")
        target_time_str = target_time.strftime("%H:%M:00")
        
        # 1. Tìm các lịch có ngày và giờ bắt đầu khớp với mốc target_time
        cursor.execute('''
            SELECT id, title, room
            FROM dbo.schedules
            WHERE schedule_date = ? AND start_time = ? AND status = 'active'
        ''', (target_date_str, target_time_str))
        
        schedules = cursor.fetchall()
        
        # 2. Duyệt qua từng lịch để lấy danh sách người tham gia và gửi thông báo
        for schedule in schedules:
            sched_id = schedule[0]
            title = schedule[1]
            room = schedule[2]
            
            # Lấy danh sách FCM Token của các người dùng được gán tham gia lịch công tác này
            cursor.execute('''
                SELECT u.fcm_token 
                FROM dbo.schedule_participants sp
                JOIN dbo.users u ON sp.user_id = u.id
                WHERE sp.schedule_id = ? AND u.fcm_token IS NOT NULL
            ''', (sched_id,))
            
            # Lọc các token không rỗng
            tokens = [row[0] for row in cursor.fetchall() if row[0]]
            
            # Nếu có thiết bị đăng ký nhận thông báo, tiến hành gửi thông qua Firebase
            if tokens:
                message_title = "Sắp diễn ra!"
                message_body = f"Lịch '{title}' tại phòng '{room}' sẽ bắt đầu trong 5 phút nữa."
                
                # Sử dụng MulticastMessage để gửi thông điệp đến hàng loạt token cùng lúc nhằm tối ưu hóa hiệu suất mạng
                message = messaging.MulticastMessage(
                    notification=messaging.Notification(
                        title=message_title,
                        body=message_body,
                    ),
                    tokens=tokens,
                )
                
                try:
                    # Gửi tin nhắn và đếm số lượng gửi thành công
                    response = messaging.send_each_for_multicast(message)
                    print(f"[Scheduler] Đã gửi thành công {response.success_count}/{len(tokens)} thông báo cho lịch {sched_id}")
                except Exception as ex:
                    print(f"[Scheduler] Lỗi gửi thông báo FCM: {ex}")
                    
    except Exception as e:
        print(f"[Scheduler] Lỗi trong quá trình quét lịch và gửi thông báo: {e}")
    finally:
        # Đảm bảo đóng cursor và giải phóng kết nối trả về pool
        cursor.close()
        return_connection(conn)


def send_import_notifications_bg(has_toantruong: bool, dept_ids: set):
    """
    Tác vụ chạy ngầm được kích hoạt sau khi import lịch thành công.
    - Nếu có lịch 'Toàn trường': Lấy tất cả FCM Token của hệ thống.
    - Nếu chỉ có lịch của Khoa/Phòng cụ thể: Chỉ lấy FCM Token của user thuộc khoa/phòng đó.
    """
    conn = get_connection()
    cursor = conn.cursor()
    tokens = set()
    try:
        if has_toantruong:
            # Gửi cho tất cả user có token
            cursor.execute("SELECT fcm_token FROM dbo.users WHERE fcm_token IS NOT NULL AND is_active = 1")
            for row in cursor.fetchall():
                tokens.add(row[0])
        elif dept_ids:
            # Gửi cho user thuộc các department cụ thể
            dept_ids_list = list(dept_ids)
            placeholders = ",".join(["?"] * len(dept_ids_list))
            query = f"SELECT fcm_token FROM dbo.users WHERE fcm_token IS NOT NULL AND is_active = 1 AND department_id IN ({placeholders})"
            cursor.execute(query, dept_ids_list)
            for row in cursor.fetchall():
                tokens.add(row[0])
        
        if tokens:
            tokens_list = list(tokens)
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title="Lịch công tác mới!",
                    body="Có lịch công tác mới vừa được cập nhật trên hệ thống. Hãy kiểm tra ngay!",
                ),
                tokens=tokens_list,
            )
            response = messaging.send_each_for_multicast(message)
            print(f"[Import Notify] Đã gửi thông báo lịch mới đến {response.success_count}/{len(tokens_list)} thiết bị.")
        else:
            print("[Import Notify] Không tìm thấy thiết bị nào để gửi thông báo.")
    except Exception as e:
        print(f"[Import Notify] Lỗi khi gửi thông báo: {e}")
    finally:
        cursor.close()
        return_connection(conn)


def auto_hide_old_schedules():
    """
    Tác vụ chạy ngầm định kỳ:
      Quét các lịch có schedule_date nhỏ hơn ngày đầu tiên (Thứ 2) của tuần hiện tại.
      Cập nhật trạng thái thành 'delete_by_admin' (xóa mềm).
      Xóa cache nếu có dữ liệu bị thay đổi.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        now = datetime.now()
        # Tìm ngày Thứ 2 của tuần hiện tại
        start_of_week = now - timedelta(days=now.weekday())
        start_of_week_str = start_of_week.strftime("%Y-%m-%d")

        # Tìm các department có lịch cũ để xóa cache
        cursor.execute('''
            SELECT DISTINCT department_id
            FROM dbo.schedules
            WHERE schedule_date < ? AND status != 'delete_by_admin'
        ''', (start_of_week_str,))
        dept_rows = cursor.fetchall()

        if dept_rows:
            # Cập nhật trạng thái
            cursor.execute('''
                UPDATE dbo.schedules
                SET status = 'delete_by_admin'
                WHERE schedule_date < ? AND status != 'delete_by_admin'
            ''', (start_of_week_str,))
            
            deleted_count = cursor.rowcount
            db_commit_needed = True
            if deleted_count > 0:
                conn.commit()
                print(f"[Auto Archive] Đã xóa mềm {deleted_count} lịch cũ (trước {start_of_week_str}).")
                # Xóa cache cho các phòng ban bị ảnh hưởng
                for row in dept_rows:
                    if row[0]:
                        invalidate_schedules(str(row[0]))
                # Xóa cache toàn trường (nếu có null department)
                invalidate_schedules(None)
    except Exception as e:
        print(f"[Auto Archive] Lỗi khi tự động ẩn lịch cũ: {e}")
    finally:
        cursor.close()
        return_connection(conn)


def start_scheduler():
    """
    Thiết lập và khởi chạy Bộ lập lịch chạy ngầm (Background Scheduler).
    Được gọi 1 lần duy nhất lúc ứng dụng FastAPI khởi động.
    """
    # Khởi tạo Firebase Admin SDK
    init_firebase()
    
    # Sử dụng BackgroundScheduler để chạy các tác vụ định kỳ mà không block luồng xử lý HTTP request chính
    scheduler = BackgroundScheduler()
    
    # Thiết lập chạy tác vụ quét lịch nhắc nhở vào mỗi phút (cron expression: minute='*')
    scheduler.add_job(check_schedules_and_notify, 'cron', minute='*')
    
    # Thiết lập chạy tác vụ ẩn lịch tuần cũ vào lúc 00:05 mỗi ngày
    scheduler.add_job(auto_hide_old_schedules, 'cron', hour=0, minute=5)
    
    # Bắt đầu chạy bộ đếm thời gian
    scheduler.start()
    print("[Scheduler] Bộ đếm thời gian chạy ngầm đã khởi động và đang quét lịch công tác.")

