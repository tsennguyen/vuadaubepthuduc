import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/firebase_auth_repository.dart';
import 'widgets/auth_validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    setState(() {
      _submitted = true;
      _firebaseError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await _authRepository.sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi link đặt lại mật khẩu vào email. Bạn kiểm tra hộp thư (và spam) nhé.'),
        ),
      );
      context.pop();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(mapFirebaseAuthErrorToMessage(e));
    } on AuthException catch (e) {
      _handleAuthError(e.message);
    } catch (_) {
      _handleAuthError('Không thể gửi yêu cầu, vui lòng thử lại.');
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
    final titleStyle = GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade900,
    );
    final subtitleStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.grey.shade700,
      fontWeight: FontWeight.w500,
    );
    final autovalidateMode =
        _submitted ? AutovalidateMode.always : AutovalidateMode.disabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF8A00), Color(0xFFFFC857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 10,
                shadowColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Đặt lại mật khẩu',
                          textAlign: TextAlign.center,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập email đã đăng ký, chúng tôi sẽ gửi link đặt lại mật khẩu cho bạn.',
                          textAlign: TextAlign.center,
                          style: subtitleStyle,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const ValueKey('forgot_password_email'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: autovalidateMode,
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading ? null : _sendResetEmail,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Gửi link đặt lại mật khẩu',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                          ),
                        ),
                        if (_firebaseError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _firebaseError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (Navigator.canPop(context)) {
                                    context.pop();
                                  } else {
                                    context.go('/signin');
                                  }
                                },
                          child: const Text('Quay lại đăng nhập'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
