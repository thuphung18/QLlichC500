from fastapi import Depends, HTTPException, Header, status
import pyodbc
from database import get_db

def verify_session_token(
    authorization: str = Header(None),
    db: pyodbc.Connection = Depends(get_db)
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Thiếu hoặc sai định dạng Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = authorization.split(" ")[1]
    
    cursor = db.cursor()
    try:
        cursor.execute("SELECT id FROM dbo.users WHERE session_token = ? AND is_active = 1", (token,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Phiên đăng nhập đã hết hạn hoặc bạn đã đăng nhập ở thiết bị khác",
                headers={"WWW-Authenticate": "Bearer"},
            )
        # return user_id if needed
        return row[0]
    finally:
        cursor.close()
