import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'theme/theme_provider.dart';
import 'theme/app_colors.dart';

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

          // Theme Enterprise chuẩn
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.backgroundLight,
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
              bodyColor: AppColors.textPrimaryLight,
              displayColor: AppColors.textPrimaryLight,
            ),
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryLight,
              secondary: AppColors.accentLight,
              surface: AppColors.surfaceLight,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimaryLight,
              error: AppColors.error,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              centerTitle: true,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: AppColors.surfaceLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderLight),
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: AppColors.surfaceLight,
              unselectedItemColor: AppColors.textSecondaryLight,
              selectedItemColor: AppColors.primaryLight,
              type: BottomNavigationBarType.fixed,
            ),
          ),
          
          darkTheme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.backgroundDark,
            cardColor: AppColors.surfaceDark,
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
              bodyColor: AppColors.textPrimaryDark,
              displayColor: AppColors.textPrimaryDark,
            ),
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryDark,
              secondary: AppColors.accentLight,
              surface: AppColors.surfaceDark,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimaryDark,
              error: AppColors.error,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.surfaceDark,
              foregroundColor: Colors.white,
              centerTitle: true,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: AppColors.surfaceDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderDark),
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: AppColors.surfaceDark,
              unselectedItemColor: AppColors.textSecondaryDark,
              selectedItemColor: AppColors.primaryDark,
              type: BottomNavigationBarType.fixed,
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