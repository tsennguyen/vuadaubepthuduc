import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String fromUid;
  final String targetType;
  final String targetId;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.fromUid,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'] as Timestamp?;
    return AppNotification(
      id: doc.id,
      type: (data['type'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      fromUid: (data['fromUid'] as String?) ?? '',
      targetType: (data['targetType'] as String?) ?? '',
      targetId: (data['targetId'] as String?) ?? '',
      createdAt: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      read: data['read'] as bool? ?? false,
    );
  }
}

