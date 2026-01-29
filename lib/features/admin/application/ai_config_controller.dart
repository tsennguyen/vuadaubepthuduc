import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_config_repository.dart';

class AiConfigListState {
  const AiConfigListState({
    required this.configs,
    this.isLoading = false,
    this.error,
  });

  final AsyncValue<List<AiConfig>> configs;
  final bool isLoading;
  final String? error;

  AiConfigListState copyWith({
    AsyncValue<List<AiConfig>>? configs,
    bool? isLoading,
    String? error,
  }) {
    return AiConfigListState(
      configs: configs ?? this.configs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AiConfigListController extends StateNotifier<AiConfigListState> {
  AiConfigListController(this._repository)
      : super(const AiConfigListState(configs: AsyncValue.loading())) {
    _subscription = _repository.watchAllConfigs().listen(
      (data) {
        if (!mounted) return;
        state = state.copyWith(
          configs: AsyncValue.data(data),
          error: null,
        );
      },
      onError: (error, stack) {
        if (!mounted) return;
        state = state.copyWith(
          configs: AsyncValue.error(error, stack),
          error: error.toString(),
        );
      },
    );
  }

  final AiConfigRepository _repository;
  late final StreamSubscription<List<AiConfig>> _subscription;

  Future<void> updateConfig(String id, Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateConfig(id, updates);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleEnabled(String id, bool enabled) async {
    await updateConfig(id, {'enabled': enabled});
  }

  Future<void> seedDefaults() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _repository;
      if (repo is FirestoreAiConfigRepository) {
        await repo.seedDefaultConfigs();
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _subscription.cancel();
  }
}

final aiConfigListControllerProvider = StateNotifierProvider.autoDispose<
    AiConfigListController, AiConfigListState>((ref) {
  final repository = ref.watch(aiConfigRepositoryProvider);
  return AiConfigListController(repository);
});
