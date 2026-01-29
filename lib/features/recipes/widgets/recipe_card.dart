import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../../../app/theme.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/application/user_cache_controller.dart';
import '../../profile/domain/user_summary.dart';
import '../../social/widgets/friend_action_button.dart';
import '../../../shared/widgets/avatar_with_follow_badge.dart';
import '../../../core/utils/time_utils.dart';

class RecipeCard extends ConsumerStatefulWidget {
  const RecipeCard({
    super.key,
    this.heroTag,
    required this.title,
    required this.imageUrl,
    required this.authorName,
    this.authorId,
    this.authorAvatarUrl,
    this.rating,
    this.difficulty,
    this.cookMinutes,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.tags = const [],
    this.createdAt,
    this.onTap,
    this.onAvatarTap,
    this.avatarHeroTag,
    this.onEdit,
    this.onDelete,
    this.showDifficulty = true,
    this.showCookTime = true,
  });

  final String? heroTag;
  final String? avatarHeroTag;
  final String title;
  final String imageUrl;
  final String authorName;
  final String? authorId;
  final String? authorAvatarUrl;
  final double? rating;
  final String? difficulty;
  final int? cookMinutes;
  final int likesCount;
  final int commentsCount;
  final List<String> tags;
  final DateTime? createdAt;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showDifficulty;
  final bool showCookTime;

  @override
  ConsumerState<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends ConsumerState<RecipeCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userCache = ref.watch(userCacheProvider);
    final authorId = widget.authorId ?? '';
    final author = authorId.isNotEmpty ? userCache[authorId] : null;
    if (author == null && authorId.isNotEmpty) {
      ref.read(userCacheProvider.notifier).preload({authorId});
    }
    final authorName = _displayName(author, authorId, widget.authorName);
    final avatarUrl = author?.photoUrl ?? widget.authorAvatarUrl;
    final currentUid = ref.watch(currentUserIdProvider);
    final showFriendAction = authorId.isNotEmpty && currentUid != authorId;

    final tagChips = widget.tags.take(3).toList();
    final avatarHero = widget.avatarHeroTag ??
        ((widget.authorId != null && widget.authorId!.isNotEmpty)
            ? 'user_avatar_${widget.authorId}'
            : null);

    final s = S(ref.watch(localeProvider));
    final localizedDifficulty = s.translateDifficulty(widget.difficulty);

    Widget cover = _RecipeImage(
      title: widget.title,
      imageUrl: widget.imageUrl,
      rating: widget.rating,
      difficulty: widget.difficulty != null ? localizedDifficulty : null,
      cookMinutes: widget.cookMinutes,
      showDifficulty: widget.showDifficulty,
      showCookTime: widget.showCookTime,
    );
    if (widget.heroTag != null) {
      cover = Hero(tag: widget.heroTag!, child: cover);
    }

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.large),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.large),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _setPressed(true),
              onTapCancel: () => _setPressed(false),
              onTapUp: (_) => _setPressed(false),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8,
                      ),
                      child: Row(
                        children: [
                          AvatarWithFollowBadge(
                            url: avatarUrl,
                            heroTag: avatarHero,
                            onTap: widget.onAvatarTap,
                            displayName: authorName,
                            targetUid: authorId,
                            size: 34,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (widget.createdAt != null)
                                  Text(
                                    TimeUtils.formatTimeAgo(widget.createdAt, context),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.onEdit != null || widget.onDelete != null) ...[
                            const SizedBox(width: AppSpacing.s8),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      child: cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Stat(
                                icon: Icons.favorite_rounded,
                                label: widget.likesCount.toString(),
                                isLiked: true,
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              _Stat(
                                icon: Icons.chat_bubble_rounded,
                                label: widget.commentsCount.toString(),
                              ),
                              const Spacer(),
                              if (widget.rating != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.rating!.toStringAsFixed(1),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: theme.brightness == Brightness.dark
                                              ? Colors.amber.shade300
                                              : Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (tagChips.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.s12),
                            Wrap(
                              spacing: AppSpacing.s6,
                              runSpacing: AppSpacing.s6,
                              children: tagChips
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.colorScheme.secondary
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.brightness == Brightness.dark
                                              ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
                                              : theme.colorScheme.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
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

class _RecipeImage extends StatelessWidget {
  const _RecipeImage({
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.difficulty,
    required this.cookMinutes,
    this.showDifficulty = true,
    this.showCookTime = true,
  });

  final String title;
  final String imageUrl;
  final double? rating;
  final String? difficulty;
  final int? cookMinutes;
  final bool showDifficulty;
  final bool showCookTime;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade200),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 32),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined, size: 32),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.s12,
            left: AppSpacing.s12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCookTime && cookMinutes != null)
                  _Badge(
                    icon: Icons.schedule,
                    label: TimeUtils.formatDuration(cookMinutes, context),
                  ),
                if (showDifficulty && difficulty != null) ...[
                  const SizedBox(width: AppSpacing.s4),
                  _Badge(
                    icon: Icons.local_fire_department_outlined,
                    label: difficulty!,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.s12,
            right: AppSpacing.s12,
            bottom: AppSpacing.s12,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.icon,
    this.background,
    this.iconColor,
    this.textColor,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = background ?? (isDark 
        ? scheme.surface.withValues(alpha: 0.7)
        : scheme.surface.withValues(alpha: 0.9));
    final iconClr = iconColor ?? (isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : scheme.onSurface);
    final textClr = textColor ?? (isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : scheme.onSurface);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconClr),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textClr,
                ),
          ),
        ],
      ),
    );
  }
}


String _displayName(UserSummary? user, String authorId, String fallback) {
  if (user != null) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
  }
  if (fallback.isNotEmpty) return fallback;
  if (authorId.isNotEmpty) {
    final short = authorId.length > 6 ? authorId.substring(0, 6) : authorId;
    return 'User $short';
  }
  return 'Nguoi dung';
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    this.isLiked = false,
  });

  final IconData icon;
  final String label;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isLiked ? Colors.red.shade400 : scheme.onSurfaceVariant.withValues(alpha: 0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
