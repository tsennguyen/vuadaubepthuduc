import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../post/data/comment_model.dart';
import '../../post/data/post_interaction_repository.dart';
import '../../notifications/application/notification_service.dart';
import '../../notifications/application/anti_spam_service.dart';
import '../data/recipe_social_repository.dart';

class RecipeSocialState {
  const RecipeSocialState({
    this.userRating,
    this.isBookmark = false,
    this.isLiked = false,
    this.isSubmittingRating = false,
    this.isTogglingBookmark = false,
    this.comments = const AsyncValue.loading(),
    this.isSendingComment = false,
  });

  final int? userRating;
  final bool isBookmark;
  final bool isLiked;
  final bool isSubmittingRating;
  final bool isTogglingBookmark;
  final AsyncValue<List<Comment>> comments;
  final bool isSendingComment;

  RecipeSocialState copyWith({
    int? userRating,
    bool? isBookmark,
    bool? isLiked,
    bool? isSubmittingRating,
    bool? isTogglingBookmark,
    AsyncValue<List<Comment>>? comments,
    bool? isSendingComment,
  }) {
    return RecipeSocialState(
      userRating: userRating ?? this.userRating,
      isBookmark: isBookmark ?? this.isBookmark,
      isLiked: isLiked ?? this.isLiked,
      isSubmittingRating: isSubmittingRating ?? this.isSubmittingRating,
      isTogglingBookmark: isTogglingBookmark ?? this.isTogglingBookmark,
      comments: comments ?? this.comments,
      isSendingComment: isSendingComment ?? this.isSendingComment,
    );
  }
}

final recipeSocialRepositoryProvider =
    Provider<RecipeSocialRepository>((ref) => RecipeSocialRepositoryImpl());

final postInteractionRepositoryProvider =
    Provider<PostInteractionRepository>((ref) => PostInteractionRepositoryImpl());

final recipeSocialControllerProvider = StateNotifierProvider.family<
    RecipeSocialController, RecipeSocialState, String>((ref, recipeId) {
  final repo = ref.watch(recipeSocialRepositoryProvider);
  final interactionRepo = ref.watch(postInteractionRepositoryProvider);
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final notificationService = NotificationService();
  final antiSpamService = AntiSpamService();
  return RecipeSocialController(
    repository: repo,
    interactionRepository: interactionRepo,
    notificationService: notificationService,
    antiSpamService: antiSpamService,
    recipeId: recipeId,
    userId: userId,
  );
});

class RecipeSocialController extends StateNotifier<RecipeSocialState> {
  RecipeSocialController({
    required RecipeSocialRepository repository,
    required PostInteractionRepository interactionRepository,
    required NotificationService notificationService,
    required AntiSpamService antiSpamService,
    required this.recipeId,
    required this.userId,
  })  : _repository = repository,
        _interactionRepository = interactionRepository,
        _notificationService = notificationService,
        _antiSpamService = antiSpamService,
        super(const RecipeSocialState()) {
    _initStreams();
  }

  final RecipeSocialRepository _repository;
  final PostInteractionRepository _interactionRepository;
  final NotificationService _notificationService;
  final AntiSpamService _antiSpamService;
  final String recipeId;
  final String? userId;
  Map<String, String?>? _contentInfo;

  StreamSubscription<int?>? _ratingSub;
  StreamSubscription<bool>? _bookmarkSub;
  StreamSubscription<List<Comment>>? _commentsSub;

  Future<Map<String, String?>> _loadContentInfo() async {
    if (_contentInfo != null) return _contentInfo!;
    _contentInfo = await _notificationService.getContentInfo(
      contentId: recipeId,
      contentType: 'recipe',
    );
    return _contentInfo!;
  }

  void _initStreams() {
    if (userId == null) return;
    
    // Rating stream
    _ratingSub = _repository
        .watchUserRating(recipeId: recipeId, userId: userId!)
        .listen((rating) {
      if (!mounted) return;
      state = state.copyWith(userRating: rating);
    });
    
    // Bookmark stream
    _bookmarkSub = _repository
        .watchBookmark(recipeId: recipeId, userId: userId!)
        .listen((bookmarked) {
      if (!mounted) return;
      state = state.copyWith(isBookmark: bookmarked);
    });
    
    // Comments stream
    _commentsSub = _interactionRepository
        .watchComments(
          type: ContentType.recipe,
          contentId: recipeId,
        )
        .listen((comments) {
      if (!mounted) return;
      state = state.copyWith(comments: AsyncValue.data(comments));
    }, onError: (e, st) {
      if (!mounted) return;
      state = state.copyWith(comments: AsyncValue.error(e, st));
    });
    
    // Init like state
    _initLikeState();
  }
  
