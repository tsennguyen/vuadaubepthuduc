import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reel_model.dart';
import '../data/reel_repository.dart';

final reelsStreamProvider = StreamProvider.autoDispose<List<Reel>>((ref) {
  final repository = ref.watch(reelRepositoryProvider);
  return repository.getReelsStream(limit: 50);
});

final reelByIdProvider =
    FutureProvider.autoDispose.family<Reel?, String>((ref, reelId) {
  final repository = ref.watch(reelRepositoryProvider);
  return repository.getReelById(reelId);
});

final userReelsProvider =
    StreamProvider.autoDispose.family<List<Reel>, String>((ref, userId) {
  final repository = ref.watch(reelRepositoryProvider);
  return repository.getReelsByUser(userId);
});

final trendingReelsProvider = StreamProvider.autoDispose<List<Reel>>((ref) {
  final repository = ref.watch(reelRepositoryProvider);
  return repository.getTrendingReels(limit: 30);
});

class ReelsController extends StateNotifier<AsyncValue<void>> {
  ReelsController(this._repository) : super(const AsyncValue.data(null));

  final ReelRepository _repository;

  Future<void> incrementViewCount(String reelId) async {
    try {
      await _repository.incrementViewCount(reelId);
    } catch (e) {
      // Silently fail for view counts
    }
  }

  Future<void> incrementShareCount(String reelId) async {
    try {
      await _repository.incrementShareCount(reelId);
    } catch (e) {
      // Silently fail for share counts
    }
  }

  Future<String> createReel(Reel reel) async {
    state = const AsyncValue.loading();
    try {
      final reelId = await _repository.createReel(reel);
      state = const AsyncValue.data(null);
      return reelId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateReel(String reelId, Reel reel) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateReel(reelId, reel);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteReel(String reelId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteReel(reelId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final reelsControllerProvider =
    StateNotifierProvider<ReelsController, AsyncValue<void>>((ref) {
  final repository = ref.watch(reelRepositoryProvider);
  return ReelsController(repository);
});
