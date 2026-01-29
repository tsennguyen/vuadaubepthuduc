import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipes_repository.dart';

class RecipesState {
  const RecipesState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.error,
    this.hasMore = true,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<RecipeSummary> items;
  final Object? error;
  final bool hasMore;

  RecipesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<RecipeSummary>? items,
    Object? error = _noUpdateError,
    bool? hasMore,
  }) {
    return RecipesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      error: error == _noUpdateError ? this.error : error,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  static const _noUpdateError = Object();
}

final recipesRepositoryProvider = Provider<RecipesRepository>((ref) {
  return RecipesRepositoryImpl();
});

final recipesControllerProvider =
    StateNotifierProvider<RecipesController, RecipesState>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  return RecipesController(repo);
});

class RecipesController extends StateNotifier<RecipesState> {
  RecipesController(this._repository) : super(const RecipesState());

  final RecipesRepository _repository;

  Future<void> loadInitial({int limit = 20}) => refresh(limit: limit);

  Future<void> refresh({int limit = 20}) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      hasMore: true,
      items: <RecipeSummary>[],
    );
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
          await _repository.fetchRecipes(limit: limit, before: lastCreatedAt);
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

  List<RecipeSummary> _mergeUnique(
    List<RecipeSummary> current,
    List<RecipeSummary> next,
  ) {
    final ids = <String>{for (final item in current) item.id};
    final merged = [...current];
    for (final item in next) {
      if (ids.add(item.id)) {
        merged.add(item);
      }
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
