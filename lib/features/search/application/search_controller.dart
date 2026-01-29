import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai_service.dart';
import '../domain/ai_recipe_suggestion.dart';
import '../data/search_repository.dart';
import '../../profile/domain/user_summary.dart';

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.loading = false,
    this.results = const [],
    this.userResults = const [],
    this.aiSuggestions = const [],
    this.error,
    this.aiLoading = false,
    this.aiError,
  });

  final String query;
  final bool loading;
  final List<SearchResultItem> results;
  final List<UserSummary> userResults;
  final List<AiRecipeSuggestion> aiSuggestions;
  final String? error;
  final bool aiLoading;
  final String? aiError;

  SearchState copyWith({
    String? query,
    bool? loading,
    List<SearchResultItem>? results,
    List<UserSummary>? userResults,
    List<AiRecipeSuggestion>? aiSuggestions,
    bool? aiLoading,
    Object? error = _noUpdateError,
    Object? aiError = _noUpdateError,
  }) {
    return SearchState(
      query: query ?? this.query,
      loading: loading ?? this.loading,
      results: results ?? this.results,
      userResults: userResults ?? this.userResults,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      aiLoading: aiLoading ?? this.aiLoading,
      error: identical(error, _noUpdateError) ? this.error : error as String?,
      aiError: identical(aiError, _noUpdateError)
          ? this.aiError
          : aiError as String?,
    );
  }

  static const _noUpdateError = Object();
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return FirestoreSearchRepository();
});

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

final searchControllerProvider =
    StateNotifierProvider<SearchController, SearchState>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  final aiService = ref.watch(aiServiceProvider);
  return SearchController(repo, aiService);
});

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._repository, this._aiService)
      : super(const SearchState());

  final SearchRepository _repository;
  final AiService _aiService;

  void setQuery(String q) {
    state = state.copyWith(query: q);
  }

  Future<void> search(String query) async {
    final normalized = query.trim();
    state = state.copyWith(query: normalized);

    if (normalized.length < 1) {
      state = state.copyWith(
        loading: false,
        aiLoading: false,
        results: const [],
        userResults: const [],
        aiSuggestions: const [],
        error: null,
        aiError: null,
      );
      return;
    }

    // Check if searching for users (starts with @)
    final isUserSearch = normalized.startsWith('@');
    final searchQuery = isUserSearch ? normalized.substring(1).trim() : normalized;

    if (searchQuery.isEmpty) {
      state = state.copyWith(
        loading: false,
        results: const [],
        userResults: const [],
        error: null,
      );
      return;
    }

    state = state.copyWith(
      loading: true,
      error: null,
      aiSuggestions: const [],
      aiError: null,
    );

    try {
      if (isUserSearch) {
        // Search ONLY users when @ prefix is used
        final users = await _repository.searchUsers(searchQuery, limit: 10);
        state = state.copyWith(
          loading: false,
          results: const [],
          userResults: users,
        );
        // NO AI suggestions when searching users
      } else {
        // Search posts/recipes (no users)
        final contentResults = await _repository.searchByKeyword(searchQuery);
        state = state.copyWith(
          loading: false,
          results: contentResults,
          userResults: const [], // Don't show users without @
        );

        // Only use AI if NO content results found and query is long enough
        if (contentResults.isEmpty && searchQuery.length >= 3) {
          await _loadAiSuggestions(searchQuery);
        }
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Không tìm được kết quả: $e',
      );
    }
  }

  Future<void> _loadAiSuggestions(String query) async {
    if (query.trim().length < 3) return;

    state = state.copyWith(aiLoading: true, aiError: null);
    try {
      final ideasData = await _aiService.suggestRecipesByIngredients(
        ingredients: [query],
      );
      final suggestions = ideasData
          .map((e) {
            try {
              return AiRecipeSuggestion.fromMap(e);
            } catch (_) {
              return null;
            }
          })
          .whereType<AiRecipeSuggestion>()
          .toList();
      state = state.copyWith(aiLoading: false, aiSuggestions: suggestions, aiError: null);
    } on AiException catch (e) {
      // If AI is disabled by admin (config.enabled = false), silently fail
      if (e.code == AiErrorCode.config) {
        state = state.copyWith(
          aiLoading: false,
          aiSuggestions: const [],
          aiError: null, // Don't show error to user
        );
      } else {
        state = state.copyWith(
          aiLoading: false,
          aiSuggestions: const [],
          aiError: e.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        aiLoading: false,
        aiSuggestions: const [],
        aiError: 'Không lấy được gợi ý AI: $e',
      );
    }
  }
}
