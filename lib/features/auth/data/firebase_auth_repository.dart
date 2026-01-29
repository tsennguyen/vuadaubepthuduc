import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Repository trung tâm cho các thao tác Firebase Auth.
class FirebaseAuthRepository {
  FirebaseAuthRepository(
    this._auth, {
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Check if user is banned or disabled
      await _checkUserStatus(credential.user?.uid);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthException(e));
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null && displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }
      // Optional: lưu hồ sơ cơ bản vào Firestore (role = client).
      await _writeUserProfile(user, displayName: displayName, provider: 'password');
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthException(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthException(e));
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final credential = await _auth.signInWithPopup(GoogleAuthProvider());
        await _writeUserProfile(credential.user, provider: 'google');
        await _checkUserStatus(credential.user?.uid);
        return credential;
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Bạn đã hủy đăng nhập Google.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      await _writeUserProfile(userCredential.user, provider: 'google');
      await _checkUserStatus(userCredential.user?.uid);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthException(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // Try to sign out from Google, but don't fail if it's not configured (e.g., on web)
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Ignore Google Sign-In errors (e.g., missing clientId on web)
      debugPrint('Google Sign-In signOut failed: $e');
    }
  }

  /// Check if user is banned or disabled after login
  Future<void> _checkUserStatus(String? uid) async {
    if (uid == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      
      final data = doc.data();
      if (data == null) return;
      
      // Check if user is disabled
      final disabled = data['disabled'] == true;
      if (disabled) {
        await signOut();
        throw AuthException('Tài khoản của bạn đã bị khóa bởi quản trị viên. Vui lòng liên hệ hỗ trợ để biết thêm chi tiết.');
      }
      
      // Check if user is banned
      final isBanned = data['isBanned'] == true;
      if (isBanned) {
        final banUntil = (data['banUntil'] as Timestamp?)?.toDate();
        
        // Check if temporary ban has expired
        if (banUntil != null && DateTime.now().isAfter(banUntil)) {
          // Auto-unban
          await _firestore.collection('users').doc(uid).update({
            'isBanned': false,
            'banReason': null,
            'banUntil': null,
          });
          return; // Allow login
        }
        
        await signOut();
        final banReason = data['banReason'] as String?;
        final banMessage = banReason != null && banReason.isNotEmpty
            ? 'Tài khoản bị cấm: $banReason'
            : 'Tài khoản của bạn đã bị cấm bởi quản trị viên.';
        
        if (banUntil != null) {
          final daysLeft = banUntil.difference(DateTime.now()).inDays;
          throw AuthException('$banMessage Thời gian còn lại: $daysLeft ngày.');
        }
        
        throw AuthException(banMessage);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      // Don't block login if we can't check status
      debugPrint('Error checking user status: $e');
    }
  }

  Future<void> _writeUserProfile(
    User? user, {
    String? displayName,
    String provider = 'password',
  }) async {
    if (user == null) return;
    final doc = _firestore.collection('users').doc(user.uid);
    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : user.displayName,
      'photoURL': user.photoURL,
      'provider': provider,
      'role': 'client',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    final snapshot = await doc.get();
    if (snapshot.exists) {
      await doc.update({
        ...data,
        'createdAt': snapshot.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      });
    } else {
      await doc.set(data);
    }
  }

  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ. Bạn kiểm tra lại nhé.';
      case 'user-not-found':
        return 'Tài khoản không tồn tại. Bạn thử đăng ký mới.';
      case 'wrong-password':
        return 'Mật khẩu không đúng. Bạn thử lại.';
      case 'weak-password':
        return 'Mật khẩu phải từ 6 ký tự.';
      case 'email-already-in-use':
        return 'Email đã tồn tại. Bạn thử đăng nhập hoặc dùng email khác.';
      case 'too-many-requests':
        return 'Bạn thử đăng nhập quá nhiều lần. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Không thể kết nối mạng. Bạn kiểm tra lại internet.';
      case 'user-disabled':
        return 'Tài khoản của bạn đã bị khoá. Liên hệ quản trị viên.';
      case 'popup-closed-by-user':
        return 'Bạn đã đóng cửa sổ đăng nhập Google.';
      case 'account-exists-with-different-credential':
        return 'Email này đã liên kết với phương thức khác.';
      default:
        return 'Đăng nhập thất bại. Bạn thử lại sau.';
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Riverpod provider tiện dụng cho repository.
final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  return FirebaseAuthRepository(FirebaseAuth.instance);
});
