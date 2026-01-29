# Manual Test Checklist (Dev)

## Auth
- [ ] Đăng ký + đăng nhập Email/Password (tài khoản mới & cũ).
- [ ] Google/Facebook sign-in (Android + Web) hoạt động, callback đúng.
- [ ] Sau login điều hướng đúng `/feed`.

## Luồng 1 – MXH
- [ ] Post/Recipe: tạo/sửa/xóa đúng quyền (authorId bắt buộc), hiển thị chi tiết.
- [ ] Tạo recipe → xuất hiện ngay trên feed (stream Firestore).
- [ ] Like/Unlike post/recipe → `likesCount` cập nhật (aggregate).
- [ ] Comment post/recipe → `commentsCount` cập nhật, thứ tự hiển thị đúng.
- [ ] Share post/recipe → `sharesCount` tăng, 1 share/user.
- [ ] Report post/recipe/message → tạo `reports/{id}`, `reportsCount` tăng, `isHiddenPendingReview` bật khi qua ngưỡng.
- [ ] Admin mở `/admin/reports` → xem & đổi status pending/resolved/ignored; auditLogs có entry reportCreated.

## Luồng 2 – Planner & Shopping & Macro
- [ ] Từ RecipeDetail → Add to Meal Plan → dữ liệu đúng path `mealPlans/{uid}/days/{yyyy-MM-dd}/meals/{mealId}`.
- [ ] Planner week view hiển thị đúng meals theo ngày/bữa; update/delete phản ánh ngay.
- [ ] Generate Shopping List từ mealPlans tuần → tạo/merge items đúng schema (name, quantity, unit, category, sourceRecipeIds).
- [ ] ShoppingListPage tick/untick → trạng thái lưu lại sau reload app.
- [ ] Macro dashboard tính đúng calories/protein/carb/fat theo meals (recipe.macros hoặc estimatedMacros x servings).

## AI Features
- [ ] AI gợi ý recipe theo nguyên liệu: khi search không ra kết quả → gọi `aiSuggestRecipesByIngredients` → hiển thị card gợi ý.
- [ ] AI enrich recipe: tại CreateRecipePage nút “AI gợi ý” → fill ingredients/tags/tokens hợp lệ.
- [ ] AI nutrition/meal plan: ít nhất 1 case chạy end-to-end `aiEstimateNutrition` hoặc `aiGenerateMealPlan` → dữ liệu ghi Firestore đúng.

## Search / Chat / Leaderboard
- [ ] Search theo ingredientsTokens/title/tags trả về đúng recipes/posts; fallback nếu thiếu index vẫn chạy.
- [ ] Chat DM: tạo DM 2 user → gửi/nhận được, lastMessageAt cập nhật, chỉ member đọc được messages.
- [ ] Group chat: tạo group nhiều thành viên → quyền xem/gửi đúng; typing indicator hoạt động.
- [ ] Leaderboard: xem week/month, điểm thay đổi sau hoạt động post/comment/react (Functions recompute).

## Security & Rules
- [ ] User A không sửa được mealPlans/shoppingLists/bookmarks của User B (Firestore rules).
- [ ] User thường không truy cập được `auditLogs/*`; admin xem được reports & leaderboards.
- [ ] Posts/Recipes chỉ author hoặc admin/mod được update/delete; subcollection reactions/comments chỉ owner chỉnh sửa.
