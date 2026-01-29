import '../../recipe/data/recipe_repository.dart';
import '../../planner/data/meal_plan_repository.dart';
import '../data/shopping_list_repository.dart';

import 'shopping_ingredient_parsing.dart';

class ShoppingFromPlanService {
  ShoppingFromPlanService({
    required this.shoppingRepo,
    required this.mealPlanRepo,
    required this.recipeRepo,
  });

  final ShoppingListRepository shoppingRepo;
  final MealPlanRepository mealPlanRepo;
  final RecipeRepository recipeRepo;

  /// Generate shopping list for a week starting from [weekStart] (7 days).
  ///
  /// Notes:
  /// - This does not clear existing items; it only upserts/accumulates.
  /// - No unit conversion (kg <-> g) in this version (TODO if needed).
  Future<void> generateWeeklyShoppingList(DateTime weekStart) async {
    final entries = await mealPlanRepo.getWeekOnce(weekStart);
    if (entries.isEmpty) return;

    final servingsByRecipe = <String, double>{};
    for (final entry in entries) {
      final rid = entry.recipeId.trim();
      if (rid.isEmpty) continue;
      final servings = entry.servings;
      if (servings <= 0) continue;
      servingsByRecipe[rid] = (servingsByRecipe[rid] ?? 0) + servings;
    }

    if (servingsByRecipe.isEmpty) return;

    final ids = servingsByRecipe.keys.toList(growable: false);
    final recipes = await Future.wait(ids.map(recipeRepo.getRecipeById));

    for (var i = 0; i < ids.length; i++) {
      final recipeId = ids[i];
      final recipe = recipes[i];
      if (recipe == null) continue;

      final multiplier = servingsByRecipe[recipeId] ?? 0;
      if (multiplier <= 0) continue;

      final ingredients = parseRecipeIngredientsForShopping(recipe);
      for (final ing in ingredients) {
        final scaledQuantity = ing.quantity * multiplier;
        if (scaledQuantity <= 0) continue;
        try {
          await shoppingRepo.upsertItemByNameAndUnit(
            name: ing.name,
            quantity: scaledQuantity,
            unit: ing.unit,
            category: ing.category,
            sourceRecipeId: recipeId,
          );
        } catch (_) {
          // Ignore individual ingredient failures to avoid blocking the whole flow.
        }
      }
    }
  }
}

