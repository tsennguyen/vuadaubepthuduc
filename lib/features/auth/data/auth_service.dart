import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service layer for authentication flows (no UI here).
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      throw Exception('Email sign-in failed: $e');
    }
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      throw Exception('Email sign-up failed: $e');
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web uses the popup flow with the provider directly.
        final googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was canceled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  Future<UserCredential> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        // Web uses the popup flow with the provider directly.
        final facebookProvider = FacebookAuthProvider();
        return await _auth.signInWithPopup(facebookProvider);
      }

      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw Exception('Facebook sign-in was canceled or failed.');
      }

      final credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      throw Exception('Facebook sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // Best-effort sign-outs for each provider.
      if (!kIsWeb) {
        await Future.wait([
          _googleSignIn.signOut(),
          FacebookAuth.instance.logOut(),
        ]);
      }
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
        return 'Sai mật khẩu, vui lòng thử lại.';
      case 'email-already-in-use':
        return 'Email đã được đăng ký.';
      case 'weak-password':
        return 'Mật khẩu quá yếu, chọn mật khẩu mạnh hơn.';
      case 'account-exists-with-different-credential':
        return 'Tài khoản đã tồn tại với provider khác.';
      case 'invalid-credential':
        return 'Thông tin đăng nhập không hợp lệ hoặc đã hết hạn.';
      case 'operation-not-allowed':
        return 'Provider này chưa được bật trên Firebase Console.';
      case 'popup-closed-by-user':
        return 'Cửa sổ đăng nhập đã bị đóng trước khi hoàn tất.';
      case 'network-request-failed':
        return 'Lỗi mạng, vui lòng thử lại.';
      default:
        return 'Lỗi xác thực: ${e.message ?? e.code}';
    }
  }
}
