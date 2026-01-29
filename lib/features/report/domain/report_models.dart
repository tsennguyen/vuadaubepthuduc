import 'package:cloud_firestore/cloud_firestore.dart';

/// Schema chuẩn cho reports, dùng chung client + admin.
///
/// Firestore collection: `reports/{reportId}` (root collection, không dùng sub-collection).
///
/// Fields:
/// - `targetType`: "post" | "recipe" | "message" | "user"
/// - `targetId`: pid/rid/mid/uid tuỳ theo `targetType`
/// - `chatId`: string? (chỉ dùng khi `targetType == 'message'`)
/// - `reasonCode`: "spam" | "inappropriate" | "violence" | "fake_info" | "hate" | "other"
/// - `reasonText`: string? (optional)
/// - `reporterId`: uid người report (FirebaseAuth)
/// - `createdAt`: Timestamp (`FieldValue.serverTimestamp()`)
/// - `status`: "pending" | "resolved" | "ignored"
class CreateReportInput {
  final String targetType; // 'post' | 'recipe' | 'message' | 'user'
  final String targetId;
  final String? chatId;
  final String reasonCode; // spam/inappropriate/...
  final String? reasonText;

  const CreateReportInput({
    required this.targetType,
    required this.targetId,
    this.chatId,
    required this.reasonCode,
    this.reasonText,
  });
}

class Report {
  final String id;
  final String targetType;
  final String targetId;
  final String? chatId;
  final String reasonCode;
  final String? reasonText;
  final String reporterId;
  final DateTime createdAt;
  final String status;

  const Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.chatId,
    required this.reasonCode,
    this.reasonText,
    required this.reporterId,
    required this.createdAt,
    required this.status,
  });

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Report(
      id: doc.id,
      targetType: data['targetType'] as String? ?? 'post',
      targetId: data['targetId'] as String? ?? '',
      chatId: data['chatId'] as String?,
      reasonCode: data['reasonCode'] as String? ?? 'other',
      reasonText: data['reasonText'] as String?,
      reporterId: data['reporterId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: data['status'] as String? ?? 'pending',
    );
  }
}
