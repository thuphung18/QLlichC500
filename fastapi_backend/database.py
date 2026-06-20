import os
import pyodbc
from typing import Generator

# Cấu hình kết nối SQL Server (Đọc từ biến môi trường hoặc dùng mặc định từ xa)
SERVER = os.environ.get('DB_SERVER', '203.128.246.222,1433')
DATABASE = os.environ.get('DB_DATABASE', 'weekly_schedule_db')
DRIVER = os.environ.get('DB_DRIVER', '{ODBC Driver 17 for SQL Server}') # Đổi thành '{SQL Server}' nếu không có Driver 17
UID = os.environ.get('DB_UID', 'nghiand')
PWD = os.environ.get('DB_PWD', '@NangHaNoi2020@')

def get_connection() -> pyodbc.Connection:
    """
    Tạo và trả về một connection đến SQL Server từ xa
    """
    connection_string = f"DRIVER={DRIVER};SERVER={SERVER};DATABASE={DATABASE};UID={UID};PWD={PWD};"
    try:
        conn = pyodbc.connect(connection_string)
        return conn
    except pyodbc.Error as e:
        # Nếu lỗi driver, thử fallback sang SQL Server default driver
        fallback_string = f"DRIVER={{SQL Server}};SERVER={SERVER};DATABASE={DATABASE};UID={UID};PWD={PWD};"
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