  Future<void> _initLikeState() async {
    if (userId == null) return;
    try {
      final liked = await _interactionRepository.isLiked(
        type: ContentType.recipe,
        contentId: recipeId,
        userId: userId!,
      );
      if (!mounted) return;
      state = state.copyWith(isLiked: liked);
    } catch (e) {
      // Error loading like state - silently fail
    }
  }

  Future<void> rate(int stars) async {
    if (userId == null) return;
    if (stars < 1 || stars > 5) return;
    state = state.copyWith(isSubmittingRating: true);
    try {
      await _repository.setRating(
        recipeId: recipeId,
        userId: userId!,
        stars: stars,
      );
      state = state.copyWith(userRating: stars);
      try {
        final info = await _loadContentInfo();
        final authorId = info['authorId'];
        if (authorId != null && authorId.isNotEmpty && authorId != userId) {
          await _notificationService.notifyRating(
            recipeId: recipeId,
            recipeAuthorId: authorId,
            recipeTitle: info['title'],
          );
        }
      } catch (e) {
        print('⚠️ [RecipeDetail] Rating notification failed: $e');
      }
    } finally {
      state = state.copyWith(isSubmittingRating: false);
    }
  }

  Future<void> toggleBookmark() async {
    if (userId == null) return;
    final target = !state.isBookmark;
    state = state.copyWith(isTogglingBookmark: true);
    try {
      await _repository.toggleBookmark(
        recipeId: recipeId,
        userId: userId!,
        value: target,
      );
      if (target) {
        try {
          final info = await _loadContentInfo();
          final authorId = info['authorId'];
          if (authorId != null && authorId.isNotEmpty && authorId != userId) {
            await _notificationService.notifySave(
              recipeId: recipeId,
              recipeAuthorId: authorId,
              recipeTitle: info['title'],
            );
          }
        } catch (e) {
          print('⚠️ [RecipeDetail] Save notification failed: $e');
        }
      }
    } finally {
      state = state.copyWith(isTogglingBookmark: false, isBookmark: target);
    }
  }
  
  Future<void> toggleLike() async {
    if (userId == null) return;
    final previous = state.isLiked;
    final target = !previous;
    
    // Only check spam when liking (not unliking)
    if (target) {
      final canLike = await _antiSpamService.checkAndLogAction(
        SpamActionType.like,
        contentId: recipeId,
      );
      if (!canLike) {
        // Spam detected
        return;
      }
    }
    
    state = state.copyWith(isLiked: target);
    try {
      await _interactionRepository.toggleLike(
        type: ContentType.recipe,
        contentId: recipeId,
        userId: userId!,
      );
      if (target) {
        try {
          final info = await _loadContentInfo();
          final authorId = info['authorId'];
          if (authorId != null && authorId.isNotEmpty && authorId != userId) {
            final service = _notificationService;
            if (service != null) {
              await service.notifyLike(
                contentId: recipeId,
                contentType: 'recipe',
                contentAuthorId: authorId,
                contentTitle: info['title'],
              );
            }
          }
        } catch (e) {
          // Silently fail notification
          print('⚠️ [RecipeDetail] Notification failed: $e');
        }
      }
    } catch (e) {
      // Error toggling like - revert state
      if (!mounted) return;
      state = state.copyWith(isLiked: previous);
    }
  }
  
  Future<void> addComment(String text) async {
    final content = text.trim();
    if (userId == null || content.isEmpty) return;
    
    // Check for spam before adding comment
    final canComment = await _antiSpamService.checkAndLogAction(
      SpamActionType.comment,
      contentId: recipeId,
      content: content,
    );
    if (!canComment) {
      // Spam detected
      return;
    }
    
    state = state.copyWith(isSendingComment: true);
    try {
      await _interactionRepository.addComment(
        type: ContentType.recipe,
        contentId: recipeId,
        userId: userId!,
        content: content,
      );
      try {
        final info = await _loadContentInfo();
        final authorId = info['authorId'];
        if (authorId != null && authorId.isNotEmpty && authorId != userId) {
          await _notificationService.notifyComment(
            contentId: recipeId,
            contentType: 'recipe',
            contentAuthorId: authorId,
            commentText: content,
            contentTitle: info['title'],
          );
        }
      } catch (e) {
        print('⚠️ [RecipeDetail] Comment notification failed: $e');
      }
    } catch (e) {
      // Error adding comment - silently fail
    } finally {
      if (mounted) {
        state = state.copyWith(isSendingComment: false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _ratingSub?.cancel();
    _bookmarkSub?.cancel();
    _commentsSub?.cancel();
  }
}
