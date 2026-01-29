import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/suggest_repository.dart';

class SuggestState {
  const SuggestState({
    this.isLoading = false,
    this.error,
    this.data,
  });

  final bool isLoading;
  final Object? error;
  final SuggestResult? data;

  SuggestState copyWith({
    bool? isLoading,
    Object? error = _noUpdateError,
    SuggestResult? data,
  }) {
    return SuggestState(
      isLoading: isLoading ?? this.isLoading,
      error: error == _noUpdateError ? this.error : error,
      data: data ?? this.data,
    );
  }

  static const _noUpdateError = Object();
}

class SuggestParams {
  SuggestParams({
    required this.rawQuery,
    required List<String> tokens,
    required this.type,
  }) : tokens = List<String>.from(tokens)..sort();

  final String rawQuery;
  final List<String> tokens;
  final String type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SuggestParams) return false;
    if (rawQuery != other.rawQuery || type != other.type) return false;
    if (tokens.length != other.tokens.length) return false;
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i] != other.tokens[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([rawQuery, type, ...tokens]);
}

final suggestRepositoryProvider = Provider<SuggestRepository>((ref) {
  return SuggestRepositoryImpl();
});

final suggestControllerProvider =
    StateNotifierProvider.family<SuggestController, SuggestState, SuggestParams>(
        (ref, params) {
  final repo = ref.watch(suggestRepositoryProvider);
  return SuggestController(repo, params);
});

class SuggestController extends StateNotifier<SuggestState> {
  SuggestController(this._repository, this._params)
      : super(const SuggestState());

  final SuggestRepository _repository;
  final SuggestParams _params;

  Future<void> fetchSuggest() async {
    if (_params.rawQuery.trim().isEmpty && _params.tokens.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repository.suggest(
        rawQuery: _params.rawQuery,
        tokens: _params.tokens,
        type: _params.type,
      );
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}
