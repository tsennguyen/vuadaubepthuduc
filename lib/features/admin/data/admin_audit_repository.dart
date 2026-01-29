import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit log schema (minimal):
/// - Collection: `auditLogs/{logId}`
/// - Core fields:
///   - `type`: string
///   - `actorId`: string? (uid admin or "system")
///   - `targetType`: string? (post/recipe/message/user/report/...)
///   - `targetId`: string?
///   - `metadata`: map? (free-form, extensible)
///   - `createdAt`: Timestamp (serverTimestamp)
///
/// Note: Keep these core fields stable; add new info via `metadata`.
class AuditLog {
  final String id;
  final String type;
  final String? actorId;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.type,
    required this.actorId,
    required this.targetType,
    required this.targetId,
    required this.metadata,
    required this.createdAt,
  });

  factory AuditLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtValue = data['createdAt'];
    final createdAt = switch (createdAtValue) {
      Timestamp ts => ts.toDate(),
      DateTime dt => dt,
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };

    final rawMetadata = data['metadata'];
    final metadata = <String, dynamic>{};
    if (rawMetadata is Map) {
      for (final entry in rawMetadata.entries) {
        metadata[entry.key.toString()] = entry.value;
      }
    }

    return AuditLog(
      id: doc.id,
      type: (data['type'] as String?)?.trim() ?? 'unknown',
      actorId: (data['actorId'] as String?)?.trim(),
      targetType: (data['targetType'] as String?)?.trim(),
      targetId: (data['targetId'] as String?)?.trim(),
      metadata: metadata,
      createdAt: createdAt,
    );
  }
}

abstract class AdminAuditRepository {
  Stream<List<AuditLog>> watchAuditLogs({
    String? typeFilter,
    DateTime? from,
    DateTime? to,
  });
}

class FirestoreAdminAuditRepository implements AdminAuditRepository {
  FirestoreAdminAuditRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _firestore.collection('auditLogs');

  @override
  Stream<List<AuditLog>> watchAuditLogs({
    String? typeFilter,
    DateTime? from,
    DateTime? to,
  }) {
    Query<Map<String, dynamic>> query = _auditLogs;

    final trimmedType = typeFilter?.trim();
    if (trimmedType != null && trimmedType.isNotEmpty && trimmedType != 'all') {
      query = query.where('type', isEqualTo: trimmedType);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AuditLog.fromDoc).toList())
        .map((logs) => _filterByTimeRange(logs, from: from, to: to));
  }

  List<AuditLog> _filterByTimeRange(
    List<AuditLog> logs, {
    DateTime? from,
    DateTime? to,
  }) {
    if (from == null && to == null) return logs;
    return logs.where((log) {
      if (from != null && log.createdAt.isBefore(from)) return false;
      if (to != null && log.createdAt.isAfter(to)) return false;
      return true;
    }).toList(growable: false);
  }
}

