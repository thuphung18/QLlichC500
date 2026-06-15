import pyodbc
from typing import Generator

# Cấu hình kết nối SQL Server
# Ở đây dùng Trusted_Connection=yes cho Windows Authentication (như đã test local)
# Bạn có thể thay đổi Driver tuỳ thuộc vào máy, thông dụng là 'ODBC Driver 17 for SQL Server'
SERVER = 'localhost'
DATABASE = 'weekly_schedule_db'
DRIVER = '{ODBC Driver 17 for SQL Server}' # Đổi thành '{SQL Server}' nếu không có Driver 17

def get_connection() -> pyodbc.Connection:
    """
    Tạo và trả về một connection đến SQL Server
    """
    connection_string = f"DRIVER={DRIVER};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;"
    try:
        conn = pyodbc.connect(connection_string)
        return conn
    except pyodbc.Error as e:
        # Nếu lỗi driver, thử fallback sang SQL Server default driver
        fallback_string = f"DRIVER={{SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;"
        return pyodbc.connect(fallback_string)

def get_db() -> Generator[pyodbc.Connection, None, None]:
    """
    Dependency injection cho FastAPI: mở kết nối và đóng sau khi dùng xong
    """
    conn = get_connection()
    try:
        yield conn
    finally:
        conn.close()
