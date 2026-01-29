# AI Prompts Management System

## Tổng quan

Hệ thống quản lý tập trung các AI prompts cho tất cả tính năng AI trong ứng dụng. Admin có thể chỉnh sửa prompts, model settings, và bật/tắt từng tính năng AI từ giao diện Admin Settings.

## Các tính năng AI được quản lý

1. **search** - Gợi ý tìm kiếm công thức nấu ăn
2. **recipe_suggest** - AI gợi ý công thức theo nguyên liệu có sẵn
3. **meal_plan** - AI tạo kế hoạch ăn uống tuần (7 ngày)
4. **nutrition** - Ước lượng dinh dưỡng (macros)
5. **chef_chat** - Trò chuyện với đầu bếp AI
6. **chat_moderation** - AI kiểm duyệt chat
7. **report_moderation** - AI kiểm duyệt báo cáo
8. **recipe_enrich** - AI làm giàu công thức (phân tách nguyên liệu, tags)

## Cấu trúc dữ liệu

### Firestore Collection: `aiConfigs`
```
aiConfigs/{featureId}
  - id: string
  - name: string (optional)
  - description: string (optional)
  - model: string (e.g., "gpt-4.1-mini")
  - systemPrompt: string
  - userPromptTemplate: string
  - temperature: number (0.0 - 1.0)
  - maxOutputTokens: number
  - enabled: boolean
  - extraNotes: string (optional)
```

## Cách sử dụng

### Từ Admin Dashboard

1. Đăng nhập với tài khoản Admin
2. Vào menu **AI Prompts** 
3. Chọn tính năng AI cần chỉnh sửa
4. Click **Chỉnh sửa** để mở dialog
5. Sửa đổi:
   - **System Prompt**: Hướng dẫn cho AI (vai trò, nhiệm vụ)
   - **User Prompt Template**: Template cho input người dùng (dùng `{{variable}}` cho placeholders)
   - **Model**: Tên model OpenAI (e.g., `gpt-4.1-mini`, `gpt-4-turbo`)
   - **Temperature**: Độ sáng tạo (0 = deterministic, 1 = creative)
   - **Max Output Tokens**: Giới hạn độ dài output
6. Click **Lưu**

### Bật/Tắt tính năng
- Toggle switch bên cạnh tên tính năng
- Khi tắt, Firebase Functions sẽ trả về lỗi `failed-precondition`

### Reset về mặc định
- Click **Reset về mặc định** để xóa config
- Functions sẽ tự động dùng config mặc định được hard-code trong `functions/src/ai_config.ts`

## Flow hoạt động

```
Flutter App → Firebase Functions → ai_config.ts
                ↓
          Firestore aiConfigs (nếu có)
                ↓
          Fallback to defaults (nếu không có)
                ↓
          Gọi OpenAI API với prompt đã config
```

### 1. **Flutter App** gọi AI service
```dart
// Example: Search feature
final aiService = AiService();
final result = await aiService.suggestRecipesByIngredients(
  ingredients: ['thịt bò', 'hành tây'],
  userPrefs: {...},
);
```

### 2. **Firebase Function** lấy config
```typescript
// functions/src/ai_suggest_recipes.ts
const config = await getAiConfigOrThrow('recipe_suggest');
if (!config.enabled) {
  throw new HttpsError('failed-precondition', 'AI disabled');
}

const systemPrompt = config.systemPrompt;
const userPrompt = renderPromptTemplate(config.userPromptTemplate, {
  ingredients: ingredients.join(", "),
  servingsLine: ...,
});
```

### 3. **OpenAI API** được gọi
```typescript
const ideas = await callOpenAIJson({
  system: systemPrompt,
  user: userPrompt,
  jsonSchema: suggestionsSchema,
  temperature: config.temperature,
  model: config.model,
  maxOutputTokens: config.maxOutputTokens,
});
```

## Template Variables

Mỗi tính năng AI có các biến template riêng:

### `recipe_suggest`
- `{{ingredients}}` - Danh sách nguyên liệu
- `{{servingsLine}}` - Số khẩu phần
- `{{maxTimeLine}}` - Thời gian nấu tối đa
- `{{allergiesLine}}` - Dị ứng/tránh
- `{{dietTagsLine}}` - Chế độ ăn ưu tiên

