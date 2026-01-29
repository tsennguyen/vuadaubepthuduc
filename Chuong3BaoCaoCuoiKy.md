# CHƯƠNG 3: CÀI ĐẶT VÀ XÂY DỰNG ỨNG DỤNG

## Mục lục chương 3
- 3.1 Kiến trúc tổng thể
- 3.2 Cấu trúc dự án và công nghệ sử dụng
- 3.3 Kết nối Firebase
- 3.4 Các module chức năng chính (từ code)
- 3.5 Bảo mật & phân quyền (Firestore/Storage)
- 3.6 Thiết kế API (Cloud Functions)
- 3.7 Giao diện người dùng
- Gợi ý flow chụp màn hình

---

## 3.1 Kiến trúc tổng thể
- Client Flutter ↔ Firebase Auth (ID token + custom claims) ↔ Firestore (stream realtime) ↔ Storage (ảnh/video) ↔ Cloud Functions (logic/AI/search/aggregate/leaderboard/chat) ↔ FCM (thông báo) ↔ Hosting (web).
- Luồng chính:
  - MXH: Auth → Feed stream → Tạo Post/Recipe (upload Storage, ghi Firestore) → triggers aggregate (likes/comments/shares/ratings, user.stats) → leaderboard cron.
  - Search: generate searchTokens/ingredientsTokens qua Functions; query array-contains-any; nếu rỗng → suggestSearch (trending + GPT).
  - Chat: callable createDM/createGroup (DM yêu cầu bạn bè), stream messages, onMessage cập nhật lastMessageAt + FCM.
  - Planner/Shopping: mealPlans per user/day, shoppingLists merge items, macro dashboard dựa trên recipes.macros/estimatedMacros.
  - AI: callable aiSuggestRecipesByIngredients, aiEnrichRecipeDraft, aiEstimateNutrition, aiGenerateMealPlan, aiChefChat; triggers ai_moderation, ai_chat_moderation, ai_analyze_reports.
- Ảnh gợi ý: sơ đồ khối Flutter ↔ Firebase (có Cloud Functions/Firestore/Storage/FCM/Hosting) + luồng MXH/Search/Chat/Planner. Có thể vẽ hoặc chụp từ slide; nếu cần H1 theo danh mục hình.

## 3.2 Cấu trúc dự án và công nghệ sử dụng
- Thư mục chính: `lib/features/*` (auth, home, feed, post, recipe, recipes, search, chat, planner, shopping, nutrition, notifications, ai, admin, report, leaderboard, profile, social, intro, **reels**); `lib/app` (router, scaffold, theme, l10n); `lib/core` (services, utils, widgets); `functions/src` (TS Cloud Functions); `docs`; cấu hình Firebase (`firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`).
- Router (GoRouter) khai báo trong `lib/app/app_router.dart`: `/splash`, `/signin|/signup|/forgot-password|/onboarding`, `/feed`, `/recipes`, `/search`, `/planner`, `/shopping`, `/chat(/:cid)`, `/post/:id`, `/recipe/:id`, `/create-post`, `/create-recipe`, `/ai-assistant`, `/macro-dashboard`, `/notifications`, `/settings/notifications`, `/profile(/:uid)`, `/friends`, **`/reels`**, **`/create-reel`**, admin: `/admin/overview|users|content|reports|chats|ai-prompts|settings|audit-logs`.
- State: Riverpod; kiến trúc controller/repository; transition tùy chỉnh (fade + slide + scale).
- Dependencies (pubspec.yaml): go_router 14.8.1, flutter_riverpod 2.5.1, firebase_core 3.5.0, firebase_auth 5.3.1, cloud_firestore 5.4.0, firebase_storage 12.2.0, cloud_functions 5.0.0, cached_network_image, image_picker, emoji_picker_flutter, **video_player 2.9.1** (reels), audioplayers, share_plus, path_provider, url_launcher, fl_chart, google_sign_in, **flutter_localizations + intl 0.20.2** (đa ngôn ngữ), **timeago 3.7.1**, **shared_preferences 2.3.3**.
- Build/CI: Flutter SDK ≥3.5, version 1.0.0+1; GitHub Actions `flutter-analyze.yml` (format+analyze), `deploy-web.yml` (build web, hosting preview PR, deploy live khi merge main).
- Ảnh gợi ý: chụp cây thư mục `lib/features` (nêu rõ reels, ai, admin) và màn `pubspec.yaml` phần dependencies nếu cần minh họa công nghệ.

