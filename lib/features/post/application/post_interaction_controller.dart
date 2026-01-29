import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/comment_model.dart';
import '../data/post_interaction_repository.dart';
import '../../notifications/application/notification_service.dart';
import '../../notifications/application/anti_spam_service.dart';

class PostInteractionParams {
  PostInteractionParams({
    required this.type,
    required this.contentId,
    required this.initialLikesCount,
    this.titleForShare,
    this.contentAuthorId,
  });

  final ContentType type;
  final String contentId;
  final int initialLikesCount;
  final String? titleForShare;
  final String? contentAuthorId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostInteractionParams &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          contentId == other.contentId &&
          initialLikesCount == other.initialLikesCount &&
          titleForShare == other.titleForShare &&
          contentAuthorId == other.contentAuthorId;

  @override
  int get hashCode =>
      type.hashCode ^
      contentId.hashCode ^
      initialLikesCount.hashCode ^
      titleForShare.hashCode ^
      contentAuthorId.hashCode;
}

class PostInteractionState {
  const PostInteractionState({
    this.isLiked = false,
    this.likesCount = 0,
    this.comments = const AsyncValue.loading(),
    this.isSendingComment = false,
    this.isSharing = false,
  });

  final bool isLiked;
  final int likesCount;
  final AsyncValue<List<Comment>> comments;
  final bool isSendingComment;
  final bool isSharing;

  PostInteractionState copyWith({
    bool? isLiked,
    int? likesCount,
    AsyncValue<List<Comment>>? comments,
    bool? isSendingComment,
    bool? isSharing,
  }) {
    return PostInteractionState(
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      comments: comments ?? this.comments,
      isSendingComment: isSendingComment ?? this.isSendingComment,
      isSharing: isSharing ?? this.isSharing,
    );
  }
}

final postInteractionRepositoryProvider =
    Provider<PostInteractionRepository>((ref) {
  return PostInteractionRepositoryImpl();
});

