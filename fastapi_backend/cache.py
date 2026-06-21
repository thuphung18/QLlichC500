# cache.py – Bộ nhớ đệm tự động hết hạn (TTL In-Memory Cache) dành cho ứng dụng FastAPI.
# 
# Chiến lược Cache:
#   - Tần suất đọc lịch công tác là cực lớn (hàng trăm lượt truy cập/phút từ ứng dụng di động).
#   - Tần suất ghi/cập nhật lịch rất nhỏ (chỉ diễn ra khi Quản trị viên/Trưởng phòng thao tác).
#   - Sử dụng cơ chế TTL (Time-To-Live) để tự động xóa bỏ các bản ghi cũ tránh chiếm dụng RAM lâu dài.
#   - Thiết lập Thread-Safe sử dụng threading.Lock để đảm bảo tính toàn vẹn dữ liệu trong môi trường đa luồng.
#   - Khi có hành động thay đổi dữ liệu (tạo mới/xóa lịch), toàn bộ cache lịch sẽ lập tức bị xóa (invalidate) để đảm bảo đồng nhất.

import threading
import time
from typing import Any, Optional

# ─────────────────────────────────────────────────────────────────
# Tham số cấu hình bộ nhớ Cache
# ─────────────────────────────────────────────────────────────────
SCHEDULE_TTL_SECONDS   = 300   # Thời gian sống của cache lịch: 5 phút (300 giây)
DEPARTMENT_TTL_SECONDS = 600   # Thời gian sống của cache phòng ban: 10 phút (600 giây)
MAX_CACHE_ENTRIES      = 2000  # Số lượng bản ghi cache tối đa được lưu trữ để tránh tràn bộ nhớ (Out Of Memory)


class TTLCache:
    """
    Bộ nhớ đệm trong RAM hỗ trợ tự động hết hạn dựa trên thời gian sống (TTL).
    Đồng bộ luồng (Thread-safe) sử dụng threading.Lock.
    """

    def __init__(self, ttl: int, max_size: int = MAX_CACHE_ENTRIES):
        self._store: dict[str, tuple[Any, float]] = {}   # Định dạng lưu trữ: key → (dữ liệu_giá_trị, thời_gian_hết_hạn)
        self._ttl   = ttl
        self._max   = max_size
        self._lock  = threading.Lock()

    def get(self, key: str) -> Optional[Any]:
        """
        Lấy dữ liệu từ cache.
        Nếu tìm thấy bản ghi nhưng thời gian sống đã hết hạn (expire_at < time.monotonic()), 
        hàm sẽ tự động xóa bản ghi đó và trả về None.
        """
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            value, expire_at = entry
            # So sánh mốc thời gian hệ thống để kiểm tra hết hạn
            if time.monotonic() > expire_at:
                del self._store[key]
                return None
            return value

    def set(self, key: str, value: Any):
        """
        Lưu dữ liệu vào cache.
        Nếu dung lượng cache hiện tại vượt ngưỡng _max, tiến hành xóa bớt 20% bản ghi
        sắp hết hạn nhất (cơ chế dọn dẹp LRU đơn giản).
        """
        with self._lock:
            # Cơ chế tự dọn dẹp khi bộ nhớ cache đầy
            if len(self._store) >= self._max:
                sorted_keys = sorted(
                    self._store, key=lambda k: self._store[k][1]
                )
                # Giải phóng 20% số lượng cache cũ nhất
                for old_key in sorted_keys[: self._max // 5]:
                    del self._store[old_key]
            # Tính toán thời điểm hết hạn và ghi đè vào cache store
            self._store[key] = (value, time.monotonic() + self._ttl)

    def delete(self, key: str):
        """Xóa thủ công một bản ghi cache theo Key."""
        with self._lock:
            self._store.pop(key, None)

    def clear(self):
        """Xóa sạch toàn bộ dữ liệu trong bộ nhớ đệm (dùng khi cập nhật dữ liệu hàng loạt)."""
        with self._lock:
            self._store.clear()

    def clear_prefix(self, prefix: str):
        """Xóa toàn bộ các bản ghi cache có Key bắt đầu bằng chuỗi prefix nhất định."""
        with self._lock:
            keys_to_delete = [k for k in self._store if k.startswith(prefix)]
            for k in keys_to_delete:
                del self._store[k]

    def size(self) -> int:
        """Trả về số lượng bản ghi cache hiện tại."""
        with self._lock:
            return len(self._store)

    def purge_expired(self) -> int:
        """
        Quét và xóa bỏ tất cả các bản ghi cache đã hết hạn.
        Được gọi định kỳ bởi luồng quét rác chạy ngầm để giải phóng bộ nhớ.
        """
        now = time.monotonic()
        with self._lock:
            expired = [k for k, (_, exp) in self._store.items() if now > exp]
            for k in expired:
                del self._store[k]
        return len(expired)


# ─────────────────────────────────────────────────────────────────
# Các instance Cache toàn cục được chia sẻ trong toàn ứng dụng
# ─────────────────────────────────────────────────────────────────
# Cache lịch công tác: TTL 5 phút, lưu trữ tối đa 2000 kết quả
schedule_cache   = TTLCache(ttl=SCHEDULE_TTL_SECONDS,   max_size=MAX_CACHE_ENTRIES)
# Cache phòng ban: TTL 10 phút, lưu trữ tối đa 200 kết quả
department_cache = TTLCache(ttl=DEPARTMENT_TTL_SECONDS, max_size=200)


# ─────────────────────────────────────────────────────────────────
# Tiến trình chạy ngầm dọn dẹp cache rác (Garbage Collector Thread)
# Tự động quét và xóa cache hết hạn mỗi 2 phút một lần.
# ─────────────────────────────────────────────────────────────────
def _purge_worker():
    while True:
        time.sleep(120)  # Tạm dừng 2 phút
        removed_s = schedule_cache.purge_expired()
        removed_d = department_cache.purge_expired()
        if removed_s or removed_d:
            print(f"[Cache] Đã dọn dẹp {removed_s} cache lịch + {removed_d} cache phòng ban hết hạn.")


# Khởi chạy luồng dọn dẹp dưới dạng Daemon Thread để tự động tắt khi tắt server chính
_purge_thread = threading.Thread(target=_purge_worker, daemon=True)
_purge_thread.start()


# ─────────────────────────────────────────────────────────────────
# Các hàm bổ trợ (Helpers) liên quan đến Cache
# ─────────────────────────────────────────────────────────────────
def make_schedule_key(user_id: str, mode: str = "all",
                      day_index: Optional[int] = None,
                      keyword: Optional[str] = None) -> str:
    """Tạo ra khóa cache (cache key) chuẩn hóa phục vụ việc tra cứu nhanh."""
    return f"sched:{user_id}:{mode}:{day_index}:{keyword}"


def invalidate_schedules(department_id: Optional[str] = None):
    """
    Hủy hiệu lực (xóa bỏ) cache lịch công tác khi xảy ra thay đổi dữ liệu lịch (Thêm, Sửa, Xóa).
    Điều này ép hệ thống phải lấy dữ liệu mới trực tiếp từ SQL Server ở request kế tiếp.
    """
    schedule_cache.clear()

