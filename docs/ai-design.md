# Thiết kế AI (Gemini)

## 1. Tổng quan

- Dùng Gemini 1.5 Flash qua Cloud Functions (region `asia-southeast1`) để giảm logic trên client, tránh lộ API key.
- AI đặt giữa client và Firestore: Flutter gọi callable → Functions gọi Gemini → parse JSON → ghi Firestore (nếu cần) hoặc trả kết quả cho UI.
- Mục tiêu: gợi ý công thức, enrich dữ liệu, ước tính dinh dưỡng, lập kế hoạch bữa ăn, hỗ trợ moderation và chat tư vấn nấu ăn.

## 2. Danh sách AI features

- AI1 – Gợi ý recipe theo nguyên liệu: `aiSuggestRecipesByIngredients` (callable).
- AI3 – Enrich recipe draft (ingredients/tags/tokens): `aiEnrichRecipeDraft` (callable).
- AI4 – Ước tính nutrition per serving: `aiEstimateNutrition` (callable).
- AI5 – Sinh meal plan 7 ngày: `aiGenerateMealPlan` (callable, ghi `mealPlans/{uid}`).
- AI6 – Moderation helper: `onReportCreateAiVerdict` (trigger trên `reports/{id}`).
- AI7 – Chat “Đầu bếp ảo”: `aiChefChat` (callable, lưu lịch sử `aiChats/{uid}/sessions/...`).
- Hỗ trợ search: `aiParseSearchQuery` (callable) chuẩn hóa query thành keywords/tags/filters.

## 3. Thiết kế Cloud Functions

| Function | Loại | Input JSON | Output / Tác dụng | Lưu Firestore? |
| --- | --- | --- | --- | --- |
| `aiSuggestRecipesByIngredients` | callable | `{ingredients: string[], userPrefs?: {servings?, maxTimeMinutes?, allergies?, dietTags?}}` | `{ideas: [{title, shortDescription, ingredients[], steps[], tags[]}]}` | Không |
| `aiEnrichRecipeDraft` | callable | `{title, description?, rawIngredients}` | `{ingredients: [{name, quantity?, unit?, note?}], tags: [], searchTokens: [], ingredientsTokens: []}` | Không |
| `aiEstimateNutrition` | callable | `{ingredients: [{name, quantity?, unit?}], servings?: number}` | `{calories, protein, carbs, fat}` per serving | Không |
| `aiGenerateMealPlan` | callable (auth check) | `{userId, weekStart: "YYYY-MM-DD"}` + đọc `users/{uid}` (dietGoal, macroTarget, mealsPerDay, favoriteIngredients, allergies) | `{weekStart, daysCount, mealsCount}` | Có: clear & ghi `mealPlans/{uid}/days/{date}/meals/{mid}` với estimatedMacros |
| `aiParseSearchQuery` | callable | `{q: string}` | `{keywords: [], tags: [], filters: {maxTime?, minTime?, maxCalories?, minCalories?, servings?, mealType?, difficulty?}}` | Không |
| `aiChefChat` | callable (auth) | `{userId, sessionId?, message}` | `{reply, sessionId}` | Có: lưu `aiChats/{uid}/sessions/{sessionId}/messages` |
| `onReportCreateAiVerdict` | Firestore trigger | Report doc mới | Gọi Gemini, update `aiVerdict` `{label, confidence, notes}` vào report | Ghi lại chính doc report |

Flow chung: `Flutter` → `FirebaseFunctions.instance.httpsCallable(name)` → `Gemini` → parse JSON (try/catch + fallback) → trả về UI; riêng `aiGenerateMealPlan` và `aiChefChat` có bước ghi Firestore sau khi parse.

## 4. Prompt & ràng buộc

- Nguyên tắc chung trong prompt:
  - Bắt Gemini trả **JSON strict** đúng schema, không markdown.
  - Ràng buộc an toàn: tránh nội dung độc hại, tránh tư vấn y khoa, tôn trọng allergies.
  - Chuẩn hóa token: lower case, bỏ dấu, snake_case khi cần (tags, tokens).
  - Nhiệt độ thấp (0.1–0.2) cho tác vụ phân tích/parse, cao hơn (0.7) cho gợi ý sáng tạo.

- Ví dụ prompt (rút gọn, không lộ secret):

**aiEnrichRecipeDraft** (system):
```
Ban la tro ly phan tich cong thuc nau an tieng Viet.
Nhiem vu: nhan title, description va rawIngredients (text tho) de tach danh sach nguyen lieu va goi y tags/tokens.
Chi tra ve JSON: {"ingredients":[...],"tags":[...],"searchTokens":[...],"ingredientsTokens":[...]}
ingredients[].name bat buoc, quantity/unit/ note neu suy ra duoc.
Tags/tokens khong dau, snake_case.
Khong giai thich, khong markdown.
```

**aiGenerateMealPlan** (system + user):
```
You create 7-day meal plans in JSON for a Vietnamese cooking app.
Use user goal, daily macro targets, meals per day, favorite ingredients, and allergies.
Output JSON ONLY: {"days":[{date, meals:[{mealType, title, recipeId?, note?, servings, estimatedMacros:{calories, protein, carbs, fat}}]}]}
Avoid allergies, distribute macros per meal ~ macroTarget/mealsPerDay.
Dates: 2025-03-10, 2025-03-11, ...
Context JSON: {... user macroTarget, goal, favorites ...}
Return JSON only.
```

## 5. Tri?n khai callable

- To?n b? h?m AI d?ng https.onCall (v2) ?? tr?nh CORS; client g?i qua Firebase Functions SDK v?i `FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('<name>')`.

## 6. An toàn & giới hạn

- API key: dùng biến môi trường `GEMINI_API_KEY` trên Functions; không để trong repo/app.
- Quy định input: kiểm tra `userId` == auth uid (aiGenerateMealPlan, aiChefChat), giới hạn độ dài message (`MAX_MESSAGE_LENGTH=2000`).
- Tần suất: chưa có rate limiting ở Functions → cân nhắc thêm (App Check / per-user quota).
- Kích thước: Storage limit 5MB/rule, payload AI ngắn gọn; aiGenerateMealPlan chỉ nhận 7 ngày.
- Rủi ro nội dung: `ai_moderation` auto dán nhãn `reports` để hỗ trợ admin; không tự động ban/xóa.
- Logging: dùng `functions/logger` để log lỗi Gemini, cắt `bodyPreview` ngắn (<=200 chars) tránh lộ dữ liệu.