## 3.3 Kết nối Firebase
- Cấu hình: `firebase_options.dart` (flutterfire configure); Android dùng `google-services.json`; Web dùng dart-define.
- Emulator: Firestore 8080, Functions 5001, Hosting 5000, Auth 9099; cấu hình qua `lib/firebase_emulator.dart`.
- Secrets: `.env` chứa GPT_API_KEY; Functions đọc GPT_API_KEY từ Firebase Secrets (`firebase functions:secrets:set GPT_API_KEY`).
- Chạy cục bộ: `flutter pub get`; `cd functions && npm install && npm run build`; `firebase emulators:start`; `cd functions && npm run seed` (dữ liệu mẫu); `flutter run -d chrome --dart-define-from-file=.env`.
- Deploy: `firebase deploy --only firestore:rules,firestore:indexes,functions,hosting,storage`.
- Ảnh gợi ý: Firebase Emulator UI hoặc màn hình cấu hình `.env`/`firebase_emulator.dart` nếu cần minh họa kết nối.

## 3.4 Các module chức năng chính (từ code)
- Auth & Role: Firebase Auth Email/Google; onUserCreate gán role=client; callable setRole cho admin; UI đổi theo custom claims.  
  - Chụp: màn Đăng nhập/Đăng ký (`lib/features/auth/presentation/login_screen.dart`, `register_screen.dart`), hồ sơ hiển thị role.
- Feed/Post/Recipe: CRUD, upload ảnh, tags/tokens; reaction 4 loại, comment (hỗ trợ ảnh + emoji), share, rating (recipe); counters aggregate qua Functions.  
  - Chụp: Feed (`lib/features/feed/presentation/feed_page.dart`), PostDetail (`lib/features/post/presentation/post_detail_page.dart`), RecipeDetail (`lib/features/recipe/presentation/recipe_detail_page.dart`), CreatePost/CreateRecipe.
- **Reels (mới)**: Video ngắn kiểu TikTok/Instagram: upload video+thumbnail+tags, feed thời gian + trending + search, like/comment/share/save, đếm view, tab Reels trong profile, admin duyệt `hidden`.  
  - Files: `lib/features/reels/presentation/reels_page.dart`, `create_reel_page.dart`, `data/reel_repository.dart`, `data/reel_interaction_repository.dart`, `widgets/reel_video_player.dart`.  
  - Chụp: Reels feed, màn tạo reel, reel detail kèm lượt thích/bình luận.
- **Đa ngôn ngữ Vi/En (mới)**: `lib/app/l10n.dart` (345+ strings), `language_controller.dart`, provider `localeProvider` đổi ngôn ngữ realtime.  
  - Chụp: màn Settings đổi ngôn ngữ (`lib/app/app_scaffold.dart` + `settings_notifications_page.dart`) hoặc hai màn cùng nội dung khác locale.
- **Gửi ảnh + emoji trong bình luận (mới)**: comment có `imageUrl`, upload Storage; emoji picker tích hợp; thread replies.  
  - Files: `lib/features/post/presentation/widgets/comments_list_widget.dart`, `data/comment_model.dart`.  
  - Chụp: Post/Recipe detail với comment có ảnh + emoji.
- **AI “nguồn gốc món” (mới)**: `FlippableDishCard` lật 3D hiển thị fun fact/nguồn gốc món theo Vi/En, gọi `aiChefService.chat()`.  
  - Files: `lib/features/recipe/presentation/widgets/flippable_dish_card.dart`, `lib/core/services/ai_chef_service.dart`.  
  - Chụp: RecipeDetail với thẻ lật AI.
- **Upload avatar từ máy (mới)**: `ProfileStorageService.uploadProfileAvatar()` upload ảnh camera/gallery, lưu `user_avatars/{uid}`.  
  - Files: `lib/features/profile/data/profile_storage_service.dart`.  
  - Chụp: màn Edit Profile chọn ảnh + avatar mới.
- Search & Suggest: search unified (title/tags/searchTokens/ingredientsTokens); ranking; fallback suggestSearch (trending + GPT).  
  - Files: `functions/src/search_tokens.ts`, `functions/src/suggest.ts`, `lib/features/search/presentation/search_page.dart`.  
  - Chụp: Search kết quả có/không có → hiển thị gợi ý.
- Chat realtime: DM (yêu cầu bạn bè), Group owner + memberIds; stream messages; FCM tùy chọn; text ≤4000; lastMessageAt cập nhật trigger.  
  - Files: `functions/src/chat.ts`, `functions/src/ai_chat_moderation.ts`, `lib/features/chat/presentation/chat_list_page.dart`, `chat_room_page.dart`.  
  - Chụp: danh sách chat + một phòng chat.
