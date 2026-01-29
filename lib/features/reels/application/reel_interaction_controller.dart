import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reel_interaction_repository.dart';

final hasLikedReelProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, reelId) {
  final repository = ref.watch(reelInteractionRepositoryProvider);
  return repository.hasLiked(reelId);
});

final hasSavedReelProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, reelId) {
  final repository = ref.watch(reelInteractionRepositoryProvider);
  return repository.hasSaved(reelId);
});

final reelCommentsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, reelId) {
  final repository = ref.watch(reelInteractionRepositoryProvider);
  return repository.getComments(reelId);
});

class ReelInteractionController extends StateNotifier<AsyncValue<void>> {
  ReelInteractionController(this._repository)
      : super(const AsyncValue.data(null));

  final ReelInteractionRepository _repository;

  Future<void> toggleLike(String reelId) async {
    try {
      await _repository.toggleLike(reelId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> toggleSave(String reelId) async {
    try {
      await _repository.toggleSave(reelId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> addComment(
    String reelId,
    String text, {
    String? replyTo,
    String? replyToName,
  }) async {
    if (text.trim().isEmpty) return;
    
    state = const AsyncValue.loading();
    try {
      await _repository.addComment(
        reelId,
        text,
        replyTo: replyTo,
        replyToName: replyToName,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteComment(String reelId, String commentId) async {
    try {
      await _repository.deleteComment(reelId, commentId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final reelInteractionControllerProvider =
    StateNotifierProvider<ReelInteractionController, AsyncValue<void>>((ref) {
  final repository = ref.watch(reelInteractionRepositoryProvider);
  return ReelInteractionController(repository);
});
