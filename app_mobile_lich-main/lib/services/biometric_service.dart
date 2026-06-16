import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [BiometricService] quản lý xác thực sinh trắc học (vân tay / Face ID)
/// và lưu trữ thông tin đăng nhập được mã hóa an toàn trên thiết bị.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyBiometricEnabled = 'biometric_enabled_flag';
  static const String _secureKeyUsername = 'biometric_username';
  static const String _secureKeyPassword = 'biometric_password';

  // Android & iOS options dùng cho lưu trữ bảo mật sinh trắc học nâng cao
  static const _androidOptions = AndroidOptions(
    resetOnError: true,
    enforceBiometrics: true, // Kích hoạt cơ chế xác thực Keystore vân tay (tự động invalidate khi đổi vân tay trên một số dòng máy)
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    accessControlFlags: [AccessControlFlag.biometryCurrentSet], // Tự động vô hiệu hóa nếu cơ sở dữ liệu Face ID / vân tay thay đổi
  );

  /// Kiểm tra xem thiết bị có hỗ trợ phần cứng sinh trắc học hay không
  Future<bool> isDeviceSupported() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (e) {
      print('Check device supported error: $e');
      return false;
    }
  }

  /// Kiểm tra xem người dùng đã cài vân tay hoặc nhận diện khuôn mặt trong máy chưa
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      print('Check enrolled biometrics error: $e');
      return false;
    }
  }

  /// Kích hoạt hộp thoại quét vân tay hoặc khuôn mặt của hệ điều hành
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Vui lòng xác thực vân tay hoặc nhận diện khuôn mặt để tiếp tục',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Authentication biometric error: $e');
      return false;
    }
  }

  /// Kiểm tra xem người dùng đã bật cài đặt sinh trắc học trong App chưa
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Lưu trạng thái bật/tắt cài đặt sinh trắc học
  Future<void> _setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  /// Lưu trữ bảo mật tài khoản/mật khẩu khi người dùng bật sinh trắc học
  Future<void> saveCredentials(String username, String password) async {
    await _secureStorage.write(
      key: _secureKeyUsername,
      value: username.trim(),
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    await _secureStorage.write(
      key: _secureKeyPassword,
      value: password.trim(),
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    await _setBiometricEnabled(true);
  }

  /// Đọc tài khoản/mật khẩu từ vùng nhớ bảo mật.
  /// Nếu người dùng có thay đổi về danh sách vân tay/khuôn mặt, hệ thống sẽ ném ra ngoại lệ.
  Future<Map<String, String>?> getCredentials() async {
    try {
      final username = await _secureStorage.read(
        key: _secureKeyUsername,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      final password = await _secureStorage.read(
        key: _secureKeyPassword,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      if (username != null && password != null) {
        return {
          'username': username,
          'password': password,
        };
      }
      return null;
    } catch (e) {
      print('Error reading credentials (biometrics database changed): $e');
      // Tự động xóa credentials cũ đã bị hỏng/vô hiệu hóa
      await clearCredentials();
      // Ném ra Exception đặc biệt để UI thông báo cho người dùng
      throw BiometricChangedException();
    }
  }

  /// Xóa thông tin đã lưu trữ bảo mật khi tắt cài đặt sinh trắc học hoặc khi đăng xuất
  Future<void> clearCredentials() async {
    await _secureStorage.delete(
      key: _secureKeyUsername,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    await _secureStorage.delete(
      key: _secureKeyPassword,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    await _setBiometricEnabled(false);
  }
}

/// Ngoại lệ ném ra khi cơ sở dữ liệu sinh trắc học trên thiết bị bị thay đổi
class BiometricChangedException implements Exception {
  final String message = 'Cơ sở dữ liệu vân tay/Face ID trên thiết bị đã thay đổi.';
  @override
  String toString() => message;
}
