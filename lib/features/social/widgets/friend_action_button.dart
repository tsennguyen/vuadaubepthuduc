import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_controller.dart';
import '../application/social_providers.dart';
import '../../profile/domain/user_ban_guard.dart';

class FriendActionButton extends ConsumerWidget {
  const FriendActionButton({
    super.key,
    required this.targetUid,
    required this.targetName,
    this.dense = false,
  });

  final String targetUid;
  final String targetName;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relation = ref.watch(relationshipProvider(targetUid));

    return relation.when(
      data: (state) => _buildButton(context, ref, state),
      loading: () => SizedBox(
        height: dense ? 34 : 38,
        width: 94,
        child: const Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
        ),
      ),
      error: (e, _) => const OutlinedButton(
        onPressed: null,
        child: Text('Follow'),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    WidgetRef ref,
    RelationshipState state,
  ) {
    final label = _label(state.status);
    final tooltip = _statusTooltip(state);

    final ButtonStyle style;
    final isFilled = state.status == RelationshipStatus.none ||
        state.status == RelationshipStatus.pendingReceived ||
        state.status == RelationshipStatus.friends;

    if (isFilled && state.status == RelationshipStatus.friends) {
      style = FilledButton.styleFrom(
        minimumSize: Size(0, dense ? 34 : 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      );
    } else if (isFilled) {
      style = FilledButton.styleFrom(
        minimumSize: Size(0, dense ? 34 : 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );
    } else {
      style = OutlinedButton.styleFrom(
        minimumSize: Size(0, dense ? 34 : 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );
    }

    final child = Text(label);
    final button = isFilled
        ? FilledButton(
            style: style,
            onPressed: () => _showActions(context, ref, state),
            child: child,
          )
        : OutlinedButton(
            style: style,
            onPressed: () => _showActions(context, ref, state),
            child: child,
          );

    return Tooltip(
      message: tooltip,
      child: button,
    );
  }

  String _label(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.none:
        return 'Follow';
      case RelationshipStatus.following:
        return dense ? 'Theo dõi' : 'Đang theo dõi';
      case RelationshipStatus.pendingSent:
        return dense ? 'Gửi' : 'Đã gửi';
      case RelationshipStatus.pendingReceived:
        return dense ? 'Chấp nhận' : 'Chấp nhận';
      case RelationshipStatus.friends:
        return 'Bạn bè';
    }
  }

  String _statusTooltip(RelationshipState state) {
    switch (state.status) {
      case RelationshipStatus.none:
        return 'Theo dõi hoặc gửi lời mời kết bạn';
      case RelationshipStatus.following:
        return 'Đang theo dõi';
      case RelationshipStatus.pendingSent:
        return 'Đã gửi lời mời kết bạn';
      case RelationshipStatus.pendingReceived:
        return 'Người dùng này muốn kết bạn với bạn';
      case RelationshipStatus.friends:
        return 'Bạn bè · Đang theo dõi';
    }
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    RelationshipState state,
  ) async {
    final currentUid = ref.read(currentUserIdProvider);
    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hay dang nhap de tuong tac')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    targetName.isNotEmpty ? targetName : 'Nguoi dung',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                ..._buildActions(ctx, ref, state),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Đóng'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    RelationshipState state,
  ) {
    switch (state.status) {
      case RelationshipStatus.none:
        return [
          ListTile(
            leading: const Icon(Icons.person_add_alt_1),
            title: const Text('Theo dõi'),
            onTap: () => _handleFollow(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('Gửi lời mời kết bạn'),
            onTap: () => _handleSendRequest(context, ref),
          ),
        ];
      case RelationshipStatus.following:
        return [
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('Gửi lời mời kết bạn'),
            onTap: () => _handleSendRequest(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Bỏ theo dõi'),
            onTap: () => _handleUnfollow(context, ref),
          ),
        ];
      case RelationshipStatus.pendingSent:
        return [
          ListTile(
            leading: const Icon(Icons.cancel_schedule_send_outlined),
            title: const Text('Hủy lời mời'),
            onTap: () => _handleCancelRequest(context, ref, state),
          ),
        ];
      case RelationshipStatus.pendingReceived:
        return [
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Chấp nhận kết bạn'),
            onTap: () => _handleAccept(context, ref, state),
          ),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('Từ chối'),
            onTap: () => _handleReject(context, ref, state),
          ),
        ];
      case RelationshipStatus.friends:
        return [
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Bỏ bạn bè'),
            onTap: () => _handleUnfriend(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Bỏ theo dõi'),
            onTap: () => _handleUnfollow(context, ref),
          ),
        ];
    }
  }

  Future<void> _handleFollow(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    final repo = ref.read(friendRepositoryProvider);
    try {
      await repo.followUser(targetUid);
      messenger.showSnackBar(SnackBar(content: Text('Đang theo dõi $targetName')));
    } catch (e) {
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Không thể theo dõi: $e')));
    }
  }

  Future<void> _handleUnfollow(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    final repo = ref.read(friendRepositoryProvider);
    try {
      await repo.unfollowUser(targetUid);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã bỏ theo dõi $targetName')),
      );
    } catch (e) {
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Không thể bỏ theo dõi: $e')));
    }
  }

  Future<void> _handleSendRequest(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    final repo = ref.read(friendRepositoryProvider);
    try {
      await repo.sendFriendRequest(targetUid);
      messenger.showSnackBar(
        const SnackBar(content: Text('Da gui loi moi ket ban')),
      );
    } catch (e) {
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Không thể gửi lời mời: $e')));
    }
  }

  Future<void> _handleCancelRequest(
    BuildContext context,
    WidgetRef ref,
    RelationshipState state,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    final repo = ref.read(friendRepositoryProvider);
    final reqId = state.pendingRequest?.id;
    if (reqId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không tìm thấy yêu cầu để hủy')),
      );
      return;
    }
    try {
      await repo.cancelFriendRequest(reqId);
      messenger.showSnackBar(const SnackBar(content: Text('Đã hủy lời mời')));
    } catch (e) {
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Không thể hủy: $e')));
    }
  }

  Future<void> _handleAccept(
    BuildContext context,
    WidgetRef ref,
    RelationshipState state,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    final repo = ref.read(friendRepositoryProvider);
    final reqId = state.pendingRequest?.id;
    if (reqId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không tìm thấy lời mời')),
      );  
      return;
    }
    try {
      await repo.acceptFriendRequest(reqId);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã kết bạn với $targetName')),
      );
    } catch (e) {
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Không thể chấp nhận: $e')));
    }
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    RelationshipState state,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    final repo = ref.read(friendRepositoryProvider);
    final reqId = state.pendingRequest?.id;
    if (reqId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không tìm thấy lời mời')),
      );
      return;
    }
    try {
      await repo.rejectFriendRequest(reqId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã từ chối lời mời')),
      );
    } catch (e) {
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Không thể từ chối: $e')));
    }
  }

  Future<void> _handleUnfriend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    final repo = ref.read(friendRepositoryProvider);
    try {
      await repo.removeFriend(targetUid);
      messenger.showSnackBar(const SnackBar(content: Text('Đã bỏ bạn bè')));
    } catch (e) {
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Không thể bỏ bạn bè: $e')));
    }
  }
}
