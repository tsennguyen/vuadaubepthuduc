import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/modern_loading.dart';
import '../../../shared/widgets/modern_ui_components.dart';
import '../../chat/application/create_chat_controller.dart';
import '../../profile/application/user_cache_controller.dart';
import '../../profile/domain/user_summary.dart';
import '../application/social_providers.dart';
import '../domain/friend_models.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              tabs: const [
                Tab(icon: Icon(Icons.people_rounded)),
                Tab(icon: Icon(Icons.mail_outline_rounded)),
                Tab(icon: Icon(Icons.send_rounded)),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FriendsTab(),
          _IncomingTab(),
          _OutgoingTab(),
        ],
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsStreamProvider);
    final userCache = ref.watch(userCacheProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return const AppEmptyView(
            title: 'Chưa có bạn bè',
            subtitle: 'Kết bạn để nhắn tin và chia sẻ công thức cùng nhau.',
          );
        }
        ref.read(userCacheProvider.notifier).preload(
              friends.map((f) => f.friendUid).toSet(),
            );

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: friends.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, endIndent: 12),
          itemBuilder: (context, index) {
            final friend = friends[index];
            final summary = userCache[friend.friendUid];
            return _FriendTile(
              friendUid: friend.friendUid,
              summary: summary,
              onMessage: () => _startDm(context, ref, friend.friendUid),
              onUnfriend: () => _unfriend(context, ref, friend.friendUid),
            );
          },
        );
      },
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonLoader(height: 80),
        ),
      ),
      error: (e, _) =>
          AppErrorView(message: 'Không tải được danh sách: $e', onRetry: () {
        ref.invalidate(friendsStreamProvider);
      }),
    );
  }

  Future<void> _startDm(
      BuildContext context, WidgetRef ref, String targetUid) async {
    try {
      final chatId =
          await ref.read(chatFunctionsRepositoryProvider).createDM(toUid: targetUid);
      if (context.mounted) {
        context.push('/chat/$chatId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tạo được chat: $e')),
        );
      }
    }
  }

  Future<void> _unfriend(
      BuildContext context, WidgetRef ref, String targetUid) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hủy kết bạn'),
            content: const Text('Bạn có chắc chắn muốn hủy kết bạn?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Đóng'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Hủy kết bạn'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(friendRepositoryProvider).removeFriend(targetUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy kết bạn')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không hủy được: $e')),
        );
      }
    }
  }
}

class _IncomingTab extends ConsumerWidget {
  const _IncomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(incomingFriendRequestsProvider);
    final userCache = ref.watch(userCacheProvider);

    return incomingAsync.when(
      data: (requests) {
        final pending = requests
            .where((r) => r.status == FriendRequestStatus.pending)
            .toList();
        if (pending.isEmpty) {
          return const AppEmptyView(
            title: 'Chưa có lời mời',
            subtitle: 'Bạn bè sẽ hiện ở đây khi có người muốn kết nối.',
          );
        }
        ref.read(userCacheProvider.notifier).preload(
              pending.map((r) => r.requesterId).toSet(),
            );

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: pending.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, endIndent: 12),
          itemBuilder: (context, index) {
            final request = pending[index];
            final requester = userCache[request.requesterId];
            return _RequestTile(
              summary: requester,
              fallbackUid: request.requesterId,
              subtitle: 'Muốn kết bạn',
              primary: () =>
                  _accept(context, ref, request.id, request.requesterId),
              secondary: () =>
                  _reject(context, ref, request.id, request.requesterId),
              primaryLabel: 'Chấp nhận',
              secondaryLabel: 'Từ chối',
            );
          },
        );
      },
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonLoader(height: 80),
        ),
      ),
      error: (e, _) => AppErrorView(
        message: 'Không tải được yêu cầu: $e',
        onRetry: () => ref.invalidate(incomingFriendRequestsProvider),
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    String requesterId,
  ) async {
    try {
      await ref.read(friendRepositoryProvider).acceptFriendRequest(requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã kết bạn với $requesterId')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không chấp nhận được: $e')),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    String requesterId,
  ) async {
    try {
      await ref.read(friendRepositoryProvider).rejectFriendRequest(requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã từ chối $requesterId')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không từ chối được: $e')),
        );
      }
    }
  }
}

