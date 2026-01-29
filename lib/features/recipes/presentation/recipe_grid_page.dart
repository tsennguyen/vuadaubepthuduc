import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/app_top_bar.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/utils/tokenizer.dart';
import '../application/recipes_controller.dart';
import '../data/recipes_repository.dart';
import '../widgets/recipe_card.dart';

final recipesStreamProvider = StreamProvider<List<RecipeSummary>>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  return repo.watchRecipes(limit: 50);
});

final recipeFilterProvider = StateProvider<RecipeFilter>((ref) => const RecipeFilter());

class RecipeFilter {
  const RecipeFilter({
    this.searchQuery = '',
    this.difficulty,
    this.maxTime,
  });

  final String searchQuery;
  final String? difficulty;
  final int? maxTime;

  RecipeFilter copyWith({
    String? searchQuery,
    String? difficulty,
    int? maxTime,
    bool clearDifficulty = false,
    bool clearMaxTime = false,
  }) {
    return RecipeFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      maxTime: clearMaxTime ? null : (maxTime ?? this.maxTime),
    );
  }

  bool get isEmpty => searchQuery.isEmpty && difficulty == null && maxTime == null;
}

final filteredRecipesProvider = Provider<AsyncValue<List<RecipeSummary>>>((ref) {
  final recipesAsync = ref.watch(recipesStreamProvider);
  final filter = ref.watch(recipeFilterProvider);

  return recipesAsync.whenData((items) {
    return items.where((recipe) {
      // Filter by search query
      if (filter.searchQuery.isNotEmpty) {
        final normalizedTitle = removeVietnameseDiacritics(recipe.title);
        final normalizedQuery = removeVietnameseDiacritics(filter.searchQuery);
        if (!normalizedTitle.contains(normalizedQuery)) return false;
      }

      // Filter by difficulty
      if (filter.difficulty != null) {
        final rDiff = recipe.difficulty;
        if (rDiff == null) return false;
        
        final normalizedItem = removeVietnameseDiacritics(rDiff);
        final normalizedFilter = removeVietnameseDiacritics(filter.difficulty!);
        
        if (normalizedItem != normalizedFilter) return false;
      }

      // Filter by cook time
      if (filter.maxTime != null) {
        if (recipe.cookTimeMinutes == null ||
            recipe.cookTimeMinutes! > filter.maxTime!) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

class RecipeGridPage extends ConsumerWidget {
  const RecipeGridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final s = S(locale);
    final filteredRecipesAsync = ref.watch(filteredRecipesProvider);
    final filter = ref.watch(recipeFilterProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: s.recipes,
        onSearchTap: () {
          // You could implement a proper search overlay here
          // For now, toggle a search mode or navigate
          context.push('/search');
        },
        onNotificationsTap: () => context.push('/notifications'),
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter, s: s),
          Expanded(
            child: filteredRecipesAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return AppEmptyView(
                    title: filter.isEmpty ? s.emptyRecipesTitle : 'Không tìm thấy kết quả',
                    subtitle: filter.isEmpty 
                        ? s.emptyRecipesSubtitle 
                        : 'Hãy thử thay đổi bộ lọc hoặc từ khóa tìm kiếm.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.s12,
                    crossAxisSpacing: AppSpacing.s12,
                    childAspectRatio: 0.55,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final recipe = items[index];
                    return RecipeCard(
                      heroTag: 'recipe_grid_image_${recipe.id}',
                      title: recipe.title,
                      imageUrl: recipe.photoUrl ?? '',
                      authorName: recipe.authorId.isNotEmpty ? recipe.authorId : s.user,
                      authorId: recipe.authorId,
                      rating: recipe.avgRating,
                      difficulty: recipe.difficulty,
                      cookMinutes: recipe.cookTimeMinutes,
                      likesCount: recipe.likesCount,
                      commentsCount: recipe.commentsCount,
                      tags: recipe.tags,
                      onTap: () => context.push('/recipe/${recipe.id}'),
                      onAvatarTap: recipe.authorId.isNotEmpty
                          ? () => context.push('/profile/${recipe.authorId}')
                          : null,
                    );
                  },
                );
              },
              loading: () => AppLoadingIndicator(message: s.loadingRecipes),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(recipesStreamProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.s});
  final RecipeFilter filter;
  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Search field could go here, but let's stick to chips for now
                _FilterChip(
                  label: s.filterAll,
                  isSelected: filter.isEmpty,
                  onSelected: (_) => ref.read(recipeFilterProvider.notifier).state = const RecipeFilter(),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: s.difficultyEasy,
                  isSelected: filter.difficulty == 'De',
                  onSelected: (selected) => ref.read(recipeFilterProvider.notifier).update(
                    (state) => state.copyWith(
                      difficulty: selected ? 'De' : null,
                      clearDifficulty: !selected,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: s.difficultyMedium,
                  isSelected: filter.difficulty == 'Trung binh',
                  onSelected: (selected) => ref.read(recipeFilterProvider.notifier).update(
                    (state) => state.copyWith(
                      difficulty: selected ? 'Trung binh' : null,
                      clearDifficulty: !selected,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: s.difficultyHard,
                  isSelected: filter.difficulty == 'Kho',
                  onSelected: (selected) => ref.read(recipeFilterProvider.notifier).update(
                    (state) => state.copyWith(
                      difficulty: selected ? 'Kho' : null,
                      clearDifficulty: !selected,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                const SizedBox(width: 16),
                _FilterChip(
                  label: '< 30 ${s.minutes}',
                  isSelected: filter.maxTime == 30,
                  onSelected: (selected) => ref.read(recipeFilterProvider.notifier).update(
                    (state) => state.copyWith(
                      maxTime: selected ? 30 : null,
                      clearMaxTime: !selected,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '< 60 ${s.minutes}',
                  isSelected: filter.maxTime == 60,
                  onSelected: (selected) => ref.read(recipeFilterProvider.notifier).update(
                    (state) => state.copyWith(
                      maxTime: selected ? 60 : null,
                      clearMaxTime: !selected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected 
            ? (theme.brightness == Brightness.dark 
                ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                : theme.colorScheme.onPrimary)
            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      selectedColor: theme.brightness == Brightness.dark
          ? theme.colorScheme.primary.withValues(alpha: 0.3)
          : theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