- Leaderboard & Badges: điểm hoạt động (Post +2, Recipe +4, Comment +1, Reaction +0.5, Share +1, Rating +1); cron weekly/monthly; badge top1/top3/top10.  
  - Files: `functions/src/leaderboard.ts`, UI `lib/features/leaderboard/presentation`.  
  - Chụp: bảng xếp hạng tuần/tháng.
- Planner & Shopping & Nutrition: add recipe vào mealPlans/{uid}/days; generate shoppingLists merge items; macro dashboard tính calories/protein/carb/fat; AI estimateNutrition & meal plan 7 ngày.  
  - Files: `lib/features/planner/presentation/planner_page.dart`, `shopping/presentation/shopping_list_page.dart`, `nutrition/presentation/macro_dashboard_page.dart`, `functions/src/ai_nutrition.ts`, `ai_generate_meal_plan.ts`.  
  - Chụp: lịch bữa ăn, danh sách mua sắm, macro dashboard.
- AI & Prompts: aiConfigs quản lý model/temperature/systemPrompt/userPromptTemplate/enable; callable AI (suggest, enrich, nutrition, meal plan, chef chat, aiParseSearchQuery, aiAnalyzeReports); triggers moderation.  
  - Files: `functions/src/ai_*.ts`, `functions/src/ai_config.ts`.  
  - Chụp: màn AI Assistant (`lib/features/ai/presentation/ai_assistant_page.dart`) hoặc màn quản trị AI prompts (`lib/features/admin/presentation/admin_ai_prompts_page.dart`).
