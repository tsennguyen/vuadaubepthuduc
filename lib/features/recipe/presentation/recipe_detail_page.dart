import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../../../app/theme.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/modern_loading.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../shared/widgets/modern_dialog.dart';
import '../../../shared/widgets/modern_ui_components.dart';
import '../../feed/application/interaction_providers.dart';
import '../../feed/data/recipe_model.dart';
import '../../planner/presentation/add_to_plan_sheet.dart';
import '../../profile/application/user_cache_controller.dart';
import '../../profile/domain/user_summary.dart';
import '../../report/presentation/report_dialog.dart';
import '../../shopping/application/shopping_from_recipe_service.dart';
import '../../shopping/data/shopping_list_repository.dart';
import '../../recipe/data/recipe_repository.dart';
import '../../social/application/social_providers.dart';
import '../application/recipe_detail_controller.dart';
import '../application/recipe_social_controller.dart';
import '../../ai/application/chef_ai_controller.dart';
import '../../../app/l10n.dart';
import '../../../core/utils/time_utils.dart';
import 'dart:convert';
import 'widgets/flippable_dish_card.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  final Set<int> _checkedIngredients = <int>{};
  bool _hasLoggedView = false;
  bool _showContent = false;
  bool _isDishFlipped = false;
  late final ShoppingFromRecipeService _shoppingService;

  @override
  void initState() {
    super.initState();
    _shoppingService = ShoppingFromRecipeService(
      shoppingRepo: FirestoreShoppingListRepository(),
      recipeRepo: RecipeRepositoryImpl(),
    );
  }

  void _logViewOnce() {
    if (_hasLoggedView) return;
    _hasLoggedView = true;
    Future.microtask(() => analytics.logViewRecipe(widget.recipeId));
  }

  void _markContentVisible() {
    if (_showContent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showContent = true);
    });
  }

  void _requireLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng đăng nhập để thực hiện thao tác này.')),
    );
    context.go('/signin');
  }

  Future<void> _openReport(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _requireLogin(context);
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => ReportDialog(
        targetType: 'recipe',
        targetId: widget.recipeId,
      ),
    );
  }

  Future<void> _addIngredientsToShopping(BuildContext context, List<String> ingredients) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _requireLogin(context);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernDialog(
        title: 'Thêm vào Shopping List',
        icon: Icons.add_shopping_cart_rounded,
        content: Text(
          'Bạn có muốn thêm ${ingredients.length} nguyên liệu vào danh sách mua sắm?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ModernButton(
            onPressed: () => Navigator.pop(context, true),
            style: ModernButtonStyle.primary,
            child: const Text('Thêm ngay'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    try {
      await _shoppingService
          .addRecipeIngredientsToShoppingList(widget.recipeId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã thêm nguyên liệu vào shopping list'),
          action: SnackBarAction(
            label: 'Xem list',
            onPressed: () => router.go('/shopping'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể thêm: $e')),
      );
    }
  }

  Future<void> _openAddToPlan(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _requireLogin(context);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddToPlanSheet(recipeId: widget.recipeId),
    );

    if (!mounted) return;
    if (added == true) {
      analytics.logAddToPlan(widget.recipeId);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã thêm vào kế hoạch'),
          action: SnackBarAction(
            label: 'Xem kế hoạch',
            onPressed: () => router.go('/planner'),
          ),
        ),
      );
    }
  }

  Future<void> _shareRecipe(Recipe recipe) async {
    try {
      final recipeUrl = 'https://vuadaubepthucduc.com/recipe/${recipe.id}';
      final shareText = 'Khám phá công thức "${recipe.title}" trên Vua Đầu Bếp Thủ Đức!\n\nXem chi tiết tại: $recipeUrl';

      await Share.share(
        shareText,
        subject: 'Chia sẻ công thức nấu ăn',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chia sẻ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRecipe = ref.watch(recipeDetailProvider(widget.recipeId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: asyncRecipe.when(
        loading: () => const _RecipeDetailSkeleton(),
        error: (e, _) => _RecipeError(
          message: e.toString(),
          onRetry: () => ref.refresh(recipeDetailProvider(widget.recipeId)),
        ),
        data: (recipe) {
          _logViewOnce();
          _markContentVisible();
          ref.read(userCacheProvider.notifier).preload({recipe.authorId});
          final author = ref.watch(userCacheProvider)[recipe.authorId];
          final authorName =
              _displayName(author, recipe.authorId, 'Chef ẩn danh');
          final avatarUrl = author?.photoUrl ?? '';

          final userId = FirebaseAuth.instance.currentUser?.uid;
          final socialState =
              ref.watch(recipeSocialControllerProvider(recipe.id));
          final socialCtrl =
              ref.read(recipeSocialControllerProvider(recipe.id).notifier);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _RecipeHeroAppBar(
                    recipe: recipe,
                    heroTag: 'recipe_image_${recipe.id}',
                    onShare: () => _shareRecipe(recipe),
                    onReport: () => _openReport(context),
                    authorName: authorName,
                    authorAvatar: avatarUrl,
                    isFlipped: _isDishFlipped,
                    onFlip: (flipped) => setState(() => _isDishFlipped = flipped),
                  ),
                  SliverToBoxAdapter(
                    child: AnimatedOpacity(
                      opacity: _showContent ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                        child: _RecipeBody(
                          recipe: recipe,
                          socialState: socialState,
                          onRate: userId == null
                              ? null
                              : (stars) async {
                                  await socialCtrl.rate(stars);
                                  ref.invalidate(
                                      recipeDetailProvider(recipe.id));
                                },
                          checked: _checkedIngredients,
                          onToggleIngredient: (index) => setState(() {
                            if (_checkedIngredients.contains(index)) {
                              _checkedIngredients.remove(index);
                            } else {
                              _checkedIngredients.add(index);
                            }
                          }),
                          onAvatarTap: recipe.authorId.isNotEmpty
                              ? () =>
                                  context.push('/profile/${recipe.authorId}')
                              : null,
                          authorName: authorName,
                          authorAvatarUrl: avatarUrl,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _CtaBar(
                isBookmarked: socialState.isBookmark,
                isBookmarking: socialState.isTogglingBookmark,
                onBookmark: userId == null
                    ? () => _requireLogin(context)
                    : () => socialCtrl.toggleBookmark(),
                onAddToPlan: () => _openAddToPlan(context),
                onAddToShopping: () => _addIngredientsToShopping(context, recipe.ingredients),
                onReport: () => _openReport(context),
                authorId: recipe.authorId,
                authorName: authorName,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecipeHeroAppBar extends StatelessWidget {
  const _RecipeHeroAppBar({
    required this.recipe,
    required this.heroTag,
    this.onShare,
    this.onReport,
    this.authorName,
    this.authorAvatar,
    this.isFlipped = false,
    this.onFlip,
  });

  final Recipe recipe;
  final String heroTag;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final String? authorName;
  final String? authorAvatar;
  final bool isFlipped;
  final ValueChanged<bool>? onFlip;

  @override
  Widget build(BuildContext context) {
    final image = recipe.coverUrl.isNotEmpty
        ? recipe.coverUrl
        : (recipe.photoURLs.isNotEmpty
            ? recipe.photoURLs.first
            : '');
    final imageUrl = image;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 280,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          tooltip: 'Chia sẻ',
          icon: const Icon(Icons.share_outlined),
          onPressed: onShare,
        ),
        Consumer(
          builder: (context, ref, _) {
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final isOwner = currentUid == recipe.authorId;

            if (!isOwner) return const SizedBox.shrink();

            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              tooltip: 'Tùy chọn',
              onSelected: (value) async {
                if (value == 'edit') {
                  context.push('/recipe/${recipe.id}/edit');
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xóa công thức'),
                      content: const Text(
                        'Bạn có chắc chắn muốn xóa công thức này không?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('recipes')
                          .doc(recipe.id)
                          .delete();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã xóa công thức')),
                        );
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Không thể xóa: $e')),
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Chỉnh sửa'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Xóa', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: FlippableDishCard(
                imageUrl: imageUrl,
                dishName: recipe.title,
                heroTag: heroTag,
                onFlip: onFlip,
              ),
            ),
            // Gradient Overlay for text readability
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isFlipped ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: Container(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight,
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isFlipped ? 0 : 1,
                child: IgnorePointer(
                  ignoring: isFlipped,
                  child: _HeroTitleBar(
                    title: recipe.title,
                    rating: recipe.avgRating,
                    cookTime: recipe.cookTimeMinutes,
                    difficulty: recipe.difficulty,
                    authorName: authorName,
                    authorAvatar: authorAvatar,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTitleBar extends ConsumerWidget {
  const _HeroTitleBar({
    required this.title,
    required this.rating,
    required this.cookTime,
    required this.difficulty,
    this.authorName,
    this.authorAvatar,
  });

  final String title;
  final double rating;
  final int? cookTime;
  final String? difficulty;
  final String? authorName;
  final String? authorAvatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));
    final localizedDifficulty = s.translateDifficulty(difficulty);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            if (cookTime != null)
              _HeroChip(
                icon: Icons.schedule,
                label: TimeUtils.formatDuration(cookTime, context),
              ),
            if (difficulty != null) ...[
              const SizedBox(width: 8),
              _HeroChip(
                icon: Icons.local_fire_department_outlined,
                label: localizedDifficulty,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _RecipeBody extends ConsumerWidget {
  const _RecipeBody({
    required this.recipe,
    required this.socialState,
    required this.checked,
    required this.onToggleIngredient,
    required this.authorName,
    required this.authorAvatarUrl,
    this.onRate,
    this.onAvatarTap,
  });

  final Recipe recipe;
  final RecipeSocialState socialState;
  final Set<int> checked;
  final ValueChanged<int> onToggleIngredient;
  final String authorName;
  final String authorAvatarUrl;
  final Future<void> Function(int stars)? onRate;
  final VoidCallback? onAvatarTap;

  String _getCookTime(BuildContext context) =>
      TimeUtils.formatDuration(recipe.cookTimeMinutes, context);
  String _getDifficulty(WidgetRef ref) => 
      S(ref.watch(localeProvider)).translateDifficulty(recipe.difficulty);

  Future<void> _toggleLike(WidgetRef ref, BuildContext context) async {
    try {
      debugPrint('🔥 [RecipeDetail] Toggling like for recipe: ${recipe.id}');
      final repo = ref.read(interactionRepositoryProvider);
      await repo.toggleRecipeLike(recipe.id);
      debugPrint('✅ [RecipeDetail] Like toggled successfully');
      
      // Refresh recipe to show updated like count
      ref.invalidate(recipeDetailProvider(recipe.id));
      debugPrint('🔄 [RecipeDetail] Recipe provider invalidated');
    } catch (e) {
      debugPrint('❌ [RecipeDetail] Like toggle failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể like: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch like status
    final likeStatusAsync = ref.watch(recipeLikeStatusProvider(recipe.id));
    final isLiked = likeStatusAsync.value ?? false;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Section
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AppAvatar(
                        url: authorAvatarUrl,
                        size: 56,
                        heroTag: recipe.authorId.isNotEmpty
                            ? 'user_avatar_${recipe.authorId}'
                            : null,
                        onTap: onAvatarTap,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                                Text(
                                  'Chef',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (recipe.createdAt != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    TimeUtils.formatTimeAgo(recipe.createdAt, context),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                            ],
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.outlineVariant.withValues(alpha: 0),
                        scheme.outlineVariant,
                        scheme.outlineVariant.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                if (recipe.description.isNotEmpty) ...[
                  Text(
                    recipe.description,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Info Chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [

                    if (recipe.tags.isNotEmpty)
                      ...recipe.tags.take(3).map(
                            (t) => TagChip(label: t),
                          ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Interaction Row
                Row(
                  children: [
                    _StatBadge(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: '${recipe.likesCount}',
                      filled: isLiked,
                      onTap: () => _toggleLike(ref, context),
                    ),
                    const SizedBox(width: 12),
                    _StatBadge(
                      icon: Icons.chat_bubble_outline,
                      label: '${recipe.commentsCount}',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng bình luận đang được phát triển'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    _UserRatingRow(
                      userRating: socialState.userRating,
                      isLoading: socialState.isSubmittingRating,
                      onRate: onRate,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _IngredientsSection(
          ingredients: recipe.ingredients,
          checked: checked,
          onToggle: onToggleIngredient,
        ),
        const SizedBox(height: 16),
        _StepsSection(steps: recipe.steps),
        const SizedBox(height: 16),
        _NutritionSection(recipe: recipe),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    // Use red color for favorite icon when filled
    final isLikeIcon = icon == Icons.favorite || icon == Icons.favorite_border;
    final iconColor = filled 
        ? (isLikeIcon ? Colors.red : scheme.primary) 
        : scheme.onSurfaceVariant;
    final borderColor = filled 
        ? (isLikeIcon ? Colors.red : scheme.primary) 
        : scheme.outlineVariant;
    final backgroundColor = filled
        ? (isLikeIcon ? Colors.red.withValues(alpha: 0.14) : scheme.primary.withValues(alpha: 0.14))
        : scheme.surface;
    final textColor = filled 
        ? (isLikeIcon ? Colors.red : scheme.primary) 
        : scheme.onSurface;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({
    required this.ingredients,
    required this.checked,
    required this.onToggle,
  });

  final List<String> ingredients;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nguyên liệu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${checked.length}/${ingredients.length} đã đánh dấu',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ingredients.isEmpty)
              const Text('Chưa có nguyên liệu.')
            else
              ...ingredients.asMap().entries.map(
                    (e) => CheckboxListTile(
                      value: checked.contains(e.key),
                      onChanged: (_) => onToggle(e.key),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      activeColor: Theme.of(context).colorScheme.primary,
                      title: Text(
                        e.value,
                        style: TextStyle(
                          decoration: checked.contains(e.key)
                              ? TextDecoration.lineThrough
                              : null,
                          color: checked.contains(e.key)
                              ? Theme.of(context).colorScheme.outline
                              : null,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Các bước thực hiện',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (steps.isEmpty)
              const Text('Chưa có các bước thực hiện.')
            else
              ...steps.asMap().entries.map(
                (e) {
                  final isLast = e.key == steps.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 0), // Removing bottom padding as intrinsic handling is cleaner
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${e.key + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Text(
                                e.value,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NutritionSection extends ConsumerWidget {
  const _NutritionSection({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    
    // Read nutrition from Recipe model fields
    final calories = recipe.calories?.toDouble();
    final protein = recipe.protein?.toDouble();
    final carbs = recipe.carbs?.toDouble();
    final fat = recipe.fat?.toDouble();
    
    final hasNutrition = calories != null || protein != null || carbs != null || fat != null;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Giá trị dinh dưỡng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!hasNutrition)
                  Text(
                    'Đang cập nhật',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (hasNutrition)
                  TextButton.icon(
                    onPressed: () => _showNutritionAdviceDialog(context, ref, recipe),
                    icon: Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                    label: Text(
                      s.analyzeByGoal,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: scheme.primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Grid layout for equal-sized pills
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _NutritionPill(
                        label: 'Calories',
                        value: calories != null
                            ? '${calories.toStringAsFixed(0)} kcal'
                            : '--',
                        icon: Icons.local_fire_department_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NutritionPill(
                        label: 'Protein',
                        value: protein != null
                            ? '${protein.toStringAsFixed(0)} g'
                            : '--',
                        icon: Icons.fitness_center_rounded,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _NutritionPill(
                        label: 'Carb',
                        value: carbs != null ? '${carbs.toStringAsFixed(0)} g' : '--',
                        icon: Icons.bubble_chart_rounded,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NutritionPill(
                        label: 'Fat',
                        value: fat != null ? '${fat.toStringAsFixed(0)} g' : '--',
                        icon: Icons.water_drop_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionPill extends StatelessWidget {
  const _NutritionPill({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: effectiveColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRatingRow extends StatelessWidget {
  const _UserRatingRow({
    this.userRating,
    this.onRate,
    this.isLoading = false,
  });

  final int? userRating;
  final Future<void> Function(int stars)? onRate;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        final filled = userRating != null && star <= userRating!;
        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
          icon: Icon(
            star <= (userRating ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
            color: star <= (userRating ?? 0) ? Colors.amber : Colors.grey.withValues(alpha: 0.5),
            size: 22,
          ),
          onPressed: isLoading || onRate == null ? null : () => onRate!(star),
        );
      }),
    );
  }
}

class _CtaBar extends ConsumerWidget {
  const _CtaBar({
    required this.isBookmarked,
    required this.isBookmarking,
    required this.onBookmark,
    required this.onAddToPlan,
    required this.onAddToShopping,
    required this.onReport,
    required this.authorId,
    required this.authorName,
  });

  final bool isBookmarked;
  final bool isBookmarking;
  final VoidCallback onBookmark;
  final VoidCallback onAddToPlan;
  final VoidCallback onAddToShopping;
  final VoidCallback onReport;
  final String authorId;
  final String authorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    
    // Don't show user menu if viewing own recipe
    final showUserMenu = currentUid != null && currentUid != authorId && authorId.isNotEmpty;
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(20),
          color: scheme.surface.withValues(alpha: 0.96),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CtaButton(
                  icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  label: isBookmarked ? 'Đã lưu' : 'Lưu',
                  onPressed: isBookmarking ? null : onBookmark,
                ),
                _CtaButton(
                  icon: Icons.calendar_month_outlined,
                  label: 'Add to plan',
                  onPressed: onAddToPlan,
                ),
                _CtaButton(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Shopping',
                  onPressed: onAddToShopping,
                ),
                if (showUserMenu)
                  _UserMenuButton(
                    authorId: authorId,
                    authorName: authorName,
                  ),
                _CtaButton(
                  icon: Icons.flag_outlined,
                  label: 'Report',
                  onPressed: onReport,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine color based on button type
    Color backgroundColor;
    Color iconColor = Colors.white;
    
    if (label == 'Đã lưu' || label == 'Lưu') {
      backgroundColor = theme.colorScheme.primary;
    } else if (label == 'Report') {
      backgroundColor = theme.colorScheme.errorContainer;
      iconColor = theme.colorScheme.onErrorContainer;
    } else {
      backgroundColor = theme.colorScheme.secondaryContainer;
      iconColor = theme.colorScheme.onSecondaryContainer;
    }

    return Tooltip(
      message: label,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailSkeleton extends StatelessWidget {
  const _RecipeDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoader(height: 300, radius: 0),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLoader(width: 60, height: 60, radius: 30),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(width: 120, height: 20),
                        SizedBox(height: 8),
                        SkeletonLoader(width: 80, height: 14),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),
                SkeletonLoader(width: double.infinity, height: 40, radius: 20),
                SizedBox(height: 16),
                SkeletonLoader(width: double.infinity, height: 100, radius: 16),
                SizedBox(height: 16),
                SkeletonLoader(width: double.infinity, height: 200, radius: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecipeError extends StatelessWidget {
  const _RecipeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          ModernButton(
            onPressed: onRetry,
            style: ModernButtonStyle.outlined,
            icon: Icons.refresh_rounded,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _UserMenuButton extends ConsumerWidget {
  const _UserMenuButton({
    required this.authorId,
    required this.authorName,
  });

  final String authorId;
  final String authorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final relationAsync = ref.watch(relationshipProvider(authorId));

    return relationAsync.when(
      data: (state) {
        return PopupMenuButton<String>(
          tooltip: 'Tùy chọn người dùng',
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_outline,
              size: 20,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          onSelected: (value) => _handleAction(context, ref, value, state),
          itemBuilder: (context) => _buildMenuItems(state),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(RelationshipState state) {
    switch (state.status) {
      case RelationshipStatus.none:
        return [
          const PopupMenuItem(
            value: 'follow',
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1, size: 20),
                SizedBox(width: 12),
                Text('Theo dõi'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'send_request',
            child: Row(
              children: [
                Icon(Icons.group_add_outlined, size: 20),
                SizedBox(width: 12),
                Text('Gửi lời mời kết bạn'),
              ],
            ),
          ),
        ];
      case RelationshipStatus.following:
        return [
          const PopupMenuItem(
            value: 'send_request',
            child: Row(
              children: [
                Icon(Icons.group_add_outlined, size: 20),
                SizedBox(width: 12),
                Text('Gửi lời mời kết bạn'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unfollow',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, size: 20),
                SizedBox(width: 12),
                Text('Bỏ theo dõi'),
              ],
            ),
          ),
        ];
      case RelationshipStatus.pendingSent:
        return [
          const PopupMenuItem(
            value: 'cancel_request',
            child: Row(
              children: [
                Icon(Icons.cancel_schedule_send_outlined, size: 20),
                SizedBox(width: 12),
                Text('Hủy lời mời'),
              ],
            ),
          ),
        ];
      case RelationshipStatus.pendingReceived:
        return [
          const PopupMenuItem(
            value: 'accept',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 12),
                Text('Chấp nhận kết bạn'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reject',
            child: Row(
              children: [
                Icon(Icons.block_outlined, size: 20),
                SizedBox(width: 12),
                Text('Từ chối'),
              ],
            ),
          ),
        ];
      case RelationshipStatus.friends:
        return [
          const PopupMenuItem(
            value: 'unfriend',
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 20),
                SizedBox(width: 12),
                Text('Bỏ bạn bè'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unfollow',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, size: 20),
                SizedBox(width: 12),
                Text('Bỏ theo dõi'),
              ],
            ),
          ),
        ];
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    RelationshipState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(friendRepositoryProvider);

    try {
      switch (action) {
        case 'follow':
          await repo.followUser(authorId);
          messenger.showSnackBar(
            SnackBar(content: Text('Đang theo dõi $authorName')),
          );
          break;
        case 'unfollow':
          await repo.unfollowUser(authorId);
          messenger.showSnackBar(
            SnackBar(content: Text('Đã bỏ theo dõi $authorName')),
          );
          break;
        case 'send_request':
          await repo.sendFriendRequest(authorId);
          messenger.showSnackBar(
            const SnackBar(content: Text('Đã gửi lời mời kết bạn')),
          );
          break;
        case 'cancel_request':
          final reqId = state.pendingRequest?.id;
          if (reqId != null) {
            await repo.cancelFriendRequest(reqId);
            messenger.showSnackBar(
              const SnackBar(content: Text('Đã hủy lời mời')),
            );
          }
          break;
        case 'accept':
          final reqId = state.pendingRequest?.id;
          if (reqId != null) {
            await repo.acceptFriendRequest(reqId);
            messenger.showSnackBar(
              SnackBar(content: Text('Đã kết bạn với $authorName')),
            );
          }
          break;
        case 'reject':
          final reqId = state.pendingRequest?.id;
          if (reqId != null) {
            await repo.rejectFriendRequest(reqId);
            messenger.showSnackBar(
              const SnackBar(content: Text('Đã từ chối lời mời')),
            );
          }
          break;
        case 'unfriend':
          await repo.removeFriend(authorId);
          messenger.showSnackBar(
            const SnackBar(content: Text('Đã bỏ bạn bè')),
          );
          break;
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể thực hiện: $e')),
      );
    }
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
  return 'Người dùng';
}

// Nutrition Advice Helper Classes

class NutritionAdvice {
  final String tomTat;
  final List<String> danhGia;
  final List<String> goiY;
  final String caloUocTinh;
  final String ghiChu;

  NutritionAdvice({
    required this.tomTat,
    required this.danhGia,
    required this.goiY,
    required this.caloUocTinh,
    required this.ghiChu,
  });

  factory NutritionAdvice.fromJson(Map<String, dynamic> json) {
    return NutritionAdvice(
      tomTat: json['tom_tat'] ?? '',
      danhGia: List<String>.from(json['danh_gia'] ?? []),
      goiY: List<String>.from(json['goi_y'] ?? []),
      caloUocTinh: json['ket_qua_uoc_tinh']?['calo'] ?? '',
      ghiChu: json['ket_qua_uoc_tinh']?['ghi_chu'] ?? '',
    );
  }
}

void _showNutritionAdviceDialog(BuildContext context, WidgetRef ref, Recipe recipe) {
  showDialog(
    context: context,
    builder: (context) => _NutritionAdviceDialog(recipe: recipe),
  );
}

class _NutritionAdviceDialog extends ConsumerStatefulWidget {
  final Recipe recipe;
  const _NutritionAdviceDialog({required this.recipe});

  @override
  ConsumerState<_NutritionAdviceDialog> createState() => _NutritionAdviceDialogState();
}

class _NutritionAdviceDialogState extends ConsumerState<_NutritionAdviceDialog> {
  String? _selectedGoal;
  bool _isLoading = false;
  String? _error;
  NutritionAdvice? _advice;

  Future<void> _getAdvice() async {
    if (_selectedGoal == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiService = ref.read(aiChefServiceProvider);
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      final nutrition = {
        'calories': widget.recipe.calories?.toDouble() ?? 0,
        'protein': widget.recipe.protein?.toDouble() ?? 0,
        'carbs': widget.recipe.carbs?.toDouble() ?? 0,
        'fat': widget.recipe.fat?.toDouble() ?? 0,
      };

      final response = await aiService.getNutritionAdvice(
        userId: userId,
        ingredients: widget.recipe.ingredients,
        nutrition: nutrition,
        goal: _selectedGoal!,
      );

      // Clean the response if it contains markdown code blocks
      String jsonStr = response.trim();
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json').last.split('```').first.trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```').last.split('```').first.trim();
      }

      final data = json.decode(jsonStr);
      setState(() {
        _advice = NutritionAdvice.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Không thể lấy tư vấn: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ModernDialog(
      title: s.nutritionAdviceTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.close),
        ),
      ],
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_advice == null && !_isLoading) ...[
                Text(
                   s.selectGoal,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _GoalOption(
                  icon: Icons.fitness_center,
                  label: s.goalWeightLoss,
                  value: 'giam_can',
                  selectedValue: _selectedGoal,
                  onSelected: (val) => setState(() => _selectedGoal = val),
                ),
                _GoalOption(
                  icon: Icons.bolt,
                  label: s.goalMuscleGain,
                  value: 'tang_co',
                  selectedValue: _selectedGoal,
                  onSelected: (val) => setState(() => _selectedGoal = val),
                ),
                _GoalOption(
                  icon: Icons.favorite,
                  label: s.goalHealthy,
                  value: 'an_lanh_manh',
                  selectedValue: _selectedGoal,
                  onSelected: (val) => setState(() => _selectedGoal = val),
                ),
                _GoalOption(
                  icon: Icons.restaurant,
                  label: s.goalSnack,
                  value: 'bua_nhe',
                  selectedValue: _selectedGoal,
                  onSelected: (val) => setState(() => _selectedGoal = val),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ModernButton(
                    onPressed: (_selectedGoal != null && !_isLoading) ? _getAdvice : null,
                    fullWidth: true,
                    child: Text(s.analyzeByGoal),
                  ),
                ),
              ],
              if (_isLoading)
                 Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const ModernLoadingIndicator(size: 40),
                        const SizedBox(height: 16),
                        Text(s.thinking),
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
              if (_advice != null) ...[
                _AdviceResultView(advice: _advice!),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ModernButton(
                    onPressed: () => setState(() {
                      _advice = null;
                      _selectedGoal = null;
                    }),
                    style: ModernButtonStyle.outlined,
                    child: const Text('Chọn mục tiêu khác'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const _GoalOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? scheme.onPrimaryContainer : theme.textTheme.bodyLarge?.color,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdviceResultView extends StatelessWidget {
  final NutritionAdvice advice;

  const _AdviceResultView({required this.advice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Avatar & Summary
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology_alt, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                advice.tomTat,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Assessment
        _AdviceSection(
          title: s.nutritionAssessment,
          items: advice.danhGia,
          icon: Icons.analytics_outlined,
          color: Colors.blue,
        ),
        const SizedBox(height: 16),
        
        // Suggestions
        _AdviceSection(
          title: s.nutritionSuggestions,
          items: advice.goiY,
          icon: Icons.lightbulb_outline,
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        
        // Estimation
        if (advice.caloUocTinh.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.secondary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: scheme.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ước tính sau điều chỉnh:',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  advice.caloUocTinh,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (advice.ghiChu.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    advice.ghiChu,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AdviceSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

  const _AdviceSection({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• ", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  item,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
