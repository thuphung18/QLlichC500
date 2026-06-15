import 'department.dart';
import 'user_compact.dart';

/// Lớp [FormDataResponse] đại diện cho kết quả trả về từ API 
/// khi ứng dụng yêu cầu dữ liệu khởi tạo (form data) để hiển thị các dropdown (chọn phòng ban, chọn người tham gia).
class FormDataResponse {
  /// Danh sách các phòng ban (Departments) có trong hệ thống
  final List<Department> departments;
  
  /// Danh sách rút gọn của người dùng (dùng để chọn người tham gia)
  final List<UserCompact> users;

  /// Constructor khởi tạo
  const FormDataResponse({
    required this.departments,
    required this.users,
  });

  /// Factory chuyển đổi dữ liệu JSON tổng hợp từ API 
  /// thành một đối tượng FormDataResponse chứa các List cụ thể.
  factory FormDataResponse.fromJson(Map<String, dynamic> json) {
    // Ép kiểu an toàn (Safe parsing) để tránh lỗi null
    var deptList = json['departments'] as List? ?? [];
    var userList = json['users'] as List? ?? [];

    return FormDataResponse(
      // Map từng phần tử JSON thành object Department và chuyển lại thành List
      departments: deptList.map((d) => Department.fromJson(d)).toList(),
      
      // Map từng phần tử JSON thành object UserCompact và chuyển lại thành List
      users: userList.map((u) => UserCompact.fromJson(u)).toList(),
    );
  }
}
