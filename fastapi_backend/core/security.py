# core/security.py – Cấu hình và dịch vụ bảo mật liên quan đến mã hóa & cấp phát Token JWT.
#
# Chức năng:
#   - Đọc khóa bảo mật và cấu hình thời hạn Token từ biến môi trường.
#   - Tạo mã Access Token JWT (Quyền truy cập hạn ngắn 60 phút).
#   - Tạo mã Refresh Token JWT (Khóa duy trì hạn dài 30 ngày).

import os
from datetime import datetime, timedelta
from jose import jwt
from typing import Optional
from dotenv import load_dotenv

# Tải cấu hình từ .env
load_dotenv()

# ─────────────────────────────────────────────
# Cấu hình khóa bí mật và thông số Token
# ─────────────────────────────────────────────
SECRET_KEY = os.environ.get(
    'JWT_SECRET_KEY',
    'super_secret_key_for_qllich_change_this_in_production'  # Fallback bảo phòng nếu chưa cấu hình .env
)
ALGORITHM  = "HS256" # Thuật toán mã hóa HMAC sử dụng SHA-256
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get('ACCESS_TOKEN_EXPIRE_MINUTES', '60'))  # Thời gian hết hạn Access Token
REFRESH_TOKEN_EXPIRE_DAYS   = int(os.environ.get('REFRESH_TOKEN_EXPIRE_DAYS',   '30'))  # Thời gian hết hạn Refresh Token


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Sinh Access Token (Token chứa thông tin phân quyền và định danh người dùng).
    Client sẽ đính kèm Token này vào Header 'Authorization: Bearer <token>' của mỗi request gọi API.
    
    Tham số:
        data (dict): Dữ liệu payload muốn đóng gói vào JWT (Ví dụ: user_id, role).
        expires_delta (timedelta, optional): Thời hạn cụ thể nếu muốn tùy biến cấu hình.
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta if expires_delta
        else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    # Gán thời điểm hết hạn 'exp' (UTC Epoch Time) vào payload
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Sinh Refresh Token (Token hạn dài dùng để gia hạn Access Token mới).
    Refresh Token được lưu ở vùng nhớ an toàn trên thiết bị client và Database để kiểm tra Single Session.
    
    Tham số:
        data (dict): Dữ liệu payload đóng gói.
        expires_delta (timedelta, optional): Thời hạn tùy biến cấu hình.
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta if expires_delta
        else timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    )
    # Thêm cờ đánh dấu phân biệt 'type': 'refresh' nhằm tránh sử dụng lầm Refresh Token thay thế cho Access Token
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

