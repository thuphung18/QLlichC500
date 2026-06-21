# main.py – Điểm khởi đầu chính của ứng dụng FastAPI.
#
# Chức năng:
#   - Khởi tạo ứng dụng FastAPI.
#   - Thiết lập Logging để ghi nhận nhật ký hoạt động.
#   - Đăng ký các Middleware: GZip (tối ưu hóa băng thông), CORS (cho phép truy cập chéo nguồn), Profiling (đo thời gian xử lý request).
#   - Đăng ký các API Routers cho từng phân hệ (auth, schedules, users, departments).
#   - Lên lịch chạy các tác vụ định kỳ khi server startup (Connection pre-warming, Background Scheduler).
#   - Cung cấp các Endpoint kiểm tra sức khỏe của Server (Health Check).

import time
import logging
from fastapi import FastAPI, Depends, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
import uvicorn

# Import các router điều hướng API từ thư mục routers
from routers import auth, schedules, users, departments
from scheduler import start_scheduler
from dependencies import verify_session_token
from database import pre_warm_pool

# ─────────────────────────────────────────────
# Cấu hình hệ thống Logging cơ bản
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("qllich")

# ─────────────────────────────────────────────
# Khởi tạo đối tượng FastAPI App
# ─────────────────────────────────────────────
app = FastAPI(
    title="QL Lịch Tuần API",
    description="RESTful API cho ứng dụng quản lý lịch tuần bằng Flutter",
    version="2.0.0",
    # Mẹo bảo mật: Tắt docs (Swagger) trên môi trường production bằng cách gán docs_url=None, redoc_url=None khi deploy.
)

# ─────────────────────────────────────────────
# Middleware: GZip compression
# Tự động nén dữ liệu phản hồi (response body) có kích thước lớn hơn 1000 Bytes (1KB) trước khi gửi về client.
# Giúp giảm tải lượng băng thông sử dụng từ 60% đến 80%.
# ─────────────────────────────────────────────
app.add_middleware(GZipMiddleware, minimum_size=1000)

# ─────────────────────────────────────────────
# Middleware: CORS (Cross-Origin Resource Sharing)
# Cho phép ứng dụng Flutter Web hoặc các client khác chạy trên cổng khác gọi API được bình thường.
# ─────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Cho phép tất cả các nguồn truy cập (nên đổi thành tên miền cụ thể trên production)
    allow_credentials=True,
    allow_methods=["*"],  # Cho phép tất cả các phương thức HTTP (GET, POST, PUT, DELETE,...)
    allow_headers=["*"],  # Cho phép tất cả các HTTP Headers gửi lên
)

# ─────────────────────────────────────────────
# Middleware: Request timing & Logging
# Ghi lại thời gian xử lý của từng Request HTTP gửi tới server.
# ─────────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.perf_counter()  # Sử dụng bộ đếm có độ chính xác cao
    response: Response = await call_next(request)
    elapsed_ms = (time.perf_counter() - start) * 1000
    
    # Ghi log dạng: GET /api/schedules → 200 (15.5 ms)
    logger.info(
        "%s %s → %d (%.1f ms)",
        request.method, request.url.path, response.status_code, elapsed_ms
    )
    
    # Thêm Header phản hồi X-Process-Time giúp client có thể tự tính toán độ trễ mạng
    response.headers["X-Process-Time"] = f"{elapsed_ms:.1f}ms"
    return response

# ─────────────────────────────────────────────
# Đăng ký các Router điều hướng
# ─────────────────────────────────────────────
# Phân hệ Auth không cần token xác thực
app.include_router(auth.router)

# Các phân hệ: Lịch công tác, Người dùng, Phòng ban đều yêu cầu xác thực JWT qua verify_session_token
app.include_router(schedules.router,   dependencies=[Depends(verify_session_token)])
app.include_router(users.router,       dependencies=[Depends(verify_session_token)])
app.include_router(departments.router, dependencies=[Depends(verify_session_token)])

# ─────────────────────────────────────────────
# Quản lý vòng đời ứng dụng (Startup / Shutdown Events)
# ─────────────────────────────────────────────
@app.on_event("startup")
def startup_event():
    """Chạy khi server bắt đầu khởi động."""
    logger.info("Khởi động server QL Lịch Tuần API v2.0...")
    
    # 1. Khởi tạo trước 5 kết nối DB rảnh đưa vào pool (Pre-warming) giúp tăng tốc request đầu tiên
    pre_warm_pool(size=5)
    
    # 2. Bắt đầu bộ lập lịch ngầm tự động quét lịch học/làm việc để gửi thông báo FCM sau mỗi 1 phút
    start_scheduler()
    
    logger.info("Server sẵn sàng phục vụ!")

@app.on_event("shutdown")
def shutdown_event():
    """Chạy khi server nhận tín hiệu dừng (tắt)."""
    logger.info("Server đang tắt. Tiến hành dọn dẹp tài nguyên và đóng các kết nối...")

# ─────────────────────────────────────────────
# Endpoints kiểm tra sức khỏe của Server (Health Check)
# ─────────────────────────────────────────────
@app.get("/", tags=["Health Check"])
def root():
    """Endpoint kiểm tra trạng thái hoạt động của Server."""
    return {"status": "ok", "message": "QL Lịch Tuần API is running!", "version": "2.0.2 - debug key"}



@app.get("/health", tags=["Health Check"])
def health():
    """
    Endpoint kiểm tra chi tiết trạng thái hoạt động của hệ thống:
      - Trạng thái cache hiện tại (Số lượng entry trong cache lịch, cache phòng ban).
      - Trạng thái Database Connection Pool (Số kết nối rảnh rỗi đang có, tổng kết nối vật lý đã tạo, số kết nối đang bị chiếm dụng).
    Thích hợp tích hợp cho các bên thứ ba như Load Balancer, Uptime Monitor.
    """
    import os
    from cache import schedule_cache, department_cache
    from database import _pool, _total
    
    gemini_key = os.environ.get("GEMINI_API_KEY")
    masked_key = f"{gemini_key[:5]}...{gemini_key[-5:]}" if gemini_key else "None"
    
    return {
        "status": "ok",
        "gemini_key": masked_key,
        "cache": {
            "schedule_entries": schedule_cache.size(),
            "department_entries": department_cache.size(),
        },
        "db_pool": {
            "pool_available": _pool.qsize(), # Số kết nối rảnh rỗi trong queue
            "total_created": _total,         # Tổng số kết nối vật lý đã tạo
            "in_use": _total - _pool.qsize(), # Số kết nối đang phục vụ request
        }
    }


# Khởi chạy server uvicorn thủ công nếu file được gọi trực tiếp bằng `python main.py`
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,               # Tắt reload tự động để tối ưu hiệu năng trên production
        workers=1,                  # Số worker chạy song song (có thể tăng lên khi deploy thật)
        log_level="info",
    )

