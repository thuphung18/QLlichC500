import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../screens/login_screen.dart';
import 'remember_login_storage.dart';

/// Lớp [HttpClient] đóng gói thư viện http để tự động bắt lỗi 401 (Hết phiên đăng nhập)
/// và hiển thị thông báo, đẩy người dùng về màn hình đăng nhập.
class HttpClient {
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.post(url, headers: headers, body: body);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.put(url, headers: headers, body: body);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers}) async {
    final response = await http.delete(url, headers: headers);
    _checkUnauthorized(response);
    return response;
  }

  static void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      _handleLogout();
    }
  }

  static bool _isLoggingOut = false;

  static Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    await RememberLoginStorage().clear();
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Phiên đăng nhập hết hạn'),
          content: const Text('Bạn đang đăng nhập ở thiết bị khác. Vui lòng đăng nhập lại.'),
          actions: [
            TextButton(
              onPressed: () {
                _isLoggingOut = false;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      );
    } else {
       _isLoggingOut = false;
    }
  }
}
