import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiConfig {
  const AiConfig({
    required this.id,
    this.name,
    this.description,
    required this.model,
    required this.systemPrompt,
    required this.userPromptTemplate,
    required this.temperature,
    required this.maxOutputTokens,
    required this.enabled,
    this.extraNotes,
  });

  final String id;
  final String? name;
  final String? description;
  final String model;
  final String systemPrompt;
  final String userPromptTemplate;
  final double temperature;
  final int maxOutputTokens;
  final bool enabled;
  final String? extraNotes;

  factory AiConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AiConfig(
      id: doc.id,
      name: data['name'] as String?,
      description: data['description'] as String?,
      model: (data['model'] as String?) ?? 'gpt-4.1-mini',
      systemPrompt: (data['systemPrompt'] as String?) ?? '',
      userPromptTemplate: (data['userPromptTemplate'] as String?) ?? '',
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.7,
      maxOutputTokens: (data['maxOutputTokens'] as num?)?.toInt() ?? 1024,
      enabled: (data['enabled'] as bool?) ?? true,
      extraNotes: data['extraNotes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'model': model,
      'systemPrompt': systemPrompt,
      'userPromptTemplate': userPromptTemplate,
      'temperature': temperature,
      'maxOutputTokens': maxOutputTokens,
      'enabled': enabled,
      if (extraNotes != null) 'extraNotes': extraNotes,
    };
  }

  AiConfig copyWith({
    String? id,
    String? name,
    String? description,
    String? model,
    String? systemPrompt,
    String? userPromptTemplate,
    double? temperature,
    int? maxOutputTokens,
    bool? enabled,
    String? extraNotes,
  }) {
    return AiConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      userPromptTemplate: userPromptTemplate ?? this.userPromptTemplate,
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      enabled: enabled ?? this.enabled,
      extraNotes: extraNotes ?? this.extraNotes,
    );
  }
}

abstract class AiConfigRepository {
  Stream<List<AiConfig>> watchAllConfigs();
  Future<AiConfig?> getConfig(String id);
  Future<void> updateConfig(String id, Map<String, dynamic> updates);
  Future<void> deleteConfig(String id);
}

class FirestoreAiConfigRepository implements AiConfigRepository {
  FirestoreAiConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _configs =>
      _firestore.collection('aiConfigs');

