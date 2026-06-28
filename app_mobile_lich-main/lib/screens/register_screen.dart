import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../data/api_auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  final String email;
  final String fullName;

  const RegisterScreen({
    super.key,
    required this.email,
    required this.fullName,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthRepository _authRepository = ApiAuthRepository();
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _departments = [];
  String? _selectedDepartmentId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    setState(() {
      _isLoading = true;
    });
    
    final depts = await _authRepository.getPublicDepartments();
    
    setState(() {
      _departments = depts;
      _isLoading = false;
    });
  }

  Future<void> _register() async {
    if (_selectedDepartmentId == null) {
      setState(() {
        _errorMessage = 'Vui lòng chọn Khoa / Phòng ban của bạn.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authRepository.register(
      email: widget.email,
      fullName: widget.fullName,
      departmentId: _selectedDepartmentId!,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Đăng ký thành công'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Đóng dialog
                Navigator.pop(context); // Quay về màn LoginScreen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Đăng ký tài khoản'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading && _departments.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hoàn tất hồ sơ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tài khoản Google của bạn chưa được liên kết với hệ thống. Vui lòng hoàn tất thông tin để đăng ký.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      
                    // Email Field (Read-only)
                    TextFormField(
                      initialValue: widget.email,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email (Google)',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Full Name Field (Read-only)
                    TextFormField(
                      initialValue: widget.fullName,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Department Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Thuộc Khoa / Phòng ban',
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      value: _selectedDepartmentId,
                      items: _departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept['id'].toString(),
                          child: Text(dept['name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartmentId = value;
                        });
                      },
                      hint: const Text('Chọn Khoa / Phòng ban'),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Register Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Đăng ký tài khoản',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
