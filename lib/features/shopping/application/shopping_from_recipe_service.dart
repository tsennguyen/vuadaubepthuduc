import 'package:flutter/foundation.dart';
import '../../recipe/data/recipe_repository.dart';
import '../data/shopping_list_repository.dart';

import 'shopping_ingredient_parsing.dart';

class ShoppingFromRecipeService {
  ShoppingFromRecipeService({
    required this.shoppingRepo,
    required this.recipeRepo,
  });

  final ShoppingListRepository shoppingRepo;
  final RecipeRepository recipeRepo;

  Future<void> addRecipeIngredientsToShoppingList(String recipeId) async {
    final rid = recipeId.trim();
    if (rid.isEmpty) {
      debugPrint('🛒 [Shopping] Recipe ID empty, aborting');
      return;
    }

    debugPrint('🛒 [Shopping] Fetching recipe: $rid');
    final recipe = await recipeRepo.getRecipeById(rid);
    if (recipe == null) {
      debugPrint('🛒 [Shopping] Recipe not found: $rid');
      return;
    }

    debugPrint('🛒 [Shopping] Recipe found: ${recipe.title}');
    final ingredients = parseRecipeIngredientsForShopping(recipe);
    debugPrint('🛒 [Shopping] Parsed ${ingredients.length} ingredients');
    
    int successCount = 0;
    int failCount = 0;
    
    for (final ing in ingredients) {
      try {
        debugPrint('🛒 [Shopping] Adding: ${ing.name} (${ing.quantity} ${ing.unit})');
        await shoppingRepo.upsertItemByNameAndUnit(
          name: ing.name,
          quantity: ing.quantity,
          unit: ing.unit,
          category: ing.category,
          sourceRecipeId: rid,
        );
        successCount++;
        debugPrint('🛒 [Shopping] ✅ Added successfully');
      } catch (e) {
        failCount++;
        debugPrint('🛒 [Shopping] ❌ Failed to add ${ing.name}: $e');
        // Ignore individual ingredient failures to avoid blocking the whole flow.
      }
    }
    
    debugPrint('🛒 [Shopping] Done! Success: $successCount, Failed: $failCount');
  }
}
