import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/data/user_repository.dart';
import '../../planner/data/meal_plan_repository.dart';
import 'nutrition_calculator.dart';
import '../domain/nutrition_models.dart';

class NutritionSummaryService {
  NutritionSummaryService({
    required this.calculator,
    required this.mealPlanRepo,
    required this.userRepo,
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  final NutritionCalculator calculator;
  final MealPlanRepository mealPlanRepo;
  final UserRepository userRepo;
  final FirebaseAuth _auth;

  /// Tổng macros của một ngày.
  Future<Macros> getDayTotalMacros(DateTime day) async {
    final summaries = await calculator.getDayMealMacros(day);
    return summaries.fold<Macros>(
      Macros.zero,
      (sum, m) => sum + m.totalMacros,
    );
  }

  /// Tổng macros của một tuần (7 ngày, bắt đầu từ weekStart).
  Future<Map<DateTime, Macros>> getWeekTotalMacros(DateTime weekStart) async {
    final start = _normalizeDate(weekStart);
    final days = List<DateTime>.generate(
      7,
      (i) => start.add(Duration(days: i)),
      growable: false,
    );

    final totals = await Future.wait(days.map(getDayTotalMacros));
    final map = <DateTime, Macros>{};
    for (var i = 0; i < days.length; i++) {
      map[days[i]] = totals[i];
    }
    return map;
  }

  /// Lấy macro target của user (nếu có) từ `users/{uid}.macroTarget`.
  Future<Macros?> getUserMacroTarget() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final data = await userRepo.getUserByUid(uid);
    if (data == null) return null;
    final targetMap = data['macroTarget'] as Map<String, dynamic>?;
    if (targetMap == null) return null;
    return Macros.fromMap(targetMap);
  }

  DateTime _normalizeDate(DateTime input) {
    final local = input.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

