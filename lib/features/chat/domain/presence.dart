import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceData {
  const PresenceData({
    required this.isOnline,
    this.lastSeenAt,
  });

  final bool isOnline;
  final DateTime? lastSeenAt;

  factory PresenceData.fromMap(Map<String, dynamic> data) {
    return PresenceData(
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeenAt: _toDateTime(data['lastSeenAt']),
    );
  }
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  return null;
}