### `meal_plan`
- `{{weekDates}}` - Danh sách ngày trong tuần
- `{{contextJson}}` - JSON chứa mục tiêu, macro, sở thích

### `nutrition`
- `{{ingredientsJson}}` - JSON danh sách nguyên liệu và khẩu phần

### `chef_chat`
- `{{history}}` - Lịch sử chat
- `{{message}}` - Tin nhắn người dùng

## Ví dụ Prompt Templates

### System Prompt (recipe_suggest)
```
Bạn là trợ lý nấu ăn. Dựa trên danh sách nguyên liệu có sẵn, gợi ý các món ăn ngon bằng tiếng Việt.
Trả về JSON đúng schema {"ideas":[{title, shortDescription, ingredients, steps, tags}]}, không giải thích hay markdown.
Tags và bước nấu không dấu, ngắn gọn, thực tế cho người nấu tại nhà.
```

### User Prompt Template (recipe_suggest)
```
Ingredients: {{ingredients}}
{{servingsLine}}
{{maxTimeLine}}
{{allergiesLine}}
{{dietTagsLine}}
Chỉ trả JSON đúng schema, ưu tiên 3-5 ý tưởng đa dạng.
```

## Best Practices

### 1. **Testing prompts**
- Test trong OpenAI Playground trước
- Dùng temperature thấp (0.1-0.3) cho structured output
- Dùng temperature cao (0.6-0.9) cho creative content

### 2. **Prompt engineering tips**
- Rõ ràng về format output (JSON schema)
- Đưa ví dụ cụ thể trong system prompt
- Dùng "không dấu" cho Vietnamese tokenization tốt hơn
- Giới hạn độ dài output bằng `maxOutputTokens`

### 3. **Model selection**
- `gpt-4.1-mini`: Nhanh, rẻ, tốt cho simple tasks
- `gpt-4-turbo`: Chậm hơn nhưng thông minh hơn
- Dùng mini cho search/nutrition/moderation
- Dùng turbo cho meal planning/chef chat

### 4. **Safety**
- Firestore Security Rules hạn chế chỉ Admin mới edit được `aiConfigs`
- Functions validate input và sanitize output
- Không echo raw user input trong prompts (injection risk)

## Firestore Security Rules

```javascript
// firestore.rules
match /aiConfigs/{configId} {
  allow read: if request.auth != null && isAdmin();
  allow write: if request.auth != null && isAdmin();
}
```

## Files liên quan

### Flutter
- `lib/features/admin/data/ai_config_repository.dart` - Repository
- `lib/features/admin/application/ai_config_controller.dart` - Controller
- `lib/features/admin/presentation/admin_ai_prompts_page.dart` - UI
- `lib/core/services/ai_service.dart` - AI service layer

### Functions
- `functions/src/ai_config.ts` - Config management & defaults
- `functions/src/ai_suggest_recipes.ts` - Recipe suggestions
- `functions/src/ai_generate_meal_plan.ts` - Meal planning
- `functions/src/ai_nutrition.ts` - Nutrition estimation
- `functions/src/ai_chef_chat.ts` - Chef chatbot
- `functions/src/ai_chat_moderation.ts` - Chat moderation
- `functions/src/ai_report_moderation.ts` - Report moderation

## Troubleshooting

### Issue: "AI config is missing"
- **Solution**: Config chưa tồn tại trong Firestore, functions sẽ dùng defaults. Nếu muốn customize, tạo document với featureId trong Admin UI.

### Issue: "AI is temporarily disabled"
- **Solution**: Check toggle switch trong Admin AI Prompts, bật lại feature.

### Issue: Prompts không có hiệu lực
- **Solution**: Functions cache configs 1 phút. Đợi 60s hoặc restart functions.

### Issue: Output không đúng format
- **Solution**: 
  1. Check JSON schema trong functions
  2. Test prompt trong OpenAI Playground
  3. Thêm ví dụ cụ thể vào system prompt

## Migration từ hardcoded prompts

Các prompts cũ đã được di chuyển từ:
- `functions/src/ai_suggest_recipes.ts` (hardcoded) → `aiConfigs/recipe_suggest`
- `functions/src/ai_generate_meal_plan.ts` (hardcoded) → `aiConfigs/meal_plan`
- Các functions khác tương tự

Defaults vẫn được giữ trong `ai_config.ts` để fallback.
