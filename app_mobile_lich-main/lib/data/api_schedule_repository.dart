import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'http_client.dart';

import '../models/user_profile.dart';
import '../models/schedule_item.dart';
import '../models/create_schedule_request.dart';
import '../models/form_data_response.dart';
import '../models/form_data_response.dart';
import '../repositories/schedule_repository.dart';
import '../utils/event_bus.dart';
import 'api_config.dart';

/// Lớp [ApiScheduleRepository] đóng vai trò lấy/gửi dữ liệu lịch trình từ/đến Backend API.
/// Kế thừa từ interface [ScheduleRepository].
class ApiScheduleRepository implements ScheduleRepository {
  final String _baseUrl = ApiConfig.baseUrl;
  
  /// Người dùng hiện tại (cần thiết để gửi kèm user_id cho mỗi request API)
  @override
  final UserProfile currentUser;

  ApiScheduleRepository({required this.currentUser});

  /// Hàm phụ trợ (helper) dùng chung để lấy một danh sách lịch từ URL cụ thể.
  Future<List<ScheduleItem>> _fetchSchedules(String url) async {
    try {
      final response = await HttpClient.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${currentUser.sessionToken}'},
      );

      if (response.statusCode == 200) {
        // Giải mã JSON thành List dynamic
        final List<dynamic> data = jsonDecode(response.body);
        // Duyệt qua từng phần tử và parse thành đối tượng ScheduleItem
        return data.map((json) => ScheduleItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Fetch error: $e');
      return []; // Nếu lỗi thì trả về danh sách rỗng để không bị crash UI
    }
  }

  /// Lấy toàn bộ lịch (phù hợp với quyền của người dùng)
  @override
  Future<List<ScheduleItem>> getAllSchedules() async {
    return _fetchSchedules('$_baseUrl/schedules?user_id=${currentUser.id}');
  }

  /// Lấy lịch theo một thứ cụ thể trong tuần (dayIndex: 2 -> thứ 2, ...)
  @override
  Future<List<ScheduleItem>> getSchedulesByDay(int dayIndex) async {
    return _fetchSchedules('$_baseUrl/schedules/day/$dayIndex?user_id=${currentUser.id}');
  }

  /// Chỉ lấy những lịch mà chính người dùng này tham gia (Lịch cá nhân)
  @override
  Future<List<ScheduleItem>> getMySchedules() async {
    return _fetchSchedules('$_baseUrl/schedules/my?user_id=${currentUser.id}');
  }

  /// Chỉ lấy lịch của khoa/phòng ban mà người dùng đang trực thuộc
  @override
  Future<List<ScheduleItem>> getDepartmentSchedules() async {
    return _fetchSchedules('$_baseUrl/schedules/department?user_id=${currentUser.id}');
  }

  /// Cập nhật FCM Token (Dùng cho chức năng Firebase Cloud Messaging - Gửi thông báo đẩy)
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${currentUser.sessionToken}'
        },
        body: jsonEncode({
          'user_id': currentUser.id,
          'fcm_token': fcmToken,
        }),
      );
      if (response.statusCode == 200) {
        print('FCM token updated successfully');
      } else {
        print('Failed to update FCM token: ${response.body}');
      }
    } catch (e) {
      print('Update FCM token error: $e');
    }
  }

  /// Tìm kiếm lịch theo từ khóa
  @override
  Future<List<ScheduleItem>> searchSchedules(String keyword) async {
    // encodeComponent để đảm bảo từ khóa có dấu tiếng Việt không làm gãy URL
    return _fetchSchedules('$_baseUrl/schedules/search?keyword=${Uri.encodeComponent(keyword)}&user_id=${currentUser.id}');
  }

  /// Lấy dữ liệu danh mục ban đầu (các khoa, danh sách người dùng)
  /// Backend áp dụng RBAC: Manager chỉ nhận users phòng mình, Admin nhận tất cả.
  @override
  Future<FormDataResponse> getFormData() async {
    try {
      final response = await HttpClient.get(
        Uri.parse('$_baseUrl/schedules/metadata/form-data?user_id=${currentUser.id}'),
        headers: {'Authorization': 'Bearer ${currentUser.sessionToken}'},
      );
      if (response.statusCode == 200) {
        return FormDataResponse.fromJson(jsonDecode(response.body));
      }
      throw Exception('Failed to load form data');
    } catch (e) {
      print('Fetch form data error: $e');
      rethrow;
    }
  }

  /// Gọi API để tạo một lịch biểu mới
  @override
  Future<bool> createSchedule(CreateScheduleRequest request) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/schedules?user_id=${currentUser.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${currentUser.sessionToken}'
        },
        body: jsonEncode(request.toJson()),
      );
      
      // Thành công khi HTTP code là 200 hoặc 201 (Created)
      if (response.statusCode == 200 || response.statusCode == 201) {
        EventBus().fireScheduleDeleted('new'); // Trigger a reload
        return true;
      }
      print('Create schedule failed: ${response.body}');
      return false;
    } catch (e) {
      print('Create schedule error: $e');
      return false;
    }
  }

  /// Gọi API để xóa một lịch biểu dựa trên scheduleId
  @override
  Future<bool> deleteSchedule(String scheduleId) async {
    try {
      final response = await HttpClient.delete(
        Uri.parse('$_baseUrl/schedules/$scheduleId?user_id=${currentUser.id}'),
        headers: {'Authorization': 'Bearer ${currentUser.sessionToken}'},
      );
      
      // Thành công khi HTTP code là 200 hoặc 204 (No Content)
      if (response.statusCode == 200 || response.statusCode == 204) {
        EventBus().fireScheduleDeleted(scheduleId);
        return true;
      }
      print('Delete schedule failed: ${response.body}');
      return false;
    } catch (e) {
      print('Delete schedule error: $e');
      return false;
    }
  }
  /// Tải file mềm (PDF) lên để AI đọc và trả về danh sách lịch preview
  Future<List<CreateScheduleRequest>> uploadScheduleFile(String filePath) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/schedules/import'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      // HttpClient.dart của ta chưa có wrapper cho Multipart, nên phải tự lấy token
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final List<dynamic> data = jsonDecode(responseData);
        return data.map((json) => CreateScheduleRequest.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Upload schedule error: $e');
      return [];
    }
  }

  /// Tải file bằng bytes (Dành cho nền tảng Web)
  Future<List<CreateScheduleRequest>> uploadScheduleFileBytes(List<int> bytes, String fileName) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/schedules/import'));
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final List<dynamic> data = jsonDecode(responseData);
        return data.map((json) => CreateScheduleRequest.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Upload schedule error bytes: $e');
      return [];
    }
  }

  /// Bulk insert schedules
  Future<bool> bulkCreateSchedules(List<CreateScheduleRequest> schedules) async {
    try {
      final response = await HttpClient.post(
        Uri.parse('$_baseUrl/schedules/bulk?user_id=${currentUser.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(schedules.map((s) => s.toJson()).toList()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Bulk create schedule error: $e');
      return false;
    }
  }
}
