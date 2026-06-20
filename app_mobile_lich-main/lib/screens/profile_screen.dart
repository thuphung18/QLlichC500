import 'package:flutter/material.dart';

import '../main.dart';
import '../models/user_profile.dart';
import '../utils/role_helper.dart';
import '../widgets/app_header.dart';
import 'admin_dashboard_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../services/biometric_service.dart';
import '../data/remember_login_storage.dart';
import '../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_schedule_repository.dart';
import '../services/notification_service.dart';

// ProfileScreen là màn hình cá nhân.
// Hiển thị thông tin user đang đăng nhập.
class ProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onLogout;
  final Function(UserProfile) onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BiometricService _biometricService = BiometricService();
  final RememberLoginStorage _rememberStorage = RememberLoginStorage();

  bool _isDeviceSupported = false;
  bool _isBiometricEnabled = false;
  bool _notifyTomorrow = true;
  bool _notifyUpcoming = true;
  int _reminderMinutes = 5;

  @override
  void initState() {
    super.initState();
    _initBiometricSettings();
    _loadNotificationSettings();
  }

  Future<void> _initBiometricSettings() async {
    final supported = await _biometricService.isDeviceSupported();
    final enabled = await _biometricService.isBiometricEnabled();
    setState(() {
      _isDeviceSupported = supported;
      _isBiometricEnabled = enabled;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Bật sinh trắc học
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xác thực sinh trắc học thất bại.')),
          );
        }
        return;
      }

      // Lấy mật khẩu để lưu bảo mật
      String? password;
      final remembered = await _rememberStorage.load();
      if (remembered != null && remembered.username == widget.profile.username) {
        password = remembered.password;
      }

      if (password == null && mounted) {
        password = await _showPasswordConfirmDialog();
      }

      if (password == null || password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hủy kích hoạt đăng nhập sinh trắc học do thiếu mật khẩu.')),
          );
        }
        return;
      }

      await _biometricService.saveCredentials(widget.profile.username, password);
      setState(() {
        _isBiometricEnabled = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã kích hoạt đăng nhập sinh trắc học thành công.')),
        );
      }
    } else {
      // Tắt sinh trắc học
      await _biometricService.clearCredentials();
      setState(() {
        _isBiometricEnabled = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy kích hoạt đăng nhập sinh trắc học.')),
        );
      }
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyTomorrow = prefs.getBool('notify_tomorrow') ?? true;
      _notifyUpcoming = prefs.getBool('notify_upcoming') ?? true;
      _reminderMinutes = prefs.getInt('reminder_minutes') ?? 5;
    });
  }

  Future<void> _toggleNotifyTomorrow(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_tomorrow', value);
    setState(() {
      _notifyTomorrow = value;
    });
    await _rescheduleAllNotifications();
  }

  Future<void> _toggleNotifyUpcoming(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_upcoming', value);
    setState(() {
      _notifyUpcoming = value;
    });
    await _rescheduleAllNotifications();
  }

  Future<void> _changeReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_minutes', minutes);
    setState(() {
      _reminderMinutes = minutes;
    });
    await _rescheduleAllNotifications();
  }

  Future<void> _rescheduleAllNotifications() async {
    try {
      final repo = ApiScheduleRepository(currentUser: widget.profile);
      final mySchedules = await repo.getMySchedules();
      final notificationService = NotificationService();
      await notificationService.updateScheduledNotifications(mySchedules);
    } catch (e) {
      print("Lỗi cập nhật lại thông báo: $e");
    }
  }

  Future<String?> _showPasswordConfirmDialog() async {
    final controller = TextEditingController();
    bool isPasswordObscured = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Xác nhận mật khẩu',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vui lòng nhập mật khẩu tài khoản hiện tại để mã hóa và lưu trữ an toàn trên thiết bị này.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: isPasswordObscured,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(isPasswordObscured ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setStateDialog(() {
                            isPasswordObscured = !isPasswordObscured;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withAlpha(12)
                          : AppColors.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Xác nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const AppHeader(
          title: 'CÁ NHÂN',
          subtitle: 'Thông tin tài khoản và đơn vị công tác',
          icon: Icons.account_circle,
          accentColor: AppColors.primaryLight,
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.borderLight : AppColors.borderDark),
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
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.profile.fullName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.profile.role,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final updatedProfile = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(profile: widget.profile),
                    ),
                  );
                  if (updatedProfile != null && updatedProfile is UserProfile) {
                    widget.onProfileUpdated(updatedProfile);
                  }
                },
                icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                label: const Text('Chỉnh sửa', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangePasswordScreen(
                        userId: widget.profile.id,
                        sessionToken: widget.profile.sessionToken ?? '',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.vpn_key, size: 18, color: Colors.white),
                label: const Text('Đổi mật khẩu', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 18),

        _ProfileInfoCard(
          icon: Icons.badge,
          label: 'Tên đăng nhập',
          value: widget.profile.username,
        ),
        _ProfileInfoCard(
          icon: Icons.business,
          label: 'Đơn vị',
          value: widget.profile.unit,
        ),
        _ProfileInfoCard(
          icon: Icons.apartment,
          label: 'Khoa / Phòng ban',
          value: widget.profile.departmentName,
        ),
        _ProfileInfoCard(
          icon: Icons.email,
          label: 'Email',
          value: widget.profile.email,
        ),
        _ProfileInfoCard(
          icon: Icons.phone,
          label: 'Số điện thoại',
          value: widget.profile.phone,
        ),

        const SizedBox(height: 10),

        // Dark Mode Toggle
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dark_mode,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: globalThemeProvider.isDarkMode,
                onChanged: (value) {
                  globalThemeProvider.toggleTheme();
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),

        // Biometric Settings Toggle
        if (_isDeviceSupported)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Đăng nhập Vân tay / Face ID',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Switch(
                  value: _isBiometricEnabled,
                  onChanged: _toggleBiometric,
                  activeColor: AppColors.success,
                ),
              ],
            ),
          ),

        // Notification Settings - Digest Tomorrow
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Báo lịch ngày mai (20:00 hàng ngày)',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nhận tóm tắt lịch công tác của ngày mai vào lúc 8h tối',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _notifyTomorrow,
                onChanged: _toggleNotifyTomorrow,
                activeColor: AppColors.primaryLight,
              ),
            ],
          ),
        ),

        // Notification Settings - Upcoming reminders
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.alarm,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhắc nhở khi chuẩn bị có lịch',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thông báo nhắc nhở trước khi sự kiện bắt đầu $_reminderMinutes phút',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    if (_notifyUpcoming) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Thời gian báo trước: ',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          DropdownButton<int>(
                            value: _reminderMinutes,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5 phút')),
                              DropdownMenuItem(value: 10, child: Text('10 phút')),
                              DropdownMenuItem(value: 15, child: Text('15 phút')),
                              DropdownMenuItem(value: 30, child: Text('30 phút')),
                              DropdownMenuItem(value: 60, child: Text('1 giờ')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                _changeReminderMinutes(val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: _notifyUpcoming,
                onChanged: _toggleNotifyUpcoming,
                activeColor: AppColors.warning,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Nút quản trị - hiển thị theo role
        if (RoleHelper.isAdmin(widget.profile.role) || RoleHelper.isManager(widget.profile.role))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminDashboardScreen(
                        adminProfile: widget.profile,
                      ),
                    ),
                  );
                },
                icon: Icon(RoleHelper.isAdmin(widget.profile.role)
                    ? Icons.admin_panel_settings
                    : Icons.manage_accounts),
                label: Text(RoleHelper.isAdmin(widget.profile.role)
                    ? 'Quản trị hệ thống'
                    : 'Quản lý thành viên khoa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentLight,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          )
        else if (RoleHelper.isManager(widget.profile.role))
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withAlpha(15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF97316).withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.manage_accounts, color: Color(0xFFF97316)),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trưởng phòng', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFF97316))),
                      Text('Bạn có quyền tạo và phân công lịch phiếu phòng ban', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Card nhá» hiển thị từng dòng thông tin cá nhân.
class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
