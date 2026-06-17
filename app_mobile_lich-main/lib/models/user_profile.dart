/// Model [UserProfile] mô tả chi tiết thông tin người dùng đang đăng nhập.
/// Dữ liệu này thường được lấy về từ API Login hoặc API GetProfile.
class UserProfile {
  /// Mã định danh người dùng (UUID hoặc ID tự tăng)
  final String id;
  
  /// Họ và tên hiển thị
  final String fullName;
  
  /// Tên đăng nhập
  final String username;
  
  /// Vai trò của người dùng trong hệ thống (VD: Admin, Giảng viên)
  final String role;
  
  /// Đơn vị trực thuộc
  final String unit;
  
  /// ID của khoa/phòng ban
  final String departmentId;
  
  /// Tên đầy đủ của khoa/phòng ban
  final String departmentName;
  
  /// Địa chỉ email liên lạc
  final String email;
  
  /// Số điện thoại liên lạc
  final String phone;

  /// Token phiên đăng nhập hiện tại
  final String? sessionToken;

  /// Constructor
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    required this.unit,
    required this.departmentId,
    required this.departmentName,
    required this.email,
    required this.phone,
    this.sessionToken,
  });

  /// Hàm [fromJson] dùng để khởi tạo một Object [UserProfile] 
  /// từ chuỗi JSON (Map) do Backend trả về.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      departmentId: json['departmentId']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      sessionToken: json['sessionToken']?.toString(),
    );
  }
}