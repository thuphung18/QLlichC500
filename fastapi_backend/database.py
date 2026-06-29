# database.py – Quản lý kết nối cơ sở dữ liệu SQL Server thông qua pyodbc và tối ưu hóa hiệu năng bằng Connection Pool tự dựng.
# 
# Thiết kế Connection Pool:
#   - Đảm bảo thread-safe cho môi trường bất đồng bộ của FastAPI (đa luồng).
#   - Giới hạn số lượng kết nối tối đa (POOL_MAX) tránh làm cạn kiệt tài nguyên hệ thống hoặc SQL Server.
#   - Tự động kiểm tra trạng thái sống của kết nối trước khi cấp phát (Health-check) và tự tạo mới nếu kết nối bị đứt.
#   - Giải quyết tình trạng Connection Leak nhờ dependency get_db bọc bằng try-finally đảm bảo luôn trả kết nối về pool.

import os
import queue
import threading
import pyodbc
from typing import Generator
from dotenv import load_dotenv

# Tải các biến môi trường từ file .env
load_dotenv()

# ─────────────────────────────────────────────
# Cấu hình kết nối SQL Server (đọc từ biến môi trường hoặc fallback mặc định)
# ─────────────────────────────────────────────
SERVER   = os.environ.get('DB_SERVER',   '203.128.246.222,1433')
DATABASE = os.environ.get('DB_DATABASE', 'weekly_schedule_db')
DRIVER   = os.environ.get('DB_DRIVER',   '{ODBC Driver 17 for SQL Server}')
UID      = os.environ.get('DB_UID',      'nghiand')
PWD      = os.environ.get('DB_PWD',      '@NangHaNoi2020@')

# TẮT pyodbc-level pooling để tránh xung đột với pool tự dựng của chúng ta.
# Khi pooling=True, pyodbc giữ socket TCP cũ trong pool nội bộ của nó, và khi gọi
# pyodbc.connect() lại (dù là fresh), nó trả về đúng socket cũ đã bị SQL Server ngắt —
# dẫn đến lỗi 08S01. Với pooling=False, mỗi pyodbc.connect() tạo TCP thực sự mới.
pyodbc.pooling = False

# ─────────────────────────────────────────────
# Kích thước Pool (Sử dụng hàng đợi Queue để lưu trữ các kết nối nhàn rỗi)
# ─────────────────────────────────────────────
POOL_MIN  = int(os.environ.get('DB_POOL_MIN',  '10'))   # Số kết nối duy trì tối thiểu trong pool
POOL_MAX  = int(os.environ.get('DB_POOL_MAX',  '30'))  # Tăng lên 30 để cân bằng giữa RAM 512MB và khả năng chịu tải

_pool:      queue.Queue      = queue.Queue()   # Queue chứa kết nối nhàn rỗi (không giới hạn kích thước queue để tránh block khi put)
_lock:      threading.Lock   = threading.Lock() # Lock đồng bộ hóa việc thay đổi số lượng kết nối tổng
_total:     int              = 0               # Tổng số kết nối vật lý hiện đang được quản lý (trong pool + đang sử dụng)


def _build_conn_str() -> str:
    """Tạo chuỗi kết nối (connection string) đến SQL Server."""
    return (
        f"DRIVER={DRIVER};SERVER={SERVER};"
        f"DATABASE={DATABASE};UID={UID};PWD={PWD};"
        f"Connection Timeout=10;"
    )


def _new_conn() -> pyodbc.Connection:
    """
    Tạo một kết nối vật lý mới đến SQL Server.
    Nếu driver chỉ định trong cấu hình gặp lỗi, hàm tự động thử kết nối bằng driver cũ để tăng khả năng tương thích.
    """
    try:
        conn = pyodbc.connect(_build_conn_str())
    except pyodbc.Error:
        # Cơ chế dự phòng (fallback) nếu hệ thống không cài ODBC Driver 17
        fallback = (
            f"DRIVER={{SQL Server}};SERVER={SERVER};"
            f"DATABASE={DATABASE};UID={UID};PWD={PWD};"
        )
        conn = pyodbc.connect(fallback)
    conn.autocommit = False  # Tắt chế độ tự động thực thi transaction để quản lý một cách an toàn
    return conn


def _is_alive(conn: pyodbc.Connection) -> bool:
    """Kiểm tra xem kết nối hiện tại còn sống và giao tiếp được với SQL Server không."""
    try:
        conn.execute("SELECT 1")
        return True
    except Exception:
        return False


