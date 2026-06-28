import 'dart:convert';
import 'http_client.dart';

import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import 'api_config.dart';
import 'token_storage.dart';

/// Lớp [ApiAuthRepository] triển khai (implements) interface [AuthRepository].
/// Chịu trách nhiệm giao tiếp trực tiếp với Backend (API) cho các nghiệp vụ:
/// Đăng nhập, Gửi mã OTP, Xác nhận OTP và Đặt lại mật khẩu.
class ApiAuthRepository implements AuthRepository {
  /// Lấy đường dẫn API gốc từ file cấu hình
  final String _baseUrl = ApiConfig.baseUrl;

  @override
  Future<List<Map<String, dynamic>>> getPublicDepartments() async {
    try {
      final response = await HttpClient.get(
        Uri.parse('$_baseUrl/departments/public'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      print('getPublicDepartments error: $e');
      return [];
    }
  }

  /// Gọi API POST để đăng nhập hệ thống.
  /// Nếu đăng nhập thành công, trả về đối tượng [UserProfile] chứa thông tin user.
  /// Nếu thất bại hoặc sai mật khẩu, trả về `null`.
  @override
  Future<UserProfile?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        // Mã hóa Map thành chuỗi JSON
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      // 200 OK: Đăng nhập thành công
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Lưu access token và refresh token
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await TokenStorage.saveTokens(accessToken, refreshToken);
        }
        
        // Trích xuất phần 'user' trong JSON trả về và parse thành UserProfile
        final userJson = Map<String, dynamic>.from(data['user']);
        userJson['sessionToken'] = accessToken;
        return UserProfile.fromJson(userJson);
      }
      return null;
    } catch (e) {
      print('Login error: $e'); // In lỗi ra console để debug
      return null;
    }
  }

  /// Gọi API POST để gửi mã xác nhận (OTP) về email của người dùng khi họ báo quên mật khẩu.
  @override
  Future<SendResetCodeResult> sendResetCode({
    required String contact, // Email hoặc số điện thoại
  }) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/auth/forgot-password/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact': contact,
        }),
      );

      final data = jsonDecode(response.body);
      // Đóng gói dữ liệu JSON thành đối tượng SendResetCodeResult để UI dễ xử lý
      return SendResetCodeResult(
        success: data['success'] ?? false,
        message: data['message'] ?? 'Có lỗi xảy ra',
        maskedContact: data['maskedContact'], // Email đã che bớt (***)
        debugCode: data['debugCode'],
      );
    } catch (e) {
      return SendResetCodeResult(
        success: false,
        message: 'Lỗi kết nối: $e',
      );
    }
  }

  /// Gọi API POST để xác thực mã OTP mà người dùng nhập vào.
  @override
  Future<VerifyResetCodeResult> verifyResetCode({
    required String contact,
    required String code, // Mã OTP 6 số
  }) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/auth/forgot-password/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact': contact,
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);
      return VerifyResetCodeResult(
        success: data['success'] ?? false,
        message: data['message'] ?? 'Có lỗi xảy ra',
        // Nếu xác thực thành công, API sẽ trả về resetToken dùng cho bước sau
        resetToken: data['resetToken'], 
      );
    } catch (e) {
      return VerifyResetCodeResult(
        success: false,
        message: 'Lỗi kết nối: $e',
      );
    }
  }

  /// Gọi API POST để thiết lập mật khẩu mới sử dụng resetToken đã được xác thực.
  @override
  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/auth/forgot-password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resetToken': resetToken,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      // Trả về true nếu success là true
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Đăng nhập bằng tài khoản Google thông qua Backend API
  @override
  Future<UserProfile?> googleLogin({
    required String email,
  }) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      // 200 OK: Đăng nhập thành công
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await TokenStorage.saveTokens(accessToken, refreshToken);
        }
        
        final userJson = Map<String, dynamic>.from(data['user']);
        userJson['sessionToken'] = accessToken;
        return UserProfile.fromJson(userJson);
      }
      
      // Các mã lỗi như 403 (chưa duyệt) hoặc 404 (chưa đăng ký) sẽ được UI bắt qua throw ngoại lệ
      if (response.statusCode == 403 || response.statusCode == 404) {
         final errorData = jsonDecode(response.body);
         throw Exception(errorData['detail'] ?? 'Lỗi đăng nhập Google');
      }
      return null;
    } catch (e) {
      print('Google login error: $e');
      rethrow; // Bắn lỗi lên trên để UI xử lý (hiển thị Dialog)
    }
  }

  /// Gọi API POST để đăng ký tài khoản mới bằng Google/Gmail
  @override
  Future<RegisterResult> register({
    required String email,
    required String fullName,
    required String departmentId,
  }) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'fullName': fullName,
          'departmentId': departmentId,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return RegisterResult(
          success: data['success'] ?? false,
          message: data['message'] ?? 'Đăng ký thành công',
        );
      } else {
        return RegisterResult(
          success: false,
          message: data['detail'] ?? 'Đăng ký thất bại',
        );
      }
    } catch (e) {
      return RegisterResult(
        success: false,
        message: 'Lỗi kết nối: $e',
      );
    }
  }
}
