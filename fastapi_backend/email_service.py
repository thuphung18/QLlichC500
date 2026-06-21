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

