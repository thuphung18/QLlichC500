/// Lớp [UpdatePasswordRequest] đại diện cho payload
/// gửi lên API để đổi mật khẩu (khi người dùng đã đăng nhập và vào Cài đặt).
class UpdatePasswordRequest {
  /// Mật khẩu cũ hiện tại (dùng để backend xác thực bảo mật)
  final String oldPassword;
  
  /// Mật khẩu mới muốn thay đổi
  final String newPassword;

  /// Constructor khởi tạo
  UpdatePasswordRequest({
    required this.oldPassword,
    required this.newPassword,
  });

  /// Hàm [toJson] để biến object thành JSON map
  Map<String, dynamic> toJson() {
    return {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    };
  }
}
