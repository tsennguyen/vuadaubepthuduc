import 'package:firebase_auth/firebase_auth.dart';

/// Email validator used across auth flows.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập email';
  }
  final email = value.trim();
  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  if (!emailRegex.hasMatch(email)) {
    return 'Email không hợp lệ';
  }
  return null;
}

/// Simple password validator for sign-in.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Vui lòng nhập mật khẩu';
  }
  return null;
}

/// Password rules for sign-up.
String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Vui lòng nhập mật khẩu';
  }
  if (value.length < 6) {
    return 'Mật khẩu phải từ 6 ký tự';
  }
  return null;
}

/// Confirmation password validator.
String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Vui lòng xác nhận mật khẩu';
  }
  if (value != password) {
    return 'Mật khẩu xác nhận không khớp';
  }
  return null;
}

/// Map Firebase Auth errors to human-friendly Vietnamese strings.
String mapFirebaseAuthErrorToMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Email không hợp lệ. Bạn kiểm tra lại nhé.';
    case 'user-not-found':
      return 'Tài khoản không tồn tại. Bạn thử đăng ký mới.';
    case 'wrong-password':
      return 'Mật khẩu không đúng. Bạn thử lại.';
    case 'user-disabled':
      return 'Tài khoản của bạn đã bị khoá. Liên hệ quản trị viên.';
    case 'too-many-requests':
      return 'Bạn thử đăng nhập quá nhiều lần. Vui lòng thử lại sau.';
    case 'network-request-failed':
      return 'Không thể kết nối mạng. Bạn kiểm tra lại internet.';
    case 'email-already-in-use':
      return 'Email đã tồn tại. Bạn thử đăng nhập hoặc dùng email khác.';
    case 'weak-password':
      return 'Mật khẩu phải từ 6 ký tự.';
    default:
      return 'Đăng nhập thất bại. Bạn thử lại sau.';
  }
}