def get_connection() -> pyodbc.Connection:
    """
    Lấy một kết nối từ pool để sử dụng.
    Quy trình xử lý:
      1. Thử lấy kết nối nhàn rỗi từ Queue (chế độ non-blocking).
      2. Nếu lấy được kết nối:
         - Kiểm tra kết nối còn sống không (health-check).
         - Nếu còn sống: Trả về kết nối.
         - Nếu kết nối đã chết: Đóng kết nối, giảm biến đếm _total, tiếp tục quét tìm kết nối khác.
      3. Nếu Queue rỗng:
         - Kiểm tra tổng số kết nối đã tạo (_total) xem đã đạt POOL_MAX chưa.
         - Nếu chưa vượt quá POOL_MAX: Tăng bộ đếm _total và tạo kết nối vật lý mới trả về.
         - Nếu đã đạt POOL_MAX: Chờ kết nối được trả lại từ các luồng khác vào Queue (chờ tối đa 30 giây).
         - Hết 30 giây nếu không có kết nối nào rảnh, ném lỗi cạn kiệt kết nối.
    """
    global _total

    # Bước 1: Thử lấy nhanh kết nối có sẵn trong pool
    while True:
        try:
            conn = _pool.get_nowait()
        except queue.Empty:
            break   # Pool rỗng, nhảy sang bước tạo mới hoặc chờ đợi

        if _is_alive(conn):
            return conn
            
        # Kết nối đã chết, giải phóng tài nguyên
        with _lock:
            _total -= 1
        try:
            conn.close()
        except Exception:
            pass

    # Bước 2: Pool rỗng, kiểm tra xem có được phép tạo thêm kết nối vật lý mới không
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

    # Bước 3: Đã đạt giới hạn POOL_MAX, chuyển sang chế độ đợi các luồng khác trả kết nối về pool
    try:
        conn = _pool.get(timeout=30)
        if _is_alive(conn):
            return conn
            
        # Kết nối lấy ra từ pool bị hỏng
        with _lock:
            _total -= 1
        try:
            conn.close()
        except Exception:
            pass
            
        # Sau khi loại bỏ kết nối hỏng, cố gắng tạo 1 kết nối mới thay thế ngay
        with _lock:
            _total += 1
        return _new_conn()
    except queue.Empty:
        raise Exception("DB connection pool exhausted – Không thể tạo thêm hoặc mượn kết nối từ pool. Thử lại sau")


def return_connection(conn: pyodbc.Connection):
    """
    Trả kết nối về pool sau khi sử dụng xong để request tiếp theo có thể tái sử dụng.
    """
    global _total
    try:
        # Hoàn tác (rollback) mọi transaction đang chạy dở để đảm bảo sạch trạng thái kết nối
        try:
            conn.rollback()
        except Exception:
            pass
        _pool.put_nowait(conn)
    except queue.Full:
        # Trường hợp hy hữu (queue bị lỗi / đầy), thực hiện đóng kết nối và giảm bộ đếm tổng
        with _lock:
            _total -= 1
        try:
            conn.close()
        except Exception:
            pass


def get_db() -> Generator[pyodbc.Connection, None, None]:
    """
    FastAPI Dependency: Cấp phát kết nối database tự động khi gọi controller
    và đảm bảo LUÔN LUÔN trả kết nối về pool khi request kết thúc nhờ cấu trúc yield trong try-finally.
    """
    conn = get_connection()
    try:
        yield conn
    except Exception:
        # Nếu luồng API gặp lỗi khi thực hiện query, thực hiện hoàn tác để bảo vệ toàn vẹn dữ liệu
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        # Đảm bảo kết nối luôn được trả về pool dù API thành công hay thất bại (tránh Connection Leak)
        return_connection(conn)


def pre_warm_pool(size: int = POOL_MIN):
    """
    Tạo sẵn một lượng kết nối tối thiểu (size) ngay khi ứng dụng FastAPI khởi động.
    Giúp giảm thiểu độ trễ (latency) của request đầu tiên gửi tới hệ thống.
    """
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
            print(f"[Pool] Khởi tạo kết nối sẵn gặp lỗi: {e}")
            break
    print(f"[Pool] Đã khởi tạo trước {warmed} kết nối (Tổng số kết nối đang quản lý={_total})")

