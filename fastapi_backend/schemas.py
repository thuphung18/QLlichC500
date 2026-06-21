# schemas.py – Định nghĩa các Pydantic Schemas (Data Models) cho ứng dụng.
#
# Chức năng:
#   - Xác thực dữ liệu đầu vào (Request Validation) từ client gửi lên API.
#   - Định cấu trúc dữ liệu phản hồi đầu ra (Response Serialization) gửi về client.
#   - Hỗ trợ tài liệu hóa API tự động (Swagger / OpenAPI Docs).

from pydantic import BaseModel
from typing import List, Optional

# ─────────────────────────────────────────────────────────────────
# 1. Schemas phục vụ phân hệ Xác thực (Authentication)
# ─────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    """Dữ liệu yêu cầu đăng nhập."""
    username: str
    password: str


class UserProfile(BaseModel):
    """Thông tin chi tiết cá nhân người dùng trả về sau khi đăng nhập thành công."""
    id: str
    username: str
    fullName: str
    role: str
    unit: str
    departmentId: str
    email: Optional[str] = None
    phone: Optional[str] = None
    avatarUrl: Optional[str] = None


class LoginResponse(BaseModel):
    """Phản hồi sau khi đăng nhập thành công, bao gồm cặp Token và thông tin User."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserProfile


class RefreshTokenRequest(BaseModel):
    """Dữ liệu yêu cầu làm mới Access Token bằng Refresh Token."""
    refresh_token: str


class TokenResponse(BaseModel):
    """Phản hồi cặp Token mới sau khi Refresh Token thành công."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class SendResetCodeRequest(BaseModel):
    """Dữ liệu yêu cầu gửi mã OTP quên mật khẩu (nhập email/sđt)."""
    contact: str


class SendResetCodeResponse(BaseModel):
    """Phản hồi kết quả gửi OTP quên mật khẩu."""
    success: bool
    message: str
    maskedContact: Optional[str] = None  # Thông tin liên lạc đã che bớt để bảo mật


class UpdateProfileRequest(BaseModel):
    """Dữ liệu người dùng gửi lên để tự chỉnh sửa thông tin cá nhân."""
    fullName: str
    email: Optional[str] = None
    phone: Optional[str] = None


class UpdatePasswordRequest(BaseModel):
    """Dữ liệu thay đổi mật khẩu tự phục vụ."""
    oldPassword: str
    newPassword: str
    debugCode: Optional[str] = None


class VerifyResetCodeRequest(BaseModel):
    """Dữ liệu gửi lên để kiểm tra mã OTP quên mật khẩu."""
    contact: str
    code: str


class VerifyResetCodeResponse(BaseModel):
    """Phản hồi sau khi xác thực OTP thành công, cung cấp resetToken tạm thời."""
    success: bool
    message: str
    resetToken: Optional[str] = None


class ResetPasswordRequest(BaseModel):
    """Dữ liệu đặt mật khẩu mới sử dụng resetToken đã xác thực."""
    resetToken: str
    newPassword: str


class ResetPasswordResponse(BaseModel):
    """Phản hồi kết quả đặt lại mật khẩu."""
    success: bool
    message: str


# ─────────────────────────────────────────────────────────────────
# 2. Schemas phục vụ phân hệ Lịch Công tác (Schedules)
# ─────────────────────────────────────────────────────────────────

class ScheduleItem(BaseModel):
    """Chi tiết một mục lịch học/làm việc hiển thị trên client."""
    id: str
    title: str
    teacher: str
    room: str
    dateLabel: str  # Ví dụ: "Thứ 2, 21/06"
    startTime: str  # Định dạng "HH:MM"
    endTime: str    # Định dạng "HH:MM"
    session: str    # Ca học: 'morning', 'afternoon', 'evening'
    note: Optional[str] = None
    unit: str       # Đơn vị tổ chức (ví dụ: Học viện ANND)
    departmentId: str
    departmentName: str
    category: str   # Phân loại: 'ToanTruong' hoặc 'BoMon'
    participants: List[str]         # Danh sách tên những người tham gia
    participantUserIds: List[str]   # Danh sách mã UUID người tham gia
    dayIndex: int   # Thứ tự ngày trong tuần (2 -> 8 tương ứng Thứ 2 -> Chủ Nhật)
    isMine: bool    # Đánh dấu lịch này có sự tham gia của User đang gọi API không
    isDepartment: bool  # Đánh dấu lịch này thuộc phòng ban của User đang gọi API không


class ScheduleListResponse(BaseModel):
    """Danh sách lịch công tác trả về."""
    data: List[ScheduleItem]


class Department(BaseModel):
    """Thông tin cơ bản về Phòng ban / Khoa."""
    id: str
    name: str


class UserCompact(BaseModel):
    """Thông tin rút gọn của người dùng (dùng hiển thị dropdown chọn người tham gia)."""
    id: str
    fullName: str
    departmentId: str


class FormDataResponse(BaseModel):
    """Dữ liệu cấu trúc phục vụ biểu mẫu tạo lịch (danh sách phòng ban + danh sách user)."""
    departments: List[Department]
    users: List[UserCompact]


class CreateScheduleRequest(BaseModel):
    """Dữ liệu gửi lên để tạo một lịch công tác mới."""
    title: str
    teacher: str
    room: str
    scheduleDate: str  # Định dạng "YYYY-MM-DD"
    startTime: str     # Định dạng "HH:MM"
    endTime: str       # Định dạng "HH:MM"
    note: Optional[str] = None
    unit: str
    departmentId: str
    category: str      # 'ToanTruong' hoặc 'BoMon'
    participantUserIds: List[str]


class FcmTokenRequest(BaseModel):
    """Yêu cầu cập nhật token thiết bị để nhận thông báo đẩy."""
    user_id: str
    fcm_token: str


# ─────────────────────────────────────────────────────────────────
# 3. Schemas phục vụ phân hệ Quản lý Người dùng (Users Management)
# ─────────────────────────────────────────────────────────────────

class CreateUserRequest(BaseModel):
    """Dữ liệu yêu cầu Admin/Manager tạo tài khoản người dùng mới."""
    username: str
    fullName: str
    role: str
    unit: str
    departmentId: str
    email: Optional[str] = None
    phone: Optional[str] = None


class AdminUpdateUserRequest(BaseModel):
    """Dữ liệu Admin/Manager gửi lên để chỉnh sửa tài khoản người dùng."""
    fullName: str
    role: str
    unit: str
    departmentId: str
    email: Optional[str] = None
    phone: Optional[str] = None
    isActive: bool = True  # True = Hoạt động, False = Bị khóa tài khoản


class UserDetail(BaseModel):
    """Thông tin đầy đủ của một người dùng hiển thị trên trang danh sách quản trị viên."""
    id: str
    username: str
    fullName: str
    role: str
    unit: str
    departmentId: str
    departmentName: str
    email: Optional[str] = None
    phone: Optional[str] = None
    isActive: bool

