import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_chat_moderation_repository.dart';

class AdminChatModerationState {
  const AdminChatModerationState({
    required this.filter,
    required this.violations,
    this.actionInProgress = false,
    this.lastError,
  });

  final ChatViolationFilter filter;
  final AsyncValue<List<ChatViolationRecord>> violations;
  final bool actionInProgress;
  final String? lastError;

  AdminChatModerationState copyWith({
    ChatViolationFilter? filter,
    AsyncValue<List<ChatViolationRecord>>? violations,
    bool? actionInProgress,
    String? lastError,
  }) {
    return AdminChatModerationState(
      filter: filter ?? this.filter,
      violations: violations ?? this.violations,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      lastError: lastError,
    );
  }

  factory AdminChatModerationState.initial() {
    return const AdminChatModerationState(
      filter: ChatViolationFilter(),
      violations: AsyncValue.loading(),
    );
  }
}

class AdminChatModerationController
    extends StateNotifier<AdminChatModerationState> {
  AdminChatModerationController(
    this._repository,
  ) : super(AdminChatModerationState.initial()) {
    _subscribe();
  }

  final AdminChatModerationRepository _repository;
  StreamSubscription<List<ChatViolationRecord>>? _sub;

  void _subscribe() {
    _sub?.cancel();
    _sub = null;
    
    if (!mounted) return;
    
    state = state.copyWith(
      violations: const AsyncValue.loading(),
      lastError: null,
    );

    _sub = _repository.watchViolations(state.filter).listen(
      (data) {
        if (!mounted) return;
        state = state.copyWith(
          violations: AsyncValue.data(data),
          lastError: null,
        );
      },
      onError: (error, stack) {
        if (!mounted) return;
        state = state.copyWith(
          violations: AsyncValue.error(error, stack),
          lastError: '$error',
        );
      },
    );
  }

  void setStatusFilter(ChatViolationStatus status) {
    if (state.filter.status == status) return;
    state = state.copyWith(filter: state.filter.copyWith(status: status));
    _subscribe();
  }

  void setSeverityFilter(ChatViolationSeverity severity) {
    if (state.filter.severity == severity) return;
    state = state.copyWith(filter: state.filter.copyWith(severity: severity));
    _subscribe();
  }

  void setTimeRange(ChatViolationTimeRange range) {
    if (state.filter.timeRange == range) return;
    state = state.copyWith(filter: state.filter.copyWith(timeRange: range));
    _subscribe();
  }

  void setSearch(String search) {
    final trimmed = search.trim();
    if (state.filter.search == trimmed) return;
    state = state.copyWith(filter: state.filter.copyWith(search: trimmed));
    _subscribe();
  }

  Future<void> refresh() async {
    _subscribe();
  }

  Future<void> updateStatus({
    required String violationId,
    required ChatViolationStatus status,
    String? notes,
    String? reviewerId,
  }) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.updateStatus(
        violationId: violationId,
        status: status,
        notes: notes,
        reviewerId: reviewerId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<void> warnViolation({
    required ChatViolation violation,
    String? notes,
    String? reviewerId,
  }) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.warnViolation(
        violation: violation,
        notes: notes,
        reviewerId: reviewerId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<void> ignoreViolation({
    required ChatViolation violation,
    String? notes,
    String? reviewerId,
  }) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.ignoreViolation(
        violation: violation,
        notes: notes,
        reviewerId: reviewerId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<void> banUserFromViolation({
    required ChatViolation violation,
    String? reason,
    DateTime? until,
    String? reviewerId,
  }) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.banUserFromViolation(
        violation: violation,
        reason: reason,
        until: until,
        reviewerId: reviewerId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<void> unbanUser(String uid) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.unbanUser(uid);
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<void> lockChatFromViolation({
    required ChatViolation violation,
    String? reviewerId,
  }) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.lockChatFromViolation(
        violation: violation,
        reviewerId: reviewerId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<void> unlockChat({
    required String chatId,
    String? violationId,
    String? reviewerId,
  }) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.unlockChat(
        chatId: chatId,
        violationId: violationId,
        reviewerId: reviewerId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<void> deleteChat({
    required String chatId,
    String? violationId,
    String? reviewerId,
  }) async {
    state = state.copyWith(actionInProgress: true, lastError: null);
    try {
      await _repository.deleteChat(
        chatId: chatId,
        violationId: violationId,
        reviewerId: reviewerId,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(lastError: '$e');
    } finally {
      if (mounted) state = state.copyWith(actionInProgress: false);
    }
  }

  Future<ChatViolationMetrics> fetchMetrics({
    required String offenderId,
    required String chatId,
  }) {
    return _repository.fetchMetrics(offenderId: offenderId, chatId: chatId);
  }

  @override
  void dispose() {
    super.dispose();
    _sub?.cancel();
  }
}

final adminChatModerationControllerProvider = AutoDisposeStateNotifierProvider<
    AdminChatModerationController, AdminChatModerationState>((ref) {
  final repo = ref.watch(adminChatModerationRepositoryProvider);
  return AdminChatModerationController(repo);
});
