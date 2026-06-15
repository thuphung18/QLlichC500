import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lớp [ApiConfig] dùng để lưu trữ cấu hình mạng dùng chung cho toàn bộ app.
class ApiConfig {
  /// Hàm getter trả về địa chỉ IP hoặc domain của Backend (FastAPI).
  /// Nếu chạy ứng dụng trên máy ảo (Emulator), bạn có thể cần trỏ về 10.0.2.2.
  /// Hiện tại đang trỏ tới IP mạng LAN của máy chủ.
  static String get baseUrl {
    // Địa chỉ IPv4 của máy chủ (backend) trên mạng Wi-Fi (ví dụ: hvan.edu.vn)
    return 'http://192.168.1.132:8000/api';
  }
}
