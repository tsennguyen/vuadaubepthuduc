import 'package:cloud_functions/cloud_functions.dart';

class AiNutritionRepository {
  AiNutritionRepository({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Call AI to estimate nutrition for a recipe
  /// Returns macros per serving: {calories, protein, carbs, fat}
  Future<Map<String, double>> estimateNutrition({
    required List<Map<String, dynamic>> ingredients,
    required int servings,
  }) async {
    try {
      // Call AI to estimate nutrition
      final callable = _functions.httpsCallable('aiEstimateNutrition');
      final result = await callable.call<Map<String, dynamic>>({
        'ingredients': ingredients,
        'servings': servings,
      });

      final data = result.data;

      final macros = {
        'calories': _toDouble(data['calories']),
        'protein': _toDouble(data['protein']),
        'carbs': _toDouble(data['carbs']),
        'fat': _toDouble(data['fat']),
      };
      return macros;
    } on FirebaseFunctionsException catch (e) {
      // User-friendly error messages
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw Exception('AI đang quá tải hoặc tạm gián đoạn. Bạn thử lại sau nhé.');
      } else if (e.code == 'unauthenticated') {
        throw Exception('Vui lòng đăng nhập để sử dụng tính năng này.');
      } else {
        throw Exception('Không thể phân tích dinh dưỡng: ${e.message ?? e.code}');
      }
    } catch (e) {
      throw Exception('Lỗi không xác định khi phân tích dinh dưỡng.');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed ?? 0.0;
  }
}
