/// Lớp [UpdateProfileRequest] đại diện cho payload
/// gửi lên API khi người dùng muốn cập nhật thông tin cá nhân.
class UpdateProfileRequest {
  /// Họ và tên mới
  final String fullName;
  
  /// Email mới (nếu có)
  final String? email;
  
  /// Số điện thoại mới (nếu có)
  final String? phone;

  /// Constructor
  UpdateProfileRequest({
    required this.fullName,
    this.email,
    this.phone,
  });

  /// Hàm parse ra JSON map
  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
    };
  }
}
