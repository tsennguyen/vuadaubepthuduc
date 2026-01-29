import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../../../app/widgets/app_top_bar.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../recipes/widgets/recipe_card.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/application/user_cache_controller.dart';
import '../../social/application/social_providers.dart';
import '../application/feed_controller.dart';
import '../data/feed_repository.dart';
import '../widgets/post_card.dart';

enum FeedFilter { latest, hot, following }

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  late final ScrollController _scrollController;
  FeedFilter _filter = FeedFilter.latest;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    Future.microtask(
      () => ref.read(homeFeedControllerProvider.notifier).loadInitial(),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 240) {
      final controller = ref.read(homeFeedControllerProvider.notifier);
      
      if (_filter == FeedFilter.following) {
        // Load more following feed
        final friendRepo = ref.read(friendRepositoryProvider);
        final friendIds = await friendRepo.getFriendIds();
        await controller.loadMoreFollowingFeed(friendIds: friendIds);
      } else {
        // Load more regular feed
        await controller.loadMore();
      }
    }
  }

  void _changeFilter(FeedFilter filter) async {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    
    final controller = ref.read(homeFeedControllerProvider.notifier);
    
    if (filter == FeedFilter.following) {
      // Load following feed
      final friendRepo = ref.read(friendRepositoryProvider);
      final friendIds = await friendRepo.getFriendIds();
      await controller.refreshFollowingFeed(friendIds: friendIds);
    } else {
      // Load regular feed (latest/hot will be sorted in UI)
      await controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(homeFeedControllerProvider);
    final locale = ref.watch(localeProvider);
    final s = S(locale);
    
    var items = _sortItems(state.items);
    final authorIds =
        items.map((e) => e.authorId).where((id) => id.isNotEmpty).toSet();
    ref.read(userCacheProvider.notifier).preload(authorIds);

    Widget content;
    if (state.isLoading && items.isEmpty) {
      content = AppLoadingIndicator(message: s.loadingFeed);
    } else if (state.error != null && items.isEmpty) {
      content = AppErrorView(
        message: state.error.toString(),
        onRetry: () => ref.read(homeFeedControllerProvider.notifier).refresh(),
      );
    } else if (items.isEmpty) {
      content = AppEmptyView(
        title: s.emptyFeedTitle,
        subtitle: s.emptyFeedSubtitle,
      );
    } else {
      content = RefreshIndicator(
        onRefresh: () =>
            ref.read(homeFeedControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: _CreatePostBar(s: s),
            ),
            SliverToBoxAdapter(
              child: _ReelsShortcutBar(s: s),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s8,
                  AppSpacing.s16,
                  AppSpacing.s12,
                ),
                child: _FilterChips(
                  filter: _filter,
                  onChanged: _changeFilter,
                  s: s,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                    child: _buildCard(context, items[index], index),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
            if (state.isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                  child: AppLoadingIndicator(message: s.loadingMore),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppTopBar(
        title: s.feed,
        onSearchTap: () {
          const currentKeyword = '';
          context.push('/search?q=${Uri.encodeComponent(currentKeyword)}');
        },
        onNotificationsTap: () => context.push('/notifications'),
        actions: [
          IconButton.filledTonal(
            tooltip: s.shopTitle,
            onPressed: () => context.push('/shopping'),
            icon: const Icon(Icons.shopping_cart_outlined, size: 26),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: theme.brightness == Brightness.dark ? 0.25 : 0.8),
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }

  Widget _buildCard(BuildContext context, FeedItem item, int index) {
    if (item.type == FeedItemType.recipe) {
      return RecipeCard(
        heroTag: 'feed_recipe_${item.id}_$index',
        title: item.title,
        imageUrl: item.imageUrl ?? '',
        authorName: item.authorId.isNotEmpty ? item.authorId : 'Chef',
        authorId: item.authorId,
        onAvatarTap: item.authorId.isNotEmpty
            ? () => context.push('/profile/${item.authorId}')
            : null,
        rating: item.avgRating,
        difficulty: null,
        cookMinutes: null,
        showDifficulty: false,
        likesCount: item.likesCount,
        commentsCount: item.commentsCount,
        tags: const [],
        createdAt: item.createdAt,
        onTap: () => context.push('/recipe/${item.id}'),
      );
    }

    return PostCard(
      id: item.id,
      authorId: item.authorId,
      authorName: item.authorId.isNotEmpty ? item.authorId : 'Nguoi dung',
      caption: item.title,
      imageUrl: item.imageUrl,
      tags: const [],
      likesCount: item.likesCount,
      commentsCount: item.commentsCount,
      createdAt: item.createdAt,
      onTap: () => context.push('/post/${item.id}'),
      onAvatarTap: item.authorId.isNotEmpty
          ? () => context.push('/profile/${item.authorId}')
          : null,
      heroTag: 'feed_post_${item.id}_$index',
    );
  }

  List<FeedItem> _sortItems(List<FeedItem> items) {
    if (_filter == FeedFilter.latest) {
      // Mới nhất
      return items.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_filter == FeedFilter.hot) {
      // Hot/Popular: sort theo engagement
      // Ưu tiên: Popular → Recent → Others
      final sorted = items.toList();
      sorted.sort((a, b) {
        final aScore = a.likesCount + a.commentsCount;
        final bScore = b.likesCount + b.commentsCount;
        
        // Xác định popular (>= 10 engagement)
        final aPopular = aScore >= 10;
        final bPopular = bScore >= 10;
        
        if (aPopular && !bPopular) return -1;
        if (!aPopular && bPopular) return 1;
        
        // Cùng category: sort by score, then date
        if (aScore != bScore) return bScore.compareTo(aScore);
        return b.createdAt.compareTo(a.createdAt);
      });
      return sorted;
    }
    // Following: giữ nguyên
    return items;
  }
}

class _ReelsShortcutBar extends StatelessWidget {
  const _ReelsShortcutBar({required this.s});
  final S s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: _ReelsButton(
        icon: Icons.video_call_rounded,
        label: s.isVi ? 'Tạo thước phim' : 'Create Reel',
        onTap: () => context.push('/create-reel'),
        color: Colors.purpleAccent,
      ),
    );
  }
}

class _ReelsButton extends StatelessWidget {
  const _ReelsButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}

class _CreatePostBar extends ConsumerWidget {
  const _CreatePostBar({required this.s});
  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider(null));
    final avatarUrl = profileState.profile?.photoUrl;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          AppAvatar(
            url: avatarUrl ?? '',
            size: 48,
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/create-post'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s20, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.04),
                  ),
                ),
                child: Text(
                  s.whatsOnYourMind,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          IconButton.filledTonal(
            onPressed: () => context.push('/create-post'),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(
              Icons.camera_alt_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.onChanged,
    required this.s,
  });

  final FeedFilter filter;
  final ValueChanged<FeedFilter> onChanged;
  final S s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: FeedFilter.values.map((f) {
          final selected = f == filter;
          final (label, icon) = switch (f) {
            FeedFilter.latest => (s.filterLatest, Icons.access_time_rounded),
            FeedFilter.hot => (s.filterHot, Icons.local_fire_department_rounded),
            FeedFilter.following => (s.filterFollowing, Icons.people_alt_rounded),
          };

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                color: selected
                    ? (theme.brightness == Brightness.dark
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.primary)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: theme.brightness == Brightness.dark ? 0.1 : 0.2,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : theme.colorScheme.outline.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  onTap: () => onChanged(f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: selected
                              ? (theme.brightness == Brightness.dark
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                                  : Colors.white)
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected
                                ? (theme.brightness == Brightness.dark
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                                    : Colors.white)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

