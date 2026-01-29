import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/modern_loading.dart';
import '../application/chat_list_controller.dart';
import '../application/chat_room_controller.dart';
import '../application/create_chat_controller.dart';
import '../data/chat_repository.dart';
import '../domain/presence.dart';
import '../../profile/application/profile_controller.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListProvider);
    final createState = ref.watch(createChatControllerProvider);
    final s = S(ref.watch(localeProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.messages),
        actions: [
          IconButton(
            tooltip: s.newMessage,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed:
                createState.isCreating ? null : () => _startDm(context, ref),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Chef AI Button - Icon only, larger
          FloatingActionButton(
            heroTag: 'chef_ai_fab',
            onPressed: () => context.go('/ai-assistant'),
            tooltip: 'Chef AI',
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            elevation: 4,
            child: const Icon(Icons.psychology_alt_rounded, size: 28),
          ),
          const SizedBox(height: 16),
          // Create Group Button - Icon only, larger with animation
          _ModernFab(
            isLoading: createState.isCreating,
            onPressed: () => _startGroup(context, ref),
            label: s.createGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          if (createState.isCreating)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                if (chats.isEmpty) {
                  return AppEmptyView(
                    title: s.noChatsYet,
                    subtitle: s.startChatting,
                  );
                }
                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return ChatListTile(
                      chat: chat,
                      onTap: () =>
                          context.go('/chat/${chat.id}', extra: chat),
                    );
                  },
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonLoader(height: 72),
                ),
              ),
              error: (error, _) => AppErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(chatListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDm(BuildContext context, WidgetRef ref) async {
    final chatId =
        await ref.read(createChatControllerProvider.notifier).createDm(context);
    if (chatId != null && context.mounted) {
      context.go('/chat/$chatId');
    }
  }

  Future<void> _startGroup(BuildContext context, WidgetRef ref) async {
    final chatId = await ref
        .read(createChatControllerProvider.notifier)
        .createGroup(context);
    if (chatId != null && context.mounted) {
      // Thêm delay nhỏ để đảm bảo dialog đã dispose trước khi navigate
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) {
        // Sử dụng go thay vì push để tránh duplicate GlobalKey 
        context.go('/chat/$chatId');
      }
    }
  }
}

class _OnlineAvatar extends ConsumerWidget {
  const _OnlineAvatar({required this.chat});
  final ChatSummary chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUid = chat.memberIds.firstWhere((id) => id != ref.watch(currentUserIdProvider), orElse: () => '');
    final presenceAsync = otherUid.isNotEmpty ? ref.watch(presenceProvider(otherUid)) : const AsyncValue.data(PresenceData(isOnline: false));
    final primaryColor = Theme.of(context).colorScheme.primary;

    final avatar = CircleAvatar(
      backgroundImage: (chat.photoUrl ?? chat.avatarUrl)?.isNotEmpty == true
          ? NetworkImage(chat.photoUrl ?? chat.avatarUrl!)
          : null,
      backgroundColor: (chat.photoUrl ?? chat.avatarUrl)?.isNotEmpty != true
          ? primaryColor.withValues(alpha: 0.12)
          : null,
      child: (chat.photoUrl ?? chat.avatarUrl)?.isNotEmpty != true
          ? Icon(Icons.person, color: primaryColor)
          : null,
    );

    return presenceAsync.maybeWhen(
      data: (p) => Stack(
        children: [
          avatar,
          if (p.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
        ],
      ),
      orElse: () => avatar,
    );
  }
}

class ChatListTile extends ConsumerStatefulWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    this.onTap,
  });

  final ChatSummary chat;
  final VoidCallback? onTap;

  @override
  ConsumerState<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends ConsumerState<ChatListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));
    final messageText = widget.chat.lastMessageText.trim();
    final hasAuthor = (widget.chat.lastMessageSenderName ?? '').isNotEmpty;
    final hasText = messageText.isNotEmpty;
    final subtitle = !hasText
        ? s.startConversation
        : hasAuthor
            ? '${widget.chat.lastMessageSenderName}: $messageText'
            : messageText;
    final timeLabel = _formatTime(widget.chat.lastMessageAt, context);
    final unread = widget.chat.unreadCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered
                ? (theme.brightness == Brightness.dark
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.3))
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHover: (hover) => setState(() => _isHovered = hover),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  widget.chat.isGroup
                      ? (widget.chat.photoUrl != null && widget.chat.photoUrl!.isNotEmpty
                          ? AppAvatar(url: widget.chat.photoUrl!, size: 56)
                          : GroupAvatar(photoUrls: widget.chat.groupAvatarUrls))
                      : _OnlineAvatar(chat: widget.chat),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                : theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: theme.brightness == Brightness.dark ? 0.15 : 0.4,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$unread',
                            style: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.photoUrls});

  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    if (photoUrls.isEmpty) {
      return const AppAvatar(
        url: '',
        size: 56,
        fallbackText: '',
      );
    }
    if (photoUrls.length == 1) {
      return AppAvatar(url: photoUrls.first, size: 56);
    }
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: AppAvatar(url: photoUrls[0], size: 36),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: AppAvatar(url: photoUrls[1], size: 36),
          ),
        ],
      ),
    );
  }
}

class _ModernFab extends StatelessWidget {
  const _ModernFab({
    required this.onPressed,
    required this.isLoading,
    this.label = 'Create Group',
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.4)
        : theme.colorScheme.primary;
    
    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      tooltip: label,
      backgroundColor: baseColor,
      foregroundColor: isDark
          ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
          : Colors.white,
      elevation: 6,
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(
                  isDark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                      : Colors.white,
                ),
              ),
            )
          : const Icon(Icons.group_add_rounded, size: 28),
    );
  }
}

String _formatTime(DateTime? time, BuildContext context) {
  if (time == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(time.year, time.month, time.day);
  
  // Get locale from context - this is a workaround since we can't use ref here
  final locale = Localizations.localeOf(context);
  final isVi = locale.languageCode == 'vi';
  
  if (date == today) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return isVi ? 'Hôm nay $hh:$mm' : 'Today $hh:$mm';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (date == yesterday) {
    return isVi ? 'Hôm qua' : 'Yesterday';
  }
  final dd = time.day.toString().padLeft(2, '0');
  final mm = time.month.toString().padLeft(2, '0');
  return '$dd/$mm';
}
