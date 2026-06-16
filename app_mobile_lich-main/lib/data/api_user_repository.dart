import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../models/create_user_request.dart';
import '../models/update_profile_request.dart';
import '../models/update_password_request.dart';
import '../models/user_profile.dart';

/// [UserDetail] - Model dùng trong trang quản trị Admin.
class UserDetail {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String unit;
  final String departmentId;
  final String departmentName;
  final String email;
  final String phone;
  final bool isActive;

  const UserDetail({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.unit,
    required this.departmentId,
    required this.departmentName,
    required this.email,
    required this.phone,
    required this.isActive,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      departmentId: json['departmentId']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isActive: json['isActive'] == true,
    );
  }
}

/// [AdminUpdateUserRequest] - Model gửi lên API khi Admin chỉnh sửa user.
class AdminUpdateUserRequest {
  final String fullName;
  final String role;
  final String unit;
  final String departmentId;
  final String? email;
  final String? phone;
  final bool isActive;

  const AdminUpdateUserRequest({
    required this.fullName,
    required this.role,
    required this.unit,
    required this.departmentId,
    this.email,
    this.phone,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'role': role,
    'unit': unit,
    'departmentId': departmentId,
    'email': email,
    'phone': phone,
    'isActive': isActive,
  };
}

/// [DepartmentRequest] - Model cho thao tác tạo / đổi tên phòng ban.
class DepartmentRequest {
  final String name;
  const DepartmentRequest({required this.name});
}

/// [ApiUserRepository] chịu trách nhiệm quản lý các API liên quan đến thao tác người dùng.
class ApiUserRepository {
  final String _baseUrl = ApiConfig.baseUrl;

  // ==================== ADMIN: Quản lý tài khoản ====================

  /// Admin lấy danh sách tất cả người dùng.
  Future<List<UserDetail>> getAllUsers(String adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/?admin_id=$adminId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => UserDetail.fromJson(json)).toList();
      }
      print('Get all users failed: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      print('Get all users error: $e');
      return [];
    }
  }

  /// Admin tạo tài khoản mới.
  Future<bool> createUser(CreateUserRequest request, String adminId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200) return true;
      print('Create user failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Create user error: $e');
      return false;
    }
  }

  /// Admin cập nhật thông tin, role, phòng ban, trạng thái tài khoản user.
  Future<bool> adminUpdateUser(
    String targetUserId,
    AdminUpdateUserRequest request,
    String adminId,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$targetUserId/admin?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200) return true;
      print('Admin update user failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Admin update user error: $e');
      return false;
    }
  }

  /// Admin xóa tài khoản người dùng.
  Future<bool> deleteUser(String targetUserId, String adminId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/$targetUserId?admin_id=$adminId'),
      );
      if (response.statusCode == 200) return true;
      print('Delete user failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Delete user error: $e');
      return false;
    }
  }

  // ==================== ADMIN: Quản lý phòng ban ====================

  /// Admin lấy danh sách phòng ban.
  Future<List<Map<String, String>>> getDepartments(String adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/departments?user_id=$adminId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map<Map<String, String>>((json) => {
          'id': json['id']?.toString() ?? '',
          'name': json['name']?.toString() ?? '',
        }).toList();
      }
      return [];
    } catch (e) {
      print('Get departments error: $e');
      return [];
    }
  }

  /// Admin tạo phòng ban mới.
  Future<bool> createDepartment(String name, String adminId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/departments?name=${Uri.encodeComponent(name)}&user_id=$adminId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Create department error: $e');
      return false;
    }
  }

  /// Admin đổi tên phòng ban.
  Future<bool> updateDepartment(String deptId, String name, String adminId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/departments/$deptId?name=${Uri.encodeComponent(name)}&user_id=$adminId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update department error: $e');
      return false;
    }
  }

  /// Admin xóa phòng ban.
  Future<String?> deleteDepartment(String deptId, String adminId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/departments/$deptId?user_id=$adminId'),
      );
      if (response.statusCode == 200) return null; // Thành công
      final body = jsonDecode(response.body);
      return body['detail']?.toString() ?? 'Lỗi không xác định';
    } catch (e) {
      return 'Lỗi kết nối: $e';
    }
  }

  // ==================== Tự cập nhật hồ sơ / mật khẩu ====================

  /// Người dùng tự cập nhật thông tin hồ sơ cá nhân.
  Future<UserProfile?> updateProfile(String userId, UpdateProfileRequest request) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      print('Update profile failed: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  /// Người dùng tự đổi mật khẩu.
  Future<bool> updatePassword(String userId, UpdatePasswordRequest request) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200) return true;
      print('Update password failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Update password error: $e');
      return false;
    }
  }
}
