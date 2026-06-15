import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

// DemoAuthRepository giả lập backend đăng nhập/quên mật khẩu.
// Sau này bạn thay file này bằng ApiAuthRepository để gọi API thật.
class DemoAuthRepository implements AuthRepository {
  static final List<_DemoAccount> _accounts = [
    _DemoAccount(
      password: '123456',
      user: const UserProfile(
        id: 'u001',
        fullName: 'Thành',
        username: 'thanh',
        role: 'Giảng viên',
        unit: 'Khoa Công nghệ thông tin',
        departmentId: 'cntt',
        departmentName: 'Khoa Công nghệ thông tin',
        email: 'thanh@academy.edu.vn',
        phone: '0123 456 789',
      ),
    ),
    _DemoAccount(
      password: '123456',
      user: const UserProfile(
        id: 'admin001',
        fullName: 'Quản trị hệ thống',
        username: 'admin',
        role: 'Quản trị viên',
        unit: 'Phòng Công nghệ thông tin',
        departmentId: 'phong_cntt',
        departmentName: 'Phòng Công nghệ thông tin',
        email: 'admin@academy.edu.vn',
        phone: '0987 654 321',
      ),
    ),
  ];

  static final Map<String, _ResetSession> _resetSessionsByContact = {};

  static String _passwordKey(String userId) {
    return 'demo_password_$userId';
  }

  @override
  Future<UserProfile?> login({
    required String username,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final inputUsername = username.trim().toLowerCase();
    final inputPassword = password.trim();

    final account = _findAccountByUsername(inputUsername);

    if (account == null) {
      return null;
    }

    final currentPassword = await _getCurrentPassword(account);

    if (inputPassword == currentPassword) {
      return account.user;
    }

    return null;
  }

  @override
  Future<SendResetCodeResult> sendResetCode({
    required String contact,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final normalizedContact = _normalizeContact(contact);

    if (normalizedContact.isEmpty) {
      return const SendResetCodeResult(
        success: false,
        message: 'Vui lòng nhập email hoặc số điện thoại.',
      );
    }

    final account = _findAccountByContact(normalizedContact);

    if (account == null) {
      return const SendResetCodeResult(
        success: false,
        message: 'Không tìm thấy tài khoản phù hợp với thông tin đã nhập.',
      );
    }

    // Demo OTP cố định để dễ test.
    // App thật: backend sẽ sinh mã ngẫu nhiên và gửi SMS/email.
    const demoCode = '123456';

    final session = _ResetSession(
      userId: account.user.id,
      contact: normalizedContact,
      code: demoCode,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    _resetSessionsByContact[normalizedContact] = session;

    return SendResetCodeResult(
      success: true,
      message: 'Mã xác thực đã được gửi.',
      maskedContact: _maskContact(contact),
      debugCode: demoCode,
    );
  }

  @override
  Future<VerifyResetCodeResult> verifyResetCode({
    required String contact,
    required String code,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final normalizedContact = _normalizeContact(contact);
    final inputCode = code.trim();

    final session = _resetSessionsByContact[normalizedContact];

    if (session == null) {
      return const VerifyResetCodeResult(
        success: false,
        message: 'Bạn chưa yêu cầu gửi mã xác thực.',
      );
    }

    if (DateTime.now().isAfter(session.expiresAt)) {
      _resetSessionsByContact.remove(normalizedContact);

      return const VerifyResetCodeResult(
        success: false,
        message: 'Mã xác thực đã hết hạn. Vui lòng gửi lại mã.',
      );
    }

    if (session.code != inputCode) {
      return const VerifyResetCodeResult(
        success: false,
        message: 'Mã xác thực không đúng.',
      );
    }

    final resetToken =
        'reset_${session.userId}_${DateTime.now().millisecondsSinceEpoch}';

    _resetSessionsByContact[normalizedContact] = session.copyWith(
      resetToken: resetToken,
      isVerified: true,
    );

    return VerifyResetCodeResult(
      success: true,
      message: 'Xác thực mã thành công.',
      resetToken: resetToken,
    );
  }

  @override
  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    _ResetSession? matchedSession;
    String? matchedContact;

    for (final entry in _resetSessionsByContact.entries) {
      final session = entry.value;

      if (session.resetToken == resetToken && session.isVerified) {
        matchedSession = session;
        matchedContact = entry.key;
        break;
      }
    }

    if (matchedSession == null || matchedContact == null) {
      return false;
    }

    if (DateTime.now().isAfter(matchedSession.expiresAt)) {
      _resetSessionsByContact.remove(matchedContact);
      return false;
    }

    // Lưu mật khẩu mới vào SharedPreferences để demo vẫn nhớ sau khi chạy lại app.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey(matchedSession.userId), newPassword);

    _resetSessionsByContact.remove(matchedContact);

    return true;
  }

  Future<String> _getCurrentPassword(_DemoAccount account) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_passwordKey(account.user.id)) ?? account.password;
  }

  _DemoAccount? _findAccountByUsername(String username) {
    for (final account in _accounts) {
      if (account.user.username.toLowerCase() == username) {
        return account;
      }
    }

    return null;
  }

  _DemoAccount? _findAccountByContact(String normalizedContact) {
    for (final account in _accounts) {
      final email = _normalizeContact(account.user.email);
      final phone = _normalizeContact(account.user.phone);

      if (email == normalizedContact || phone == normalizedContact) {
        return account;
      }
    }

    return null;
  }

  String _normalizeContact(String value) {
    final text = value.trim().toLowerCase();

    if (text.contains('@')) {
      return text;
    }

    return text.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
  }

  String _maskContact(String value) {
    final text = value.trim();

    if (text.contains('@')) {
      final parts = text.split('@');

      if (parts.length != 2 || parts.first.isEmpty) {
        return text;
      }

      final first = parts.first;
      final domain = parts.last;

      return '${first[0]}***@$domain';
    }

    final digits = text.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');

    if (digits.length <= 3) {
      return text;
    }

    return '*** *** ${digits.substring(digits.length - 3)}';
  }
}

class _DemoAccount {
  final UserProfile user;
  final String password;

  const _DemoAccount({
    required this.user,
    required this.password,
  });
}

class _ResetSession {
  final String userId;
  final String contact;
  final String code;
  final DateTime expiresAt;
  final bool isVerified;
  final String? resetToken;

  const _ResetSession({
    required this.userId,
    required this.contact,
    required this.code,
    required this.expiresAt,
    this.isVerified = false,
    this.resetToken,
  });

  _ResetSession copyWith({
    bool? isVerified,
    String? resetToken,
  }) {
    return _ResetSession(
      userId: userId,
      contact: contact,
      code: code,
      expiresAt: expiresAt,
      isVerified: isVerified ?? this.isVerified,
      resetToken: resetToken ?? this.resetToken,
    );
  }
}