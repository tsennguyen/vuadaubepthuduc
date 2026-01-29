import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/chat_repository.dart';
import '../data/user_directory_repository.dart';
import '../domain/message.dart';
import '../domain/presence.dart';
import '../domain/chat_display.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_ban_guard.dart';

class ChatRoomState {
  const ChatRoomState({
    this.isSending = false,
    this.isUploading = false,
    this.error,
    this.messages = const [],
    this.typing = const {},
    this.replyMessage,
    this.editingMessage,
    this.isLocked = false,
    this.chat,
    this.pinnedMessages = const [],
  });

  final bool isSending;
  final bool isUploading;
  final Object? error;
  final List<ChatMessage> messages;
  final Map<String, bool> typing;
  final ChatMessage? replyMessage;
  final ChatMessage? editingMessage;
  final bool isLocked;
  final Chat? chat;
  final List<ChatMessage> pinnedMessages;

  ChatRoomState copyWith({
    bool? isSending,
    bool? isUploading,
    Object? error = _noUpdateError,
    List<ChatMessage>? messages,
    Map<String, bool>? typing,
    Object? replyMessage = _noUpdateMessage,
    Object? editingMessage = _noUpdateMessage,
    bool? isLocked,
    Object? chat = _noUpdateChat,
    List<ChatMessage>? pinnedMessages,
  }) {
    return ChatRoomState(
      isSending: isSending ?? this.isSending,
      isUploading: isUploading ?? this.isUploading,
      error: error == _noUpdateError ? this.error : error,
      messages: messages ?? this.messages,
      typing: typing ?? this.typing,
      replyMessage: replyMessage == _noUpdateMessage
          ? this.replyMessage
          : (replyMessage as ChatMessage?),
      editingMessage: editingMessage == _noUpdateMessage
          ? this.editingMessage
          : (editingMessage as ChatMessage?),
      isLocked: isLocked ?? this.isLocked,
      chat: chat == _noUpdateChat ? this.chat : (chat as Chat?),
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
    );
  }

  static const _noUpdateMessage = Object();

  static const _noUpdateError = Object();

  static const _noUpdateChat = Object();
}

final chatStreamProvider = StreamProvider.autoDispose.family<Chat, String>((ref, chatId) {
  return FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots().map((doc) => Chat.fromDoc(doc));
});

final chatMembersProvider = StreamProvider.autoDispose.family<List<AppUserSummary>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchChatMembers(chatId);
});

final chatRoomDisplayProvider =
    Provider.autoDispose.family<AsyncValue<ChatDisplayInfo>, String>((ref, chatId) {
  final chatAsync = ref.watch(chatStreamProvider(chatId));
  final membersAsync = ref.watch(chatMembersProvider(chatId));

  return chatAsync.whenData((chat) {
    final membersById = {
      for (final m in membersAsync.value ?? <AppUserSummary>[]) m.uid: m,
    };
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) {
       // Return basic info or throw? Returning basic info is safer for UI not shrinking
       return ChatDisplayInfo(title: 'Loading...', isGroup: chat.isGroup);
    }
    return buildChatDisplayInfo(
      chat: chat,
      currentUserId: currentUserId,
      membersById: membersById,
    );
  });
});

final presenceProvider = StreamProvider.autoDispose.family<PresenceData, String>((ref, userId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchPresence(userId);
});

final chatRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatRoomController, ChatRoomState, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final controller = ChatRoomController(
    repository: repo,
    chatId: chatId,
    currentUserId: uid,
    banGuard: ref.watch(userBanGuardProvider),
  );

  return controller;
});

class ChatRoomController extends StateNotifier<ChatRoomState> {
  ChatRoomController({
    required ChatRepository repository,
    required String chatId,
    required String? currentUserId,
    required UserBanGuard banGuard,
  })  : _repository = repository,
        _chatId = chatId,
        _currentUserId = currentUserId,
        _banGuard = banGuard,
        super(const ChatRoomState()) {
    _listenChatMeta();
    _listenMessages();
    _listenTyping();
  }

  final ChatRepository _repository;
  final String _chatId;
  final String? _currentUserId;
  final UserBanGuard _banGuard;
  StreamSubscription<List<ChatMessage>>? _sub;
  StreamSubscription<List<ChatMessage>>? _pinnedSub;
  StreamSubscription<Map<String, bool>>? _typingSub;
  StreamSubscription<Chat>? _chatSub;
  Timer? _typingOffTimer;
  bool _isTyping = false;

