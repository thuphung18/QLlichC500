import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/api_auth_repository.dart';
import '../data/api_schedule_repository.dart';
import '../data/remember_login_storage.dart';
import '../data/token_storage.dart';
import '../data/api_config.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import 'forgot_password_screen.dart';
import 'main_shell.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart';

// LoginScreen là màn hình đăng nhập đầu tiên của app.
// Chức năng:
// 1. Nhập tên đăng nhập.
// 2. Nhập mật khẩu.
// 3. Ghi nhớ tài khoản/mật khẩu nếu người dùng tick.
// 4. Chuyển sang màn chính nếu đăng nhập đúng.
// 5. Chuyển sang màn quên mật khẩu nếu bấm "Quên mật khẩu?".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Dùng AuthRepository để sau này dễ thay DemoAuthRepository bằng ApiAuthRepository.
  final AuthRepository _authRepository = ApiAuthRepository();

  // Storage dùng để lưu tài khoản/mật khẩu khi tick "Ghi nhớ".
  final RememberLoginStorage _rememberStorage = RememberLoginStorage();
  final BiometricService _biometricService = BiometricService();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _isBiometricConfigured = false;

  @override
  void initState() {
    super.initState();

    // Khi mở app, tự kiểm tra trước đó có lưu tài khoản không.
    _loadRememberedLogin();
    _checkBiometricConfigured();
  }

  Future<void> _checkBiometricConfigured() async {
    final supported = await _biometricService.isDeviceSupported();
    final enabled = await _biometricService.isBiometricEnabled();
    if (supported && enabled) {
      setState(() {
        _isBiometricConfigured = true;
      });
    }
  }

  Future<void> _loadRememberedLogin() async {
    final rememberedLogin = await _rememberStorage.load();

    if (!mounted) return;

    if (rememberedLogin != null) {
      setState(() {
        _rememberMe = true;
        _usernameController.text = rememberedLogin.username;
        _passwordController.text = rememberedLogin.password;
      });
      // Tự động đăng nhập
      _login();
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final authenticated = await _biometricService.authenticate();
    if (!authenticated) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Xác thực sinh trắc học không thành công.';
      });
      return;
    }

    // Sau khi xác thực sinh trắc học, dùng Refresh Token để lấy Access Token mới
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập bằng mật khẩu.';
      });
      return;
    }

    UserProfile? user;
    try {
      // Gọi trực tiếp http.post để không bị vướng logic tự refresh của HttpClient
      final refreshResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (refreshResponse.statusCode == 200) {
        final data = jsonDecode(refreshResponse.body);
        await TokenStorage.saveTokens(data['access_token'], data['refresh_token']);
        final userJson = Map<String, dynamic>.from(data['user']);
        userJson['sessionToken'] = data['access_token'];
        user = UserProfile.fromJson(userJson);
      }
    } catch (e) {
      print('Biometric login error: $e');
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (user == null) {
      setState(() {
        _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập bằng mật khẩu.';
      });
      return;
    }

    // Yêu cầu quyền thông báo và lấy FCM Token
    if (!kIsWeb) {
      try {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          String? token = await messaging.getToken();
          if (token != null) {
            final scheduleRepo = ApiScheduleRepository(currentUser: user);
            await scheduleRepo.updateFcmToken(token);
          }
        }
      } catch (e) {
        print('Firebase Messaging init error: $e');
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainShell(
          currentUser: user!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.trim().isEmpty || password.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = await _authRepository.login(
      username: username,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (user == null) {
      setState(() {
        _errorMessage = 'Tên đăng nhập hoặc mật khẩu không đúng.';
      });
      return;
    }

    // Nếu tick ghi nhớ thì lưu lại tài khoản/mật khẩu.
    // Nếu không tick thì xóa thông tin đã lưu.
    if (_rememberMe) {
      await _rememberStorage.save(
        username: username.trim(),
        password: password.trim(),
      );
    } else {
      await _rememberStorage.clear();
    }

    if (!mounted) return;

    // Yêu cầu quyền thông báo và lấy FCM Token
    if (!kIsWeb) {
      try {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          String? token = await messaging.getToken();
          if (token != null) {
            // Gửi token lên server
            final scheduleRepo = ApiScheduleRepository(currentUser: user);
            await scheduleRepo.updateFcmToken(token);
          }
        }
      } catch (e) {
        print('Firebase Messaging init error: $e');
      }
    }

    if (!mounted) return;

    // Đăng nhập thành công thì chuyển sang màn hình chính.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainShell(
          currentUser: user,
        ),
      ),
    );
  }

  Future<void> _googleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '734831076442-obad39spt67l8aggj3l4tj5dhvelvamt.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the login flow
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final email = googleUser.email;
      final displayName = googleUser.displayName ?? email;

      try {
        final user = await _authRepository.googleLogin(email: email);

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainShell(
                currentUser: user,
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        
        final errorMessage = e.toString();
        if (errorMessage.contains('404') || errorMessage.contains('chưa tồn tại') || errorMessage.contains('chưa đăng ký')) {
           // Đi tới màn hình Đăng ký
           Navigator.push(
             context,
             MaterialPageRoute(
               builder: (context) => RegisterScreen(
                 email: email,
                 fullName: displayName,
               ),
             ),
           );
        } else {
           setState(() {
             _errorMessage = errorMessage.replaceAll('Exception: ', '');
           });
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi Google Sign-In: $error';
      });
    }
  }

  void _goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForgotPasswordScreen(
          authRepository: _authRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primaryLight,
                          child: const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 50,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Đăng nhập',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ứng dụng quản lý lịch tuần, lịch cá nhân và lịch khoa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Tên đăng nhập',
                          hintText: '',
                          prefixIcon: const Icon(Icons.person),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(12) : AppColors.backgroundLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          _login();
                        },
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          hintText: '',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(12) : AppColors.backgroundLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });

                              // Nếu bỏ tick thì xóa dữ liệu đã lưu.
                              if (_rememberMe == false) {
                                _rememberStorage.clear();
                              }
                            },
                          ),
                          Text(
                            'Ghi nhớ đăng nhập',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF334155),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _goToForgotPassword,
                            child: Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        _MessageBox(
                          message: _errorMessage!,
                          isSuccess: false,
                        ),
                      ],

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_isBiometricConfigured) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 54,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _loginWithBiometrics,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fingerprint,
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Nút đăng nhập Google
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _googleLogin,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                            side: const BorderSide(color: Colors.grey, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                            height: 24,
                            width: 24,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 36),
                          ),
                          label: const Text(
                            'Đăng nhập bằng Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E3A8A).withAlpha(50) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget hiển thị thông báo lỗi/thành công.
// Viết riêng để tái sử dụng trong màn hình.
class _MessageBox extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _MessageBox({
    required this.message,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
    isSuccess ? AppColors.success.withAlpha(20) : AppColors.error.withAlpha(20);

    final borderColor =
    isSuccess ? AppColors.success.withAlpha(60) : AppColors.error.withAlpha(60);

    final textColor = isSuccess ? AppColors.success : AppColors.error;

    final iconColor = isSuccess ? AppColors.success : AppColors.error;

    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}