import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/report_models.dart';
import '../../profile/domain/user_ban_guard.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/data/firebase_profile_repository.dart';

/// Schema chuẩn cho reports, dùng chung client + admin.
///
/// Firestore collection: `reports/{reportId}`.
///
/// ⚠️ Không thêm field ngoài schema đã mô tả; nếu cần mở rộng sau thì TODO
/// "schema cần thêm" ở đúng chỗ sử dụng.
abstract class ReportRepository {
  Future<void> createReport(CreateReportInput input);
}

class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException();

  @override
  String toString() =>
      'NotAuthenticatedException: User must be signed in to create a report.';
}

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    UserBanGuard? userBanGuard,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _banGuard = userBanGuard ??
            UserBanGuard(profileRepository: FirebaseProfileRepository());

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UserBanGuard _banGuard;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  @override
  Future<void> createReport(CreateReportInput input) async {
    await _banGuard.ensureNotBanned();
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const NotAuthenticatedException();
    }

    if (input.targetType == 'message') {
      final chatId = input.chatId;
      if (chatId == null || chatId.isEmpty) {
        throw ArgumentError.value(
          input.chatId,
          'chatId',
          'chatId is required when targetType == "message".',
        );
      }
    }

    await _reports.add({
      'targetType': input.targetType,
      'targetId': input.targetId,
      'chatId': input.chatId,
      'reasonCode': input.reasonCode,
      'reasonText': input.reasonText,
      'reporterId': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(
    userBanGuard: ref.watch(userBanGuardProvider),
  );
});
