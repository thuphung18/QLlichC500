import os
from datetime import datetime, timedelta
from jose import jwt
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────
# JWT Config (đọc từ .env để tránh hardcode secret)
# ─────────────────────────────────────────────
SECRET_KEY = os.environ.get(
    'JWT_SECRET_KEY',
    'super_secret_key_for_qllich_change_this_in_production'  # fallback nếu chưa đặt .env
)
ALGORITHM  = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get('ACCESS_TOKEN_EXPIRE_MINUTES', '60'))
REFRESH_TOKEN_EXPIRE_DAYS   = int(os.environ.get('REFRESH_TOKEN_EXPIRE_DAYS',   '30'))


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta if expires_delta
        else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta if expires_delta
        else timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    )
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
