import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../features/auth/data/user_repository.dart';

class GoogleAuthService {
  GoogleAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    required this.userRepository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserRepository userRepository;

  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(googleProvider);
      final user = cred.user;
      if (user != null) {
        await userRepository.createUserIfNotExists(
          user,
          provider: 'google',
          fullName: user.displayName,
        );
        await userRepository.updateLastLogin(user.uid);
      }
      return user;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user != null) {
      await userRepository.createUserIfNotExists(
        user,
        provider: 'google',
        fullName: user.displayName,
      );
      await userRepository.updateLastLogin(user.uid);
    }
    return user;
  }
}
