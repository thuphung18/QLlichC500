"""
cache.py  –  TTL in-memory cache cho dữ liệu lịch công tác.

Chiến lược:
  • Đọc lịch rất nhiều (hàng trăm user/phút), ghi rất ít (chỉ Admin/Manager).
  • Cache kết quả truy vấn schedule theo key (user_id, mode, day_index, keyword).
  • Tự động hết hạn sau SCHEDULE_TTL_SECONDS giây.
  • Khi Admin/Manager tạo hoặc xóa lịch → xóa toàn bộ cache để đảm bảo nhất quán.
"""

import threading
import time
from typing import Any, Optional

# ─────────────────────────────────────────────────────────────────
# Cấu hình
# ─────────────────────────────────────────────────────────────────
SCHEDULE_TTL_SECONDS   = 300   # Cache lịch hết hạn sau 5 phút
DEPARTMENT_TTL_SECONDS = 600   # Cache danh sách phòng ban: 10 phút
MAX_CACHE_ENTRIES      = 2000  # Giới hạn số entry tối đa (tránh OOM)


class TTLCache:
    """Thread-safe in-memory cache với thời gian sống (TTL) cho mỗi entry."""

    def __init__(self, ttl: int, max_size: int = MAX_CACHE_ENTRIES):
        self._store: dict[str, tuple[Any, float]] = {}   # key → (value, expire_at)
        self._ttl   = ttl
        self._max   = max_size
        self._lock  = threading.Lock()

    def get(self, key: str) -> Optional[Any]:
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            value, expire_at = entry
            if time.monotonic() > expire_at:
                del self._store[key]
                return None
            return value

    def set(self, key: str, value: Any):
        with self._lock:
            # Nếu đầy → xóa 20% entry cũ nhất (LRU đơn giản theo expire_at)
            if len(self._store) >= self._max:
                sorted_keys = sorted(
                    self._store, key=lambda k: self._store[k][1]
                )
                for old_key in sorted_keys[: self._max // 5]:
                    del self._store[old_key]
            self._store[key] = (value, time.monotonic() + self._ttl)

    def delete(self, key: str):
        with self._lock:
            self._store.pop(key, None)

    def clear(self):
        """Xóa toàn bộ cache (dùng khi có thay đổi dữ liệu lịch)."""
        with self._lock:
            self._store.clear()

    def clear_prefix(self, prefix: str):
        """Xóa tất cả entry có key bắt đầu bằng prefix."""
        with self._lock:
            keys_to_delete = [k for k in self._store if k.startswith(prefix)]
            for k in keys_to_delete:
                del self._store[k]

    def size(self) -> int:
        with self._lock:
            return len(self._store)

    def purge_expired(self):
        """Dọn dẹp các entry đã hết hạn (chạy định kỳ bởi background thread)."""
        now = time.monotonic()
        with self._lock:
            expired = [k for k, (_, exp) in self._store.items() if now > exp]
            for k in expired:
                del self._store[k]
        return len(expired)


# ─────────────────────────────────────────────────────────────────
# Các instance cache toàn cục
# ─────────────────────────────────────────────────────────────────
schedule_cache   = TTLCache(ttl=SCHEDULE_TTL_SECONDS,   max_size=MAX_CACHE_ENTRIES)
department_cache = TTLCache(ttl=DEPARTMENT_TTL_SECONDS, max_size=200)


# ─────────────────────────────────────────────────────────────────
# Background thread tự động dọn dẹp cache mỗi 2 phút
# ─────────────────────────────────────────────────────────────────
def _purge_worker():
    while True:
        time.sleep(120)
        removed_s = schedule_cache.purge_expired()
        removed_d = department_cache.purge_expired()
        if removed_s or removed_d:
            print(f"[Cache] Purged {removed_s} schedule + {removed_d} department entries.")


_purge_thread = threading.Thread(target=_purge_worker, daemon=True)
_purge_thread.start()


# ─────────────────────────────────────────────────────────────────
# Helpers để tạo cache key chuẩn hóa
# ─────────────────────────────────────────────────────────────────
def make_schedule_key(user_id: str, mode: str = "all",
                      day_index: Optional[int] = None,
                      keyword: Optional[str] = None) -> str:
    return f"sched:{user_id}:{mode}:{day_index}:{keyword}"


def invalidate_schedules(department_id: Optional[str] = None):
    """
    Xóa cache lịch khi có thay đổi dữ liệu.
    Nếu cung cấp department_id thì chỉ xóa cache của phòng đó (tương lai),
    hiện tại xóa toàn bộ để đơn giản và an toàn.
    """
    schedule_cache.clear()
