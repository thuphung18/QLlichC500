import 'package:flutter/material.dart';

/// Bảng màu phong cách Enterprise (Lựa chọn A: Navy/Slate).
/// Ưu tiên sự chuyên nghiệp, tin cậy, không quá sặc sỡ.
class AppColors {
  // ==================== LIGHT MODE ====================
  
  /// Xanh Navy đậm - Màu chủ đạo cho AppBars, các nút bấm chính, icon quan trọng.
  static const Color primaryLight = Color(0xFF1E3A8A); // Blue 900
  
  /// Accent Color - Màu nhấn cho các hành động phụ hoặc badge.
  static const Color accentLight = Color(0xFF2563EB); // Blue 600
  
  /// Background chính của app (hơi xám nhẹ giúp mắt dễ chịu hơn trắng tinh).
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  
  /// Background của các card, container (Trắng tinh để nổi bật trên nền xám nhẹ).
  static const Color surfaceLight = Color(0xFFFFFFFF); 
  
  /// Text chính (Xám than thay vì đen tuyền).
  static const Color textPrimaryLight = Color(0xFF1E293B); // Slate 800
  
  /// Text phụ, caption (Xám nhạt hơn).
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  
  /// Viền (Border) mỏng nhẹ cho các card.
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // ==================== DARK MODE ====================
  
  /// Primary trong Dark mode sáng hơn một chút để đảm bảo độ tương phản.
  static const Color primaryDark = Color(0xFF3B82F6); // Blue 500
  
  /// Nền chính của dark mode (Xám đậm không gian, không dùng đen tuyệt đối).
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  
  /// Bề mặt các card trong dark mode (Sáng hơn nền một chút).
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  
  /// Text chính trong dark mode (Trắng ngà mờ).
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  
  /// Text phụ trong dark mode.
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  
  /// Viền (Border) trong dark mode.
  static const Color borderDark = Color(0xFF334155); // Slate 700

  // ==================== TRẠNG THÁI (STATES) ====================
  
  /// Màu thành công (Xanh ngọc - Teal).
  static const Color success = Color(0xFF0F766E); // Teal 700
  
  /// Màu lỗi/cảnh báo (Đỏ gạch).
  static const Color error = Color(0xFFB91C1C); // Red 700
  
  /// Màu thông tin phụ (Cam đậm).
  static const Color warning = Color(0xFFC2410C); // Orange 700
}