  @override
  Stream<List<AiConfig>> watchAllConfigs() {
    return _configs.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AiConfig.fromFirestore(doc))
          .toList()
        ..sort((a, b) => (a.name ?? a.id).compareTo(b.name ?? b.id));
    });
  }

  @override
  Future<AiConfig?> getConfig(String id) async {
    final doc = await _configs.doc(id).get();
    return doc.exists ? AiConfig.fromFirestore(doc) : null;
  }

  @override
  Future<void> updateConfig(String id, Map<String, dynamic> updates) async {
    await _configs.doc(id).set(updates, SetOptions(merge: true));
  }

  @override
  Future<void> deleteConfig(String id) async {
    await _configs.doc(id).delete();
  }

  /// Seed default configs from hardcoded defaults (matching functions/src/ai_config.ts)
  Future<void> seedDefaultConfigs() async {
    final defaults = _getDefaultConfigs();
    final batch = _firestore.batch();
    
    for (final config in defaults) {
      final docRef = _configs.doc(config['id'] as String);
      batch.set(docRef, config);
    }
    
    await batch.commit();
  }

  List<Map<String, dynamic>> _getDefaultConfigs() {
    return [
      {
        'id': 'search',
        'name': 'Gợi ý tìm kiếm',
        'description': 'Phân tích truy vấn tìm kiếm và trích xuất từ khóa/bộ lọc.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''Bạn là search query parser cho app nấu ăn.
Nhiệm vụ: nhận câu tiếng Việt tự nhiên và trả về JSON đúng schema {keywords, tags, filters}.
Tags viết không dấu, snake_case nếu có thể. Không markdown/giải thích.''',
        'userPromptTemplate': '''Input query:
{{query}}
Nếu query khó, dùng logic và phân tích như ví dụ sau:
User: "món bún dễ nấu cho 2 người ăn sáng ít calo"
Output mẫu:
{
  "keywords": ["bun"],
  "tags": ["vietnamese", "breakfast", "low_calorie"],
  "filters": {
    "maxTime": 20,
    "maxCalories": 400,
    "servings": 2,
    "mealType": "breakfast",
    "difficulty": "easy"
  }
}
Hãy trả về JSON đúng schema, ưu tiên từ khóa không dấu.''',
        'temperature': 0.2,
        'maxOutputTokens': 600,
        'enabled': true,
      },
      {
        'id': 'recipe_suggest',
        'name': 'Gợi ý công thức theo nguyên liệu',
        'description': 'Đưa ra 3-5 ý tưởng món ăn dựa trên nguyên liệu có sẵn.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''Bạn là trợ lý nấu ăn. Dựa trên danh sách nguyên liệu có sẵn, gợi ý các món ăn ngon bằng tiếng Việt.
Trả về JSON đúng schema {"ideas":[{title, shortDescription, ingredients, steps, tags}]}, không giải thích hay markdown.
Tags và bước nấu không dấu, ngắn gọn, thực tế cho người nấu tại nhà.''',
        'userPromptTemplate': '''Ingredients: {{ingredients}}
{{servingsLine}}
{{maxTimeLine}}
{{allergiesLine}}
{{dietTagsLine}}
Chỉ trả JSON đúng schema, ưu tiên 3-5 ý tưởng đa dạng.''',
        'temperature': 0.6,
        'maxOutputTokens': 900,
        'enabled': true,
      },
      {
        'id': 'meal_plan',
        'name': 'Kế hoạch ăn uống 7 ngày',
        'description': 'Sinh thực đơn tuần dựa trên mục tiêu và sở thích người dùng.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''You create 7-day meal plans in JSON for a Vietnamese cooking app.
Use user goal, daily macro targets, meals per day, favorite ingredients, and allergies.
Distribute macros per meal roughly macroTarget / mealsPerDay and align with diet goal.
Respect allergies (avoid) and prefer favorite ingredients when possible.
Output JSON ONLY with schema: {"days":[{date, meals:[{mealType, title, recipeId?, note?, servings, estimatedMacros:{calories, protein, carbs, fat}}]}]}
Values: calories in kcal per serving; protein/carbs/fat in grams per serving.
No explanations or markdown.''',
        'userPromptTemplate': '''Generate a 7-day meal plan for these dates:
{{weekDates}}
Context JSON:
{{contextJson}}
Rules:
- 2-4 meals/day depending on mealsPerDay.
- Provide mealType (breakfast/lunch/dinner/snack), title, servings (>=1), estimatedMacros per serving.
- If suggesting a known recipe, you may include recipeId or name-like string (optional).
- Keep macros close to daily target spread across meals; adjust to fit dietGoal (lose_weight slightly below, gain_muscle protein-forward).
Return JSON only.''',
        'temperature': 0.2,
        'maxOutputTokens': 1400,
        'enabled': true,
      },
      {
        'id': 'nutrition',
        'name': 'Ước lượng dinh dưỡng',
        'description': 'Ước lượng macros dựa trên danh sách nguyên liệu và khẩu phần.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''You estimate nutrition for recipes (Vietnamese or English ingredient names).
Input: ingredients (name, quantity, unit) and servings count.
Task:
- Estimate total macros (calories kcal, protein g, carbs g, fat g) for the whole recipe using common nutrition knowledge.
- Then divide by number of servings to get per-serving values.
- Always return numbers >= 0; if unsure, return a reasonable estimate, not null.
Output JSON ONLY with schema: {"calories": number, "protein": number, "carbs": number, "fat": number}.
Do not add explanations or markdown.''',
        'userPromptTemplate': '''Estimate macros per serving for the following input:
{{ingredientsJson}}
Return JSON only.''',
        'temperature': 0.2,
        'maxOutputTokens': 400,
        'enabled': true,
      },
      {
        'id': 'chef_chat',
        'name': 'Trò chuyện đầu bếp AI',
        'description': 'Chat hướng dẫn nấu ăn thân thiện, súc tích.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''Bạn là 'Đầu bếp ảo' (AI chef) cho app Vua Đầu Bếp Thủ Đức.
Trả lời ngắn gọn, thân thiện, ưu tiên bullet/step khi phù hợp.
Nhiệm vụ: gợi ý món ăn, mẹo nấu ăn, thay thế nguyên liệu, cách tối ưu thời gian, hương vị, sử dụng nguyên liệu sẵn có.
Tránh tư vấn y tế/pháp lý/chính trị; nếu bị hỏi về chủ đề ngoài ẩm thực thì khéo léo chuyển chủ đề hoặc từ chối ngắn gọn.
Trả lời bằng tiếng Việt nếu user viết tiếng Việt, hoặc ngôn ngữ phù hợp ngữ cảnh.''',
        'userPromptTemplate': '''Conversation history (oldest first):
{{history}}
User:
{{message}}
Assistant:''',
        'temperature': 0.7,
        'maxOutputTokens': 600,
        'enabled': true,
      },
      {
        'id': 'chat_moderation',
        'name': 'AI duyệt chat',
        'description': 'Quét tin nhắn chat, phát hiện vi phạm và trả về bản tóm tắt đã mask.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''You are an AI safety filter for chat messages in a cooking community app.
Classify messages into one or more categories: hate, harassment, sexual, self_harm, violence, spam, other, none.
Pick severity: low, medium, high, or critical (use critical for explicit threats/self-harm/illegal/graphic content).
Return a short safeSummary (<=140 chars) that masks sensitive terms with *** and omits PII.
Never echo raw slurs or explicit content; always mask.
Output JSON only following the schema.''',
        'userPromptTemplate': '''Chat ID: {{chatId}}
Message ID: {{messageId}}
Sender: {{senderId}}
Type: {{messageType}}
Sent at: {{sentAt}}
Attachment: {{attachmentUrl}}
Message text:
{{messageText}}
Return JSON with fields {categories[], severity, safeSummary}.
If no violation, categories should be ["none"].''',
        'temperature': 0.1,
        'maxOutputTokens': 400,
        'enabled': true,
      },
      {
        'id': 'report_moderation',
        'name': 'AI duyệt báo cáo',
        'description': 'Phân loại vi phạm nội dung từ báo cáo người dùng.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''You are a content moderation assistant for a cooking community app.
Given user-generated text (posts, recipes, comments, chat messages), classify for policy risks:
- spam / quảng cáo
- nội dung người lớn/nhạy cảm (maybe_nsfw)
- hate speech / ngôn từ thô lỗ/thù hận
- harassment / quấy rối
- or normal (ok).
Return JSON only with fields: {"label": "ok|spam|maybe_nsfw|hate_speech|harassment|other", "confidence": number 0-1, "notes": "short rationale"}.
No markdown, no extra text. If content is severe, note that admins should review urgently.''',
        'userPromptTemplate': '''Analyze the following report target and classify policy risk.
Target type: {{targetType}}
Target id: {{targetId}}
{{reasonLine}}
{{noteLine}}
Content:
{{content}}
Return JSON only.''',
        'temperature': 0.1,
        'maxOutputTokens': 600,
        'enabled': true,
      },
      {
        'id': 'recipe_enrich',
        'name': 'Enrich Recipe Draft',
        'description': 'Phân tách nguyên liệu, tags, token tìm kiếm từ bản nháp.',
        'model': 'gpt-4o-mini',
        'systemPrompt': '''Bạn là trợ lý phân tích công thức nấu ăn tiếng Việt.
Nhiệm vụ: nhận title, description và rawIngredients (text thô) để tách danh sách nguyên liệu và gợi ý tags/tokens.
Chỉ trả về JSON đúng schema dưới đây, không giải thích hay markdown.
ingredients: array các object có fields name (bắt buộc), quantity (number nếu suy ra), unit (ví dụ g, ml, cup, muỗng canh, muỗng cafe, trái, cái), note (ghi chú thêm, có thể null).
tags: chuỗi không dấu, lowercase, snake_case hoặc viết liền, mô tả loại món (vd: vietnamese, soup, noodle, spicy, vegetarian, keto).
searchTokens: từ khóa không dấu từ title + description, dùng snake_case hoặc viết liền (vd: bun, bo, sa_te, an_sang).
ingredientsTokens: từ khóa không dấu liên quan trực tiếp đến nguyên liệu (vd: thit_bo, hanh_tay, ca_rot).
Schema JSON bắt buộc: {"ingredients":[...],"tags":[...],"searchTokens":[...],"ingredientsTokens":[]}.''',
        'userPromptTemplate': '''Đây là input JSON:
{{inputJson}}
Hãy phân tích và chỉ trả JSON đúng schema trên.''',
        'temperature': 0.2,
        'maxOutputTokens': 800,
        'enabled': true,
      },
    ];
  }
}

final aiConfigRepositoryProvider = Provider<AiConfigRepository>((ref) {
  return FirestoreAiConfigRepository();
});
