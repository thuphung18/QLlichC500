import '../models/schedule_item.dart';
import '../models/user_profile.dart';
import '../models/create_schedule_request.dart';
import '../models/form_data_response.dart';

/// [ScheduleRepository] là một Abstract Class (Interface).
/// Định nghĩa tất cả các thao tác liên quan đến Lịch biểu (Schedule).
/// Cấu trúc này giúp phân tách UI ra khỏi Data. UI chỉ cần gọi hàm, 
/// không cần biết nó đang gọi Fake Data (Demo) hay API thật.
abstract class ScheduleRepository {
  /// Thông tin người dùng hiện tại đang đăng nhập
  UserProfile get currentUser;

  /// Lấy tất cả lịch biểu
  Future<List<ScheduleItem>> getAllSchedules();

  /// Lấy danh sách lịch biểu thuộc về một ngày cụ thể (Ví dụ: Thứ 2 = 2)
  Future<List<ScheduleItem>> getSchedulesByDay(int dayIndex);

  /// Lấy danh sách lịch của CHÍNH người dùng (Lịch cá nhân)
  Future<List<ScheduleItem>> getMySchedules();

  /// Lấy danh sách lịch của khoa/phòng ban mà người dùng trực thuộc
  Future<List<ScheduleItem>> getDepartmentSchedules();

  /// Tìm kiếm lịch biểu bằng một chuỗi từ khóa
  Future<List<ScheduleItem>> searchSchedules(String keyword);

  /// Tải dữ liệu để fill vào các form dropdown (Tạo lịch biểu)
  Future<FormDataResponse> getFormData();

  /// Đẩy dữ liệu lên server để khởi tạo một lịch biểu mới
  Future<bool> createSchedule(CreateScheduleRequest request);

  /// Gửi lệnh xóa lịch biểu (Chỉ dành cho người tạo hoặc admin)
  Future<bool> deleteSchedule(String scheduleId);

  /// Xóa toàn bộ lịch (Admin xóa hết, Trưởng khoa xóa phòng/khoa của mình)
  Future<bool> clearAllSchedules();

  /// Đăng xuất, dọn dẹp data
}