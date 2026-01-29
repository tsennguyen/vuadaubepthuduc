import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/message.dart';
import '../domain/presence.dart';
import 'user_directory_repository.dart';

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.isGroup,
    required this.memberIds,
    required this.adminIds,
    required this.title,
    required this.lastMessageText,
    required this.groupAvatarUrls,
    required this.mutedBy,
    this.name,
    this.photoUrl,
    this.avatarUrl,
    this.lastMessageSenderName,
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.theme,
    this.isLocked = false,
  });

  final String id;
  final bool isGroup;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? name;
  final String title;
  final String? photoUrl;
  final String? avatarUrl;
  final List<String> groupAvatarUrls;
  final String lastMessageText;
  final String? lastMessageSenderName;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final List<String> mutedBy;
  final String? theme;
  final bool isLocked;

  String get type => isGroup ? 'group' : 'dm';
}

class Chat {
  Chat({
    required this.id,
    required this.isGroup,
    required this.memberIds,
    required this.adminIds,
    this.name,
    this.photoUrl,
    this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.unreadCount,
    this.mutedBy = const [],
    this.nicknames = const {},
    this.theme,
    this.createdAt,
    this.updatedAt,
    this.snapshot,
    this.isLocked = false,
    this.lastViolationAt,
    this.violationCount24h = 0,
    this.pinnedMessageIds = const [],
  });

  final String id;
  final bool isGroup;
  final String? name;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? photoUrl;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final int? unreadCount;
  final List<String> mutedBy;
  final Map<String, String> nicknames;
  final String? theme;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;
  final bool isLocked;
  final DateTime? lastViolationAt;
  final int violationCount24h;
  final List<String> pinnedMessageIds;

  String get type => isGroup ? 'group' : 'dm';

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final memberIds = _stringList(data['memberIds']);
    final adminIds = _stringList(data['adminIds']);
    return Chat(
      id: doc.id,
      isGroup: (data['isGroup'] as bool?) ??
          ((data['type'] as String?)?.toLowerCase() == 'group'),
      name: data['name'] as String?,
      photoUrl: data['photoUrl'] as String?,
      memberIds: memberIds,
      adminIds: adminIds.isNotEmpty ? adminIds : memberIds,
      lastMessageAt: _toDateTime(data['lastMessageAt']),
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageSenderId: (data['lastMessageSenderId'] as String?) ??
          (data['lastMessageAuthorId'] as String?),
      unreadCount: (data['unreadCount'] as num?)?.toInt(),
      mutedBy: _stringList(data['mutedBy']),
      nicknames: _stringMap(data['nicknames']),
      theme: data['theme'] as String?,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      snapshot: doc,
      isLocked: _parseBool(data['isLocked']),
      lastViolationAt: _toDateTime(data['lastViolationAt']),
      violationCount24h: (data['violationCount24h'] as num?)?.toInt() ?? 0,
      pinnedMessageIds: _stringList(data['pinnedMessageIds']),
    );
  }
}

