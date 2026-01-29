import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _adminRoleValue = 'admin';

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

Future<bool> checkIsAdmin({
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
}) async {
  final authInstance = auth ?? FirebaseAuth.instance;
  final firestoreInstance = firestore ?? FirebaseFirestore.instance;

  final user = authInstance.currentUser;
  if (user == null) return false;

  try {
    final doc =
        await firestoreInstance.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;

    final data = doc.data();
    final role = (data?['role'] as String?)?.toLowerCase();
    final disabled = _parseBool(data?['disabled']);
    return role == _adminRoleValue && !disabled;
  } catch (_) {
    return false;
  }
}

FutureOr<String?> adminOnlyRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) return '/signin';

  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await checkIsAdmin();
  if (ok) return null;

  final isVi = Localizations.localeOf(context).languageCode == 'vi';
  messenger?.showSnackBar(
    SnackBar(content: Text(isVi ? 'Bạn không có quyền truy cập trang quản trị.' : 'You do not have permission to access the admin area.')),
  );
  return '/feed';
}
