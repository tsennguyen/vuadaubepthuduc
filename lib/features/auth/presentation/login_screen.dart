import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/firebase_auth_repository.dart';
import 'widgets/auth_validators.dart';
import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    setState(() {
      _submitted = true;
      _firebaseError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await _authRepository.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập thành công')),
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) context.go('/feed');
        });
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(mapFirebaseAuthErrorToMessage(e));
      if (mounted) setState(() => _isLoading = false);
    } on AuthException catch (e) {
      _handleAuthError(e.message);
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      _handleAuthError('Đăng nhập thất bại. Bạn thử lại sau.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _firebaseError = null);
    setState(() => _isLoading = true);
    try {
      await _authRepository.signInWithGoogle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập Google thành công')),
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) context.go('/feed');
        });
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(mapFirebaseAuthErrorToMessage(e));
      if (mounted) setState(() => _isLoading = false);
    } on AuthException catch (e) {
      _handleAuthError(e.message);
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      _handleAuthError('Không thể đăng nhập Google, thử lại sau.');
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
    final isVi = locale.languageCode == 'vi';

    final titleStyle = GoogleFonts.lexend(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade900,
      letterSpacing: -0.5,
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
                                      Icons.restaurant_menu_rounded,
                                      color: Color(0xFF2D6A4F),
                                      size: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  isVi ? 'Chào mừng quay lại!' : 'Welcome back!',
                                  textAlign: TextAlign.center,
                                  style: titleStyle,
                                ),
                                const SizedBox(height: 40),
                                TextFormField(
                                  key: const ValueKey('login_email'),
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
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const ValueKey('login_password'),
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
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                                  validator: validatePassword,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: const Color(0xFF2D6A4F),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        onChanged: _isLoading
                                            ? null
                                            : (val) => setState(() => _rememberMe = val ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isVi ? 'Ghi nhớ đăng nhập' : 'Remember me',
                                      style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => context.push('/forgot-password'),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        s.forgotPassword,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2D6A4F),
                                        ),
                                      ),
                                    ),
                                  ],
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
                                    onPressed: _isLoading ? null : _handleEmailLogin,
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
                                            s.login,
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
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey.shade200)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        isVi ? 'Hoặc tiếp tục với' : 'Or continue with',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey.shade200)),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 56,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: BorderSide(color: Colors.grey.shade200),
                                      backgroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    onPressed: _isLoading ? null : _handleGoogleLogin,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const _GoogleIcon(size: 24),
                                        const SizedBox(width: 12),
                                        Text(
                                          isVi ? 'Tiếp tục với Google' : 'Continue with Google',
                                          style: GoogleFonts.lexend(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SignUpLink(s: s),
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

class _SignUpLink extends StatelessWidget {
  const _SignUpLink({required this.s});
  final S s;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          s.dontHaveAccount,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        TextButton(
          onPressed: () => context.go('/signup'),
          child: Text(
            s.signupNow,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF2D6A4F),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, size: size, color: Colors.blue),
    );
  }
}

