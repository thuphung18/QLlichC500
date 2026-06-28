# email_service.py – Dịch vụ gửi email (sử dụng SMTP) để gửi mã xác thực (OTP) cho chức năng Quên mật khẩu.

import smtplib
from email.message import EmailMessage
import os

# ─────────────────────────────────────────────
# Cấu hình SMTP Server của Gmail
# ─────────────────────────────────────────────
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 465  # Sử dụng cổng 465 cho kết nối bảo mật SSL

# Tài khoản email gửi đi (đã cấu hình App Password trong tài khoản Google)
SMTP_USER = "thuphung18122005@gmail.com" 
SMTP_PASS = "zjfvappjaoflzidq"  # Mật khẩu ứng dụng (App Password) được cấp bởi Google

def send_otp_email(recipient_email: str, otp_code: str):
    """
    Gửi email chứa mã OTP xác nhận quên mật khẩu đến hòm thư người dùng.
    Hàm này thường được chạy ngầm dưới dạng BackgroundTask của FastAPI để không chặn response chính.
    
    Tham số:
        recipient_email (str): Địa chỉ email của người nhận.
        otp_code (str): Mã xác thực OTP gồm 6 chữ số ngẫu nhiên.
    """
    try:
        # Khởi tạo đối tượng tin nhắn email
        msg = EmailMessage()
        msg['Subject'] = 'Mã xác thực Quên mật khẩu'
        msg['From'] = SMTP_USER
        msg['To'] = recipient_email
        
        # Thiết lập nội dung tin nhắn email dưới dạng văn bản thuần
        msg.set_content(
            f"Chào bạn,\n\n"
            f"Mã xác thực để đặt lại mật khẩu của bạn là: {otp_code}\n\n"
            f"Mã này sẽ hết hạn trong vòng 5 phút.\n\n"
            f"Nếu bạn không yêu cầu hành động này, vui lòng bỏ qua email.\n\n"
            f"Trân trọng,\n"
            f"Ban Quản Trị"
        )

        # Thiết lập kết nối an toàn với máy chủ SMTP qua giao thức SSL và gửi tin nhắn
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
            server.login(SMTP_USER, SMTP_PASS)  # Đăng nhập tài khoản gửi email
            server.send_message(msg)            # Thực hiện gửi thư
            
        print(f"Sent OTP to {recipient_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")


def send_admin_notification_email(new_user_email: str, full_name: str, department_name: str):
    """
    Gửi email thông báo cho Admin (thuphung18122005@gmail.com) khi có người dùng mới đăng ký.
    """
    admin_email = "thuphung18122005@gmail.com"
    try:
        msg = EmailMessage()
        msg['Subject'] = 'Yêu cầu phê duyệt tài khoản mới'
        msg['From'] = SMTP_USER
        msg['To'] = admin_email
        
        msg.set_content(
            f"Kính gửi Admin,\n\n"
            f"Hệ thống vừa nhận được một yêu cầu đăng ký tài khoản mới với thông tin sau:\n"
            f"- Họ và tên: {full_name}\n"
            f"- Email (Google): {new_user_email}\n"
            f"- Phòng ban / Khoa: {department_name}\n\n"
            f"Tài khoản hiện đang ở trạng thái 'Chờ duyệt' (is_active = 0).\n"
            f"Vui lòng truy cập hệ thống Quản trị viên để kiểm tra và kích hoạt tài khoản này.\n\n"
            f"Trân trọng,\n"
            f"Hệ thống QL Lịch"
        )

        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
            
        print(f"Sent Admin Notification for {new_user_email}")
    except Exception as e:
        print(f"Failed to send admin notification email: {e}")

