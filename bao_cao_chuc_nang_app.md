# BÁO CÁO TỔNG QUAN CHỨC NĂNG ỨNG DỤNG QUẢN LÝ LỊCH

Dựa trên cấu trúc mã nguồn hiện tại của dự án, ứng dụng đang sở hữu một hệ thống tính năng rất đầy đủ, từ phân quyền người dùng đến quản lý lịch trình thông minh. Dưới đây là bảng tổng hợp chi tiết các chức năng đã được tích hợp vào hệ thống:

## 1. Hệ thống Xác thực & Tài khoản (Authentication & Profile)
Hệ thống quản lý định danh người dùng được thiết kế bảo mật và thuận tiện:

*   **Đăng nhập hệ thống:** Bảo mật phiên đăng nhập qua Token, hỗ trợ ghi nhớ đăng nhập (Remember Me).
*   **Quên mật khẩu & OTP:** Hỗ trợ quy trình khôi phục mật khẩu chuẩn mực thông qua mã xác thực OTP.
*   **Đổi mật khẩu:** Cho phép người dùng chủ động thay đổi mật khẩu sau khi đã đăng nhập.
*   **Trang cá nhân (Profile):**
    *   Xem thông tin cá nhân chi tiết (Tên, Email, Khoa/Phòng ban, Chức vụ...).
    *   Cập nhật, chỉnh sửa thông tin cá nhân.
*   **Phân quyền (Role-based):** Hệ thống phân chia rõ ràng các quyền: `Admin`, `Quản lý` (có quyền tạo/xóa lịch), và `Nhân viên/Giảng viên` (chỉ xem lịch).

## 2. Quản lý Lịch công tác & Giảng dạy (Schedule Management)
Đây là module cốt lõi của ứng dụng, được chia thành nhiều góc nhìn (view) khác nhau để người dùng dễ theo dõi:

*   **Lịch của tôi (My Schedule):** Hiển thị riêng các lịch có liên quan trực tiếp đến user đang đăng nhập.
*   **Lịch của Khoa (Department Schedule):** Hiển thị lịch chung của toàn bộ Khoa/Phòng ban mà user trực thuộc.
*   **Lịch Tuần / Lịch Toàn trường (Week Schedule):** 
    *   Hiển thị tổng quan tất cả các lịch trong tuần.
    *   Phân chia rõ ràng theo từng buổi: Sáng, Chiều, Tối.
*   **Tìm kiếm lịch (Search):** Chức năng tìm kiếm nhanh các lịch công tác.
*   **Chi tiết lịch:** Xem đầy đủ nội dung, thời gian, địa điểm, và người tham gia của một sự kiện.
*   **Thông báo nhắc lịch:** Tích hợp hệ thống Push Notification (Firebase Cloud Messaging) và Local Notification để nhắc nhở khi sắp đến giờ.

## 3. Thao tác dữ liệu Lịch (Dành cho Quản lý/Admin)
*   **Thêm lịch thủ công:** Nhập tay thông tin để tạo lịch mới.
*   **Xóa lịch:** Quản lý/Admin có thể xóa lịch không còn hiệu lực.
*   **Tính năng nổi bật - Import Lịch bằng AI (PDF):** 
    *   Cho phép người dùng upload file lịch dạng PDF.
    *   Hệ thống Backend (FastAPI + AI) sẽ đọc và trích xuất dữ liệu.
    *   **Màn hình duyệt lịch (Review):** Cho phép người dùng kiểm tra, chỉnh sửa lại kết quả do AI nhận diện trước khi lưu chính thức vào cơ sở dữ liệu.

## 4. Bảng điều khiển Quản trị viên (Admin Dashboard)
Khu vực dành riêng cho quản trị viên hệ thống để kiểm soát toàn bộ dữ liệu:

*   **Tổng quan hệ thống:** Xem thống kê chung.
*   **Quản lý người dùng:** Cho phép Admin tạo mới (Create User) tài khoản cho nhân viên/giảng viên, cấp quyền.
*   **Quản lý lịch toàn hệ thống:** Quyền kiểm soát toàn bộ dữ liệu lịch của các Khoa.

---

> [!NOTE] 
> Ứng dụng đã được làm sạch dữ liệu giả (Mock/Demo data) và hiện tại đã sẵn sàng để tích hợp hoàn toàn với RESTful API thực tế thông qua các file Repository (`api_auth_repository.dart`, `api_schedule_repository.dart`). 

> [!TIP]
> Việc cấu trúc màn hình dạng thẻ (Card) kết hợp với Bottom Navigation Bar (`main_shell.dart`) mang lại trải nghiệm người dùng (UX) rất tốt cho một ứng dụng mang tính chất nội bộ, doanh nghiệp.
