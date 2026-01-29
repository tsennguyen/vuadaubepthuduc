import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReport {
  final String id;
  final String targetType; // post/recipe/message/user
  final String targetId;
  final String? chatId;
  final String reasonCode;
  final String? reasonText;
  final String reporterId;
  final String reporterName; // Display name of the reporter
  final DateTime createdAt;
  final String status; // pending/resolved/ignored

  const AdminReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.chatId,
    required this.reasonCode,
    required this.reasonText,
    required this.reporterId,
    required this.reporterName,
    required this.createdAt,
    required this.status,
  });

  factory AdminReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtValue = data['createdAt'];
    final createdAt = switch (createdAtValue) {
      Timestamp ts => ts.toDate(),
      DateTime dt => dt,
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };

    return AdminReport(
      id: doc.id,
      targetType: (data['targetType'] as String?)?.trim() ?? '',
      targetId: (data['targetId'] as String?)?.trim() ?? '',
      chatId: (data['chatId'] as String?)?.trim(),
      reasonCode: (data['reasonCode'] as String?)?.trim() ?? '',
      reasonText: (data['reasonText'] as String?)?.trim(),
      reporterId: (data['reporterId'] as String?)?.trim() ?? '',
      reporterName: '', // Will be resolved separately
      createdAt: createdAt,
      status: (data['status'] as String?)?.trim() ?? 'pending',
    );
  }
}

enum ReportStatusFilter { all, pending, resolved, ignored }

abstract class AdminReportRepository {
  Stream<List<AdminReport>> watchReports(ReportStatusFilter filter);
  Future<void> updateReportStatus(String id, String status);
}

class FirestoreAdminReportRepository implements AdminReportRepository {
  FirestoreAdminReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  static const allowedStatuses = <String>{'pending', 'resolved', 'ignored'};

  @override
  Stream<List<AdminReport>> watchReports(ReportStatusFilter filter) {
    Query<Map<String, dynamic>> query = _reports;

    if (filter != ReportStatusFilter.all) {
      query = query.where('status', isEqualTo: _statusValue(filter));
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminReport.fromDoc).toList());
  }

  @override
  Future<void> updateReportStatus(String id, String status) async {
    final normalized = status.trim().toLowerCase();
    if (!allowedStatuses.contains(normalized)) {
      throw ArgumentError.value(status, 'status', 'Invalid status');
    }
    await _reports.doc(id).update({'status': normalized});
  }

  static String _statusValue(ReportStatusFilter filter) {
    switch (filter) {
      case ReportStatusFilter.all:
        return 'all';
      case ReportStatusFilter.pending:
        return 'pending';
      case ReportStatusFilter.resolved:
        return 'resolved';
      case ReportStatusFilter.ignored:
        return 'ignored';
    }
  }
}

