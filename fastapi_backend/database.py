import os
import queue
import threading
import pyodbc
from typing import Generator
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────
# Cấu hình kết nối SQL Server (đọc từ .env)
# ─────────────────────────────────────────────
SERVER   = os.environ.get('DB_SERVER',   '203.128.246.222,1433')
DATABASE = os.environ.get('DB_DATABASE', 'weekly_schedule_db')
DRIVER   = os.environ.get('DB_DRIVER',   '{ODBC Driver 17 for SQL Server}')
UID      = os.environ.get('DB_UID',      'nghiand')
PWD      = os.environ.get('DB_PWD',      '@NangHaNoi2020@')

# ─────────────────────────────────────────────
# Bật ODBC Connection Pooling (tái sử dụng
# kết nối ở tầng ODBC Driver để giảm TCP overhead)
# ─────────────────────────────────────────────
pyodbc.pooling = True

# ─────────────────────────────────────────────
# Thread-safe Connection Pool
# ─────────────────────────────────────────────
POOL_SIZE = int(os.environ.get('DB_POOL_SIZE', '20'))   # kết nối mặc định giữ mở
MAX_OVERFLOW = int(os.environ.get('DB_MAX_OVERFLOW', '30'))  # kết nối tối đa được tạo thêm

_pool: queue.Queue = queue.Queue(maxsize=POOL_SIZE + MAX_OVERFLOW)
_pool_lock = threading.Lock()
_active_connections = 0                 # tổng số kết nối đã tạo (bao gồm đang dùng + trong hàng đợi)

def _build_connection_string(use_fallback: bool = False) -> str:
    if use_fallback:
        return f"DRIVER={{SQL Server}};SERVER={SERVER};DATABASE={DATABASE};UID={UID};PWD={PWD};"
    return f"DRIVER={DRIVER};SERVER={SERVER};DATABASE={DATABASE};UID={UID};PWD={PWD};"

def _create_new_connection() -> pyodbc.Connection:
    """Tạo một kết nối vật lý mới đến SQL Server."""
    try:
        conn = pyodbc.connect(_build_connection_string(), timeout=10)
        conn.autocommit = False
        return conn
    except pyodbc.Error:
        # Fallback về driver mặc định nếu ODBC Driver 17 không khả dụng
        conn = pyodbc.connect(_build_connection_string(use_fallback=True), timeout=10)
        conn.autocommit = False
        return conn

def _is_connection_alive(conn: pyodbc.Connection) -> bool:
    """Kiểm tra kết nối có còn hợp lệ không (tránh lỗi broken pipe sau thời gian dài nhàn rỗi)."""
    try:
        conn.execute("SELECT 1")
        return True
    except Exception:
        return False

def get_connection() -> pyodbc.Connection:
    """
    Lấy kết nối từ pool. Nếu pool còn kết nối khả dụng thì tái sử dụng,
    ngược lại tạo mới (trong phạm vi MAX_OVERFLOW).
    """
    global _active_connections

    # Thử lấy ngay từ pool (non-blocking)
    try:
        conn = _pool.get_nowait()
        # Kiểm tra health trước khi tái sử dụng
        if _is_connection_alive(conn):
            return conn
        else:
            # Kết nối chết → đóng và tạo lại
            with _pool_lock:
                _active_connections -= 1
            try:
                conn.close()
            except Exception:
                pass
    except queue.Empty:
        pass

    # Pool rỗng → tạo kết nối mới nếu chưa đạt giới hạn
    with _pool_lock:
        if _active_connections < POOL_SIZE + MAX_OVERFLOW:
            _active_connections += 1
        else:
            # Đã đạt giới hạn → chờ pool có kết nối trả về (tối đa 10 giây)
            pass

    try:
        conn = _pool.get(timeout=10)   # chờ kết nối được trả lại
        if _is_connection_alive(conn):
            return conn
        with _pool_lock:
            _active_connections -= 1
        try:
            conn.close()
        except Exception:
            pass
    except queue.Empty:
        pass

    return _create_new_connection()

def return_connection(conn: pyodbc.Connection):
    """Trả kết nối về pool sau khi sử dụng xong."""
    try:
        _pool.put_nowait(conn)
    except queue.Full:
        # Pool đầy → đóng kết nối này (xảy ra khi MAX_OVERFLOW bị vượt qua)
        global _active_connections
        with _pool_lock:
            _active_connections -= 1
        try:
            conn.close()
        except Exception:
            pass

def get_db() -> Generator[pyodbc.Connection, None, None]:
    """
    FastAPI Dependency: cung cấp kết nối từ pool cho mỗi request,
    và tự động trả về pool sau khi request hoàn thành.
    """
    conn = get_connection()
    try:
        yield conn
    except Exception:
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        return_connection(conn)

def pre_warm_pool(size: int = 5):
    """
    Khởi tạo trước một số kết nối trong pool khi server khởi động,
    giúp giảm độ trễ cho những request đầu tiên.
    """
    global _active_connections
    warmed = 0
    for _ in range(min(size, POOL_SIZE)):
        try:
            conn = _create_new_connection()
            with _pool_lock:
                _active_connections += 1
            _pool.put_nowait(conn)
            warmed += 1
        except Exception as e:
            print(f"[Pool] Không thể khởi tạo kết nối trước: {e}")
            break
    print(f"[Pool] Đã khởi tạo trước {warmed} kết nối.")
