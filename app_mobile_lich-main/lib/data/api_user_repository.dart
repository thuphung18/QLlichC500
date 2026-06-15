import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../models/create_user_request.dart';
import '../models/update_profile_request.dart';
import '../models/update_password_request.dart';
import '../models/user_profile.dart';

/// Lớp [ApiUserRepository] chịu trách nhiệm quản lý các API liên quan đến thao tác người dùng (Cập nhật, Tạo mới).
class ApiUserRepository {
  // Lấy địa chỉ IP máy chủ (Backend) từ cấu hình chung
  final String _baseUrl = ApiConfig.baseUrl;

  /// Gửi yêu cầu (HTTP POST) lên Backend để tạo một tài khoản mới.
  /// Đầu vào: Biến [request] chứa tất cả thông tin user đã nhập từ Form.
  /// Đầu ra: Trả về `true` nếu server báo tạo thành công, ngược lại trả về `false`.
  Future<bool> createUser(CreateUserRequest request) async {
    try {
      // Gửi request POST tới đường dẫn /api/users/
      final response = await http.post(
        Uri.parse('$_baseUrl/users/'),
        // Chỉ định loại dữ liệu gửi đi là JSON
        headers: {'Content-Type': 'application/json'},
        // Chuyển đổi object Dart sang chuỗi JSON
        body: jsonEncode(request.toJson()),
      );

      // 200 OK: Nghĩa là Backend đã xử lý lưu DB thành công
      if (response.statusCode == 200) {
        return true;
      } else {
        // Thất bại có thể do validation (400) hoặc lỗi server (500)
        print('Create user failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      // Bắt các lỗi văng ra do mất mạng lưới, server sập...
      print('Create user error: $e');
      return false;
    }
  }

  /// Cập nhật thông tin hồ sơ cá nhân (Họ tên, SĐT, Email).
  /// Trả về đối tượng [UserProfile] mới đã được cập nhật nếu thành công.
  Future<UserProfile?> updateProfile(String userId, UpdateProfileRequest request) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      } else {
        print('Update profile failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  /// Cập nhật mật khẩu mới khi người dùng đổi mật khẩu trong phần cài đặt tài khoản.
  Future<bool> updatePassword(String userId, UpdatePasswordRequest request) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Update password failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Update password error: $e');
      return false;
    }
  }
}
