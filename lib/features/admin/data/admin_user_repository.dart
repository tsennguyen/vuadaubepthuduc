import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String role;
  final bool disabled;
  final bool isBanned;
  final String? banReason;
  final DateTime? banUntil;

  const AdminUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    required this.role,
    required this.disabled,
    required this.isBanned,
    this.banReason,
    this.banUntil,
  });

  factory AdminUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminUser(
      uid: doc.id,
      displayName:
          (data['displayName'] ?? data['fullName'] ?? data['name']) as String?,
      email: data['email'] as String?,
      photoUrl: data['photoURL'] as String?,
      role: (data['role'] as String?)?.toLowerCase() ?? 'client',
      disabled: _parseBool(data['disabled']),
      isBanned: _parseBool(data['isBanned']),
      banReason: (data['banReason'] as String?)?.trim(),
      banUntil: (data['banUntil'] as Timestamp?)?.toDate(),
    );
  }
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return false;
}

abstract class AdminUserRepository {
  /// Search strategy:
  /// - When [query] is empty: load first 50 users ordered by displayName.
  /// - When [query] is provided: run prefix search on BOTH `email` and
  ///   `displayName`, then union results client-side (OR emulation).
  Stream<List<AdminUser>> watchUsers({String? query});
  Future<void> updateUserRole(String uid, String role);
  Future<void> toggleUserDisabled(String uid, bool disabled);
  Future<void> setBanStatus(
    String uid, {
    required bool isBanned,
    String? banReason,
    DateTime? banUntil,
  });
}

class FirestoreAdminUserRepository implements AdminUserRepository {
  FirestoreAdminUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static const allowedRoles = <String>{'admin', 'moderator', 'client'};

  @override
  Stream<List<AdminUser>> watchUsers({String? query}) {
    final trimmed = query?.trim().toLowerCase() ?? '';
    
    // Load all users (limit 200 for admin panel)
    return _users
        .orderBy('displayName')
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs.map(AdminUser.fromDoc).toList();
          
          // If no query, return all
          if (trimmed.isEmpty) {
            users.sort(_compareUsers);
            return users;
          }
          
          // Filter client-side for flexible search
          final filtered = users.where((user) {
            final email = (user.email ?? '').toLowerCase();
            final displayName = (user.displayName ?? '').toLowerCase();
            
            // Check if query matches email
            if (email.contains(trimmed)) return true;
            
            // Check if query matches any word in display name
            if (displayName.contains(trimmed)) return true;
            
            // Check if query matches start of any word in display name
            final words = displayName.split(' ');
            for (final word in words) {
              if (word.startsWith(trimmed)) return true;
            }
            
            return false;
          }).toList();
          
          filtered.sort(_compareUsers);
          return filtered;
        });
  }

  @override
  Future<void> updateUserRole(String uid, String role) async {
    final normalizedRole = role.trim().toLowerCase();
    if (!allowedRoles.contains(normalizedRole)) {
      throw ArgumentError.value(role, 'role', 'Invalid role');
    }
    await _users.doc(uid).update({'role': normalizedRole});
  }

  @override
  Future<void> toggleUserDisabled(String uid, bool disabled) async {
    await _users.doc(uid).update({'disabled': disabled});
  }

  @override
  Future<void> setBanStatus(
    String uid, {
    required bool isBanned,
    String? banReason,
    DateTime? banUntil,
  }) async {
    await _users.doc(uid).set(
      {
        'isBanned': isBanned,
        'banReason': banReason,
        'banUntil': banUntil != null ? Timestamp.fromDate(banUntil) : null,
      },
      SetOptions(merge: true),
    );
  }

  int _compareUsers(AdminUser a, AdminUser b) {
    final nameA = (a.displayName ?? '').toLowerCase();
    final nameB = (b.displayName ?? '').toLowerCase();
    if (nameA != nameB) return nameA.compareTo(nameB);
    final emailA = (a.email ?? '').toLowerCase();
    final emailB = (b.email ?? '').toLowerCase();
    if (emailA != emailB) return emailA.compareTo(emailB);
    return a.uid.compareTo(b.uid);
  }

}
