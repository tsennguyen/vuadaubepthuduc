import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AiErrorCode {
  unavailable,
  invalidRequest,
  auth,
  permission,
  config,
  unknown,
}

class AiException implements Exception {
  const AiException({
    required this.code,
    required this.message,
  });

  factory AiException.fromFunctions(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unavailable':
      case 'resource-exhausted':
        return const AiException(
          code: AiErrorCode.unavailable,
          message: 'AI đang quá tải hoặc tạm gián đoạn. Bạn thử lại sau nhé.',
        );
      case 'invalid-argument':
        return const AiException(
          code: AiErrorCode.invalidRequest,
          message:
              'Yêu cầu AI không hợp lệ. Bạn hãy kiểm tra lại dữ liệu nhập.',
        );
      case 'failed-precondition':
        return const AiException(
          code: AiErrorCode.config,
          message:
              'AI chưa được cấu hình đúng trên máy chủ. Vui lòng báo admin.',
        );
      case 'permission-denied':
        return const AiException(
          code: AiErrorCode.permission,
          message: 'Bạn không có quyền sử dụng AI cho thao tác này.',
        );
      case 'unauthenticated':
        return const AiException(
          code: AiErrorCode.auth,
          message: 'Bạn cần đăng nhập để sử dụng AI.',
        );
      default:
        return AiException(
          code: AiErrorCode.unknown,
          message:
              'Không tạo được kết quả từ AI (${e.code}). Bạn thử lại sau nhé.',
        );
    }
  }

  final AiErrorCode code;
  final String message;

  @override
  String toString() => message;
}

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

class AiService {
  AiService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  HttpsCallable get _generateMealPlan =>
      _functions.httpsCallable('aiGenerateMealPlan');
  HttpsCallable get _enrichRecipeDraft =>
      _functions.httpsCallable('aiEnrichRecipeDraft');
  HttpsCallable get _suggestRecipes =>
      _functions.httpsCallable('aiSuggestRecipesByIngredients');
  HttpsCallable get _estimateNutrition =>
      _functions.httpsCallable('aiEstimateNutrition');


  Future<Map<String, dynamic>> generateMealPlan({
    required DateTime weekStart,
    String? userId,
  }) async {
    try {
      final result = await _generateMealPlan.call<Map<String, dynamic>>({
        if (userId != null) 'userId': userId,
        'weekStartIso': weekStart.toUtc().toIso8601String(),
      });
      return (result.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AiException.fromFunctions(e);
    } catch (_) {
      throw const AiException(
        code: AiErrorCode.unknown,
        message: 'Lỗi không xác định khi gọi AI.',
      );
    }
  }

  Future<Map<String, dynamic>> enrichRecipeDraft({
    required String title,
    String? description,
    required String rawIngredients,
  }) async {
    try {
      final result = await _enrichRecipeDraft.call<Map<String, dynamic>>({
        'title': title,
        'description': description ?? '',
        'rawIngredients': rawIngredients,
      });
      return (result.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AiException.fromFunctions(e);
    } catch (_) {
      throw const AiException(
        code: AiErrorCode.unknown,
        message: 'Lỗi không xác định khi gọi AI.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> suggestRecipesByIngredients({
    required List<String> ingredients,
    Map<String, dynamic>? userPrefs,
  }) async {
    try {
      final result =
          await _suggestRecipes.call<Map<String, dynamic>>(<String, dynamic>{
        'ingredients': ingredients,
        if (userPrefs != null) 'userPrefs': userPrefs,
      });
      final data =
          (result.data as Map<String, dynamic>?) ?? <String, dynamic>{};
      return (data['ideas'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          <Map<String, dynamic>>[];
    } on FirebaseFunctionsException catch (e) {
      throw AiException.fromFunctions(e);
    } catch (_) {
      throw const AiException(
        code: AiErrorCode.unknown,
        message: 'Lỗi không xác định khi gọi AI.',
      );
    }
  }

  /// Estimate nutrition values for a list of ingredients
  /// Returns Map with keys: calories, protein, carbs, fat (all integers)
  Future<Map<String, dynamic>> estimateNutrition({
    required List<String> ingredients,
    required int servings,
  }) async {
    try {
      // Convert ingredients from List<String> to List<Map> with 'name' field
      // as expected by the Firebase Function
      final ingredientsData = ingredients
          .map((ingredient) => {'name': ingredient})
          .toList();

      final result = await _estimateNutrition.call<Map<String, dynamic>>({
        'ingredients': ingredientsData,
        'servings': servings,
      });
      return (result.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AiException.fromFunctions(e);
    } catch (_) {
      throw const AiException(
        code: AiErrorCode.unknown,
        message: 'Lỗi không xác định khi gọi AI.',
      );
    }
  }
}
