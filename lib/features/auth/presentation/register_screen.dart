import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../data/firebase_auth_repository.dart';
import 'widgets/auth_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _submitted = false;
  String? _firebaseError;

  late final FirebaseAuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authRepository = FirebaseAuthRepository(FirebaseAuth.instance);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(S s) async {
    setState(() {
      _submitted = true;
      _firebaseError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    try {
      await _authRepository.registerWithEmail(
        email: email,
        password: password,
        displayName: name.isEmpty ? null : name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.isVi ? 'Đăng ký thành công, chào mừng bạn tới Vua Đầu Bếp!' : 'Registration successful, welcome to Vua Dau Bep!')),
      );
      context.go('/feed');
    } on FirebaseAuthException catch (e) {
      _handleAuthError(mapFirebaseAuthErrorToMessage(e));
    } on AuthException catch (e) {
      _handleAuthError(e.message);
    } catch (_) {
      _handleAuthError(s.isVi ? 'Đăng ký thất bại. Bạn thử lại sau.' : 'Registration failed. Please try again later.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(String message) {
    if (!mounted) return;
    setState(() => _firebaseError = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = S(locale);
    final isVi = s.isVi;

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
    final autovalidateMode =
        _submitted ? AutovalidateMode.always : AutovalidateMode.disabled;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFD1DCD7),
              Color(0xFFBDC9C3),
              Color(0xFFEBF0EE),
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
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: const Color(0xFF2D6A4F).withOpacity(0.1), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2D6A4F).withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.disabled,
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
                                  s.register,
                                  textAlign: TextAlign.center,
                                  style: titleStyle,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isVi ? 'Tham gia cộng đồng Vua Đầu Bếp ngay hôm nay' : 'Join the Vua Dau Bep community today',
                                  textAlign: TextAlign.center,
                                  style: subtitleStyle,
                                ),
                                const SizedBox(height: 40),
                                TextFormField(
                                  key: const ValueKey('register_email'),
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autovalidateMode: autovalidateMode,
                                  style: GoogleFonts.lexend(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: s.email,
                                    hintText: 'name@example.com',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 1.5),
                                    ),
                                  ),
                                  validator: validateEmail,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const ValueKey('register_name'),
                                  controller: _nameController,
                                  autovalidateMode: autovalidateMode,
                                  style: GoogleFonts.lexend(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: isVi ? 'Họ tên' : 'Full name',
                                    hintText: isVi ? 'Nguyễn Văn A' : 'John Doe',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 1.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const ValueKey('register_password'),
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  autovalidateMode: autovalidateMode,
                                  style: GoogleFonts.lexend(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: s.password,
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() => _obscurePassword = !_obscurePassword);
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 1.5),
                                    ),
                                  ),
                                  validator: validateNewPassword,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const ValueKey('register_confirm_password'),
                                  controller: _confirmController,
                                  obscureText: _obscureConfirm,
                                  autovalidateMode: autovalidateMode,
                                  style: GoogleFonts.lexend(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: isVi ? 'Xác nhận mật khẩu' : 'Confirm password',
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() => _obscureConfirm = !_obscureConfirm);
                                      },
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF2D6A4F), width: 1.5),
                                    ),
                                  ),
                                  validator: (value) =>
                                      validateConfirmPassword(value, _passwordController.text),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      backgroundColor: const Color(0xFF2D6A4F),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    onPressed: _isLoading ? null : () => _handleRegister(s),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            s.register,
                                            style: GoogleFonts.lexend(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                if (_firebaseError != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _firebaseError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isVi ? 'Đã có tài khoản?' : 'Already have an account?',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.go('/signin'),
                          child: Text(
                            isVi ? 'Đăng nhập ngay' : 'Login now',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF2D6A4F),
                            ),
                          ),
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
