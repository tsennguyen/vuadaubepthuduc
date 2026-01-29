import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/data/recipe_model.dart';
import '../data/recipe_repository.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepositoryImpl();
});

final recipeDetailProvider =
    FutureProvider.family<Recipe, String>((ref, id) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final recipe = await repo.getRecipeById(id);
  if (recipe == null) {
    throw Exception('Recipe không tồn tại');
  }
  return recipe;
});
