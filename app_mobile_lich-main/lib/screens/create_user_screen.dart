import 'package:flutter/material.dart';

import '../data/api_schedule_repository.dart';
import '../data/api_user_repository.dart';
import '../models/create_user_request.dart';
import '../models/department.dart';
import '../models/user_profile.dart';
import '../utils/role_helper.dart';

class CreateUserScreen extends StatefulWidget {
  final UserProfile currentUser;

  const CreateUserScreen({super.key, required this.currentUser});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Sử dụng danh sách role chuẩn từ RoleHelper
  String _selectedRole = RoleHelper.availableRoles.first;
  final List<String> _roles = RoleHelper.availableRoles;

  String _unit = '';
  String _selectedDepartmentId = '';

  List<Department> _departments = [];
  bool _isLoadingFormData = true;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {

    try {
      final scheduleRepo = ApiScheduleRepository(currentUser: widget.currentUser);
      final formData = await scheduleRepo.getFormData();
      setState(() {
        if (RoleHelper.isManager(widget.currentUser.role)) {
          _departments = formData.departments
              .where((d) => d.id == widget.currentUser.departmentId)
              .toList();
          if (_departments.isEmpty) {
            _departments = formData.departments;
          }
        } else {
          _departments = formData.departments;
        }
        // Mặc định chọn phòng ban đầu tiên trong danh sách để tránh bị rỗng (null)
        if (_departments.isNotEmpty) {
          _selectedDepartmentId = _departments.first.id;
          _unit = _departments.first.name;
        }
        _isLoadingFormData = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFormData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được danh sách phòng ban')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    // """
    // Hàm xử lý sự kiện khi Admin bấm nút "Tạo tài khoản".
    // Sẽ kiểm tra xác thực (validate) Form, gom dữ liệu thành model CreateUserRequest,
    // và gọi ApiUserRepository để đẩy lên Backend.
    // """
    // Nếu có trường dữ liệu bắt buộc bị bỏ trống, thì báo lỗi đỏ và dừng lại
    if (!_formKey.currentState!.validate()) return;

    // Hiển thị vòng tròn loading
    setState(() {
      _isLoading = true;
    });

    // Đóng gói dữ liệu vào Model
    final request = CreateUserRequest(
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      role: _selectedRole,
      unit: _unit,
      departmentId: _selectedDepartmentId,
      // Xử lý để gửi null nếu không nhập gì (thay vì gửi chuỗi rỗng)
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    // Gửi yêu cầu qua API, truyền adminId để backend kiểm tra quyền
    final userRepo = ApiUserRepository(sessionToken: widget.currentUser.sessionToken ?? '');
    final success = await userRepo.createUser(request, widget.currentUser.id);

    // Dừng hiển thị vòng tròn loading
    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    // Xử lý giao diện (Hiển thị popup xanh/đỏ) dựa trên kết quả trả về
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo tài khoản thành công! Mật khẩu mặc định là 123456')),
      );
      // Trả về true để màn hình trước biết cần reload
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo tài khoản thất bại! Có thể username đã tồn tại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo tài khoản mới', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: _isLoadingFormData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập (*)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập tên đăng nhập' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên (*)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập họ và tên' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Vai trò (*)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.manage_accounts),
                      ),
                      value: _selectedRole,
                      items: _roles.map((role) {
                        return DropdownMenuItem(value: role, child: Text(role));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Phòng ban / Khoa quản lý (*)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      value: _selectedDepartmentId.isEmpty ? null : _selectedDepartmentId,
                      items: _departments.map((dept) {
                        return DropdownMenuItem(value: dept.id, child: Text(dept.name));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedDepartmentId = val;
                            _unit = _departments.firstWhere((d) => d.id == val).name;
                          });
                        }
                      },
                      validator: (value) => value == null || value.isEmpty ? 'Vui lòng chọn phòng ban' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (Tùy chọn)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại (Tùy chọn)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Tạo tài khoản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
