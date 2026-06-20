import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../screens/login_screen.dart';
import 'remember_login_storage.dart';
import 'token_storage.dart';
import 'api_config.dart';

/// Lớp [HttpClient] đóng gói thư viện http để tự động gắn Token và bắt lỗi 401.
class HttpClient {
  static Future<Map<String, String>> _getHeaders(Map<String, String>? originalHeaders) async {
    final headers = originalHeaders != null ? Map<String, String>.from(originalHeaders) : <String, String>{};
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final authHeaders = await _getHeaders(headers);
    var response = await http.get(url, headers: authHeaders);
    response = await _checkUnauthorizedAndRetry(response, () async {
      final newHeaders = await _getHeaders(headers);
      return http.get(url, headers: newHeaders);
    });
    return response;
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final authHeaders = await _getHeaders(headers);
    var response = await http.post(url, headers: authHeaders, body: body);
    response = await _checkUnauthorizedAndRetry(response, () async {
      final newHeaders = await _getHeaders(headers);
      return http.post(url, headers: newHeaders, body: body);
    });
    return response;
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final authHeaders = await _getHeaders(headers);
    var response = await http.put(url, headers: authHeaders, body: body);
    response = await _checkUnauthorizedAndRetry(response, () async {
      final newHeaders = await _getHeaders(headers);
      return http.put(url, headers: newHeaders, body: body);
    });
    return response;
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers}) async {
    final authHeaders = await _getHeaders(headers);
    var response = await http.delete(url, headers: authHeaders);
    response = await _checkUnauthorizedAndRetry(response, () async {
      final newHeaders = await _getHeaders(headers);
      return http.delete(url, headers: newHeaders);
    });
    return response;
  }

  static bool _isRefreshing = false;

  static Future<http.Response> _checkUnauthorizedAndRetry(http.Response response, Future<http.Response> Function() retryAction) async {
    if (response.statusCode == 401) {
      if (_isRefreshing) {
        // Prevent concurrent refreshes, wait or just fail
        return response;
      }
      _isRefreshing = true;
      try {
        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken != null) {
          final refreshResponse = await http.post(
            Uri.parse('${ApiConfig.baseUrl}/auth/refresh-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          );

          if (refreshResponse.statusCode == 200) {
            final data = jsonDecode(refreshResponse.body);
            await TokenStorage.saveTokens(data['access_token'], data['refresh_token']);
            // Retry original request with new token
            return await retryAction();
          }
        }
      } catch (e) {
        print('Refresh token error: $e');
      } finally {
        _isRefreshing = false;
      }
      // If we reach here, refresh failed.
      _handleLogout();
    }
    return response;
  }

  static bool _isLoggingOut = false;

  static Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    await RememberLoginStorage().clear();
    await TokenStorage.clearTokens();
    
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Phiên đăng nhập hết hạn'),
          content: const Text('Bạn đang đăng nhập ở thiết bị khác hoặc phiên đã quá hạn. Vui lòng đăng nhập lại.'),
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
