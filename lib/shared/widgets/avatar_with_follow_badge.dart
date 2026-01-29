import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../features/profile/application/profile_controller.dart';
import '../../features/social/application/social_providers.dart';
import '../../features/social/widgets/friend_action_button.dart';

/// Avatar với dấu cộng/tích nhỏ giống Threads phía dưới góc phải
class AvatarWithFollowBadge extends ConsumerWidget {
  const AvatarWithFollowBadge({
    super.key,
    this.url,
    this.heroTag,
    this.onTap,
    required this.displayName,
    required this.targetUid,
    this.size = 42,
  });

  final String? url;
  final String? heroTag;
  final VoidCallback? onTap;
  final String displayName;
  final String targetUid;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUid = ref.watch(currentUserIdProvider);
    final showBadge = targetUid.isNotEmpty && currentUid != targetUid;

    final hasImage = url != null && url!.isNotEmpty;
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1) : '';

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5), // Premium thin white ring
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => _buildFallback(theme, initial, size),
              )
            : _buildFallback(theme, initial, size),
      ),
    );

    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }

    if (!showBadge) {
      // No badge - just wrap with gesture if needed
      if (onTap != null) {
        avatar = GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: avatar,
        );
      }
      return avatar;
    }

    // With badge - handle taps separately for avatar and badge
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Avatar with tap (if provided)
          // Use deferToChild so taps on badge won't trigger this
          if (onTap != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.deferToChild,
                child: avatar,
              ),
            )
          else
            Positioned.fill(child: avatar),
          
          // Badge overlay - has its own tap handler in _FollowBadge
          Positioned(
            right: 0,
            bottom: 0,
            child: _FollowBadge(targetUid: targetUid),
          ),
        ],
      ),
    );
  }
}

/// Badge nhỏ hiển thị dấu + hoặc ✓ tùy theo trạng thái follow
class _FollowBadge extends ConsumerWidget {
  const _FollowBadge({required this.targetUid});

  final String targetUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final relation = ref.watch(relationshipProvider(targetUid));

    return relation.when(
      data: (state) {
        final isFollowingOrFriend = state.isFollowing || state.isFriend;
        
        // Hide badge if already connected (no tick icon as per user request)
        if (isFollowingOrFriend || state.status == RelationshipStatus.pendingSent) {
          return const SizedBox.shrink();
        }

        final icon = Icons.add;
        final bgColor = theme.colorScheme.primary;
        final iconColor = theme.colorScheme.onPrimary;

        return GestureDetector(
          onTap: () => _handleTap(context, ref, state),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(
                color: theme.colorScheme.surface,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 13,
              color: iconColor,
            ),
          ),
        );
      },
      loading: () => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
        ),
        child: const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    RelationshipState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(friendRepositoryProvider);

    // Nếu chưa theo dõi -> Hiển thị menu chọn
    if (state.status == RelationshipStatus.none) {
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('Theo dõi'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await repo.followUser(targetUid);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đang theo dõi')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Gửi lời mời kết bạn'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await repo.sendFriendRequest(targetUid);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã gửi lời mời kết bạn')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Đóng'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        },
      );
    } else if (state.status == RelationshipStatus.following) {
      // Đang theo dõi -> Hiển thị menu với tùy chọn gửi kết bạn hoặc bỏ theo dõi
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Gửi lời mời kết bạn'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await repo.sendFriendRequest(targetUid);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã gửi lời mời kết bạn')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Bỏ theo dõi'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await repo.unfollowUser(targetUid);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã bỏ theo dõi')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Đóng'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        },
      );
    } else if (state.status == RelationshipStatus.friends) {
      // Đã là bạn bè -> Hiển thị menu bỏ theo dõi hoặc bỏ bạn
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: const Text('Bỏ bạn bè'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await repo.removeFriend(targetUid);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã bỏ bạn bè')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Bỏ theo dõi'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await repo.unfollowUser(targetUid);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã bỏ theo dõi')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Đóng'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        },
      );
    } else if (state.status == RelationshipStatus.pendingSent) {
      // Đã gửi lời mời kết bạn -> Cho phép hủy
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.hourglass_empty),
                  title: const Text('Đã gửi lời mời kết bạn'),
                  enabled: false,
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.orange),
                  title: const Text('Hủy lời mời'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final requestId = state.pendingRequest?.id;
                    if (requestId != null) {
                      try {
                        await repo.cancelFriendRequest(requestId);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Đã hủy lời mời kết bạn')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Đóng'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        },
      );
    } else if (state.status == RelationshipStatus.pendingReceived) {
      // Nhận được lời mời kết bạn -> Cho phép chấp nhận hoặc từ chối
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.blue),
                  title: const Text('Lời mời kết bạn'),
                  enabled: false,
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Chấp nhận'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final requestId = state.pendingRequest?.id;
                    if (requestId != null) {
                      try {
                        await repo.acceptFriendRequest(requestId);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Đã chấp nhận kết bạn')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.red),
                  title: const Text('Từ chối'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final requestId = state.pendingRequest?.id;
                    if (requestId != null) {
                      try {
                        await repo.rejectFriendRequest(requestId);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Đã từ chối lời mời')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }
}

Widget _buildFallback(ThemeData theme, String initial, double size) {
  return Container(
    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
    child: Center(
      child: initial.isNotEmpty
          ? Text(
              initial.toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38,
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.6,
              color: theme.colorScheme.primary,
            ),
    ),
  );
}
