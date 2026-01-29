import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tokenizer.dart';
import '../../feed/data/recipe_model.dart';
import '../data/search_repository.dart';
import 'search_controller.dart';

class IngredientSearchState {
  const IngredientSearchState({
    this.ingredients = const [],
    this.mode = IngredientFilterMode.any,
    this.isLoading = false,
    this.error,
    this.results = const [],
  });

  final List<String> ingredients;
  final IngredientFilterMode mode;
  final bool isLoading;
  final Object? error;
  final List<Recipe> results;

  IngredientSearchState copyWith({
    List<String>? ingredients,
    IngredientFilterMode? mode,
    bool? isLoading,
    Object? error = _noUpdateError,
    List<Recipe>? results,
  }) {
    return IngredientSearchState(
      ingredients: ingredients ?? this.ingredients,
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
      error: error == _noUpdateError ? this.error : error,
      results: results ?? this.results,
    );
  }

  static const _noUpdateError = Object();
}

class IngredientSearchController extends StateNotifier<IngredientSearchState> {
  IngredientSearchController(this._repository)
      : super(const IngredientSearchState());

  final SearchRepository _repository;

  void addIngredient(String rawInput) {
    final tokens = tokenize(rawInput)
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return;
    final current = {...state.ingredients, ...tokens}.toList();
    state = state.copyWith(ingredients: current);
  }

  void removeIngredient(String token) {
    final updated = state.ingredients.where((t) => t != token).toList();
    state = state.copyWith(ingredients: updated);
  }

  void changeMode(IngredientFilterMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode);
  }

  Future<void> submit() async {
    if (state.ingredients.isEmpty) {
      state = state.copyWith(results: [], error: null);
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final recipes = await _repository.searchRecipesByIngredients(
        tokens: state.ingredients,
        mode: state.mode,
        limit: 20,
      );
      state = state.copyWith(isLoading: false, results: recipes);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

final ingredientSearchControllerProvider =
    StateNotifierProvider<IngredientSearchController, IngredientSearchState>(
  (ref) {
    final repo = ref.watch(searchRepositoryProvider);
    return IngredientSearchController(repo);
  },
);
