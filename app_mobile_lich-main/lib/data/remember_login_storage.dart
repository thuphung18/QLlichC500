import 'package:shared_preferences/shared_preferences.dart';

/// [RememberLoginStorage] chịu trách nhiệm quản lý việc ghi nhớ tài khoản 
/// trên bộ nhớ cục bộ (Local Storage) của thiết bị điện thoại.
/// Sử dụng thư viện `shared_preferences`.
/// Lưu ý: Ứng dụng thực tế không nên lưu mật khẩu dạng plain text. Nên lưu JWT Token.
class RememberLoginStorage {
  // Các khóa (Key) được định nghĩa sẵn để lưu dữ liệu dưới dạng Key-Value
  static const String _keyRemember = 'remember_login';
  static const String _keyUsername = 'remember_username';
  static const String _keyPassword = 'remember_password';

  /// Khôi phục tài khoản từ bộ nhớ thiết bị.
  /// Gọi hàm này khi mở ứng dụng xem user trước đó có tích "Ghi nhớ đăng nhập" hay không.
  Future<RememberedLogin?> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Kiểm tra xem cờ ghi nhớ có được bật không
    final remember = prefs.getBool(_keyRemember) ?? false;

    if (!remember) {
      return null; // Không bật thì trả về null
    }

    // Lấy thông tin user / pass
    final username = prefs.getString(_keyUsername) ?? '';
    final password = prefs.getString(_keyPassword) ?? '';

    if (username.isEmpty || password.isEmpty) {
      return null;
    }

    return RememberedLogin(
      username: username,
      password: password,
    );
  }

  /// Ghi thông tin đăng nhập vào bộ nhớ điện thoại 
  /// (Được gọi khi người dùng check vào ô "Ghi nhớ" và đăng nhập thành công)
  Future<void> save({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Đặt cờ nhớ là true và ghi username, password
    await prefs.setBool(_keyRemember, true);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyPassword, password);
  }

  /// Xóa thông tin đăng nhập khỏi thiết bị (Được gọi khi người dùng chọn Đăng Xuất)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    // Đặt cờ nhớ về false và xóa dữ liệu text
    await prefs.setBool(_keyRemember, false);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
  }
}

/// Lớp [RememberedLogin] đóng gói kết quả trả về cho hàm load()
class RememberedLogin {
  final String username;
  final String password;

  const RememberedLogin({
    required this.username,
    required this.password,
  });
}