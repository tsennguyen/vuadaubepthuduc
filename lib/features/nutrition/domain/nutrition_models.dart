import '../../planner/domain/meal_plan_models.dart';

/// Macro dinh dưỡng (per serving nếu lấy từ recipe).
class Macros {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const Macros({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Macros operator +(Macros other) {
    return Macros(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
    );
  }

  Macros scale(double factor) {
    return Macros(
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
    );
  }

  static const zero = Macros(calories: 0, protein: 0, carbs: 0, fat: 0);

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  factory Macros.fromMap(Map<String, dynamic>? map) {
    if (map == null) return Macros.zero;

    double parse(String key) {
      final v = map[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return Macros(
      calories: parse('calories'),
      protein: parse('protein'),
      carbs: parse('carbs'),
      fat: parse('fat'),
    );
  }
}

class MealMacroSummary {
  /// Meal từ mealPlans (bao gồm recipeId, servings).
  final MealPlanEntry meal;

  /// Macro cho 1 khẩu phần của recipe.
  final Macros macrosPerServing;

  /// Macro cho meal này (macrosPerServing * servings).
  final Macros totalMacros;

  const MealMacroSummary({
    required this.meal,
    required this.macrosPerServing,
    required this.totalMacros,
  });
}
