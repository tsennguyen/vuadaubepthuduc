import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_repository.dart';
import '../domain/user_summary.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<UserSummary?> watchUser(String uid) {
    if (uid.isEmpty) return Stream<UserSummary?>.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserSummary.fromDoc(doc);
    });
  }

  @override
  Future<UserSummary?> getUserOnce(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserSummary.fromDoc(doc);
  }

  @override
  Stream<Map<String, UserSummary>> watchUsersByIds(Set<String> uids) {
    final filtered = uids.where((e) => e.isNotEmpty).toSet();
    if (filtered.isEmpty) {
      return Stream<Map<String, UserSummary>>.value({});
    }

    final chunks = _chunk(filtered.toList(), 10);
    final controller = StreamController<Map<String, UserSummary>>();
    final current = <String, UserSummary>{};
    final subs = <StreamSubscription>[];

    void emit() {
      if (!controller.isClosed) {
        controller.add(Map<String, UserSummary>.from(current));
      }
    }

    for (final chunk in chunks) {
      final sub = _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .listen((snap) {
        final seen = <String>{};
        for (final doc in snap.docs) {
          final summary = UserSummary.fromDoc(doc);
          current[summary.uid] = summary;
          seen.add(summary.uid);
        }
        for (final uid in chunk) {
          if (!seen.contains(uid)) current.remove(uid);
        }
        emit();
      });
      subs.add(sub);
    }

    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  List<List<String>> _chunk(List<String> items, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size) > items.length ? items.length : i + size;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }
}
