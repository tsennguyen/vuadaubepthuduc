import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatViolation {
  const ChatViolation({
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.offenderId,
    required this.type,
    required this.violationCategories,
    required this.severity,
    required this.messageSummary,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    required this.status,
    this.notes,
    this.evidenceMessages = const [],
    this.evidenceImages = const [],
  });

  final String id;
  final String chatId;
  final String messageId;
  final String offenderId;
  final String type;
  final List<String> violationCategories;
  final String severity;
  final String messageSummary;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String status;
  final String? notes;
  final List<Map<String, dynamic>> evidenceMessages;
  final List<String> evidenceImages;

  factory ChatViolation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = _toDateTime(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ChatViolation(
      id: doc.id,
      chatId: (data['chatId'] as String? ?? '').trim(),
      messageId: (data['messageId'] as String? ?? '').trim(),
      offenderId: (data['offenderId'] as String? ??
              data['senderId'] as String? ??
              data['userId'] as String? ??
              '')
          .trim(),
      type: (data['type'] as String? ?? 'text').trim(),
      violationCategories: _stringList(data['violationCategories']),
      severity: (data['severity'] as String? ?? 'medium').trim(),
      messageSummary: (data['messageSummary'] as String? ?? '').trim(),
      createdAt: createdAt,
      reviewedAt: _toDateTime(data['reviewedAt']),
      reviewedBy: (data['reviewedBy'] as String?)?.trim(),
      status: (data['status'] as String? ?? 'pending').trim(),
      notes: (data['notes'] as String?)?.trim(),
      evidenceMessages: List<Map<String, dynamic>>.from(data['evidenceMessages'] ?? []),
      evidenceImages: _stringList(data['evidenceImages']),
    );
  }

  ChatViolation copyWith({
    String? id,
    String? chatId,
    String? messageId,
    String? offenderId,
    String? type,
    List<String>? violationCategories,
    String? severity,
    String? messageSummary,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? status,
    String? notes,
    List<Map<String, dynamic>>? evidenceMessages,
    List<String>? evidenceImages,
  }) {
    return ChatViolation(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      offenderId: offenderId ?? this.offenderId,
      type: type ?? this.type,
      violationCategories: violationCategories ?? this.violationCategories,
      severity: severity ?? this.severity,
      messageSummary: messageSummary ?? this.messageSummary,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      evidenceMessages: evidenceMessages ?? this.evidenceMessages,
      evidenceImages: evidenceImages ?? this.evidenceImages,
    );
  }
}

class AdminChatUser {
  const AdminChatUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.isBanned = false,
    this.banReason,
    this.banUntil,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isBanned;
  final String? banReason;
  final DateTime? banUntil;
}

class ChatMeta {
  const ChatMeta({
    required this.id,
    required this.isGroup,
    required this.name,
    required this.memberCount,
    required this.isLocked,
    this.lastViolationAt,
    this.violationCount24h = 0,
  });

  final String id;
  final bool isGroup;
  final String? name;
  final int memberCount;
  final bool isLocked;
  final DateTime? lastViolationAt;
  final int violationCount24h;
}

class ChatViolationRecord {
  const ChatViolationRecord({
    required this.violation,
    this.offender,
    this.chat,
  });

  final ChatViolation violation;
  final AdminChatUser? offender;
  final ChatMeta? chat;
}

class ChatViolationMetrics {
  const ChatViolationMetrics({
    required this.userViolationsAllTime,
    required this.userViolations7d,
    required this.chatViolations7d,
  });

  final int userViolationsAllTime;
  final int userViolations7d;
  final int chatViolations7d;
}

enum ChatViolationStatus { all, pending, warning, muted, banned, ignored }

enum ChatViolationSeverity { all, low, medium, high, critical }

enum ChatViolationTimeRange { all, last24h, last7d, last30d }

class ChatViolationFilter {
  const ChatViolationFilter({
    this.status = ChatViolationStatus.all,
    this.severity = ChatViolationSeverity.all,
    this.timeRange = ChatViolationTimeRange.last24h,
    this.search = '',
  });

  final ChatViolationStatus status;
  final ChatViolationSeverity severity;
  final ChatViolationTimeRange timeRange;
  final String search;

  DateTime? get startTime {
    final now = DateTime.now();
    switch (timeRange) {
      case ChatViolationTimeRange.last24h:
        return now.subtract(const Duration(hours: 24));
      case ChatViolationTimeRange.last7d:
        return now.subtract(const Duration(days: 7));
      case ChatViolationTimeRange.last30d:
        return now.subtract(const Duration(days: 30));
      case ChatViolationTimeRange.all:
        return null;
    }
  }

  ChatViolationFilter copyWith({
    ChatViolationStatus? status,
    ChatViolationSeverity? severity,
    ChatViolationTimeRange? timeRange,
    String? search,
  }) {
    return ChatViolationFilter(
      status: status ?? this.status,
      severity: severity ?? this.severity,
      timeRange: timeRange ?? this.timeRange,
      search: search ?? this.search,
    );
  }
}