  void _listenChatMeta() {
    _chatSub = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .snapshots()
        .map(Chat.fromDoc)
        .listen((chat) {
      if (!mounted) return;
      state = state.copyWith(chat: chat, isLocked: chat.isLocked);
    }, onError: (e, __) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    });
  }

  void _listenMessages() {
    if (_currentUserId == null) {
      state = state.copyWith(
        error: Exception('Not signed in'),
        messages: const [],
      );
      return;
    }

    _sub = _repository.watchMessages(_chatId).listen((messages) {
      if (!mounted) return;
      state = state.copyWith(error: null, messages: messages);
      _markReadIfNeeded(messages).catchError((_) {});
    }, onError: (e, __) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    });

    _pinnedSub = _repository.watchPinnedMessages(_chatId).listen((pinned) {
      if (!mounted) return;
      state = state.copyWith(pinnedMessages: pinned);
    });
  }

  void _listenTyping() {
    if (_currentUserId == null) return;
    _typingSub = _repository.watchTyping(_chatId).listen((typingMap) {
      if (!mounted) return;
      state = state.copyWith(typing: typingMap);
    });
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    final userId = _currentUserId;
    if (trimmed.isEmpty || userId == null) return;

    if (!await _ensureCanSend()) return;

    state = state.copyWith(isSending: true, error: null);
    try {
      if (state.editingMessage != null) {
        await _repository.editTextMessage(
          chatId: _chatId,
          messageId: state.editingMessage!.id,
          newText: trimmed,
        );
        state = state.copyWith(editingMessage: null);
      } else {
        await _repository.sendTextMessage(
          chatId: _chatId,
          authorId: userId,
          text: trimmed,
          replyToMessageId: state.replyMessage?.id,
        );
        state = state.copyWith(replyMessage: null);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    } finally {
      if (mounted) {
        state = state.copyWith(isSending: false);
      }
    }
  }

  Future<void> sendImage(XFile file, {String? caption}) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (!await _ensureCanSend()) return;
    state = state.copyWith(isUploading: true, error: null);
    try {
      await _repository.sendImageMessage(
        chatId: _chatId,
        authorId: userId,
        imageFile: file,
        caption: caption,
        replyToMessageId: state.replyMessage?.id,
      );
      state = state.copyWith(replyMessage: null);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    } finally {
      if (mounted) state = state.copyWith(isUploading: false);
    }
  }

  Future<void> sendVideo(
    XFile file, {
    String? caption,
    int? durationMs,
    XFile? thumbnailFile,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (!await _ensureCanSend()) return;
    state = state.copyWith(isUploading: true, error: null);
    try {
      await _repository.sendVideoMessage(
        chatId: _chatId,
        authorId: userId,
        videoFile: file,
        caption: caption,
        durationMs: durationMs,
        thumbnailFile: thumbnailFile,
        replyToMessageId: state.replyMessage?.id,
      );
      state = state.copyWith(replyMessage: null);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    } finally {
      if (mounted) state = state.copyWith(isUploading: false);
    }
  }

  Future<void> sendAudio(XFile file, {required int durationMs}) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (!await _ensureCanSend()) return;
    state = state.copyWith(isUploading: true, error: null);
    try {
      await _repository.sendAudioMessage(
        chatId: _chatId,
        authorId: userId,
        audioFile: file,
        durationMs: durationMs,
        replyToMessageId: state.replyMessage?.id,
      );
      state = state.copyWith(replyMessage: null);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    } finally {
      if (mounted) state = state.copyWith(isUploading: false);
    }
  }

  Future<void> sendSticker(String url) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (!await _ensureCanSend()) return;
    state = state.copyWith(isSending: true, error: null);
    try {
      await _repository.sendStickerMessage(
        chatId: _chatId,
        authorId: userId,
        stickerUrl: url,
        replyToMessageId: state.replyMessage?.id,
      );
      state = state.copyWith(replyMessage: null);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  Future<void> sendGif(String url) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (!await _ensureCanSend()) return;
    state = state.copyWith(isSending: true, error: null);
    try {
      await _repository.sendGifMessage(
        chatId: _chatId,
        authorId: userId,
        gifUrl: url,
        replyToMessageId: state.replyMessage?.id,
      );
      state = state.copyWith(replyMessage: null);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }


  Future<void> _markReadIfNeeded(List<ChatMessage> messages) async {
    final userId = _currentUserId;
    if (userId == null || messages.isEmpty) return;
    final unread = messages
        .where((m) =>
            m.senderId != userId && !(m.readBy.containsKey(userId)))
        .toList();
    if (unread.isEmpty) return;
    // Limit to recent messages to avoid huge batches.
    final toUpdate =
        unread.length > 50 ? unread.sublist(unread.length - 50) : unread;
    await _repository.markMessagesAsRead(
      chatId: _chatId,
      userId: userId,
      messages: toUpdate,
    );
  }

  // --- New Group Management Actions ---

  Future<void> renameGroup(String newName) async {
    try {
      await _repository.updateGroupName(_chatId, newName);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> changeGroupPhoto(XFile file) async {
    try {
      await _repository.updateGroupPhoto(_chatId, file);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> changeTheme(String theme) async {
    try {
      await _repository.updateChatTheme(_chatId, theme);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> setNickname(String userId, String? nickname) async {
    try {
      await _repository.setNickname(_chatId, userId, nickname);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> promoteToAdmin(String userId) async {
    try {
      await _repository.promoteAdmin(_chatId, userId);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> demoteAdmin(String userId) async {
    try {
      await _repository.demoteAdmin(_chatId, userId);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> removeMember(String userId) async {
    try {
      await _repository.removeMember(_chatId, userId);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> addMembers(List<String> userIds) async {
    try {
      await _repository.addMembers(_chatId, userIds);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> leaveGroup() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _repository.leaveChat(_chatId, uid);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> toggleMute() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _repository.toggleMute(_chatId, uid);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final msg = state.messages.firstWhere((m) => m.id == messageId);
      final currentReaction = msg.reactions[userId];
      final newEmoji = currentReaction == emoji ? null : emoji;
      await _repository.reactToMessage(
        chatId: _chatId,
        messageId: messageId,
        userId: userId,
        emoji: newEmoji,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  void setReplyTo(ChatMessage? message) {
    state = state.copyWith(
      replyMessage: message,
      editingMessage: null,
    );
  }

  void startEditing(ChatMessage message) {
    if (message.type != MessageType.text) return;
    state = state.copyWith(
      editingMessage: message,
      replyMessage: null,
    );
  }

  void cancelEditing() {
    state = state.copyWith(editingMessage: null);
  }

  Future<void> softDeleteMessage(String messageId) async {
    try {
      await _repository.softDeleteMessage(
        chatId: _chatId,
        messageId: messageId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  void onTextChanged(String value) {
    final uid = _currentUserId;
    if (uid == null) return;
    final isNotEmpty = value.trim().isNotEmpty;

    if (isNotEmpty && !_isTyping) {
      _isTyping = true;
      _repository.setTyping(
        chatId: _chatId,
        userId: uid,
        isTyping: true,
      );
    }

    _typingOffTimer?.cancel();
    _typingOffTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _repository.setTyping(
          chatId: _chatId,
          userId: uid,
          isTyping: false,
        );
      }
    });

    if (!isNotEmpty && _isTyping) {
      _isTyping = false;
      _typingOffTimer?.cancel();
      _repository.setTyping(
        chatId: _chatId,
        userId: uid,
        isTyping: false,
      );
    }
  }

  Future<void> deleteChat() async {
    try {
      await _repository.deleteChat(_chatId);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> blockUser(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await _repository.blockUser(userId, targetUserId);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> pinMessage(String messageId) async {
    try {
      await _repository.pinMessage(_chatId, messageId);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> unpinMessage(String messageId) async {
    try {
      await _repository.unpinMessage(_chatId, messageId);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> report(
    String reasonCode,
    String targetId,
    String reason, {
    List<Map<String, dynamic>>? evidenceMessages,
    List<String>? evidenceImagePaths,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final fullReason = '[$reasonCode] $reason';
      final targetType = targetId == _chatId ? 'chat' : 'user';

      List<String> imageUrls = [];
      if (evidenceImagePaths != null && evidenceImagePaths.isNotEmpty) {
        for (final path in evidenceImagePaths) {
          final url = await _repository.uploadEvidence(XFile(path));
          imageUrls.add(url);
        }
      }

      await _repository.report(
        targetType,
        targetId,
        userId,
        fullReason,
        chatId: _chatId,
        evidenceMessages: evidenceMessages,
        evidenceImages: imageUrls,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(error: e);
    }
  }

  @override
  void dispose() {
    // Attempt to set typing false immediately before dispose
    final userId = _currentUserId;
    if (userId != null && _isTyping) {
      _repository.setTyping(
        chatId: _chatId,
        userId: userId,
        isTyping: false,
      ).catchError((_) {});
    }

    _sub?.cancel();
    _typingSub?.cancel();
    _chatSub?.cancel();
    _pinnedSub?.cancel();
    _typingOffTimer?.cancel();
    super.dispose();
  }

  Future<bool> _ensureCanSend() async {
    if (state.isLocked) {
      state = state.copyWith(error: const ChatLockedException());
      return false;
    }
    try {
      await _banGuard.ensureNotBanned();
    } on UserBannedException catch (e) {
      if (mounted) {
        state = state.copyWith(error: e);
      }
      return false;
    }
    return true;
  }
}

class ChatLockedException implements Exception {
  const ChatLockedException();

  @override
  String toString() =>
      'Doan chat da bi khoa boi quan tri vien do vi pham tieu chuan cong dong.';
}
