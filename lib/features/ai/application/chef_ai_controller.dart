import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai_chef_service.dart';
import '../../profile/application/profile_controller.dart';

@immutable
class ChefAiMessage {
  const ChefAiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
}

@immutable
class ChefAiState {
  const ChefAiState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.sessionId,
  });

  final List<ChefAiMessage> messages;
  final bool isLoading;
  final String? error;
  final String? sessionId;

  ChefAiState copyWith({
    List<ChefAiMessage>? messages,
    bool? isLoading,
    String? Function()? error,
    String? Function()? sessionId,
  }) {
    return ChefAiState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      sessionId: sessionId != null ? sessionId() : this.sessionId,
    );
  }
}

final aiChefServiceProvider = Provider<AiChefService>((ref) {
  return AiChefService();
});

final chefAiControllerProvider =
    StateNotifierProvider<ChefAiController, ChefAiState>((ref) {
  final service = ref.watch(aiChefServiceProvider);
  return ChefAiController(service, ref);
});

class ChefAiController extends StateNotifier<ChefAiState> {
  ChefAiController(this._service, this._ref) : super(const ChefAiState());

  final AiChefService _service;
  final Ref _ref;

  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    // Get current user ID
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(
        error: () => 'Vui lòng đăng nhập để sử dụng Chef AI',
      );
      return;
    }
    final uid = userId;

    // Add user message
    final userMsg = ChefAiMessage(
      role: 'user',
      content: userMessage,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: () => null,
    );

    try {
      // Call AI service with userId and sessionId
      final response = await _service.chat(
        userId: uid,
        message: userMessage,
        sessionId: state.sessionId,
      );

      // Add assistant response
      final assistantMsg = ChefAiMessage(
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  void clearMessages() {
    state = const ChefAiState();
  }

  void clearError() {
    state = state.copyWith(error: () => null);
  }
}
