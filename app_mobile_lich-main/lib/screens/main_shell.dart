import 'package:flutter/material.dart';

import '../data/api_schedule_repository.dart';
import '../data/remember_login_storage.dart';
import '../models/user_profile.dart';
import 'department_schedule_screen.dart';
import 'login_screen.dart';
import 'my_schedule_screen.dart';
import 'profile_screen.dart';
import 'search_schedule_screen.dart';
import 'week_schedule_screen.dart';
import '../services/notification_service.dart';

// MainShell là khung chính sau khi đăng nhập.
// Nó chứa BottomNavigationBar để chuyển giữa các tab:
// 1. Lịch tuần
// 2. Lịch của tôi
// 3. Lịch khoa
// 4. Tìm kiếm
// 5. Cá nhân
class MainShell extends StatefulWidget {
  final UserProfile currentUser;

  const MainShell({
    super.key,
    required this.currentUser,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  late ApiScheduleRepository _repository;
  late List<Widget> _pages;
  late UserProfile _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _repository = ApiScheduleRepository(
      currentUser: _currentUser,
    );
    _buildPages();
    _setupNotifications();
  }

  void _buildPages() {
    final isAdmin = _currentUser.role.toLowerCase() == 'quản trị viên' || 
                    _currentUser.role.toLowerCase() == 'admin';

    _pages = [
      WeekScheduleScreen(repository: _repository, isAdmin: isAdmin),
      MyScheduleScreen(repository: _repository),
      DepartmentScheduleScreen(
        repository: _repository,
        departmentName: _currentUser.departmentName,
      ),
      SearchScheduleScreen(repository: _repository),
      ProfileScreen(
        profile: _currentUser,
        onLogout: _handleLogout,
        onProfileUpdated: _handleProfileUpdated,
      ),
    ];
  }

  void _handleProfileUpdated(UserProfile updatedProfile) {
    setState(() {
      _currentUser = updatedProfile;
      // Recreate repository with new profile
      _repository = ApiScheduleRepository(
        currentUser: _currentUser,
      );
      // Rebuild pages with new profile
      _buildPages();
    });
  }

  Future<void> _setupNotifications() async {
    try {
      final mySchedules = await _repository.getMySchedules();
      final notificationService = NotificationService();
      
      // Xóa các lịch nhắc nhở cũ để tránh bị trùng lặp
      await notificationService.cancelAll();
      
      // Lên lịch cho tất cả các sự kiện cá nhân chưa diễn ra
      for (final item in mySchedules) {
        if (!item.isPassed) {
          await notificationService.scheduleScheduleNotification(item);
        }
      }
    } catch (e) {
      print("Lỗi lên lịch thông báo: $e");
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản hiện tại không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    // Xóa thông tin ghi nhớ đăng nhập nếu trước Ä‘ó ngÆ°á»i dùng có tick "Ghi nhớ".
    await RememberLoginStorage().clear();

    if (!mounted) {
      return;
    }

    // Quay vá» màn đăng nhập và xóa toàn bộ màn trước Ä‘ó.
    // Như vậy sau khi đăng xuất, bấm nút Back sẽ không quay lại màn chính.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month),
              label: (widget.currentUser.role.toLowerCase() == 'quản trị viên' || 
                      widget.currentUser.role.toLowerCase() == 'admin') 
                      ? 'Toàn trường'
                      : 'Lịch tuần',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_pin_circle),
              label: 'Lịch của tôi',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.business),
              label: 'Lịch khoa',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Tìm kiếm',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}
