import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled,
}

FriendRequestStatus _parseStatus(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'accepted':
      return FriendRequestStatus.accepted;
    case 'rejected':
      return FriendRequestStatus.rejected;
    case 'cancelled':
      return FriendRequestStatus.cancelled;
    default:
      return FriendRequestStatus.pending;
  }
}

String _statusToString(FriendRequestStatus status) {
  switch (status) {
    case FriendRequestStatus.pending:
      return 'pending';
    case FriendRequestStatus.accepted:
      return 'accepted';
    case FriendRequestStatus.rejected:
      return 'rejected';
    case FriendRequestStatus.cancelled:
      return 'cancelled';
  }
}

class FriendRequest {
  FriendRequest({
    required this.id,
    required this.requesterId,
    required this.targetId,
    required this.status,
    this.createdAt,
    this.respondedAt,
    this.lastUpdatedAt,
    this.snapshot,
  });

  final String id;
  final String requesterId;
  final String targetId;
  final FriendRequestStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? lastUpdatedAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  FriendRequest copyWith({
    FriendRequestStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? lastUpdatedAt,
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  }) {
    return FriendRequest(
      id: id,
      requesterId: requesterId,
      targetId: targetId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      snapshot: snapshot ?? this.snapshot,
    );
  }

  factory FriendRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FriendRequest(
      id: doc.id,
      requesterId: data['requesterId'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp?)?.toDate(),
      snapshot: doc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requesterId': requesterId,
      'targetId': targetId,
      'status': _statusToString(status),
      'createdAt': createdAt,
      'respondedAt': respondedAt,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }
}

class Friend {
  const Friend({
    required this.friendUid,
    this.createdAt,
    this.lastInteractionAt,
    this.snapshot,
  });

  final String friendUid;
  final DateTime? createdAt;
  final DateTime? lastInteractionAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  factory Friend.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Friend(
      friendUid: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastInteractionAt: (data['lastInteractionAt'] as Timestamp?)?.toDate(),
      snapshot: doc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt,
      'lastInteractionAt': lastInteractionAt,
    };
  }
}

