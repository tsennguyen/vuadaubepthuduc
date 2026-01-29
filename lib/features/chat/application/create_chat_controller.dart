import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_functions_repository.dart';
import '../presentation/widgets/user_picker_dialog.dart';
import '../../social/application/social_providers.dart';
import '../../social/domain/friend_repository.dart';
import '../../profile/domain/user_ban_guard.dart';
import '../../profile/application/profile_controller.dart';

class CreateChatState {
  const CreateChatState({
    this.isCreating = false,
    this.error,
  });

  final bool isCreating;
  final Object? error;

  CreateChatState copyWith({
    bool? isCreating,
    Object? error = _noUpdateError,
  }) {
    return CreateChatState(
      isCreating: isCreating ?? this.isCreating,
      error: error == _noUpdateError ? this.error : error,
    );
  }

  static const _noUpdateError = Object();
}

final chatFunctionsRepositoryProvider =
    Provider<ChatFunctionsRepository>((ref) {
  return ChatFunctionsRepositoryImpl();
});

final createChatControllerProvider =
    StateNotifierProvider.autoDispose<CreateChatController, CreateChatState>(
        (ref) {
  final repo = ref.watch(chatFunctionsRepositoryProvider);
  final friendRepo = ref.watch(friendRepositoryProvider);
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final banGuard = ref.watch(userBanGuardProvider);
  return CreateChatController(
    functionsRepository: repo,
    friendRepository: friendRepo,
    currentUserId: currentUserId,
    banGuard: banGuard,
  );
});

class CreateChatController extends StateNotifier<CreateChatState> {
  CreateChatController({
    required ChatFunctionsRepository functionsRepository,
    required FriendRepository friendRepository,
    required String? currentUserId,
    required UserBanGuard banGuard,
  })  : _functionsRepository = functionsRepository,
        _friendRepository = friendRepository,
        _currentUserId = currentUserId,
        _banGuard = banGuard,
        super(const CreateChatState());

  final ChatFunctionsRepository _functionsRepository;
  final FriendRepository _friendRepository;
  final String? _currentUserId;
  final UserBanGuard _banGuard;

  Future<String?> createDm(BuildContext context) async {
    final userId = _currentUserId;
    final messenger = ScaffoldMessenger.of(context);
    if (userId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Hay dang nhap')));
      return null;
    }
    if (!await _ensureNotBanned(context)) return null;
    if (!context.mounted) return null;
    final toUser = await UserPickerDialog.pickSingle(
      context,
      excludeUid: userId,
    );
    if (!context.mounted) return null;
    if (toUser == null) return null;
    final isFriend = await _friendRepository.isFriend(toUser.uid);
    if (!isFriend) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chi ket ban moi co the nhan tin')),
      );
      return null;
    }
    if (!mounted) return null;
    state = state.copyWith(isCreating: true, error: null);
    try {
      final chatId = await _functionsRepository.createDM(toUid: toUser.uid);
      return chatId;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e);
      }
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Khong tao duoc chat: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        state = state.copyWith(isCreating: false);
      }
    }
  }

  Future<String?> createGroup(BuildContext context) async {
    final userId = _currentUserId;
    final messenger = ScaffoldMessenger.of(context);
    if (userId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Hay dang nhap')));
      return null;
    }
    if (!await _ensureNotBanned(context)) return null;
    if (!context.mounted) return null;
    final name = await _askGroupName(context);
    if (!context.mounted) return null;
    if (name == null || name.trim().isEmpty) return null;

    final picked = await UserPickerDialog.pickMulti(
      context,
      excludeUid: userId,
    );
    if (!context.mounted) return null;
    
    // If user didn't pick anyone, assume they canceled
    // (Dialog requires at least one selection to submit)
    if (picked.isEmpty) {
      return null; // Silent cancel, no error message
    }
    
    final memberIds = {
      ...picked.map((u) => u.uid),
      userId,
    }.toList();
    
    // This should not happen if dialog works correctly,
    // but keep as safety check
    if (memberIds.length < 2) {
      messenger.showSnackBar(const SnackBar(content: Text('Cần ít nhất 2 thành viên')));
      return null;
    }
    
    for (final member in picked) {
      final ok = await _friendRepository.isFriend(member.uid);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Chỉ có thể thêm bạn bè vào nhóm')),
        );
        return null;
      }
    }

    if (!mounted) return null;
    state = state.copyWith(isCreating: true, error: null);
    try {
      final chatId = await _functionsRepository.createGroup(
        name: name,
        memberIds: memberIds,
      );
      return chatId;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e);
      }
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Không thể tạo nhóm: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        state = state.copyWith(isCreating: false);
      }
    }
  }

  Future<String?> _askGroupName(BuildContext context) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final hasText = controller.text.trim().isNotEmpty;
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerHighest,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Tạo nhóm',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên nhóm',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      prefixIcon: Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        Navigator.of(dialogContext).pop(value.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Hủy',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: hasText
                              ? LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                )
                              : null,
                          color: hasText ? null : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: hasText
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: ElevatedButton(
                          onPressed: hasText
                              ? () {
                                  Navigator.of(dialogContext).pop(controller.text.trim());
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Tạo',
                            style: TextStyle(
                              color: hasText ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    
    // If user canceled (null), return without error message
    if (result == null) {
      return null;
    }
    
    // If user submitted but name is empty, show error
    if (result.trim().isEmpty) {
      if (!context.mounted) return null;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Tên nhóm không được để trống'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return null;
    }
    
    return result.trim();
  }

  Future<bool> _ensureNotBanned(BuildContext context) async {
    try {
      await _banGuard.ensureNotBanned();
      return true;
    } on UserBannedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    }
  }
}