- Admin: Users (ban/unban/đổi role), Content (duyệt post/recipe/**reel**), Reports, Chat moderation, AI Prompts, Settings, Audit Logs.  
  - Files: `lib/features/admin/presentation/*` (admin_home_page, admin_users_page, admin_content_page, admin_reports_page, admin_chat_moderation_page, admin_ai_prompts_page, admin_settings_page, admin_audit_logs_page).  
  - Chụp: dashboard admin + một màn duyệt nội dung/reels + màn audit logs.
- Notifications & Friends: `notifications/{uid}/items`, optional FCM; Friends page trong social.  
  - Chụp: màn Notifications (`lib/features/notifications/presentation/notifications_page.dart`) và Friends (`lib/features/social/presentation/friends_page.dart`).
- **UI/UX cải tiến**: GradientAvatar, FlippableCard, SortChips, threaded comments, profile tabs (Posts/Recipes/Reels/Saved), bottom nav, language switcher; animations (flip 3D, fade/slide/scale, hero).  
  - Files: `lib/shared/widgets/modern_ui_components.dart`, `lib/core/widgets/modern_loading.dart`, `lib/features/profile/presentation/profile_page.dart`.  
  - Chụp: profile tabs, hiệu ứng flip card, bottom nav.

## 3.5 Bảo mật & phân quyền (tóm tắt từ rules)
- Roles: admin toàn quyền; moderator duyệt nội dung/báo cáo/chat; user bị giới hạn theo owner.
- users: đăng nhập mới được tạo; chỉ chủ sở hữu được sửa hồ sơ/bookmarks/plannerSettings/mealPlans/shoppingLists; admin/mod có thể chỉnh khi cần.
- posts/recipes/reels: đọc công khai; create cần signed-in + authorId==uid; update/delete chỉ owner hoặc admin/mod; `hidden`/`isHiddenPendingReview` phục vụ moderation.
- reactions/comments/ratings/shares: mỗi user 1 doc (id=uid); validate type/stars; createdAt == request.time.
- chats/messages: chỉ member đọc/ghi; createDM yêu cầu bạn bè; text ≤4000; onMessage cập nhật lastMessageAt.
- leaderboards: chỉ Functions ghi; public read.
- reports: user tạo/đọc của mình; admin/mod chỉnh status; aiVerdict do Functions; auditLogs append-only chỉ admin đọc.
- aiConfigs/adminSettings/chatViolations: chỉ admin; chatViolations ghi bởi AI moderation.
- Triển khai rules/indexes: `firebase deploy --only firestore:rules,firestore:indexes`; xem tóm tắt trong `FIRESTORE_RULES_SUMMARY.md`, file chính `firestore.rules`, `storage.rules`.
- Ảnh gợi ý: chụp trích đoạn rules (phân quyền post/comment) hoặc giao diện kiểm thử Emulator Security Rules.

## 3.6 Thiết kế API (Cloud Functions)
- Triggers:
  - `aggregates.ts`: onReactionChange/onCommentChange/onRatingChange/onShareAdd; onAnyCreate cập nhật user.stats; onMessage cập nhật lastMessageAt.
  - `search_tokens.ts`: onWritePost/onWriteRecipe tạo searchTokens/ingredientsTokens.
  - `leaderboard.ts`: cron recomputeLeaderboard (week/month), gắn badges.
  - `report_moderation.ts`: onReportCreate (reportsCount, isHiddenPendingReview, auditLogs).
  - `social_notifs.ts`, `planner_notifs.ts`: thông báo (nếu bật).
- Callable:
  - `suggestSearch({q,tokens,type})`; `createDM({toUid})`; `createGroup({name,memberIds})`; `setRole`; `aiParseSearchQuery`.
  - AI: `aiSuggestRecipesByIngredients`, `aiEnrichRecipeDraft`, `aiEstimateNutrition`, `aiGenerateMealPlan`, `aiChefChat`, `aiAnalyzeReports`; `ai_chat_moderation` (trigger message), `ai_moderation` (trigger report).
- Seed & tiện ích: `seed.ts` (10 posts + 10 recipes + 2 chats + messages), `setupEnv.ts` (đọc .env local).
- Ảnh gợi ý: Postman call `suggestSearch` hoặc bảng Functions list trong Firebase Emulator.

## 3.7 Giao diện người dùng
- Các màn chính (router ở `lib/app/app_router.dart`):
  - Onboarding/Splash/SignIn/SignUp/ForgotPassword.
  - Tabs: Feed, Recipes, **Reels**, Search, Chat, Planner, Shopping, Profile/Me, Notifications, Macro Dashboard.
  - Detail: PostDetail, RecipeDetail (rating/ingredients/steps/photos), Reel detail.
  - CreatePost/CreateRecipe/CreateReel (upload ảnh/video, tags; AI enrich/estimate nutrition; load từ AI suggestion).
  - SearchResult + AI gợi ý khi không có kết quả.
  - ChatRoom (DM/Group), Friends page, AI Assistant/Chef AI chatbot.
  - Leaderboard tuần/tháng.
  - Admin: Overview, Users, Content, Reports, Chat moderation, AI Prompts, Settings, Audit Logs.
  - Chuyển trang: fade + slide + scale (CustomTransitionPage).
- Ảnh gợi ý: bộ ảnh giao diện gồm Onboarding, Feed, RecipeDetail (có rating + FlippableDishCard), Reels feed, Search (kết quả + gợi ý AI), Chat list/room, Planner, Shopping list, Macro dashboard, AI Assistant, Leaderboard, Admin dashboard.

## Gợi ý flow chụp màn hình (tham chiếu mục 3)
1) H1: Sơ đồ kiến trúc Flutter ↔ Firebase (3.1).  
2) H2: Luồng MXH (Login → Feed → Create Post/Recipe → React/Comment) từ các màn feed/post/recipe (3.4).  
3) H3: Planner & Shopping List (Planner page + Shopping list) (3.4).  
4) H4: Giao diện Feed & Recipe Detail (có rating, AI card) (3.4, 3.7).  
5) H5: Giao diện Chat (DM/Group) + Leaderboard (3.4, 3.7).  
6) H6: Giao diện Admin (Reports, AI Prompts, Audit Logs, duyệt Reels) (3.4, 3.7).  
7) H7: Màn AI Assistant / Chef AI chatbot (3.4, 3.7).  
8) H8: Lược đồ Firestore chính (users, posts, recipes, **reels**, chats, leaderboards, aiConfigs…) hoặc trích rules (3.5).  
9) Bổ sung (mới): Reels feed + CreateReel; đa ngôn ngữ (một màn ở VI và EN); comment có ảnh; upload avatar; macro dashboard.  
   - Vị trí file để mở/chạy: `lib/features/reels/presentation/reels_page.dart`, `create_reel_page.dart`, `lib/app/l10n.dart`, `lib/features/post/presentation/widgets/comments_list_widget.dart`, `lib/features/profile/data/profile_storage_service.dart`, `lib/features/nutrition/presentation/macro_dashboard_page.dart`.  
10) Nếu cần minh họa API: Postman call `functions/src/suggest.ts` (suggestSearch) hoặc Emulator UI tab Functions (3.6).

*Lưu ý*: Tất cả nội dung trên viết thuần tiếng Việt, dữ liệu mã nguồn đối chiếu tại các đường dẫn đã nêu trong repo `lib/...` và `functions/src/...`. Khi đưa sang Word, chèn hình vào đúng mục 3.x tương ứng với “Ảnh gợi ý”/H1–H8 để giữ flow báo cáo.
