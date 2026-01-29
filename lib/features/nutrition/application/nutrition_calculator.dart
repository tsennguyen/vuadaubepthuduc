import '../../feed/data/recipe_model.dart';
import '../../planner/data/meal_plan_repository.dart';
import '../../planner/domain/meal_plan_models.dart';
import '../../recipe/data/recipe_repository.dart';
import '../domain/nutrition_models.dart';

/// Calculator cho macro dinh dưỡng dựa trên mealPlan + macros per serving trong recipe.
/// Assumption: recipe.macros là macro cho 1 khẩu phần.
class NutritionCalculator {
  NutritionCalculator({
    required this.recipeRepo,
    required this.mealPlanRepo,
  });

  final RecipeRepository recipeRepo;
  final MealPlanRepository mealPlanRepo;

  /// Lấy macro cho 1 meal cụ thể (xác định bằng day + mealId).
  Future<MealMacroSummary?> getMealMacro({
    required DateTime day,
    required String mealId,
  }) async {
    final meals = await mealPlanRepo.watchDay(day).first;
    MealPlanEntry? meal;
    for (final m in meals) {
      if (m.id == mealId) {
        meal = m;
        break;
      }
    }
    if (meal == null) return null;

    final recipe = await recipeRepo.getRecipeById(meal.recipeId);
    final macrosPerServing = _macrosForMeal(meal, recipe: recipe);
    final total = macrosPerServing.scale(meal.servings.toDouble());

    return MealMacroSummary(
      meal: meal,
      macrosPerServing: macrosPerServing,
      totalMacros: total,
    );
  }

  /// Lấy macro cho tất cả meals trong một ngày.
  Future<List<MealMacroSummary>> getDayMealMacros(DateTime day) async {
    final meals = await mealPlanRepo.watchDay(day).first;
    if (meals.isEmpty) return const [];

    // Cache recipeId -> macros.
    final cache = <String, Macros>{};
    final results = <MealMacroSummary>[];

    for (final meal in meals) {
      final recipeId = meal.recipeId.trim();
      if (recipeId.isEmpty) continue;

      var perServing = cache[recipeId] ?? await _loadAndCache(recipeId, cache);
      if (!_hasNonZero(perServing)) {
        perServing = _macrosFromEstimate(meal.estimatedMacros);
      }

      final total = perServing.scale(meal.servings.toDouble());
      results.add(
        MealMacroSummary(
          meal: meal,
          macrosPerServing: perServing,
          totalMacros: total,
        ),
      );
    }

    return results;
  }

  Future<Macros> _loadAndCache(String recipeId, Map<String, Macros> cache) async {
    final recipe = await recipeRepo.getRecipeById(recipeId);
    if (recipe == null) {
      cache[recipeId] = Macros.zero;
      return Macros.zero;
    }
    final macros = _macrosFromRecipe(recipe);
    cache[recipeId] = macros;
    return macros;
  }

  Macros _macrosFromRecipe(Recipe recipe) {
    // Recipe model chưa expose macros -> đọc từ snapshot nếu có (macros per serving).
    final data = recipe.snapshot?.data();
    if (data is Map<String, dynamic>) {
      final macrosMap = data['macros'] as Map<String, dynamic>?;
      return Macros.fromMap(macrosMap);
    }
    return Macros.zero;
  }

  Macros _macrosForMeal(MealPlanEntry meal, {Recipe? recipe}) {
    final fromRecipe =
        recipe == null ? Macros.zero : _macrosFromRecipe(recipe);
    if (_hasNonZero(fromRecipe)) return fromRecipe;
    return _macrosFromEstimate(meal.estimatedMacros);
  }

  Macros _macrosFromEstimate(Map<String, double>? map) {
    if (map == null) return Macros.zero;
    return Macros.fromMap(map);
  }

  bool _hasNonZero(Macros macros) {
    return macros.calories > 0 ||
        macros.protein > 0 ||
        macros.carbs > 0 ||
        macros.fat > 0;
  }
}
