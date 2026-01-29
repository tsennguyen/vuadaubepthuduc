import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUserSummary {
  AppUserSummary({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.snapshot,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  factory AppUserSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final name = (data['displayName'] ??
            data['fullName'] ??
            data['name'] ??
            '') as String? ??
        '';
    return AppUserSummary(
      uid: doc.id,
      displayName: name,
      photoUrl: data['photoURL'] as String?,
      snapshot: doc,
    );
  }
}

abstract class UserDirectoryRepository {
  Stream<List<AppUserSummary>> watchAllUsers({String? excludeUid});
}

class UserDirectoryRepositoryImpl implements UserDirectoryRepository {
  UserDirectoryRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AppUserSummary>> watchAllUsers({String? excludeUid}) {
    return _firestore.collection('users').snapshots().map(
      (snap) {
        return snap.docs
            .map(AppUserSummary.fromDoc)
            .where((u) => excludeUid == null || u.uid != excludeUid)
            .toList();
      },
    );
  }
}

final userDirectoryRepositoryProvider =
    Provider<UserDirectoryRepository>((ref) {
  return UserDirectoryRepositoryImpl();
});

final allUsersStreamProvider =
    StreamProvider.autoDispose<List<AppUserSummary>>((ref) {
  final repo = ref.watch(userDirectoryRepositoryProvider);
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  return repo.watchAllUsers(excludeUid: currentUid);
});