class _OutgoingTab extends ConsumerWidget {
  const _OutgoingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outgoingAsync = ref.watch(outgoingFriendRequestsProvider);
    final userCache = ref.watch(userCacheProvider);

    return outgoingAsync.when(
      data: (requests) {
        final pending = requests
            .where((r) => r.status == FriendRequestStatus.pending)
            .toList();
        if (pending.isEmpty) {
          return const AppEmptyView(
            title: 'Chưa gửi lời mời nào',
            subtitle: 'Gửi lời mời kết bạn để trò chuyện.',
          );
        }
        ref.read(userCacheProvider.notifier).preload(
              pending.map((r) => r.targetId).toSet(),
            );
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: pending.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, endIndent: 12),
          itemBuilder: (context, index) {
            final request = pending[index];
            final target = userCache[request.targetId];
            return _RequestTile(
              summary: target,
              fallbackUid: request.targetId,
              subtitle: 'Đang chờ phê duyệt',
              primary: () =>
                  _cancel(context, ref, request.id, request.targetId),
              primaryLabel: 'Hủy lời mời',
              secondary: null,
            );
          },
        );
      },
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonLoader(height: 80),
        ),
      ),
      error: (e, _) => AppErrorView(
        message: 'Không tải được danh sách: $e',
        onRetry: () => ref.invalidate(outgoingFriendRequestsProvider),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    String targetId,
  ) async {
    try {
      await ref.read(friendRepositoryProvider).cancelFriendRequest(requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã hủy lời mời tới $targetId')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không hủy được: $e')),
        );
      }
    }
  }
}

class _FriendTile extends StatefulWidget {
  const _FriendTile({
    required this.friendUid,
    required this.summary,
    required this.onMessage,
    required this.onUnfriend,
  });

  final String friendUid;
  final UserSummary? summary;
  final VoidCallback onMessage;
  final VoidCallback onUnfriend;

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.summary?.displayName?.isNotEmpty == true 
        ? widget.summary!.displayName! 
        : widget.friendUid;
    final avatarUrl = widget.summary?.photoUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isHovered
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/profile/${widget.friendUid}'),
            onHover: (hover) => setState(() => _isHovered = hover),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  AppAvatar(
                    url: avatarUrl ?? '',
                    size: 56,
                    fallbackText: name.isNotEmpty ? name[0].toUpperCase() : '?',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Online',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ModernButton(
                    onPressed: widget.onMessage,
                    style: ModernButtonStyle.primary,
                    icon: Icons.chat_bubble_outline_rounded,
                    child: const Text('Nhắn tin'),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'unfriend') {
                        widget.onUnfriend();
                      }
                    },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'unfriend',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_remove_outlined,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hủy kết bạn',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'Tùy chọn',
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

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.summary,
    required this.fallbackUid,
    required this.subtitle,
    required this.primary,
    required this.primaryLabel,
    this.secondary,
    this.secondaryLabel,
  });

  final UserSummary? summary;
  final String fallbackUid;
  final String subtitle;
  final VoidCallback primary;
  final VoidCallback? secondary;
  final String primaryLabel;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final name =
        summary?.displayName?.isNotEmpty == true ? summary!.displayName! : fallbackUid;
    final avatarUrl = summary?.photoUrl;

    return ListTile(
      leading: AppAvatar(
        url: avatarUrl ?? '',
        size: 48,
        fallbackText: name.isNotEmpty ? name[0].toUpperCase() : '?',
      ),
      title: Text(name),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (secondary != null)
            IconButton(
              onPressed: secondary,
              icon: Icon(
                Icons.close_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: secondaryLabel ?? 'Bỏ qua',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              ),
            ),
          IconButton(
            onPressed: primary,
            icon: Icon(
              primaryLabel == 'Chấp nhận' 
                  ? Icons.check_rounded 
                  : Icons.close_rounded,
              color: primaryLabel == 'Chấp nhận'
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            tooltip: primaryLabel,
            style: IconButton.styleFrom(
              backgroundColor: primaryLabel == 'Chấp nhận'
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
      onTap: () => context.push('/profile/$fallbackUid'),
    );
  }
}
