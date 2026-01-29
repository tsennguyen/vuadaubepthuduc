import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/firebase_auth_service.dart';
import '../data/user_repository.dart';
import '../../../services/google_auth_service.dart';

import 'package:google_fonts/google_fonts.dart';

class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({super.key, this.onLoggedIn});

  final VoidCallback? onLoggedIn;

  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _authService = FirebaseAuthService();
  final _userRepo = UserRepository();
  late final GoogleAuthService _googleService =
      GoogleAuthService(userRepository: _userRepo);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    setState(() => _isLoading = true);
    try {
      final cred = await _authService.loginWithEmail(email, password);
      final user = cred.user;
      if (user != null) {
        await _userRepo.updateLastLogin(user.uid);
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('current_user_uid', user.uid);
          await prefs.setString('login_provider', 'password');
          await prefs.setString('user_email', user.email ?? '');
          await prefs.setString('user_name', user.displayName ?? '');
          await prefs.setString('user_avatar', user.photoURL ?? '');
        }
        widget.onLoggedIn?.call();
        if (mounted) {
          _showSnack('Đăng nhập thành công');
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) context.go('/feed');
          });
        }
      }
    } catch (e) {
      _showSnack('Đăng nhập thất bại: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await _googleService.signInWithGoogle();
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('current_user_uid', user.uid);
        await prefs.setString('login_provider', 'google');
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_name', user.displayName ?? '');
        await prefs.setString('user_avatar', user.photoURL ?? '');

        widget.onLoggedIn?.call();
        if (mounted) {
          _showSnack('Đăng nhập Google thành công');
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) context.go('/feed');
          });
        }
      }
    } catch (e) {
      _showSnack('Đăng nhập Google thất bại: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        child: Form(
                          key: _formKey,
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
                                      Icons.restaurant_menu_rounded,
                                      color: Color(0xFF2D6A4F),
                                      size: 40,
                                    ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Vua Đầu Bếp',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lexend(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Đăng nhập để đặt món ngay',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lexend(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                ),
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
                                validator: (val) => (val == null || val.isEmpty) ? 'Vui lòng nhập email' : null,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.lexend(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (val) => (val == null || val.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFF2D6A4F),
                                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                  ),
                                  const Text('Ghi nhớ', style: TextStyle(fontSize: 14)),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {}, // Link to forgot password if needed
                                    child: const Text('Quên mật khẩu?', style: TextStyle(color: Color(0xFF2D6A4F))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D6A4F),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Text('Đăng nhập', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade200)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('Hoặc', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey.shade200)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _loginWithGoogle,
                                icon: Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                                  height: 24,
                                ),
                                label: Text(
                                  'Tiếp tục với Google',
                                  style: GoogleFonts.lexend(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  height: 56,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: Colors.grey.shade200),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản? '),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: const Text('Đăng ký ngay', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2D6A4F))),
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

