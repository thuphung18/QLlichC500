/// Lớp [CreateUserRequest] đại diện cho payload dữ liệu 
/// được gửi lên API để đăng ký/tạo mới một tài khoản người dùng (thường dùng cho Admin).
class CreateUserRequest {
  /// Tên đăng nhập của người dùng mới
  final String username;
  
  /// Họ và tên đầy đủ
  final String fullName;
  
  /// Vai trò của người dùng (VD: "Admin", "User", "Giảng viên")
  final String role;
  
  /// Đơn vị công tác
  final String unit;
  
  /// ID của phòng ban mà người dùng này trực thuộc
  final String departmentId;
  
  /// Email liên hệ (có thể null nếu không bắt buộc)
  final String? email;
  
  /// Số điện thoại liên hệ (có thể null)
  final String? phone;

  /// Constructor khởi tạo các giá trị. Email và phone là tùy chọn.
  CreateUserRequest({
    required this.username,
    required this.fullName,
    required this.role,
    required this.unit,
    required this.departmentId,
    this.email,
    this.phone,
  });

  /// Hàm chuyển đổi Object thành JSON (Map<String, dynamic>)
  /// dùng để encode thành body của HTTP POST request.
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullName': fullName,
      'role': role,
      'unit': unit,
      'departmentId': departmentId,
      'email': email,
      'phone': phone,
    };
  }
}
