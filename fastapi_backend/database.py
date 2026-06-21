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

# Bật ODBC-level pooling để driver tái sử dụng socket
pyodbc.pooling = True

# ─────────────────────────────────────────────
# Kích thước pool
# ─────────────────────────────────────────────
POOL_MIN  = int(os.environ.get('DB_POOL_MIN',  '5'))   # kết nối luôn giữ sẵn trong pool
POOL_MAX  = int(os.environ.get('DB_POOL_MAX',  '20'))  # tổng kết nối tối đa được phép tồn tại

_pool:      queue.Queue      = queue.Queue()   # không giới hạn kích thước queue
_lock:      threading.Lock   = threading.Lock()
_total:     int              = 0              # tổng kết nối vật lý đã tạo (trong pool + đang dùng)


def _build_conn_str() -> str:
    return (
        f"DRIVER={DRIVER};SERVER={SERVER};"
        f"DATABASE={DATABASE};UID={UID};PWD={PWD};"
        f"Connection Timeout=10;"
    )


def _new_conn() -> pyodbc.Connection:
    """Tạo một kết nối vật lý mới, thử fallback nếu driver không tìm thấy."""
    try:
        conn = pyodbc.connect(_build_conn_str())
    except pyodbc.Error:
        fallback = (
            f"DRIVER={{SQL Server}};SERVER={SERVER};"
            f"DATABASE={DATABASE};UID={UID};PWD={PWD};"
        )
        conn = pyodbc.connect(fallback)
    conn.autocommit = False
    return conn


def _is_alive(conn: pyodbc.Connection) -> bool:
    try:
        conn.execute("SELECT 1")
        return True
    except Exception:
        return False


def get_connection() -> pyodbc.Connection:
    """
    Lấy kết nối từ pool.
    Logic đơn giản & chính xác:
      1. Thử lấy ngay từ queue (non-blocking).
      2. Nếu lấy được → kiểm tra còn sống không → dùng.
      3. Nếu queue rỗng và chưa đạt POOL_MAX → tạo mới.
      4. Nếu đã đạt POOL_MAX → chờ queue tối đa 15s.
    """
    global _total

    # Bước 1: thử lấy ngay từ pool
    while True:
        try:
            conn = _pool.get_nowait()
        except queue.Empty:
            break   # pool rỗng → sang bước tiếp

        if _is_alive(conn):
            return conn
        # Kết nối chết → bỏ, giảm bộ đếm, thử tiếp
        with _lock:
            _total -= 1
        try:
            conn.close()
        except Exception:
            pass

    # Bước 2: pool rỗng → tạo mới hoặc chờ
    with _lock:
        can_create = _total < POOL_MAX
        if can_create:
            _total += 1

    if can_create:
        try:
            return _new_conn()
        except Exception:
            with _lock:
                _total -= 1
            raise

    # Bước 3: đã đạt giới hạn → chờ kết nối được trả về
    try:
        conn = _pool.get(timeout=15)
        if _is_alive(conn):
            return conn
        with _lock:
            _total -= 1
        try:
            conn.close()
        except Exception:
            pass
        # Sau khi discard, thử tạo mới
        with _lock:
            _total += 1
        return _new_conn()
    except queue.Empty:
        raise Exception("DB connection pool exhausted – thử lại sau")


def return_connection(conn: pyodbc.Connection):
    """Trả kết nối về pool để request tiếp theo tái sử dụng."""
    global _total
    try:
        # Reset trạng thái trước khi trả lại
        try:
            conn.rollback()   # hủy transaction dở dang (nếu có)
        except Exception:
            pass
        _pool.put_nowait(conn)
    except queue.Full:
        # Không nên xảy ra vì queue không giới hạn, nhưng phòng thủ
        with _lock:
            _total -= 1
        try:
            conn.close()
        except Exception:
            pass


def get_db() -> Generator[pyodbc.Connection, None, None]:
    """
    FastAPI Dependency: inject kết nối vào handler, tự trả về pool sau request.
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


def pre_warm_pool(size: int = POOL_MIN):
    """Tạo sẵn một số kết nối khi server khởi động để giảm latency request đầu tiên."""
    global _total
    warmed = 0
    for _ in range(min(size, POOL_MAX)):
        try:
            with _lock:
                _total += 1
            conn = _new_conn()
            _pool.put_nowait(conn)
            warmed += 1
        except Exception as e:
            with _lock:
                _total -= 1
            print(f"[Pool] Pre-warm failed: {e}")
            break
    print(f"[Pool] Pre-warmed {warmed} connections (total={_total})")
