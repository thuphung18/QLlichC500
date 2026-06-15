import os
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
import firebase_admin
from firebase_admin import credentials, messaging
from database import get_connection

def init_firebase():
    """
    Khởi tạo kết nối với Firebase Cloud Messaging (FCM) thông qua thư viện firebase_admin.
    Hàm này sẽ đọc file serviceAccountKey.json chứa thông tin xác thực do Firebase cung cấp.
    Chỉ khởi tạo nếu ứng dụng chưa được khởi tạo trước đó.
    """
    try:
        if not firebase_admin._apps:
            # File cấu hình tải từ Firebase Console (Project Settings -> Service Accounts)
            cred = credentials.Certificate('serviceAccountKey.json')
            firebase_admin.initialize_app(cred)
            print("Firebase initialized successfully.")
    except Exception as e:
        print(f"Error initializing Firebase: {e}")

def check_schedules_and_notify():
    """
    Hàm thực thi ngầm định kỳ:
    1. Tính toán thời gian tương lai (hiện tại + 5 phút).
    2. Quét cơ sở dữ liệu để tìm các Lịch học/Làm việc (schedules) bắt đầu đúng vào thời gian đó.
    3. Trích xuất danh sách FCM Token của các thành viên tham gia lịch đó.
    4. Gửi thông báo Push Notification hàng loạt qua Firebase.
    """
    # Mở một luồng kết nối DB mới (tránh dùng chung với luồng API chính)
    conn = get_connection()
    cursor = conn.cursor()
    try:
        now = datetime.now()
        # Tính toán khoảng thời gian chuẩn bị diễn ra: 5 phút tới
        target_time = now + timedelta(minutes=5)
        
        # Định dạng thành chuỗi để so sánh với kiểu DATE và TIME trong SQL Server
        target_date_str = target_time.strftime("%Y-%m-%d")
        target_time_str = target_time.strftime("%H:%M:00")
        
        # Lấy danh sách các sự kiện (lịch) sẽ bắt đầu chính xác vào 'target_time'
        cursor.execute('''
            SELECT id, title, room
            FROM dbo.schedules
            WHERE schedule_date = ? AND start_time = ? AND status = 'active'
        ''', (target_date_str, target_time_str))
        
        schedules = cursor.fetchall()
        
        for schedule in schedules:
            sched_id = schedule[0]
            title = schedule[1]
            room = schedule[2]
            
            # Tìm tất cả FCM Token (mã định danh thiết bị cài app) của những người có mặt trong sự kiện
            cursor.execute('''
                SELECT u.fcm_token 
                FROM dbo.schedule_participants sp
                JOIN dbo.users u ON sp.user_id = u.id
                WHERE sp.schedule_id = ? AND u.fcm_token IS NOT NULL
            ''', (sched_id,))
            
            # Đẩy tất cả token hợp lệ vào một mảng
            tokens = [row[0] for row in cursor.fetchall() if row[0]]
            
            if tokens:
                # Cấu trúc nội dung thông báo gửi về điện thoại
                message_title = "Sắp diễn ra!"
                message_body = f"Lịch '{title}' tại '{room}' sẽ bắt đầu trong 5 phút nữa."
                
                # MulticastMessage giúp gửi 1 thông báo cho hàng loạt thiết bị cùng lúc, tiết kiệm băng thông
                message = messaging.MulticastMessage(
                    notification=messaging.Notification(
                        title=message_title,
                        body=message_body,
                    ),
                    tokens=tokens,
                )
                
                try:
                    response = messaging.send_each_for_multicast(message)
                    print(f"Sent {response.success_count} messages for schedule {sched_id}")
                except Exception as ex:
                    print(f"Error sending push: {ex}")
                    
    except Exception as e:
        print(f"Scheduler error: {e}")
    finally:
        cursor.close()
        conn.close()

def start_scheduler():
    """
    Hàm thiết lập và khởi động bộ đếm thời gian chạy ngầm (Background Scheduler).
    Nó sẽ được gọi 1 lần duy nhất khi ứng dụng FastAPI khởi động (startup event).
    """
    # Khởi tạo dịch vụ Firebase
    init_firebase()
    
    # Tạo luồng chạy ngầm độc lập với luồng xử lý API
    scheduler = BackgroundScheduler()
    
    # Lên lịch chạy hàm check_schedules_and_notify mỗi phút một lần (chuẩn Cron expression)
    scheduler.add_job(check_schedules_and_notify, 'cron', minute='*')
    
    # Bắt đầu vòng lặp thời gian
    scheduler.start()
    print("Scheduler started. Background notification scanning is active.")
