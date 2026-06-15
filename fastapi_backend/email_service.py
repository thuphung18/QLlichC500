import smtplib
from email.message import EmailMessage
import os

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 465
SMTP_USER = "thuphung18122005@gmail.com" # Default to this as the username, user didn't specify
SMTP_PASS = "zjfvappjaoflzidq" # App password

def send_otp_email(recipient_email: str, otp_code: str):
    try:
        msg = EmailMessage()
        msg['Subject'] = 'Mã xác thực Quên mật khẩu'
        msg['From'] = SMTP_USER
        msg['To'] = recipient_email
        msg.set_content(f"Chào bạn,\n\nMã xác thực để đặt lại mật khẩu của bạn là: {otp_code}\n\nMã này sẽ hết hạn trong vòng 5 phút.\n\nTrân trọng,\nBan Quản Trị")

        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
            
        print(f"Sent OTP to {recipient_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")
