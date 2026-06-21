# dependencies.py – Định nghĩa các dependency dùng chung trong ứng dụng FastAPI, đặc biệt là xác thực người dùng.

from fastapi import Depends, HTTPException, Header, status
from core.security import SECRET_KEY, ALGORITHM
from jose import jwt, JWTError

def verify_session_token(
    authorization: str = Header(None)
):
    """
    Dependency dùng để xác thực Session Token (Access Token JWT) gửi kèm trong Header của request.
    
    Quy trình xác thực:
    1. Kiểm tra sự tồn tại của header Authorization và định dạng "Bearer <token>".
    2. Tách và lấy chuỗi token JWT.
    3. Giải mã (decode) token sử dụng SECRET_KEY và thuật toán mã hóa quy định.
    4. Trích xuất thông tin người dùng (user_id/subject) từ payload của token.
    5. Đảm bảo token được sử dụng không phải là Refresh Token (chỉ chấp nhận Access Token).
    6. Trả về user_id hợp lệ cho endpoint tiếp tục xử lý.
    
    Nếu có bất kỳ lỗi nào (thiếu header, token sai, hết hạn, sai loại token), hệ thống sẽ ném lỗi 401 Unauthorized.
    """
    # 1. Kiểm tra header Authorization
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Thiếu hoặc sai định dạng Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 2. Tách chuỗi để lấy token JWT
    token = authorization.split(" ")[1]
    
    try:
        # 3. Giải mã token JWT
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        # 4. Trích xuất user_id từ trường 'sub' (subject)
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ")
            
        # 5. Đảm bảo đây không phải là refresh token (không cho phép gọi API bằng Refresh Token)
        if payload.get("type") == "refresh":
             raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Không thể dùng Refresh Token ở đây")
             
        # 6. Trả về user_id hợp lệ
        return user_id
    except JWTError:
        # Xử lý các lỗi liên quan đến giải mã JWT (hết hạn, sai chữ ký, cấu trúc lỗi)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Phiên đăng nhập đã hết hạn hoặc token không hợp lệ",
            headers={"WWW-Authenticate": "Bearer"},
        )

