import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_settings_repository.dart';

class AdminSettingsState {
  const AdminSettingsState({
    required this.settings,
    this.saving = false,
    this.lastError,
  });

  final AsyncValue<AdminSettings?> settings;
  final bool saving;
  final String? lastError;

  AdminSettingsState copyWith({
    AsyncValue<AdminSettings?>? settings,
    bool? saving,
    String? lastError,
  }) {
    return AdminSettingsState(
      settings: settings ?? this.settings,
      saving: saving ?? this.saving,
      lastError: lastError,
    );
  }

  factory AdminSettingsState.initial() {
    return const AdminSettingsState(
      settings: AsyncValue.loading(),
    );
  }
}

class AdminSettingsController extends StateNotifier<AdminSettingsState> {
  AdminSettingsController(this._repository)
      : super(AdminSettingsState.initial()) {
    _subscribe();
  }

  final AdminSettingsRepository _repository;
  StreamSubscription<AdminSettings?>? _sub;

  void _subscribe() {
    _sub?.cancel();
    _sub = null;
    
    if (!mounted) return;
    
    state = state.copyWith(settings: const AsyncValue.loading(), lastError: null);
    _sub = _repository.watchGeneral().listen(
      (settings) {
        if (!mounted) return;
        state = state.copyWith(settings: AsyncValue.data(settings));
      },
      onError: (error, stack) {
        if (!mounted) return;
        state = state.copyWith(settings: AsyncValue.error(error, stack));
      },
    );
  }

  Future<void> refresh() async {
    _subscribe();
  }

  Future<void> save(AdminSettings settings, {required String updatedBy}) async {
    state = state.copyWith(saving: true, lastError: null);
    try {
      await _repository.save(settings, updatedBy: updatedBy);
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _sub?.cancel();
  }
}

final adminSettingsControllerProvider =
    AutoDisposeStateNotifierProvider<AdminSettingsController, AdminSettingsState>(
        (ref) {
  final repo = ref.watch(adminSettingsRepositoryProvider);
  return AdminSettingsController(repo);
});
