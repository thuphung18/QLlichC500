import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import 'reset_password_screen.dart';

// Màn hình quên mật khẩu bước 2.
// Người dùng nhập mã OTP.
// Nếu đúng thì app chuyển sang màn đặt mật khẩu mới.
class VerifyOtpScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final String contact;
  final String maskedContact;
  final String? debugCode;

  const VerifyOtpScreen({
    super.key,
    required this.authRepository,
    required this.contact,
    required this.maskedContact,
    this.debugCode,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _debugCode;

  @override
  void initState() {
    super.initState();

    // Mã OTP demo để bạn test.
    _debugCode = widget.debugCode;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mã xác thực.';
      });
      return;
    }

    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Mã xác thực gồm 6 chữ số.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.authRepository.verifyResetCode(
      contact: widget.contact,
      code: code,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success || result.resetToken == null) {
      setState(() {
        _errorMessage = result.message;
      });
      return;
    }

    // OTP đúng thì chuyển sang màn đặt mật khẩu mới.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResetPasswordScreen(
          authRepository: widget.authRepository,
          resetToken: result.resetToken!,
        ),
      ),
    );
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final result = await widget.authRepository.sendResetCode(
      contact: widget.contact,
    );

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (!result.success) {
      setState(() {
        _errorMessage = result.message;
      });
      return;
    }

    setState(() {
      _debugCode = result.debugCode;
      _codeController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã gửi lại mã xác thực.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Xác thực mã',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withAlpha(25),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.verified_user,
                  color: Color(0xFF2563EB),
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nhập mã xác thực',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã xác thực đã được gửi tới ${widget.maskedContact}. Vui lòng nhập mã gồm 6 chữ số.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        _verifyCode();
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'Mã xác thực',
                        hintText: '123456',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _MessageBox(
                        message: _errorMessage!,
                        isSuccess: false,
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'Xác nhận mã',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton.icon(
                      onPressed: _isResending ? null : _resendCode,
                      icon: _isResending
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.refresh),
                      label: const Text(
                        'Gửi lại mã',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_debugCode != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Mã OTP demo là: $_debugCode\nSau này mã này sẽ được gửi qua SMS hoặc Email từ backend.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _MessageBox({
    required this.message,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
    isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);

    final borderColor =
    isSuccess ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);

    final textColor =
    isSuccess ? const Color(0xFF166534) : const Color(0xFFB91C1C);

    final iconColor =
    isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}