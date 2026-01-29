import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/recipes_controller.dart';
import '../data/recipes_repository.dart';
import '../../profile/application/user_cache_controller.dart';
import '../widgets/recipe_card.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  late final Stream<List<RecipeSummary>> _recipesStream;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(recipesRepositoryProvider);
    _recipesStream = repo.watchRecipes(limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RecipeSummary>>(
      stream: _recipesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Da xay ra loi.'),
                const SizedBox(height: 8),
                Text('${snapshot.error}', textAlign: TextAlign.center),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? const <RecipeSummary>[];
        final authorIds =
            items.map((r) => r.authorId).where((id) => id.isNotEmpty).toSet();
        ref.read(userCacheProvider.notifier).preload(authorIds);
        if (items.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: Text('Chua co cong thuc nao')),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final recipe = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RecipeCard(
                heroTag: 'recipe_image_${recipe.id}',
                title: recipe.title,
                imageUrl: recipe.photoUrl ?? '',
                authorName:
                    recipe.authorId.isNotEmpty ? recipe.authorId : 'Chef',
                authorId: recipe.authorId,
                rating: recipe.avgRating,
                difficulty: recipe.difficulty,
                cookMinutes: recipe.cookTimeMinutes,
                likesCount: recipe.likesCount,
                commentsCount: recipe.commentsCount,
                tags: const [],
                createdAt: recipe.createdAt,
                onAvatarTap: recipe.authorId.isNotEmpty
                    ? () => context.push('/profile/${recipe.authorId}')
                    : null,
                onTap: () => context.push('/recipe/${recipe.id}'),
              ),
            );
          },
        );
      },
    );
  }
}
