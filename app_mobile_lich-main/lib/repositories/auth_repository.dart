import '../models/user_profile.dart';

/// [AuthRepository] là một Abstract Class (Interface).
/// Mục đích: Ép buộc các class con (như ApiAuthRepository hay DemoAuthRepository)
/// phải triển khai các phương thức cốt lõi liên quan đến xác thực.
/// Sử dụng interface giúp ta dễ dàng chuyển đổi giữa việc xài Fake Data (Demo) và xài API thật.
abstract class AuthRepository {
  /// Lấy danh sách phòng ban công khai để hiển thị trên form Đăng ký
  Future<List<Map<String, dynamic>>> getPublicDepartments();

  /// Đăng nhập bằng tên đăng nhập và mật khẩu
  Future<UserProfile?> login({
    required String username,
    required String password,
  });

  /// Gửi mã xác nhận quên mật khẩu đến email hoặc sđt
  Future<SendResetCodeResult> sendResetCode({
    required String contact,
  });

  /// Kiểm tra mã OTP do người dùng nhập vào
  Future<VerifyResetCodeResult> verifyResetCode({
    required String contact,
    required String code,
  });

  /// Đặt lại mật khẩu sử dụng token
  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  /// Đăng nhập bằng tài khoản Google
  Future<UserProfile?> googleLogin({
    required String email,
  });

  /// Đăng ký tài khoản mới bằng Google/Gmail
  Future<RegisterResult> register({
    required String email,
    required String fullName,
    required String departmentId,
  });
}

/// [RegisterResult] là lớp chứa kết quả trả về khi người dùng đăng ký tài khoản.
class RegisterResult {
  final bool success;
  final String message;

  const RegisterResult({
    required this.success,
    required this.message,
  });
}

/// [SendResetCodeResult] là lớp chứa kết quả trả về khi người dùng yêu cầu gửi mã OTP.
class SendResetCodeResult {
  /// Cờ xác định thành công hay thất bại
  final bool success;
  
  /// Câu thông báo chi tiết (VD: "Đã gửi mail thành công")
  final String message;
  
  /// Email bị che bớt để đảm bảo quyền riêng tư trên UI (VD: tru***@gmail.com)
  final String? maskedContact;

  /// Mã OTP thật dùng để hiển thị sẵn (Chỉ nên dùng cho môi trường Demo/Test).
  /// Môi trường thật (Production) không bao giờ được trả về biến này.
  final String? debugCode;

  const SendResetCodeResult({
    required this.success,
    required this.message,
    this.maskedContact,
    this.debugCode,
  });
}

/// [VerifyResetCodeResult] là lớp chứa kết quả trả về khi người dùng nhập xong OTP.
class VerifyResetCodeResult {
  /// Thành công hay thất bại
  final bool success;
  
  /// Câu thông báo lỗi nếu mã sai
  final String message;

  /// Chìa khóa tạm thời để cho phép đổi mật khẩu ở bước sau.
  /// Nếu API trả về chuỗi này, nghĩa là mã OTP hợp lệ.
  final String? resetToken;

  const VerifyResetCodeResult({
    required this.success,
    required this.message,
    this.resetToken,
  });
}