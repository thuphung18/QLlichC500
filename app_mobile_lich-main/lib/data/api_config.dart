import 'package:flutter/foundation.dart';

/// Lớp [ApiConfig] dùng để lưu trữ cấu hình mạng dùng chung cho toàn bộ app.
class ApiConfig {
  /// Đặt true nếu muốn kết nối với API đã deploy trên Render.
  /// Đặt false nếu muốn chạy test dưới local (localhost hoặc IP mạng LAN).
  static const bool useProduction = true;

  /// Đường dẫn API đã deploy trên Render.
  /// Hãy thay đổi URL này bằng URL thực tế trên Render dashboard của bạn.
  static const String prodUrl = 'https://qllichc500-1.onrender.com/api';

  /// Hàm getter trả về địa chỉ IP hoặc domain của Backend (FastAPI).
  static String get baseUrl {
    if (useProduction) {
      return prodUrl;
    }
    if (kIsWeb) {
      // Tự động lấy hostname của trang web đang chạy (localhost hoặc IP hiện tại)
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:8000/api';
    }
    // Địa chỉ IPv4 của máy chủ (backend) trên mạng Wi-Fi (ví dụ: hvan.edu.vn)
    return 'http://192.168.1.132:8000/api';
  }
}
