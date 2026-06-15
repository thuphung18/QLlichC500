/// Lớp [UserCompact] chứa thông tin tóm tắt cơ bản của một người dùng.
/// Thông thường được dùng cho các Dropdown hoặc danh sách chọn người tham gia
/// thay vì lấy toàn bộ Profile nặng nề.
class UserCompact {
  /// ID của người dùng
  final String id;
  
  /// Họ tên để hiển thị
  final String fullName;
  
  /// ID phòng ban (dùng để phân loại/lọc danh sách theo khoa)
  final String departmentId;

  /// Constructor mặc định
  const UserCompact({
    required this.id,
    required this.fullName,
    required this.departmentId,
  });

  /// Hàm khởi tạo [UserCompact] từ cấu trúc dữ liệu JSON trả về bởi API.
  factory UserCompact.fromJson(Map<String, dynamic> json) {
    return UserCompact(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      departmentId: json['departmentId']?.toString() ?? '',
    );
  }
}
