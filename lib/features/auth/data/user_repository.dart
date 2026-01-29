import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createUserIfNotExists(
    User user, {
    String? fullName,
    String provider = 'password',
  }) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();
    final data = {
      'uid': user.uid,
      'email': user.email,
      'fullName': fullName ?? user.displayName,
      'photoURL': user.photoURL,
      'provider': provider,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
    if (!doc.exists) {
      await docRef.set(data);
    } else {
      final update = {
        'email': user.email,
        'fullName': fullName ?? user.displayName,
        'photoURL': user.photoURL,
        'provider': provider,
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      await docRef.update(update);
    }
  }

  Future<void> updateLastLogin(String uid) async {
    await _users.doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }
}
