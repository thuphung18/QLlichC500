/// [RoleHelper] - Lớp tiện ích để chuẩn hóa việc kiểm tra vai trò người dùng.
/// Tất cả logic phân quyền trong UI đều đi qua đây để tránh hardcode rải rác.
class RoleHelper {
  /// Kiểm tra người dùng có phải là Quản trị viên (Admin) không.
  static bool isAdmin(String role) {
    final r = role.toLowerCase().trim();
    return r == 'admin' || r == 'quản trị viên';
  }

  /// Kiểm tra người dùng có phải là Trưởng phòng (Manager) hoặc Trưởng khoa không.
  static bool isManager(String role) {
    final r = role.toLowerCase().trim();
    return r == 'manager' || r == 'trưởng phòng' || r == 'trưởng khoa';
  }

  /// Kiểm tra người dùng có quyền tạo / xóa lịch không.
  /// Cả Admin và Manager đều có quyền này.
  static bool canManageSchedule(String role) {
    return isAdmin(role) || isManager(role);
  }

  /// Lấy nhãn hiển thị thân thiện theo role.
  static String getDisplayLabel(String role) {
    if (isAdmin(role)) return 'Quản trị viên';
    final r = role.toLowerCase().trim();
    if (r == 'trưởng khoa') return 'Trưởng khoa';
    if (isManager(role)) return 'Trưởng phòng';
    return 'Nhân viên';
  }

  /// Danh sách các role có thể chọn khi Admin tạo / sửa tài khoản.
  static const List<String> availableRoles = [
    'Nhân viên',
    'Trưởng phòng',
    'Quản trị viên',
  ];
}
