# Tài liệu Tổng hợp Chức năng Ứng dụng Quản lý Lịch Tuần (QL Lịch C500)

Ứng dụng **Quản lý Lịch Tuần** là một hệ thống đa nền tảng (Backend FastAPI & Frontend Flutter Mobile) được thiết kế đặc thù cho việc quản lý, theo dõi, phê duyệt và thông báo lịch công tác tuần của các phòng ban thuộc Học viện.

---

## 1. Phân hệ Backend (FastAPI API)

Backend được xây dựng bằng Python sử dụng framework FastAPI hiệu năng cao, tích hợp kết nối Cơ sở dữ liệu SQL Server và dịch vụ Firebase Cloud Messaging.

### 1.1. Phân hệ Xác thực & Phân quyền (Authentication)
* **Đăng nhập/Đăng xuất**: Đăng nhập bằng tài khoản và mật khẩu, quản lý phiên làm việc bằng Session Token và mã hóa bảo mật.
* **Token JWT**: Quản lý phiên làm việc an toàn thông qua JWT.
* **Phân quyền người dùng (Role-based Access Control)**:
  * **Admin (Quản trị viên tối cao)**: Quyền thao tác trên toàn hệ thống, cấu hình phòng ban, người dùng và tất cả lịch trình.
  * **Trưởng phòng / Trưởng ban**: Chỉ có quyền tạo, sửa, xóa, duyệt và tác động đến các lịch trình thuộc phạm vi phòng/ban mình quản lý. Không có quyền can thiệp sang phòng ban khác.
  * **Cán bộ / Giảng viên (User thường)**: Xem lịch công tác toàn trường, lịch của đơn vị mình, và nhận thông báo.

### 1.2. Quản lý Lịch công tác (Schedules Management)
* **Xem lịch công tác**: Hỗ trợ bộ lọc thông minh theo ngày, theo tuần, theo phòng ban hoặc phân loại lịch (Toàn trường, Lịch đơn vị).
* **Tạo mới & Cập nhật**: Cán bộ quản lý nhập liệu lịch công tác chi tiết (Tiêu đề, Người chủ trì, Thời gian, Địa điểm, Phòng ban liên quan, Thành phần tham gia).
* **Duyệt lịch**: Trưởng phòng ban hoặc Admin phê duyệt lịch trình trước khi công bố công khai lên ứng dụng di động.
* **Xóa & Khôi phục**: Hỗ trợ xóa lịch trình cũ hoặc hủy lịch.
* **Gửi thông báo thay đổi**: Khi lịch công tác có sự thay đổi (sửa đổi địa điểm, thời gian hoặc nội dung), hệ thống sẽ gửi thông báo đẩy (Push Notification) đến tất cả thiết bị có liên quan.

### 1.3. Tính năng Trích xuất AI (AI Import Service)
* **Import tài liệu tự động**: Người dùng chỉ cần upload file tài liệu lịch tuần dạng **`.pdf`**, **`.docx`** (Word), hoặc **`.xlsx`** (Excel).
* **Trích xuất thông minh bằng Gemini 2.5 Flash**:
  * Tích hợp Google GenAI SDK để đọc hiểu cấu trúc văn bản.
  * Tự động trích xuất các trường thông tin: Nội dung công việc, Người chủ trì, Địa điểm, Thời gian bắt đầu/kết thúc, Ngày diễn ra.
  * **Thuật toán So khớp Phòng ban**: Nhận diện các từ khóa viết tắt phòng ban được AI tìm thấy trong văn bản (ví dụ: "QLĐT", "HC", "NV1") và tự động đối chiếu, ánh xạ chính xác sang mã UUID của phòng ban đó trong cơ sở dữ liệu.
  * **Cơ chế Parallel Chunking (Xử lý song song)**: Tự động chia nhỏ tệp lịch dài thành các nhóm ngày trong tuần (T2-T3, T4-T5, T6-CN) để gửi song song lên Gemini, giúp giảm thời gian phản hồi từ 3 phút xuống chỉ còn **10 - 15 giây** và khắc phục giới hạn quota API Free Tier.
  * **Lightweight PDF Parser**: Sử dụng thư viện `pdfplumber` gọn nhẹ để trích xuất text PDF cực nhanh, giảm tải CPU và RAM trên máy chủ, chống lỗi timeout kết nối.

### 1.4. Quản lý Phòng ban (Departments)
* **Danh sách đơn vị**: Quản lý thông tin các phòng, khoa, ban trong Học viện.
* **Ánh xạ từ viết tắt**: Định nghĩa các từ viết tắt của phòng ban để phục vụ cho thuật toán đối khớp tự động của AI.

### 1.5. Bộ lập lịch & Dịch vụ gửi thông báo ngầm (Scheduler & Push Notification)
* **Background Scheduler**: Bộ lập lịch ngầm tự động kích hoạt định kỳ mỗi 1 phút trên Server để quét các lịch công tác sắp diễn ra.
* **Firebase Cloud Messaging (FCM)**: Gửi thông báo đẩy tức thì (Push Notification) nhắc nhở lịch họp/lịch làm việc đến thiết bị di động của cán bộ, giảng viên có liên quan.

### 1.6. Tối ưu hóa & Hiệu năng hệ thống
* **Database Connection Pool (Pre-warming)**: Khởi tạo sẵn và giữ các kết nối Database rảnh rỗi trong bộ đệm khi server startup, giúp tăng tốc độ truy vấn cơ sở dữ liệu.
* **Caching**: Lưu trữ bộ đệm (Cache) cho danh sách lịch công tác và danh sách phòng ban, tự động xóa cache để cập nhật dữ liệu mới khi có thay đổi nhằm tối ưu tối đa tốc độ truy xuất của Client và giảm tải cho Database.
* **GZip Compression**: Tự động nén dữ liệu API phản hồi có dung lượng trên 1KB, giúp tiết kiệm băng thông mạng từ 60% đến 80%.

---

## 2. Phân hệ Frontend (Flutter Mobile App)

Ứng dụng di động được xây dựng bằng công nghệ Flutter, mang lại trải nghiệm mượt mà, phản hồi nhanh chóng và giao diện hiện đại.

* **Giao diện Lịch tuần trực quan**: Hiển thị danh sách công việc theo từng ngày trong tuần (từ Thứ Hai đến Chủ Nhật).
* **Đăng nhập & Lưu phiên**: Đăng nhập nhanh bằng tài khoản nội bộ và duy trì phiên đăng nhập bảo mật.
* **Đăng ký nhận thông báo thay đổi**: Tích hợp Firebase Cloud Messaging để nhận thông báo tức thì khi có lịch mới hoặc lịch bị thay đổi phòng họp/thời gian.
* **Tính năng Import tài liệu bằng Camera/Tệp**: Hỗ trợ người dùng chọn file `.pdf`, `.docx`, hoặc `.xlsx` từ bộ nhớ máy hoặc chụp ảnh tài liệu để gửi lên AI trích xuất tự động ngay trên điện thoại.
* **Màn hình duyệt trước lịch trích xuất (Preview)**: Sau khi AI trích xuất xong, ứng dụng hiển thị danh sách lịch dưới dạng bảng trực quan để người dùng kiểm tra, chỉnh sửa thủ công nếu cần trước khi bấm nút xác nhận lưu hàng loạt vào Cơ sở dữ liệu.
* **Phân hệ riêng cho Trưởng phòng/ban**: Giao diện quản lý chuyên biệt hỗ trợ Trưởng đơn vị thêm, sửa, xóa và phê duyệt lịch công tác của phòng ban mình một cách nhanh chóng.
