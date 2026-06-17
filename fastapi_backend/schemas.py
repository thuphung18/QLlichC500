from pydantic import BaseModel
from typing import List, Optional

# --- Schemas cho Authentication ---

class LoginRequest(BaseModel):
    username: str
    password: str

class UserProfile(BaseModel):
    id: str
    username: str
    fullName: str
    role: str
    unit: str
    departmentId: str
    email: Optional[str] = None
    phone: Optional[str] = None
    avatarUrl: Optional[str] = None
    sessionToken: Optional[str] = None

class LoginResponse(BaseModel):
    user: UserProfile

class SendResetCodeRequest(BaseModel):
    contact: str

class SendResetCodeResponse(BaseModel):
    success: bool
    message: str
    maskedContact: Optional[str] = None

class UpdateProfileRequest(BaseModel):
    fullName: str
    email: Optional[str] = None
    phone: Optional[str] = None

class UpdatePasswordRequest(BaseModel):
    oldPassword: str
    newPassword: str
    debugCode: Optional[str] = None

class VerifyResetCodeRequest(BaseModel):
    contact: str
    code: str

class VerifyResetCodeResponse(BaseModel):
    success: bool
    message: str
    resetToken: Optional[str] = None

class ResetPasswordRequest(BaseModel):
    resetToken: str
    newPassword: str

class ResetPasswordResponse(BaseModel):
    success: bool
    message: str


# --- Schemas cho Schedules ---

class ScheduleItem(BaseModel):
    id: str
    title: str
    teacher: str
    room: str
    dateLabel: str
    startTime: str
    endTime: str
    session: str # 'morning', 'afternoon', 'evening'
    note: Optional[str] = None
    unit: str
    departmentId: str
    departmentName: str
    category: str
    participants: List[str]
    participantUserIds: List[str]
    dayIndex: int
    isMine: bool
    isDepartment: bool

class ScheduleListResponse(BaseModel):
    data: List[ScheduleItem]

class Department(BaseModel):
    id: str
    name: str

class UserCompact(BaseModel):
    id: str
    fullName: str
    departmentId: str

class FormDataResponse(BaseModel):
    departments: List[Department]
    users: List[UserCompact]

class CreateScheduleRequest(BaseModel):
    title: str
    teacher: str
    room: str
    scheduleDate: str
    startTime: str
    endTime: str
    note: Optional[str] = None
    unit: str
    departmentId: str
    category: str
    participantUserIds: List[str]

class FcmTokenRequest(BaseModel):
    user_id: str
    fcm_token: str

class CreateUserRequest(BaseModel):
    username: str
    fullName: str
    role: str
    unit: str
    departmentId: str
    email: Optional[str] = None
    phone: Optional[str] = None

class AdminUpdateUserRequest(BaseModel):
    """Schema Admin dùng để chỉnh sửa thông tin, role, phòng ban, trạng thái tài khoản."""
    fullName: str
    role: str
    unit: str
    departmentId: str
    email: Optional[str] = None
    phone: Optional[str] = None
    isActive: bool = True  # True = hoạt động, False = khóa

class UserDetail(BaseModel):
    """Schema trả về thông tin đầy đủ của một user cho trang quản trị."""
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
