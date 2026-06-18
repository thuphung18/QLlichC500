from fastapi import Depends, HTTPException, Header, status
from core.security import SECRET_KEY, ALGORITHM
from jose import jwt, JWTError

def verify_session_token(
    authorization: str = Header(None)
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Thiếu hoặc sai định dạng Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = authorization.split(" ")[1]
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ")
        # Ensure it's not a refresh token being used as access token
        if payload.get("type") == "refresh":
             raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Không thể dùng Refresh Token ở đây")
        return user_id
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Phiên đăng nhập đã hết hạn hoặc token không hợp lệ",
            headers={"WWW-Authenticate": "Bearer"},
        )
