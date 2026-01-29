import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../application/chat_room_controller.dart';
import '../../domain/chat_display.dart';

class ChatRoomHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatRoomHeader({
    super.key,
    required this.chatId,
    required this.onOpenInfo,
    this.onSearch,
    this.hideLeading = false,
    this.actions,
  });

  final String chatId;
  final VoidCallback onOpenInfo;
  final VoidCallback? onSearch;
  final bool hideLeading;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayAsync = ref.watch(chatRoomDisplayProvider(chatId));

    return displayAsync.when(
      data: (display) {
        return AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainer,
                ],
              ),
            ),
          ),
          elevation: 0,
          scrolledUnderElevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          leading: hideLeading ? null : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/chat');
              }
            },
          ),
          automaticallyImplyLeading: false,
          titleSpacing: hideLeading ? 16 : 0,
          title: Row(
            children: [
              _Avatar(display: display),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      display.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!display.isGroup && display.peerUserId != null)
                      _PresenceSubtitle(userId: display.peerUserId!)
                    else if (display.subtitle != null)
                      Text(
                        display.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: onSearch,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: onOpenInfo,
            ),
            if (actions != null) ...actions!,
          ],
        );
      },
      loading: () => AppBar(title: const Text('...')),
      error: (e, _) => AppBar(title: const Text('Lỗi')),
    );
  }
}

class _PresenceSubtitle extends ConsumerWidget {
  const _PresenceSubtitle({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(presenceProvider(userId));

    return presenceAsync.when(
      data: (presence) {
        if (presence.isOnline) {
          return Text(
            'Đang hoạt động',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        } else if (presence.lastSeenAt != null) {
          final diff = DateTime.now().difference(presence.lastSeenAt!);
          String timeStr;
          if (diff.inMinutes < 60) {
            timeStr = 'Hoạt động ${diff.inMinutes} phút trước';
          } else if (diff.inHours < 24) {
            timeStr = 'Hoạt động ${diff.inHours} giờ trước';
          } else {
            timeStr = 'Hoạt động vài ngày trước';
          }
          return Text(
            timeStr,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.display});
  final ChatDisplayInfo display;

  @override
  Widget build(BuildContext context) {
    if (!display.isGroup) {
      return AppAvatar(
        url: display.avatarUrl ?? '',
        size: 40,
        fallbackText: (display.title.isNotEmpty) ? display.title[0] : '?',
      );
    }

    if (display.avatarUrl != null && display.avatarUrl!.isNotEmpty) {
      return AppAvatar(url: display.avatarUrl!, size: 40);
    }

    // Stack group avatars
    if (display.groupAvatarUrls.isEmpty) {
      return const AppAvatar(url: '', size: 40, fallbackText: 'G');
    }

    if (display.groupAvatarUrls.length == 1) {
      return AppAvatar(url: display.groupAvatarUrls.first, size: 40);
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            child: AppAvatar(
              url: display.groupAvatarUrls[0],
              size: 28,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                shape: BoxShape.circle,
              ),
              child: AppAvatar(
                url: display.groupAvatarUrls[1],
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
