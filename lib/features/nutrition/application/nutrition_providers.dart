import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_repository.dart';
import '../../planner/data/meal_plan_repository.dart';
import '../../recipe/data/recipe_repository.dart';
import 'nutrition_calculator.dart';
import 'nutrition_summary_service.dart';

final nutritionCalculatorProvider = Provider<NutritionCalculator>((ref) {
  final recipeRepo = ref.watch(recipeRepositoryProvider);
  final mealRepo = ref.watch(mealPlanRepositoryProvider);
  return NutritionCalculator(
    recipeRepo: recipeRepo,
    mealPlanRepo: mealRepo,
  );
});

final nutritionSummaryServiceProvider = Provider<NutritionSummaryService>((ref) {
  final calculator = ref.watch(nutritionCalculatorProvider);
  final mealRepo = ref.watch(mealPlanRepositoryProvider);
  return NutritionSummaryService(
    calculator: calculator,
    mealPlanRepo: mealRepo,
    userRepo: UserRepository(), // Could also be a provider
    auth: FirebaseAuth.instance,
  );
});
