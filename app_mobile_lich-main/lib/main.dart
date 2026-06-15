import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'theme/theme_provider.dart';

final ThemeProvider globalThemeProvider = ThemeProvider();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Cần gọi Firebase.initializeApp() nếu muốn dùng các Firebase services trong background
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// File main.dart là điểm bắt đầu của app.
// Khi bấm Run, Flutter sẽ chạy từ hàm main() này trước.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await NotificationService().init();
  } catch (e) {
    print("Notification init error: $e");
  }
  
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print("Firebase init error: $e");
  }
  runApp(const ScheduleApp());
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: globalThemeProvider,
      builder: (context, _) {
        return MaterialApp(
          // Ẩn chữ DEBUG ở góc phải màn hình.
          debugShowCheckedModeBanner: false,

          title: 'Lịch giảng dạy',
          
          themeMode: globalThemeProvider.themeMode,

          // Theme chung của toàn bộ app.
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F7FB),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.light,
            ),
          ),
          
          darkTheme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            cardColor: const Color(0xFF1E293B),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6),
              brightness: Brightness.dark,
              surface: const Color(0xFF1E293B),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1E293B),
              unselectedItemColor: Color(0xFF94A3B8),
              selectedItemColor: Color(0xFF3B82F6),
            ),
          ),

      // Màn hình đầu tiên là màn hình đăng nhập.
      // routes dùng để các màn khác có thể quay về màn đăng nhập khi đăng xuất.
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
        );
      },
    );
  }
}