abstract class ChatRepository {
  Stream<List<ChatSummary>> watchUserChats(String userId);
  Stream<List<ChatMessage>> watchMessages(String chatId);
  Stream<Map<String, bool>> watchTyping(String chatId);
  Future<void> setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  });
  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
    required List<ChatMessage> messages,
  });
  Future<void> sendTextMessage({
    required String chatId,
    required String authorId,
    required String text,
    String? replyToMessageId,
  });
  Future<void> sendImageMessage({
    required String chatId,
    required String authorId,
    required XFile imageFile,
    String? caption,
    String? replyToMessageId,
  });
  Future<void> sendVideoMessage({
    required String chatId,
    required String authorId,
    required XFile videoFile,
    String? caption,
    int? durationMs,
    XFile? thumbnailFile,
    String? replyToMessageId,
  });
  Future<void> sendFileMessage({
    required String chatId,
    required String authorId,
    required XFile file,
    String? label,
    String? replyToMessageId,
  });
  Future<void> sendAudioMessage({
    required String chatId,
    required String authorId,
    required XFile audioFile,
    required int durationMs,
    String? replyToMessageId,
  });
  Future<void> sendStickerMessage({
    required String chatId,
    required String authorId,
    required String stickerUrl,
    String? replyToMessageId,
  });
  Future<void> sendGifMessage({
    required String chatId,
    required String authorId,
    required String gifUrl,
    String? replyToMessageId,
  });
  Future<void> reactToMessage({
    required String chatId,
    required String messageId,
    required String userId,
    String? emoji,
  });
  Future<void> editTextMessage({
    required String chatId,
    required String messageId,
    required String newText,
  });
  Future<void> softDeleteMessage({
    required String chatId,
    required String messageId,
  });
  Future<void> updateGroupName(String chatId, String name);
  Future<void> updateGroupPhoto(String chatId, XFile file);
  Future<void> updateChatTheme(String chatId, String theme);
  Future<void> setNickname(String chatId, String userId, String? nickname);
  Future<void> promoteAdmin(String chatId, String userId);
  Future<void> demoteAdmin(String chatId, String userId);
  Future<void> removeMember(String chatId, String userId);
  Future<void> addMembers(String chatId, List<String> userIds);
  Future<void> leaveChat(String chatId, String userId);
  Future<void> toggleMute(String chatId, String userId);
  Future<void> pinMessage(String chatId, String messageId);
  Future<void> unpinMessage(String chatId, String messageId);
  Stream<List<ChatMessage>> watchPinnedMessages(String chatId);
  Stream<PresenceData> watchPresence(String userId);
  Stream<List<AppUserSummary>> watchChatMembers(String chatId);
  Future<void> deleteChat(String chatId);
  Future<void> blockUser(String currentUserId, String targetUserId);
  Future<void> unblockUser(String currentUserId, String targetUserId);
  Future<void> report(
    String type,
    String targetId,
    String reporterId,
    String reason, {
    String? chatId,
    List<Map<String, dynamic>>? evidenceMessages,
    List<String>? evidenceImages,
  });
  Future<String> uploadEvidence(XFile file);
}

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  Stream<List<ChatSummary>> watchUserChats(String userId) {
    final query = _firestore
        .collection('chats')
        .where('memberIds', arrayContains: userId);

    return query.snapshots().asyncMap((snap) async {
      final chats = snap.docs.map(Chat.fromDoc).toList();
      final userIds = <String>{};
      for (final chat in chats) {
        userIds.addAll(chat.memberIds);
        final lastSenderId = chat.lastMessageSenderId;
        if (lastSenderId != null && lastSenderId.isNotEmpty) {
          userIds.add(lastSenderId);
        }
      }
      userIds.removeWhere((id) => id.isEmpty);

      final usersMap = await _fetchUsers(userIds);

      final summaries = chats.map((chat) {
        return _toChatSummary(
          chat: chat,
          usersMap: usersMap,
          currentUserId: userId,
        );
      }).toList();

      summaries.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });
      return summaries;
    });
  }

  Future<Map<String, _ChatUserProfile>> _fetchUsers(Set<String> userIds) async {
    if (userIds.isEmpty) return <String, _ChatUserProfile>{};
    final futures = userIds.map(
      (uid) => _firestore.collection('users').doc(uid).get(),
    );
    final snaps = await Future.wait(futures);
    final users = <String, _ChatUserProfile>{};
    for (final doc in snaps) {
      if (!doc.exists) continue;
      final profile = _ChatUserProfile.fromDoc(doc);
      users[profile.uid] = profile;
    }
    return users;
  }

  ChatSummary _toChatSummary({
    required Chat chat,
    required Map<String, _ChatUserProfile> usersMap,
    required String currentUserId,
  }) {
    final isGroup = chat.isGroup;
    String title;
    String? avatarUrl;
    String? photoUrl = chat.photoUrl;
    var groupAvatarUrls = <String>[];

    final otherMemberIds =
        chat.memberIds.where((id) => id != currentUserId).toList();

    if (isGroup) {
      title = chat.name?.isNotEmpty == true ? chat.name! : 'Nhom khong ten';
      if (photoUrl == null || photoUrl.isEmpty) {
        final avatars = <String>[];
        for (final uid in otherMemberIds) {
          final photo = usersMap[uid]?.photoUrl;
          if (photo != null && photo.isNotEmpty) {
            avatars.add(photo);
          }
          if (avatars.length == 2) break;
        }
        groupAvatarUrls = avatars;
      }
    } else {
      final peerId = otherMemberIds.isNotEmpty
          ? otherMemberIds.first
          : (chat.memberIds.isNotEmpty ? chat.memberIds.first : currentUserId);
      final peerUser = usersMap[peerId];
      title = chat.name?.isNotEmpty == true
          ? chat.name!
          : (peerUser?.displayName ?? 'Nguoi dung');
      avatarUrl = peerUser?.photoUrl;
      photoUrl = photoUrl?.isNotEmpty == true ? photoUrl : avatarUrl;
      groupAvatarUrls = [
        if (photoUrl != null && photoUrl.isNotEmpty) photoUrl,
      ];
    }

    final lastSenderId = chat.lastMessageSenderId;
    final lastSenderUser =
        lastSenderId != null ? usersMap[lastSenderId] : null;
    final isMe = lastSenderId != null && lastSenderId == currentUserId;
    final lastSenderName = lastSenderId == null
        ? null
        : (isMe ? 'Ban' : (lastSenderUser?.displayName ?? 'Nguoi dung'));

    var unreadCount = chat.unreadCount ?? 0;
    final data = chat.snapshot?.data();
    if (data != null) {
      final unreadMap = data['unread'] as Map<String, dynamic>?;
      if (unreadMap != null && unreadMap.containsKey(currentUserId)) {
        unreadCount =
            (unreadMap[currentUserId] as num?)?.toInt() ?? unreadCount;
      } else if (data['unreadCount'] is num) {
        unreadCount = (data['unreadCount'] as num).toInt();
      }
    }

    return ChatSummary(
      id: chat.id,
      isGroup: isGroup,
      memberIds: chat.memberIds,
      adminIds: chat.adminIds.isNotEmpty ? chat.adminIds : chat.memberIds,
      name: chat.name,
      title: title,
      photoUrl: photoUrl,
      avatarUrl: avatarUrl,
      groupAvatarUrls: groupAvatarUrls,
      lastMessageText: chat.lastMessageText?.trim() ?? '',
      lastMessageSenderName: lastSenderName,
      lastMessageSenderId: lastSenderId,
      lastMessageAt: chat.lastMessageAt,
      unreadCount: unreadCount,
      mutedBy: chat.mutedBy,
      theme: chat.theme,
      isLocked: chat.isLocked,
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => _messageFromDoc(doc, chatId)).toList();
    });
  }

  @override
  Stream<Map<String, bool>> watchTyping(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return <String, bool>{};
      final raw = data['typing'] as Map<String, dynamic>?;
      if (raw == null) return <String, bool>{};
      return raw.map((key, value) => MapEntry(key, value == true));
    });
  }

  @override
  Future<void> setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    await _firestore.collection('chats').doc(chatId).set(
      {
        'typing': {userId: isTyping}
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
    required List<ChatMessage> messages,
  }) async {
    if (messages.isEmpty) return;
    final batch = _firestore.batch();
    for (final msg in messages) {
      final docRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(msg.id);
      batch.set(
        docRef,
        {
          'readBy': {userId: FieldValue.serverTimestamp()},
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> sendTextMessage({
    required String chatId,
    required String authorId,
    required String text,
    String? replyToMessageId,
  }) async {
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageId = docRef.id;
    await _writeMessage(
      docRef: docRef,
      chatId: chatId,
      authorId: authorId,
      messageId: messageId,
      data: {
        'type': 'text',
        'text': text,
        'replyToMessageId': replyToMessageId,
      },
      lastMessageText: text,
    );
  }

  @override
  Future<void> sendImageMessage({
    required String chatId,
    required String authorId,
    required XFile imageFile,
    String? caption,
    String? replyToMessageId,
  }) async {
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageId = docRef.id;
    final path = 'chatMedia/$chatId/images/$messageId.jpg';
    final url = await _uploadFile(path: path, file: imageFile);
    await _writeMessage(
      docRef: docRef,
      chatId: chatId,
      authorId: authorId,
      messageId: messageId,
      data: {
        'type': 'image',
        'text': caption ?? '',
        'attachmentUrl': url,
        'attachmentThumbUrl': url,
        'replyToMessageId': replyToMessageId,
      },
      lastMessageText: caption?.isNotEmpty == true ? caption! : '[Ảnh]',
    );
  }

  @override
  Future<void> sendVideoMessage({
    required String chatId,
    required String authorId,
    required XFile videoFile,
    String? caption,
    int? durationMs,
    XFile? thumbnailFile,
    String? replyToMessageId,
  }) async {
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageId = docRef.id;
    final videoPath = 'chatMedia/$chatId/videos/$messageId.mp4';
    final videoUrl = await _uploadFile(path: videoPath, file: videoFile);

    String? thumbUrl;
    if (thumbnailFile != null) {
      final thumbPath = 'chatMedia/$chatId/thumbnails/$messageId.jpg';
      thumbUrl = await _uploadFile(path: thumbPath, file: thumbnailFile);
    }

    await _writeMessage(
      docRef: docRef,
      chatId: chatId,
      authorId: authorId,
      messageId: messageId,
      data: {
        'type': 'video',
        'text': caption ?? '',
        'attachmentUrl': videoUrl,
        'attachmentThumbUrl': thumbUrl,
        'durationMs': durationMs,
        'replyToMessageId': replyToMessageId,
      },
      lastMessageText: caption?.isNotEmpty == true ? caption! : '[Video]',
    );
  }

  @override
  Future<void> sendAudioMessage({
    required String chatId,
    required String authorId,
    required XFile audioFile,
    required int durationMs,
    String? replyToMessageId,
  }) async {
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageId = docRef.id;
    final audioPath = 'chatMedia/$chatId/audio/$messageId.m4a';
    final audioUrl = await _uploadFile(path: audioPath, file: audioFile);

    await _writeMessage(
      docRef: docRef,
      chatId: chatId,
      authorId: authorId,
      messageId: messageId,
      data: {
        'type': 'audio',
        'attachmentUrl': audioUrl,
        'durationMs': durationMs,
        'replyToMessageId': replyToMessageId,
      },
      lastMessageText: '[Voice]',
    );
  }

  @override
  Future<void> sendFileMessage({
    required String chatId,
    required String authorId,
    required XFile file,
    String? label,
    String? replyToMessageId,
  }) async {
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageId = docRef.id;
    final rawName = file.name.isNotEmpty
        ? file.name
        : (file.path.split(RegExp(r'[\\\\/]')).last);
    final safeName = rawName.isNotEmpty ? rawName : 'file';
    final storagePath = 'chatMedia/$chatId/files/${messageId}_$safeName';
    final url = await _uploadFile(path: storagePath, file: file);
    final textLabel =
        (label != null && label.isNotEmpty) ? label : safeName;

    await _writeMessage(
      docRef: docRef,
      chatId: chatId,
      authorId: authorId,
      messageId: messageId,
      data: {
        'type': 'file',
        'text': textLabel,
        'attachmentUrl': url,
        'replyToMessageId': replyToMessageId,
      },
      lastMessageText: textLabel,
    );
  }

  @override
  Future<void> sendStickerMessage({
    required String chatId,
    required String authorId,
    required String stickerUrl,
    String? replyToMessageId,
  }) async {
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageId = docRef.id;

    await _writeMessage(
      docRef: docRef,
      chatId: chatId,
      authorId: authorId,
      messageId: messageId,
      data: {
        'type': 'sticker',
        'attachmentUrl': stickerUrl,
        'replyToMessageId': replyToMessageId,
      },
      lastMessageText: '[Nhãn dán]',
    );
  }

  @override
  Future<void> sendGifMessage({
    required String chatId,
    required String authorId,
    required String gifUrl,
    String? replyToMessageId,
  }) async {
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageId = docRef.id;

    await _writeMessage(
      docRef: docRef,
      chatId: chatId,
      authorId: authorId,
      messageId: messageId,
      data: {
        'type': 'gif',
        'attachmentUrl': gifUrl,
        'replyToMessageId': replyToMessageId,
      },
      lastMessageText: '[GIF]',
    );
  }

  @override
  Future<void> reactToMessage({
    required String chatId,
    required String messageId,
    required String userId,
    String? emoji,
  }) async {
    final docRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    if (emoji == null) {
      await docRef.update({'reactions.$userId': FieldValue.delete()});
    } else {
      await docRef.update({'reactions.$userId': emoji});
    }
  }

  @override
  Future<void> editTextMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> softDeleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': null,
      'attachmentUrl': null,
      'attachmentThumbUrl': null,
      'type': 'system', // Display as "Message removed" in UI
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateGroupName(String chatId, String name) async {
    await _firestore.collection('chats').doc(chatId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateGroupPhoto(String chatId, XFile file) async {
    final path = 'chat_avatars/$chatId.jpg';
    final url = await _uploadFile(path: path, file: file);
    await _firestore.collection('chats').doc(chatId).update({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateChatTheme(String chatId, String theme) async {
    await _firestore.collection('chats').doc(chatId).update({
      'theme': theme,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setNickname(
      String chatId, String userId, String? nickname) async {
    await _firestore.collection('chats').doc(chatId).update({
      'nicknames.$userId': nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> promoteAdmin(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> demoteAdmin(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'adminIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeMember(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> addMembers(String chatId, List<String> userIds) async {
    await _firestore.collection('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayUnion(userIds),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> leaveChat(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> toggleMute(String chatId, String userId) async {
    final doc = await _firestore.collection('chats').doc(chatId).get();
    final data = doc.data() ?? {};
    final mutedBy = _stringList(data['mutedBy']);
    if (mutedBy.contains(userId)) {
      await _firestore.collection('chats').doc(chatId).update({
        'mutedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await _firestore.collection('chats').doc(chatId).update({
        'mutedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  @override
  Stream<PresenceData> watchPresence(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      return PresenceData.fromMap(doc.data() ?? {});
    });
  }

  @override
  Future<void> pinMessage(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'pinnedMessageIds': FieldValue.arrayUnion([messageId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unpinMessage(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'pinnedMessageIds': FieldValue.arrayRemove([messageId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<ChatMessage>> watchPinnedMessages(String chatId) {
    final chatRef = _firestore.collection('chats').doc(chatId);
    return chatRef.snapshots().asyncMap((chatSnap) async {
      final data = chatSnap.data();
      final pinnedIds = _stringList(data?['pinnedMessageIds']);
      if (pinnedIds.isEmpty) return <ChatMessage>[];

      final futures = pinnedIds.map((id) => chatRef.collection('messages').doc(id).get());
      final snaps = await Future.wait(futures);
      final messages =
          snaps.where((s) => s.exists).map((doc) => _messageFromDoc(doc, chatId)).toList();
      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return messages;
    });
  }

  @override
  Stream<List<AppUserSummary>> watchChatMembers(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .asyncMap((chatSnap) async {
      final data = chatSnap.data();
      if (data == null) return [];
      final memberIds = _stringList(data['memberIds']);
      if (memberIds.isEmpty) return [];

      // Fetch user profiles. 
      // Note: This fetches once per chat update. 
      // If real-time user profile updates are required, this needs to be composed of user streams.
      final futures = memberIds.map((uid) => _firestore.collection('users').doc(uid).get());
      final snaps = await Future.wait(futures);
      return snaps
          .where((s) => s.exists)
          .map(AppUserSummary.fromDoc)
          .toList();
    });
  }

  ChatMessage _messageFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String chatId,
  ) {
    final data = doc.data() ?? {};
    final type = messageTypeFromString(data['type'] as String?);
    final readMap = <String, DateTime?>{};
    final rawReadBy = data['readBy'];
    if (rawReadBy is Map<String, dynamic>) {
      for (final entry in rawReadBy.entries) {
        readMap[entry.key] = _toDateTime(entry.value);
      }
    } else if (rawReadBy is List) {
      for (final uid in rawReadBy.whereType<String>()) {
        readMap[uid] = null;
      }
    }
    final reactionsRaw = data['reactions'] as Map<String, dynamic>?;
    final reactions = <String, String>{};
    reactionsRaw?.forEach((key, value) {
      if (value is String) {
        reactions[key] = value;
      }
    });

    return ChatMessage(
      id: doc.id,
      chatId: chatId,
      senderId: (data['senderId'] as String?) ??
          (data['authorId'] as String?) ??
          '',
      type: type,
      text: data['text'] as String?,
      attachmentUrl: (data['attachmentUrl'] as String?) ??
          (data['mediaUrl'] as String?),
      attachmentThumbUrl: (data['attachmentThumbUrl'] as String?) ??
          (data['thumbnailUrl'] as String?),
      durationMs: (data['durationMs'] as num?)?.toInt() ??
          (data['mediaDurationMs'] as num?)?.toInt(),
      createdAt: _toDateTime(data['createdAt']),
      editedAt: _toDateTime(data['editedAt']),
      deletedAt: _toDateTime(data['deletedAt']),
      reactions: reactions,
      readBy: readMap,
      replyToMessageId: data['replyToMessageId'] as String?,
      systemType: data['systemType'] as String?,
      snapshot: doc,
    );
  }

  Future<void> _writeMessage({
    required DocumentReference<Map<String, dynamic>> docRef,
    required String chatId,
    required String authorId,
    required String messageId,
    required Map<String, dynamic> data,
    required String lastMessageText,
  }) async {
    final attachmentUrl = data['attachmentUrl'] ?? data['mediaUrl'];
    final attachmentThumbUrl =
        data['attachmentThumbUrl'] ?? data['thumbnailUrl'];
    final durationMs = data['durationMs'] ?? data['mediaDurationMs'];
    final messageType =
        messageTypeToString(messageTypeFromString(data['type'] as String?));

    final payload = {
      'id': messageId,
      'senderId': authorId,
      // Kept for backward compatibility with older documents.
      'authorId': authorId,
      'type': messageType,
      'text': data['text'],
      'attachmentUrl': attachmentUrl,
      'attachmentThumbUrl': attachmentThumbUrl,
      'durationMs': durationMs,
      'replyToMessageId': data['replyToMessageId'],
      'systemType': data['systemType'],
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedAt': null,
      'reactions': <String, String>{},
      'readBy': {authorId: FieldValue.serverTimestamp()},
    };

    payload.removeWhere((key, value) => value == null);

    await docRef.set(payload);
    await _firestore.collection('chats').doc(chatId).set(
      {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': lastMessageText,
        'lastMessageSenderId': authorId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> _uploadFile({
    required String path,
    required XFile file,
  }) async {
    final ref = _storage.ref().child(path);
    final bytes = await file.readAsBytes();
    await ref.putData(
      bytes,
      SettableMetadata(contentType: _getContentType(path)),
    );
    return ref.getDownloadURL();
  }

  String? _getContentType(String path) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.mp4')) return 'video/mp4';
    if (path.endsWith('.m4a')) return 'audio/mp4';
    return null;
  }


  @override
  Future<void> deleteChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).delete();
  }

  @override
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(targetUserId)
        .set({'blockedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(targetUserId)
        .delete();
  }

  @override
  Future<void> report(
    String type,
    String targetId,
    String reporterId,
    String reason, {
    String? chatId,
    List<Map<String, dynamic>>? evidenceMessages,
    List<String>? evidenceImages,
  }) async {
    if (type == 'chat' || type == 'group' || type == 'message') {
      String offenderId = '';
      if (type == 'message' &&
          chatId != null &&
          chatId.isNotEmpty &&
          targetId.isNotEmpty) {
        // Try to fetch original sender
        try {
          final msgSnap = await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(targetId)
              .get();
          offenderId = (msgSnap.data()?['senderId'] ??
                  msgSnap.data()?['authorId'] ??
                  '')
              .toString();
        } catch (e) {
          offenderId = '';
        }
      }

      await _firestore.collection('chatViolations').add({
        'chatId': chatId ?? (type == 'chat' || type == 'group' ? targetId : ''),
        'messageId': type == 'message' ? targetId : '',
        'offenderId': offenderId,
        'type': 'user_report',
        'violationCategories': ['report'],
        'severity': 'medium',
        'messageSummary': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'notes': reason,
        'evidenceMessages': evidenceMessages ?? [],
        'evidenceImages': evidenceImages ?? [],
      });
    }

    await _firestore.collection('reports').add({
      'targetType': type,
      'targetId': targetId,
      'reporterId': reporterId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'evidenceMessages': evidenceMessages ?? [],
      'evidenceImages': evidenceImages ?? [],
    });
  }

  @override
  Future<String> uploadEvidence(XFile file) async {
    final ref = _storage.ref().child('chat_evidence/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
    // On web, use putData. On mobile, putFile. XFile handles both via readAsBytes mostly for web.
    // For simplicity with File (mobile req):
    final metadata = SettableMetadata(
        contentType: file.mimeType ?? 'image/jpeg',
    );
    try {
        await ref.putFile(File(file.path), metadata);
    } catch (_) {
       final bytes = await file.readAsBytes();
       await ref.putData(bytes, metadata);
    }
    return await ref.getDownloadURL();
  }
}

class _ChatUserProfile {
  _ChatUserProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;

  factory _ChatUserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final name = (data['displayName'] ?? data['fullName'] ?? data['name'] ?? '')
            as String? ??
        '';
    return _ChatUserProfile(
      uid: doc.id,
      displayName: name.isNotEmpty ? name : 'Nguoi dung',
      photoUrl: data['photoURL'] as String?,
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
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
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return const [];
}

Map<String, String> _stringMap(dynamic value) {
  if (value is Map) {
    final result = <String, String>{};
    value.forEach((key, val) {
      if (key is String && val is String) {
        result[key] = val;
      }
    });
    return result;
  }
  return const {};
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
