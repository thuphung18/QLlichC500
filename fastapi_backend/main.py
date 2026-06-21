import time
import logging
from fastapi import FastAPI, Depends, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
import uvicorn

# Import các router
from routers import auth, schedules, users, departments
from scheduler import start_scheduler
from dependencies import verify_session_token
from database import pre_warm_pool

# ─────────────────────────────────────────────
# Logging cơ bản
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("qllich")

# ─────────────────────────────────────────────
# FastAPI App
# ─────────────────────────────────────────────
app = FastAPI(
    title="QL Lịch Tuần API",
    description="RESTful API cho ứng dụng quản lý lịch tuần bằng Flutter",
    version="2.0.0",
    # Tắt docs trên production để bảo mật (bật lại khi cần debug)
    # docs_url=None, redoc_url=None,
)

# ─────────────────────────────────────────────
# Middleware: GZip compression
# Tự động nén response > 1KB → giảm băng thông ~60-80%
# ─────────────────────────────────────────────
app.add_middleware(GZipMiddleware, minimum_size=1000)

# ─────────────────────────────────────────────
# Middleware: CORS
# ─────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────
# Middleware: Request timing + logging
# ─────────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.perf_counter()
    response: Response = await call_next(request)
    elapsed_ms = (time.perf_counter() - start) * 1000
    logger.info(
        "%s %s → %d (%.1f ms)",
        request.method, request.url.path, response.status_code, elapsed_ms
    )
    # Thêm header X-Process-Time để client đo được latency
    response.headers["X-Process-Time"] = f"{elapsed_ms:.1f}ms"
    return response

# ─────────────────────────────────────────────
# Đăng ký các Router
# ─────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(schedules.router,   dependencies=[Depends(verify_session_token)])
app.include_router(users.router,       dependencies=[Depends(verify_session_token)])
app.include_router(departments.router, dependencies=[Depends(verify_session_token)])

# ─────────────────────────────────────────────
# Startup / Shutdown events
# ─────────────────────────────────────────────
@app.on_event("startup")
def startup_event():
    logger.info("Khởi động server QL Lịch Tuần API v2.0...")
    # Khởi tạo trước 5 kết nối DB vào pool để giảm latency cho request đầu tiên
    pre_warm_pool(size=5)
    # Khởi động scheduler gửi push notification nhắc lịch
    start_scheduler()
    logger.info("Server sẵn sàng phục vụ!")

@app.on_event("shutdown")
def shutdown_event():
    logger.info("Server đang tắt. Dọn dẹp tài nguyên...")

# ─────────────────────────────────────────────
# Health check endpoint
# ─────────────────────────────────────────────
@app.get("/", tags=["Health Check"])
def root():
    """Endpoint kiểm tra trạng thái hoạt động của Server."""
    return {"status": "ok", "message": "QL Lịch Tuần API is running!", "version": "2.0"}

@app.get("/health", tags=["Health Check"])
def health():
    """Endpoint kiểm tra chi tiết hơn (dùng cho load balancer/uptime monitor)."""
    from cache import schedule_cache, department_cache
    from database import _pool, _active_connections
    return {
        "status": "ok",
        "cache": {
            "schedule_entries": schedule_cache.size(),
            "department_entries": department_cache.size(),
        },
        "db_pool": {
            "pool_available": _pool.qsize(),
            "total_created": _active_connections,
        }
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,               # Tắt reload khi production
        workers=1,                  # Tăng lên (2*CPU+1) khi deploy thật
        log_level="info",
    )
