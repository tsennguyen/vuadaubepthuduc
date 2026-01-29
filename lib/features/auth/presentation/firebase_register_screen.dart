import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/firebase_auth_service.dart';
import '../data/user_repository.dart';

class FirebaseRegisterScreen extends StatefulWidget {
  const FirebaseRegisterScreen({super.key, this.onRegistered});

  final VoidCallback? onRegistered;

  @override
  State<FirebaseRegisterScreen> createState() => _FirebaseRegisterScreenState();
}

class _FirebaseRegisterScreenState extends State<FirebaseRegisterScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  final _authService = FirebaseAuthService();
  final _userRepo = UserRepository();

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    final fullName = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Vui lòng nhập email và mật khẩu');
      return;
    }
    if (password != confirm) {
      _showSnack('Mật khẩu không khớp');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await _authService.registerWithEmail(email, password);
      final user = cred.user;
      if (user != null) {
        await _userRepo.createUserIfNotExists(
          user,
          fullName: fullName,
          provider: 'password',
        );
        await _userRepo.updateLastLogin(user.uid);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('current_user_uid', user.uid);
        await prefs.setString('login_provider', 'password');
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_name', fullName);
        await prefs.setString('user_avatar', user.photoURL ?? '');

        widget.onRegistered?.call();
        if (mounted) {
          _showSnack('Đăng ký thành công');
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) context.go('/feed');
          });
        }
      }
    } catch (e) {
      _showSnack('Đăng ký thất bại: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.lexend(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade900,
      letterSpacing: -0.5,
    );
    final subtitleStyle = GoogleFonts.lexend(
      fontSize: 15,
      color: Colors.grey.shade600,
      fontWeight: FontWeight.w400,
    );

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFD1DCD7), // Muted desaturated sage
              Color(0xFFBDC9C3), // Deeper muted sage
              Color(0xFFEBF0EE), // Soft greyish white
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.green.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE8F3EE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_add_rounded,
                                    color: Color(0xFF2D6A4F),
                                    size: 40,
                                  ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Đăng ký tài khoản',
                              textAlign: TextAlign.center,
                              style: titleStyle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cùng tham gia cộng đồng Vua Đầu Bếp',
                              textAlign: TextAlign.center,
                              style: subtitleStyle,
                            ),
                            const SizedBox(height: 40),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Họ tên',
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmController,
                              obscureText: true,
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Xác nhận mật khẩu',
                                prefixIcon: const Icon(Icons.lock_reset_outlined),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D6A4F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('Đăng ký', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Đã có tài khoản? '),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.pop(),
                          child: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2D6A4F))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