abstract class AdminChatModerationRepository {
  Stream<List<ChatViolationRecord>> watchViolations(ChatViolationFilter filter);

  Future<void> updateStatus({
    required String violationId,
    required ChatViolationStatus status,
    String? notes,
    String? reviewerId,
  });

  Future<void> warnViolation({
    required ChatViolation violation,
    String? notes,
    String? reviewerId,
  });

  Future<void> ignoreViolation({
    required ChatViolation violation,
    String? notes,
    String? reviewerId,
  });

  Future<void> banUserFromViolation({
    required ChatViolation violation,
    String? reason,
    DateTime? until,
    String? reviewerId,
  });

  Future<void> unbanUser(String uid);

  Future<void> lockChatFromViolation({
    required ChatViolation violation,
    String? reviewerId,
  });

  Future<void> unlockChat({
    required String chatId,
    String? violationId,
    String? reviewerId,
  });

  Future<ChatViolationMetrics> fetchMetrics({
    required String offenderId,
    required String chatId,
  });

  Future<void> deleteChat({
    required String chatId,
    String? violationId,
    String? reviewerId,
  });
}

class FirestoreAdminChatModerationRepository
    implements AdminChatModerationRepository {
  FirestoreAdminChatModerationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _violations =>
      _firestore.collection('chatViolations');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  final Map<String, AdminChatUser> _userCache = {};
  final Map<String, ChatMeta> _chatCache = {};

  @override
  Stream<List<ChatViolationRecord>> watchViolations(
    ChatViolationFilter filter,
  ) {
    Query<Map<String, dynamic>> query = _violations;

    if (filter.status != ChatViolationStatus.all) {
      query = query.where('status', isEqualTo: filter.status.name);
    }

    if (filter.severity != ChatViolationSeverity.all) {
      query = query.where('severity', isEqualTo: _severityToString(filter.severity));
    }

    final start = filter.startTime;
    if (start != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }

    query = query.orderBy('createdAt', descending: true).limit(100);

    return query.snapshots().asyncMap((snapshot) async {
      final search = filter.search.trim().toLowerCase();
      final futures = snapshot.docs.map((doc) async {
        final violation = ChatViolation.fromDoc(doc);
        // Self-heal: If offenderId is missing but we have messageId and chatId, try to fetch it
        var finalViolation = violation;
        if (violation.offenderId.isEmpty &&
            violation.chatId.isNotEmpty &&
            violation.messageId.isNotEmpty) {
          try {
            final msgSnap = await _firestore
                .collection('chats')
                .doc(violation.chatId)
                .collection('messages')
                .doc(violation.messageId)
                .get();
            if (msgSnap.exists) {
              final sender = (msgSnap.data()?['senderId'] ??
                  msgSnap.data()?['authorId']) as String?;
              if (sender != null && sender.isNotEmpty) {
                finalViolation = violation.copyWith(offenderId: sender);
                // Optional: Update DB to persist the fix
                 _violations.doc(violation.id).update({'offenderId': sender});
              }
            }
          } catch (_) {
            // Ignore error, just stay with empty offender
          }
        }

        final offender = await _loadUser(finalViolation.offenderId);
        final chat = await _loadChat(finalViolation.chatId);

        if (search.isNotEmpty &&
            !_matchesSearch(search, finalViolation, offender, chat)) {
          return null;
        }

        return ChatViolationRecord(
          violation: finalViolation,
          offender: offender,
          chat: chat,
        );
      }).toList();

      final results = await Future.wait(futures);
      return results.whereType<ChatViolationRecord>().toList();
    });
  }

  @override
  Future<void> updateStatus({
    required String violationId,
    required ChatViolationStatus status,
    String? notes,
    String? reviewerId,
  }) async {
    await _violations.doc(violationId).set({
      'status': status.name,
      'notes': notes,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewerId,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> warnViolation({
    required ChatViolation violation,
    String? notes,
    String? reviewerId,
  }) async {
    await _violations.doc(violation.id).set({
      'status': 'warning',
      'notes': notes,
      'adminNote': notes,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> ignoreViolation({
    required ChatViolation violation,
    String? notes,
    String? reviewerId,
  }) async {
    await _violations.doc(violation.id).set({
      'status': 'ignored',
      'notes': notes,
      'adminNote': notes,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> banUserFromViolation({
    required ChatViolation violation,
    String? reason,
    DateTime? until,
    String? reviewerId,
  }) async {
    final banReason = (reason?.trim().isNotEmpty == true)
        ? reason!.trim()
        : (violation.messageSummary.isNotEmpty
            ? violation.messageSummary
            : 'Violated chat policy');
    await _users.doc(violation.offenderId).set(
      {
        'isBanned': true,
        'banReason': banReason,
        'banUntil': until != null ? Timestamp.fromDate(until) : null,
      },
      SetOptions(merge: true),
    );
    await _violations.doc(violation.id).set({
      'status': 'banned',
      'action': 'user_banned',
      'notes': banReason,
      'adminNote': banReason,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unbanUser(String uid) async {
    await _users.doc(uid).set(
      {
        'isBanned': false,
        'banReason': null,
        'banUntil': null,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> lockChatFromViolation({
    required ChatViolation violation,
    String? reviewerId,
  }) async {
    await _chats.doc(violation.chatId).set(
      {
        'isLocked': true,
        'lastLockedAt': FieldValue.serverTimestamp(),
        'lockedByAdminId': reviewerId,
      },
      SetOptions(merge: true),
    );
    await _violations.doc(violation.id).set({
      'status': 'chat_locked',
      'action': 'chat_locked',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unlockChat({
    required String chatId,
    String? violationId,
    String? reviewerId,
  }) async {
    await _chats.doc(chatId).set(
      {
        'isLocked': false,
      },
      SetOptions(merge: true),
    );
    if (violationId != null && violationId.isNotEmpty) {
      await _violations.doc(violationId).set({
        'status': 'chat_unlocked',
        'action': 'chat_unlocked',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> deleteChat({
    required String chatId,
    String? violationId,
    String? reviewerId,
  }) async {
    await _chats.doc(chatId).delete();
    if (violationId != null && violationId.isNotEmpty) {
      await _violations.doc(violationId).set({
        'status': 'resolved',
        'action': 'chat_deleted',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewerId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<ChatViolationMetrics> fetchMetrics({
    required String offenderId,
    required String chatId,
  }) async {
    final now = DateTime.now();
    final since7d = Timestamp.fromDate(now.subtract(const Duration(days: 7)));

    final userAll = await _violations
        .where('offenderId', isEqualTo: offenderId)
        .count()
        .get();
    final user7d = await _violations
        .where('offenderId', isEqualTo: offenderId)
        .where('createdAt', isGreaterThanOrEqualTo: since7d)
        .count()
        .get();
    final chat7d = await _violations
        .where('chatId', isEqualTo: chatId)
        .where('createdAt', isGreaterThanOrEqualTo: since7d)
        .count()
        .get();

    return ChatViolationMetrics(
      userViolationsAllTime: userAll.count ?? 0,
      userViolations7d: user7d.count ?? 0,
      chatViolations7d: chat7d.count ?? 0,
    );
  }

  Future<AdminChatUser?> _loadUser(String uid) async {
    if (uid.isEmpty) return null;
    if (_userCache.containsKey(uid)) return _userCache[uid];

    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (data == null) return null;

    final user = AdminChatUser(
      uid: uid,
      displayName: (data['displayName'] ??
          data['fullName'] ??
          data['name'] ??
          data['username']) as String?,
      email: data['email'] as String?,
      photoUrl: data['photoURL'] as String? ??
          data['photoUrl'] as String? ??
          data['avatar'] as String? ??
          data['image'] as String?,
      isBanned: _parseBool(data['isBanned']),
      banReason: (data['banReason'] as String?)?.trim(),
      banUntil: _toDateTime(data['banUntil']),
    );
    _userCache[uid] = user;
    return user;
  }

  Future<ChatMeta?> _loadChat(String chatId) async {
    if (chatId.isEmpty) return null;
    if (_chatCache.containsKey(chatId)) return _chatCache[chatId];

    final snap = await _chats.doc(chatId).get();
    final data = snap.data();
    if (data == null) return null;

    final meta = ChatMeta(
      id: chatId,
      isGroup: _parseBool(data['isGroup']) ||
          ((data['type'] as String?)?.toLowerCase() == 'group'),
      name: (data['name'] as String?)?.trim(),
      memberCount: (data['memberIds'] is List) ? (data['memberIds'] as List).length : 0,
      isLocked: _parseBool(data['isLocked']),
      lastViolationAt: _toDateTime(data['lastViolationAt']),
      violationCount24h: (data['violationCount24h'] as num?)?.toInt() ?? 0,
    );
    _chatCache[chatId] = meta;
    return meta;
  }

  bool _matchesSearch(
    String search,
    ChatViolation violation,
    AdminChatUser? offender,
    ChatMeta? chat,
  ) {
    if (violation.chatId.toLowerCase().contains(search)) return true;
    if (violation.offenderId.toLowerCase().contains(search)) return true;

    final offenderName = offender?.displayName?.toLowerCase() ?? '';
    final offenderEmail = offender?.email?.toLowerCase() ?? '';
    if (offenderName.contains(search) || offenderEmail.contains(search)) {
      return true;
    }

    final chatName = chat?.name?.toLowerCase() ?? '';
    if (chatName.contains(search)) return true;

    return false;
  }

  String _severityToString(ChatViolationSeverity severity) {
    switch (severity) {
      case ChatViolationSeverity.low:
        return 'low';
      case ChatViolationSeverity.medium:
        return 'medium';
      case ChatViolationSeverity.high:
        return 'high';
      case ChatViolationSeverity.critical:
        return 'critical';
      case ChatViolationSeverity.all:
        return '';
    }
  }
}

final adminChatModerationRepositoryProvider =
    Provider<AdminChatModerationRepository>((ref) {
  return FirestoreAdminChatModerationRepository();
});

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return false;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true).toLocal();
  }
  return null;
}
