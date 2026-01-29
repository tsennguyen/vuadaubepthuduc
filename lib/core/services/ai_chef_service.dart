import 'package:cloud_functions/cloud_functions.dart';

class AiChefService {
  AiChefService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  HttpsCallable get _chefChat => _functions.httpsCallable('aiChefChat');

  /// Chat with AI Chef Assistant
  /// 
  /// The AI has access to:
  /// - Recipe database (can search and recommend)
  /// - Nutrition knowledge
  /// - Cooking techniques
  /// - Ingredient substitutions
  Future<String> chat({
    required String userId,
    required String message,
    String? sessionId,
  }) async {
    try {
      final result = await _chefChat.call<Map<String, dynamic>>({
        'userId': userId,
        'message': message,
        if (sessionId != null) 'sessionId': sessionId,
      });

      final data = result.data;
      if (data.isEmpty) {
        throw Exception('Không nhận được phản hồi từ Chef AI');
      }

      // Function returns {reply: string, sessionId: string}
      final response = data['reply'] as String?;
      if (response == null || response.isEmpty) {
        throw Exception('Chef AI trả về phản hồi rỗng');
      }

      return response;
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    } catch (e) {
      throw Exception('Lỗi kết nối với Chef AI: $e');
    }
  }

  /// Get personalized nutrition advice based on goal
  Future<String> getNutritionAdvice({
    required String userId,
    required List<String> ingredients,
    required Map<String, double> nutrition,
    required String goal,
  }) async {
    final ingredientsList = ingredients.map((e) => '- $e').join('\n');
    final calories = nutrition['calories']?.toStringAsFixed(0) ?? '0';
    final protein = nutrition['protein']?.toStringAsFixed(0) ?? '0';
    final carbs = nutrition['carbs']?.toStringAsFixed(0) ?? '0';
    final fat = nutrition['fat']?.toStringAsFixed(0) ?? '0';

    final prompt = '''
Bạn là trợ lý dinh dưỡng thân thiện trong ứng dụng mạng xã hội chia sẻ công thức nấu ăn.
Nhiệm vụ của bạn là đưa ra nhận xét và gợi ý dinh dưỡng ngắn gọn, dễ hiểu, mang tính hỗ trợ.
KHÔNG đóng vai bác sĩ, KHÔNG đưa ra lời khuyên y khoa.
Sử dụng ngôn ngữ tích cực, nhẹ nhàng, không phán xét.
Câu trả lời phải ngắn gọn, phù hợp hiển thị trên ứng dụng di động.

Người dùng đã chọn các nguyên liệu và định lượng sau:

Nguyên liệu:
$ingredientsList

Giá trị dinh dưỡng đã tính:
- Năng lượng: $calories kcal
- Chất đạm (Protein): $protein g
- Tinh bột (Carb): $carbs g
- Chất béo (Fat): $fat g

Mục tiêu ăn uống của người dùng: $goal
(Giá trị có thể là: giam_can | tang_co | an_lanh_manh | bua_nhe)

Yêu cầu:
1. Đưa ra nhận xét tổng quan ngắn gọn về món ăn (1 câu).
2. Đánh giá nhanh dinh dưỡng bằng 2–3 ý ngắn.
3. Đề xuất tối đa 3 điều chỉnh nhỏ về nguyên liệu hoặc định lượng để phù hợp hơn với mục tiêu.
4. Nếu có thể, ước lượng lại lượng calo sau khi điều chỉnh.
5. Sử dụng ngôn ngữ thân thiện, không chê trách, không cực đoan.
6. Tổng nội dung không quá 120 từ.

CHỈ trả về kết quả theo đúng định dạng JSON sau, không thêm bất kỳ nội dung nào khác:

{
  "tom_tat": "",
  "danh_gia": [],
  "goi_y": [],
  "ket_qua_uoc_tinh": {
    "calo": "",
    "ghi_chu": ""
  }
}
''';

    return chat(userId: userId, message: prompt);
  }

  Exception _mapException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return Exception('Vui lòng đăng nhập để sử dụng Chef AI');
      case 'failed-precondition':
        return Exception('Tính năng Chef AI hiện đang bảo trì');
      case 'resource-exhausted':
        return Exception('Chef AI đang quá tải, vui lòng thử lại sau');
      case 'invalid-argument':
        return Exception('Tin nhắn không hợp lệ');
      default:
        return Exception('Lỗi không xác định: ${e.message}');
    }
  }
}
