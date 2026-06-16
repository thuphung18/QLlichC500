import 'package:flutter/material.dart';

import '../main.dart';
import '../models/user_profile.dart';
import '../widgets/app_header.dart';
import 'create_user_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../services/biometric_service.dart';
import '../data/remember_login_storage.dart';

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

  @override
  void initState() {
    super.initState();
    _initBiometricSettings();
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
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
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
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          accentColor: Color(0xFF2563EB),
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withAlpha(25),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF2563EB),
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
                      builder: (context) => ChangePasswordScreen(userId: widget.profile.id),
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
                  color: const Color(0xFF2563EB).withAlpha(22),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.dark_mode,
                  color: Color(0xFF2563EB),
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
                activeColor: const Color(0xFF2563EB),
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
                    color: const Color(0xFF10B981).withAlpha(22),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: Color(0xFF10B981),
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
                  activeColor: const Color(0xFF10B981),
                ),
              ],
            ),
          ),

        const SizedBox(height: 10),

        if (widget.profile.role.toLowerCase() == 'quản trị viên' || widget.profile.role.toLowerCase() == 'admin')
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
                      builder: (context) => CreateUserScreen(currentUser: widget.profile),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Tạo tài khoản mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
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
                borderRadius: BorderRadius.circular(18),
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
              color: const Color(0xFF2563EB).withAlpha(22),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2563EB),
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
