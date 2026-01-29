import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/feed_repository.dart';
import '../data/post_model.dart';
import '../data/recipe_model.dart';

class FeedState<T> {
  FeedState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.error,
    this.hasMore = true,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  final bool isLoading;
  final bool isLoadingMore;
  final List<T> items;
  final Object? error;
  final bool hasMore;
  final DateTime lastUpdated;

  FeedState<T> copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<T>? items,
    Object? error = _noUpdateError,
    bool? hasMore,
    DateTime? lastUpdated,
  }) {
    return FeedState<T>(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      error: error == _noUpdateError ? this.error : error,
      hasMore: hasMore ?? this.hasMore,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  static const _noUpdateError = Object();
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepositoryImpl();
});

final homeFeedControllerProvider =
    StateNotifierProvider<HomeFeedController, FeedState<FeedItem>>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return HomeFeedController(repo);
});

final postFeedControllerProvider =
    StateNotifierProvider<PostFeedController, FeedState<Post>>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return PostFeedController(repo);
});

final recipeFeedControllerProvider =
    StateNotifierProvider<RecipeFeedController, FeedState<Recipe>>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return RecipeFeedController(repo);
});

class PostFeedController extends StateNotifier<FeedState<Post>> {
  PostFeedController(this._repository) : super(FeedState<Post>());

  final FeedRepository _repository;

  Future<void> refresh({int limit = 10}) async {
    state =
        state.copyWith(isLoading: true, error: null, hasMore: true, items: []);
    try {
      final items = await _repository.fetchPosts(limit: limit);
      state = state.copyWith(
        isLoading: false,
        items: items,
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore({int limit = 10}) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final last = state.items.isNotEmpty ? state.items.last : null;
      final items = await _repository.fetchPosts(
        lastPost: last,
        limit: limit,
      );
      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...items],
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }
}

class RecipeFeedController extends StateNotifier<FeedState<Recipe>> {
  RecipeFeedController(this._repository) : super(FeedState<Recipe>());

  final FeedRepository _repository;

  Future<void> refresh({int limit = 10}) async {
    state =
        state.copyWith(isLoading: true, error: null, hasMore: true, items: []);
    try {
      final items = await _repository.fetchRecipes(limit: limit);
      state = state.copyWith(
        isLoading: false,
        items: items,
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore({int limit = 10}) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final last = state.items.isNotEmpty ? state.items.last : null;
      final items = await _repository.fetchRecipes(
        lastRecipe: last,
        limit: limit,
      );
      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...items],
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }
}

class HomeFeedController extends StateNotifier<FeedState<FeedItem>> {
  HomeFeedController(this._repository) : super(FeedState<FeedItem>());

  final FeedRepository _repository;

  Future<void> loadInitial({int limit = 20}) => refresh(limit: limit);

  Future<void> refresh({int limit = 20}) async {
    state =
        state.copyWith(isLoading: true, error: null, hasMore: true, items: []);
    try {
      final items = await _repository.fetchHomeFeed(limit: limit);
      state = state.copyWith(
        isLoading: false,
        items: items,
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore({int limit = 20}) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    final lastCreatedAt =
        state.items.isNotEmpty ? state.items.last.createdAt : null;
    if (lastCreatedAt == null) {
      await refresh(limit: limit);
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final items =
          await _repository.fetchHomeFeed(limit: limit, before: lastCreatedAt);
      final merged = _mergeUnique(state.items, items);
      state = state.copyWith(
        isLoadingMore: false,
        items: merged,
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  List<FeedItem> _mergeUnique(List<FeedItem> current, List<FeedItem> next) {
    final keys = <String>{for (final item in current) _key(item)};
    final merged = [...current];
    for (final item in next) {
      final key = _key(item);
      if (keys.add(key)) {
        merged.add(item);
      }
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  String _key(FeedItem item) => '${item.type.name}-${item.id}';

  /// Load following feed with friend IDs
  Future<void> refreshFollowingFeed({
    required List<String> friendIds,
    int limit = 20,
  }) async {
    state =
        state.copyWith(isLoading: true, error: null, hasMore: true, items: []);
    try {
      final items = await _repository.fetchFollowingFeed(
        followingIds: friendIds,
        limit: limit,
      );
      state = state.copyWith(
        isLoading: false,
        items: items,
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMoreFollowingFeed({
    required List<String> friendIds,
    int limit = 20,
  }) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    final lastCreatedAt =
        state.items.isNotEmpty ? state.items.last.createdAt : null;
    if (lastCreatedAt == null) {
      await refreshFollowingFeed(friendIds: friendIds, limit: limit);
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final items = await _repository.fetchFollowingFeed(
        followingIds: friendIds,
        limit: limit,
        before: lastCreatedAt,
      );
      final merged = _mergeUnique(state.items, items);
      state = state.copyWith(
        isLoadingMore: false,
        items: merged,
        hasMore: items.length == limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }
}
