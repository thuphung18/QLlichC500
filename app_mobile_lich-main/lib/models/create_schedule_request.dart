/// Lớp [CreateScheduleRequest] đại diện cho mô hình dữ liệu (payload)
/// được gửi lên server (API) khi người dùng muốn tạo một lịch biểu mới.
class CreateScheduleRequest {
  /// Tiêu đề của lịch biểu (VD: "Họp giao ban")
  final String title;
  
  /// Tên giáo viên hoặc người phụ trách
  final String teacher;
  
  /// Phòng học hoặc địa điểm diễn ra
  final String room;
  
  /// Ngày diễn ra lịch biểu theo định dạng YYYY-MM-DD
  final String scheduleDate; 
  
  /// Thời gian bắt đầu theo định dạng HH:MM
  final String startTime;    
  
  /// Thời gian kết thúc theo định dạng HH:MM
  final String endTime;      
  
  /// Ghi chú thêm cho lịch biểu (có thể null)
  final String? note;
  
  /// Đơn vị tổ chức hoặc khoa/phòng ban
  final String unit;
  
  /// Mã định danh (ID) của phòng ban tổ chức
  final String departmentId;
  
  /// Thể loại của lịch biểu (VD: "Học tập", "Họp hành")
  final String category;
  
  /// Danh sách ID của những người tham gia (được chọn từ danh sách người dùng)
  final List<String> participantUserIds;

  /// Constructor yêu cầu các thông tin bắt buộc và cho phép [note] là tùy chọn.
  CreateScheduleRequest({
    required this.title,
    required this.teacher,
    required this.room,
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    this.note,
    required this.unit,
    required this.departmentId,
    required this.category,
    required this.participantUserIds,
  });

  /// Hàm [toJson] dùng để chuyển đổi đối tượng Dart này thành một Map (JSON)
  /// để dễ dàng gửi body qua giao thức HTTP (POST request).
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'teacher': teacher,
      'room': room,
      'scheduleDate': scheduleDate,
      'startTime': startTime,
      'endTime': endTime,
      'note': note,
      'unit': unit,
      'departmentId': departmentId,
      'category': category,
      'participantUserIds': participantUserIds,
    };
  }
}
