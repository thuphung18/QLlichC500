from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Import các router
from routers import auth, schedules, users, departments
from scheduler import start_scheduler

app = FastAPI(
    title="QL Lịch Tuần API",
    description="RESTful API cho ứng dụng quản lý lịch tuần bằng Flutter",
    version="1.0.0"
)

# Cấu hình CORS để Flutter Web hoặc App có thể gọi API mà không bị chặn
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Đăng ký các Router
app.include_router(auth.router)
app.include_router(schedules.router)
app.include_router(users.router)
app.include_router(departments.router)

@app.on_event("startup")
def startup_event():
    start_scheduler()

@app.get("/", tags=["Health Check"])
def root():
    """
    Endpoint kiểm tra trạng thái hoạt động của Server.
    """
    return {"message": "QL Lịch Tuần API is running!"}

if __name__ == "__main__":
    # Để chạy server, gõ: uvicorn main:app --reload
    # Hoặc đơn giản là chạy file main.py này.
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