final postInteractionControllerProvider = StateNotifierProvider.autoDispose
    .family<PostInteractionController, PostInteractionState,
        PostInteractionParams>((ref, params) {
  final repo = ref.watch(postInteractionRepositoryProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final notificationService = NotificationService();
  final antiSpamService = AntiSpamService();
  final controller = PostInteractionController(
    repository: repo,
    notificationService: notificationService,
    antiSpamService: antiSpamService,
    type: params.type,
    contentId: params.contentId,
    currentUserId: uid,
    initialLikesCount: params.initialLikesCount,
    titleForShare: params.titleForShare,
    contentAuthorId: params.contentAuthorId,
  );
  controller.init();
  return controller;
});

class PostInteractionController extends StateNotifier<PostInteractionState> {
  PostInteractionController({
    required PostInteractionRepository repository,
    required NotificationService notificationService,
    required AntiSpamService antiSpamService,
    required ContentType type,
    required String contentId,
    required int initialLikesCount,
    required String? currentUserId,
    this.titleForShare,
    this.contentAuthorId,
  })  : _repository = repository,
        _notificationService = notificationService,
        _antiSpamService = antiSpamService,
        _type = type,
        _contentId = contentId,
        _currentUserId = currentUserId,
        super(
          PostInteractionState(
            likesCount: initialLikesCount,
          ),
        );

  final PostInteractionRepository _repository;
  final NotificationService _notificationService;
  final AntiSpamService _antiSpamService;
  final ContentType _type;
  final String _contentId;
  final String? _currentUserId;
  final String? titleForShare;
  final String? contentAuthorId;
  StreamSubscription<List<Comment>>? _commentsSub;

  void init() {
    _listenComments();
    _initLikeState();
  }

  void _listenComments() {
    // Reading comments is only allowed for signed-in users per Firestore rules.
    if (_currentUserId == null) {
      if (!mounted) return;
      state = state.copyWith(comments: const AsyncValue.data([]));
      return;
    }
    if (!mounted) return;
    state = state.copyWith(comments: const AsyncValue.loading());
    _commentsSub = _repository
        .watchComments(type: _type, contentId: _contentId)
        .listen((list) {
      if (!mounted) return;
      state = state.copyWith(comments: AsyncValue.data(list));
    }, onError: (e, __) {
      if (!mounted) return;
      state = state.copyWith(comments: AsyncValue.error(e, StackTrace.current));
    });
  }

  Future<void> _initLikeState() async {
    if (_currentUserId == null) return;
    try {
      final userId = _currentUserId;
      final liked = await _repository.isLiked(
        type: _type,
        contentId: _contentId,
        userId: userId,
      );
      if (!mounted) return;
      state = state.copyWith(isLiked: liked);
    } catch (_) {
      // ignore
    }
  }

  Future<void> toggleLike() async {
    if (_currentUserId == null || !mounted) return;
    final userId = _currentUserId;
    final previous = state;
    final newLiked = !previous.isLiked;
    
    // Only check spam when liking (not unliking)
    if (newLiked) {
      final canLike = await _antiSpamService.checkAndLogAction(
        SpamActionType.like,
        contentId: _contentId,
      );
      if (!canLike) {
        // Show error to user - spam detected
        return;
      }
    }
    
    final delta = newLiked ? 1 : -1;
    state = state.copyWith(
      isLiked: newLiked,
      likesCount: (previous.likesCount + delta).clamp(0, 1 << 31),
    );
    try {
      await _repository.toggleLike(
        type: _type,
        contentId: _contentId,
        userId: userId,
      );
      
      // Create notification if liking (not unliking) and have author info
      if (newLiked && contentAuthorId != null && contentAuthorId != userId) {
        try {
          await _notificationService.notifyLike(
            contentId: _contentId,
            contentType: _type == ContentType.post ? 'post' : 'recipe',
            contentAuthorId: contentAuthorId!,
            contentTitle: titleForShare,
          );
        } catch (e) {
          print('⚠️ [PostInteraction] Like notification failed: $e');
        }
      }
    } catch (_) {
      // revert on error
      if (!mounted) return;
      state = state.copyWith(
        isLiked: previous.isLiked,
        likesCount: previous.likesCount,
      );
    }
  }

  Future<void> sendComment(String text, {String? imageUrl}) async {
    if (_currentUserId == null || (text.trim().isEmpty && imageUrl == null) || !mounted) return;
    final userId = _currentUserId;
    
    // Check for spam before sending comment
    final canComment = await _antiSpamService.checkAndLogAction(
      SpamActionType.comment,
      contentId: _contentId,
      content: text.trim(),
    );
    if (!canComment) {
      throw Exception('Phát hiện hành động spam. Vui lòng thử lại sau.');
    }
    
    state = state.copyWith(isSendingComment: true);
    try {
      await _repository.addComment(
        type: _type,
        contentId: _contentId,
        userId: userId,
        content: text.trim(),
        imageUrl: imageUrl,
      );
      
      // Create notification if have author info
      if (contentAuthorId != null && contentAuthorId != userId) {
        try {
          await _notificationService.notifyComment(
            contentId: _contentId,
            contentType: _type == ContentType.post ? 'post' : 'recipe',
            contentAuthorId: contentAuthorId!,
            commentText: text.trim(),
            contentTitle: titleForShare,
          );
        } catch (e) {
          print('⚠️ [PostInteraction] Comment notification failed: $e');
        }
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isSendingComment: false);
      }
    }
  }

  Future<void> share() async {
    if (_currentUserId == null || !mounted) return;
    final userId = _currentUserId;
    
    // Check for spam before sharing
    final canShare = await _antiSpamService.checkAndLogAction(
      SpamActionType.share,
      contentId: _contentId,
    );
    if (!canShare) {
      // Spam detected
      return;
    }
    
    state = state.copyWith(isSharing: true);
    try {
      await _repository.addShare(
        type: _type,
        contentId: _contentId,
        userId: userId,
      );
      
      // Create notification if have author info
      if (contentAuthorId != null && contentAuthorId != userId) {
        try {
          await _notificationService.notifyShare(
            contentId: _contentId,
            contentType: _type == ContentType.post ? 'post' : 'recipe',
            contentAuthorId: contentAuthorId!,
            contentTitle: titleForShare,
          );
        } catch (e) {
          print('⚠️ [PostInteraction] Share notification failed: $e');
        }
      }
      
      if (!mounted) return;
      final title = titleForShare ?? 'Vua Dau Bep Thu Duc';
      await Share.share('Xem $title tren Vua Dau Bep Thu Duc');
    } finally {
      if (mounted) {
        state = state.copyWith(isSharing: false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _commentsSub?.cancel();
  }
}
