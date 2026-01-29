import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/application/user_cache_controller.dart';
import '../../profile/domain/user_summary.dart';
import '../../social/widgets/friend_action_button.dart';
import '../application/interaction_providers.dart';
import '../../../shared/widgets/avatar_with_follow_badge.dart';
import '../../../core/utils/time_utils.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({
    super.key,
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.tags,
    this.authorAvatarUrl,
    this.imageUrl,
    this.avatarHeroTag,
    this.heroTag,
    this.createdAt,
    this.onTap,
    this.onAvatarTap,
    this.onEdit,
    this.onDelete,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String? imageUrl;
  final String? avatarHeroTag;
  final String? heroTag;
  final DateTime? createdAt;
  final String caption;
  final List<String> tags;
  final int likesCount;
  final int commentsCount;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _pressed = false;
  int? _optimisticLikeCount;
  bool? _optimisticIsLiked;
  bool _isToggling = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  Future<void> _toggleLike() async {
    // Prevent multiple simultaneous toggles
    if (_isToggling) return;
    
    // Get current state before optimistic update
    final likeStatusAsync = ref.read(postLikeStatusProvider(widget.id));
    final currentIsLiked = likeStatusAsync.value ?? false;
    
    // Get current count from stream (real-time) or optimistic state
    final likesCountAsync = ref.read(postLikesCountProvider(widget.id));
    final streamCount = likesCountAsync.value ?? widget.likesCount;
    final currentCount = _optimisticLikeCount ?? streamCount;
    
    // Optimistic update
    setState(() {
      _isToggling = true;
      _optimisticIsLiked = !currentIsLiked;
      _optimisticLikeCount = currentIsLiked ? currentCount - 1 : currentCount + 1;
    });

    try {
      final repo = ref.read(interactionRepositoryProvider);
      await repo.togglePostLike(widget.id);
      
      // Keep optimistic state - it will be overridden when stream updates
      // Don't clear immediately to prevent flickering
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _optimisticLikeCount = currentCount;
          _optimisticIsLiked = currentIsLiked;
          _isToggling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể like: $e')),
        );
      }
    }
  }

  Future<void> _sharePost(BuildContext context) async {
    try {
      final postUrl = 'https://vuadaubepthucduc.com/post/${widget.id}';
      final shareText = '${widget.caption}\n\nXem chi tiết tại: $postUrl';

      await Share.share(
        shareText,
        subject: 'Chia sẻ bài viết từ Vua Đầu Bếp Thủ Đức',
      );

      final repo = ref.read(interactionRepositoryProvider);
      await repo.sharePost(widget.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chia sẻ: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userCache = ref.watch(userCacheProvider);
    final currentUid = ref.watch(currentUserIdProvider);
    final author = userCache[widget.authorId];
    if (author == null && widget.authorId.isNotEmpty) {
      ref.read(userCacheProvider.notifier).preload({widget.authorId});
    }
    final authorName = _displayName(author, widget.authorId, widget.authorName);
    final avatarUrl = author?.photoUrl ?? widget.authorAvatarUrl;

    // Watch like status and count from Firestore
    final likeStatusAsync = ref.watch(postLikeStatusProvider(widget.id));
    final streamIsLiked = likeStatusAsync.value ?? false;
    
    final likesCountAsync = ref.watch(postLikesCountProvider(widget.id));
    final streamLikesCount = likesCountAsync.value ?? widget.likesCount;
    
    // Clear optimistic state if both stream values have caught up
    if (_optimisticIsLiked != null && 
        _optimisticLikeCount != null &&
        _optimisticIsLiked == streamIsLiked && 
        _optimisticLikeCount == streamLikesCount &&
        !_isToggling) {
      // Stream has updated to match our optimistic state, safe to clear
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _optimisticIsLiked = null;
            _optimisticLikeCount = null;
          });
        }
      });
    }
    
    // Use optimistic state if available, otherwise use stream state
    final isLiked = _optimisticIsLiked ?? streamIsLiked;
    final likeCount = _optimisticLikeCount ?? streamLikesCount;

    final image = widget.imageUrl;
    final hasImage = image != null && image.isNotEmpty;
    final tagChips = widget.tags.take(3).toList();
    final avatarHeroTag = null; // Disabled Hero to prevent duplicate tags
    final showFriendAction =
        widget.authorId.isNotEmpty && currentUid != widget.authorId;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8), // Better separation
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.large),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Avatar + Name + Menu
                    Row(
                      children: [
                        AvatarWithFollowBadge(
                          url: avatarUrl,
                          heroTag: avatarHeroTag,
                          onTap: widget.onAvatarTap,
                          displayName: authorName,
                          targetUid: widget.authorId,
                          size: 42,
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (showFriendAction) 
                                Text(
                                  'Gợi ý cho bạn',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else if (widget.createdAt != null)
                                Text(
                                  TimeUtils.formatTimeAgo(widget.createdAt, context),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.onEdit != null || widget.onDelete != null)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit' && widget.onEdit != null) {
                                widget.onEdit!();
                              } else if (value == 'delete' && widget.onDelete != null) {
                                widget.onDelete!();
                              }
                            },
                            itemBuilder: (context) => [
                              if (widget.onEdit != null)
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 20),
                                      SizedBox(width: 8),
                                      Text('Chỉnh sửa'),
                                    ],
                                  ),
                                ),
                              if (widget.onDelete != null)
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Xóa', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    
                    // Caption
                    Text(
                      widget.caption,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                      ),
                    ),
                    
                    // Tags
                    if (tagChips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Wrap(
                        spacing: AppSpacing.s6,
                        runSpacing: AppSpacing.s6,
                        children: tagChips
                            .map(
                              (t) => Text(
                                '#$t',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    
                    // Image
                    if (hasImage) ...[
                      const SizedBox(height: AppSpacing.s12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              height: 200,
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: AppSpacing.s16),
                    
                    // Footer: Interactions
                    Row(
                      children: [
                        _LikeButton(
                          liked: isLiked,
                          count: likeCount,
                          onToggle: _toggleLike,
                          postId: widget.id,
                        ),
                        const SizedBox(width: AppSpacing.s24),
                        _Stat(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: widget.commentsCount.toString(),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _sharePost(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.share_outlined,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


String _displayName(UserSummary? user, String authorId, String fallbackName) {
  if (user != null) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
  }
  if (fallbackName.isNotEmpty) return fallbackName;
  if (authorId.isNotEmpty) {
    final short = authorId.length > 6 ? authorId.substring(0, 6) : authorId;
    return 'User $short';
  }
  return 'Người dùng';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurfaceVariant.withValues(alpha: 0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onToggle,
    required this.postId,
  });

  final bool liked;
  final int count;
  final VoidCallback onToggle;
  final String postId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = liked ? Colors.red : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: liked ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Text(
              '$count',
              key: ValueKey<String>('${postId}_$count'), // Unique key per post
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
