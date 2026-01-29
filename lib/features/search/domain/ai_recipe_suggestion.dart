import '../../nutrition/domain/nutrition_models.dart';

class AiRecipeSuggestion {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final int ingredientCount;
  final int stepCount;
  final int? estimatedMinutes;
  final String? difficulty;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final NutritionInfo? nutrition;

  AiRecipeSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.ingredientCount,
    required this.stepCount,
    this.estimatedMinutes,
    this.difficulty,
    required this.ingredients,
    required this.steps,
    this.nutrition,
  });

  factory AiRecipeSuggestion.fromMap(Map<String, dynamic> map) {
    // Generate a temporary ID if none provided (e.g. from server)
    final id = map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

    final title = (map['title'] as String? ?? '').trim();
    final description = ((map['shortDescription'] as String?) ??
            (map['description'] as String?) ??
            '')
        .trim();

    final tags = (map['tags'] as List<dynamic>?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];

    // Parse ingredients
    final rawIngredients = (map['ingredients'] as List<dynamic>?) ?? [];
    final List<RecipeIngredient> ingredientsList = [];
    if (rawIngredients.isNotEmpty) {
      for (var i in rawIngredients) {
        if (i is String) {
          ingredientsList.add(RecipeIngredient(original: i.trim()));
        } else if (i is Map<String, dynamic>) {
          ingredientsList.add(RecipeIngredient.fromMap(i));
        }
      }
    }

    // Parse steps
    final rawSteps = (map['steps'] as List<dynamic>?) ?? [];
    final List<RecipeStep> stepsList = [];
    if (rawSteps.isNotEmpty) {
      for (var i in rawSteps) {
        if (i is String) {
          stepsList.add(RecipeStep(content: i.trim()));
        } else if (i is Map<String, dynamic>) {
          stepsList.add(RecipeStep.fromMap(i));
        }
      }
    }

    // Parse nutrition
    NutritionInfo? nutritionInfo;
    if (map['nutrition'] != null && map['nutrition'] is Map<String, dynamic>) {
      nutritionInfo = NutritionInfo.fromMap(map['nutrition']);
    }

    return AiRecipeSuggestion(
      id: id,
      title: title,
      description: description,
      tags: tags,
      ingredientCount: ingredientsList.length,
      stepCount: stepsList.length,
      estimatedMinutes: (map['timeMinutes'] as num?)?.toInt() ??
          (map['estimatedMinutes'] as num?)?.toInt(),
      difficulty: map['difficulty'] as String?,
      ingredients: ingredientsList,
      steps: stepsList,
      nutrition: nutritionInfo,
    );
  }
}

class RecipeIngredient {
  final String original;
  final String? name;
  final String? amount;

  RecipeIngredient({
    required this.original,
    this.name,
    this.amount,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      original: map['original'] ?? map['name'] ?? '',
      name: map['name'],
      amount: map['amount'],
    );
  }
  
  @override
  String toString() => original;
}

class RecipeStep {
  final String content;

  RecipeStep({required this.content});

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      content: map['content'] ?? map['step'] ?? '',
    );
  }

  @override
  String toString() => content;
}

class NutritionInfo {
  final Macros macros;

  NutritionInfo({required this.macros});

  factory NutritionInfo.fromMap(Map<String, dynamic> map) {
    return NutritionInfo(
      macros: Macros.fromMap(map), // Reuse existing Macros parsing
    );
  }
}
