import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSummary {
  final String id;
  final bool isGroup;
  final String? name;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? photoUrl;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;

  const ChatSummary({
    required this.id,
    required this.isGroup,
    required this.name,
    required this.memberIds,
    required this.adminIds,
    required this.photoUrl,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
  });

  String get type => isGroup ? 'group' : 'dm';

  factory ChatSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final memberIds = _stringList(data['memberIds']);
    final adminIds = _stringList(data['adminIds']);
    final isGroup = (data['isGroup'] as bool?) ??
        ((data['type'] as String?)?.trim().toLowerCase() == 'group');

    return ChatSummary(
      id: doc.id,
      isGroup: isGroup,
      name: (data['name'] as String?)?.trim(),
      memberIds: memberIds,
      adminIds: adminIds.isNotEmpty ? adminIds : memberIds,
      photoUrl: data['photoUrl'] as String?,
      lastMessageText: (data['lastMessageText'] as String?)?.trim(),
      lastMessageSenderId: (data['lastMessageSenderId'] as String?) ??
          (data['lastMessageAuthorId'] as String?),
      lastMessageAt: _toDateTime(data['lastMessageAt']),
    );
  }
}

class AdminMessage {
  final String id;
  final String senderId;
  final String text;
  final String type;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const AdminMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.createdAt,
    required this.deletedAt,
  });

  factory AdminMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt =
        _toDateTime(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);

    final deleted = data['deleted'] as bool? ?? false;
    final deletedAt = _toDateTime(data['deletedAt']);
    final type = (data['type'] as String?)?.trim() ?? 'text';
    final text = (data['text'] as String?)?.trim() ?? '';
    final fallback =
        type == 'image' ? '[Image]' : type == 'video' ? '[Video]' : type == 'audio' ? '[Audio]' : type == 'file' ? '[File]' : '';

    final sender = (data['senderId'] as String?)?.trim() ??
        (data['authorId'] as String?)?.trim() ??
        '';

    return AdminMessage(
      id: doc.id,
      senderId: sender,
      text: (deleted || deletedAt != null) ? '[deleted]' : (text.isNotEmpty ? text : fallback),
      type: type,
      createdAt: createdAt,
      deletedAt: deletedAt,
    );
  }
}

enum ChatTypeFilter { all, dm, group }

abstract class AdminChatRepository {
  Stream<List<ChatSummary>> watchChats({
    ChatTypeFilter typeFilter,
    String? userIdFilter,
  });

  Stream<List<AdminMessage>> watchMessages(String chatId);
}

class FirestoreAdminChatRepository implements AdminChatRepository {
  FirestoreAdminChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  @override
  Stream<List<ChatSummary>> watchChats({
    ChatTypeFilter typeFilter = ChatTypeFilter.all,
    String? userIdFilter,
  }) {
    Query<Map<String, dynamic>> query = _chats;

    if (typeFilter == ChatTypeFilter.dm) {
      query = query.where('isGroup', isEqualTo: false);
    } else if (typeFilter == ChatTypeFilter.group) {
      query = query.where('isGroup', isEqualTo: true);
    }

    final trimmedUserId = userIdFilter?.trim() ?? '';

    return query
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs.map(ChatSummary.fromDoc).toList();
      if (trimmedUserId.isEmpty) return chats;
      return chats.where((c) => c.memberIds.contains(trimmedUserId)).toList();
    });
  }

  @override
  Stream<List<AdminMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminMessage.fromDoc).toList());
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList();
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
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
        .toLocal();
  }
  return null;
}
