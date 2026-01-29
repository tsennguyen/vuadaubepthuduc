# BÁO CÁO CUỐI KỲ DỰ ÁN “VUA ĐẦU BẾP THỦ ĐỨC”

## Thông tin nhóm
- Nhóm trưởng: Nguyễn Việt Thành – MSSV: 2280602952
- Thành viên: Phan Trúc Giang – MSSV: 2280600767
- Thành viên: Đỗ Thanh Hiệp – MSSV: 2280600926
- Thành viên: Ngô Minh Hùng – MSSV: 2280601103

---

## LỜI MỞ ĐẦU
“Vua Đầu Bếp Thủ Đức” là ứng dụng mạng xã hội ẩm thực đa nền tảng (Android/Web) trên Flutter, kết hợp Firebase (Auth, Firestore, Storage, Functions, FCM, Hosting) và các mô-đun AI (OpenAI) để hỗ trợ người dùng chia sẻ bài viết, công thức nấu ăn, trò chuyện realtime, lập kế hoạch bữa ăn, quản lý danh sách mua sắm, và nhận gợi ý thông minh. Ứng dụng đặt mục tiêu tạo cộng đồng ẩm thực tương tác cao, đồng thời cung cấp công cụ AI giúp tìm kiếm, gợi ý, kiểm duyệt và tối ưu trải nghiệm nấu ăn.

## LỜI CẢM ƠN
Nhóm xin cảm ơn thầy/cô đã hướng dẫn, góp ý; cảm ơn cộng đồng Flutter/Firebase và các thư viện mã nguồn mở; cảm ơn bạn bè đã hỗ trợ kiểm thử. Những đóng góp này giúp nhóm hoàn thiện sản phẩm đúng tiến độ và chất lượng.

## MỤC LỤC
- LỜI MỞ ĐẦU
- LỜI CẢM ƠN
- MỤC LỤC
- DANH MỤC HÌNH ẢNH
- CHƯƠNG 1: GIỚI THIỆU VỀ ĐỀ TÀI
- CHƯƠNG 2: CƠ SỞ THỰC TIỄN VÀ LÝ THUYẾT
- CHƯƠNG 3: CÀI ĐẶT VÀ XÂY DỰNG ỨNG DỤNG
- CHƯƠNG 4: KIỂM THỬ VÀ ĐÁNH GIÁ
- CHƯƠNG 5: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN
- TÀI LIỆU THAM KHẢO / ĐÍNH KÈM

## DANH MỤC HÌNH ẢNH (dự kiến chèn khi xuất Word)
- H1: Kiến trúc tổng thể Flutter – Firebase – Cloud Functions.
- H2: Luồng MXH (Login → Feed → Create Recipe/Post → Reaction/Comment).
- H3: Luồng Planner & Shopping List.
- H4: Giao diện Feed và Recipe Detail.
- H5: Giao diện Chat (DM/Group) và Leaderboard.
- H6: Giao diện Admin (Reports, AI Prompts, Audit Logs).
- H7: Màn hình AI Assistant / Chef AI.
- H8: Lược đồ Firestore (users, posts, recipes, chats, leaderboards, aiConfigs…).

---

# CHƯƠNG 1: GIỚI THIỆU VỀ ĐỀ TÀI

## 1.1 Giới thiệu đề tài
- Xây dựng ứng dụng mạng xã hội ẩm thực trên Android/Web bằng Flutter.
- Hỗ trợ đăng nhập Email/Google; CRUD Post & Recipe, upload ảnh, gắn tag/tokens; reaction 4 loại, bình luận, đánh giá (recipe), chia sẻ trong/ngoài app.
- Tìm kiếm thống nhất (title/tags/searchTokens/ingredientsTokens) kèm gợi ý trending + AI khi không có kết quả; chat realtime (DM/Group); bảng xếp hạng đóng góp và huy hiệu.
- Tích hợp AI qua Cloud Functions: gợi ý công thức theo nguyên liệu, enrich bản nháp, ước tính dinh dưỡng, sinh meal plan 7 ngày, chatbot Chef AI, gợi ý tìm kiếm, moderation báo cáo/chat.

## 1.2 Nhiệm vụ đồ án
### 1.2.1 Bối cảnh và tính cấp thiết
- Nhu cầu chia sẻ công thức, tìm nhanh theo nguyên liệu sẵn có, gợi ý thay thế, lập kế hoạch bữa ăn.
- Nhiều nền tảng hiện có phân tán, ít AI, thiếu realtime và thiếu quản trị tập trung.
### 1.2.2 Ý nghĩa khoa học và thực tiễn
- Kết hợp Flutter (client) + Firebase (backend realtime) + AI on-cloud để nâng cao tìm kiếm/gợi ý.
### 1.2.3 Mục tiêu nghiên cứu
- Thiết kế kiến trúc đa tầng: presentation (UI), application (controller/service), data (repository) bao bọc Firebase SDK + Cloud Functions.
- Xây dựng full flow social: Auth, Feed, Post/Recipe, Reaction/Comment/Rating/Share, Search thống nhất, Chat realtime, Leaderboard.
- Tích hợp AI đa tác vụ (suggest, enrich, nutrition, meal plan, chatbot, moderation) + quản lý prompt (aiConfigs).
- Đảm bảo bảo mật, phân quyền (admin/mod/client), log/audit, kiểm thử emulator.
### 1.2.4 Đối tượng nghiên cứu
- Người dùng yêu bếp muốn tìm/đăng công thức, trò chuyện, lập kế hoạch bữa ăn.
- Admin/Moderator quản lý nội dung, báo cáo, cấu hình AI.
### 1.2.5 Phạm vi và giới hạn
- MVP Android/Web, chưa triển khai iOS; dữ liệu Firestore, ảnh Firebase Storage.
- AI phụ thuộc OpenAI; chi phí có thể tăng nếu không cache/fallback.
- Planner/Shopping mức cá nhân, chưa offline-first nâng cao.
### 1.2.6 Phương pháp thực hiện
- Thu thập yêu cầu → thiết kế kiến trúc, DB schema/index → hiện thực Flutter + Functions TS → kiểm thử emulator + checklist → tài liệu + CI/CD.
- Phân công theo nhánh feat/chore; Conventional Commits; PR < 400 dòng; bắt buộc flutter analyze trước PR.

## 1.3 Cấu trúc đồ án
- Chương 1: Giới thiệu, mục tiêu, phạm vi.
- Chương 2: Cơ sở thực tiễn/lý thuyết, công nghệ, yêu cầu, thiết kế CSDL, so sánh giải pháp.
- Chương 3: Kiến trúc, cấu trúc dự án, kết nối Firebase, module chức năng, API, giao diện, bảo mật.
- Chương 4: Kế hoạch kiểm thử, kịch bản, đánh giá.
- Chương 5: Kết luận và hướng phát triển.
- Phụ lục: Checklist, hướng dẫn chạy, prompts AI, rules Firestore, CI/CD.

---

# CHƯƠNG 2: CƠ SỞ THỰC TIỄN VÀ LÝ THUYẾT

## 2.1 Cơ sở thực tiễn
- Nhu cầu chia sẻ công thức và kinh nghiệm bếp, tương tác cộng đồng (react, comment, share) tăng.
- Người dùng muốn tìm nhanh theo nguyên liệu; cần gợi ý khi không có kết quả.
- Xu hướng dùng AI để tính dinh dưỡng, lập thực đơn, kiểm duyệt nội dung.
- Khoảng trống: ít ứng dụng kết hợp social + chat realtime + planner/shopping + AI, kèm bảo mật và quản trị.

## 2.2 Cơ sở lý thuyết
- Flutter 3.x: UI đa nền tảng, state Riverpod, điều hướng GoRouter.
- Firebase: Auth (Email/Google), Firestore (NoSQL realtime), Storage (ảnh), Cloud Functions (logic/AI), FCM (thông báo), Hosting.
- Kiến trúc phân lớp: presentation ↔ application/controller ↔ repository ↔ Firebase adapters.
- Cloud Functions (TypeScript, asia-southeast1) với triggers (Firestore, cron) và callable (AI, chat).
- AI (OpenAI): gọi qua Functions, ép JSON schema, quản lý prompt aiConfigs, tránh lộ key.

## 2.3 Công nghệ hỗ trợ (từ code/config)
- Client (pubspec.yaml): go_router 14.8.1, flutter_riverpod 2.5.1, firebase_core 3.5.0, firebase_auth 5.3.1, cloud_firestore 5.4.0, firebase_storage 12.2.0, cloud_functions 5.0.0, firebase_messaging/analytics, cached_network_image, image_picker, google_fonts, emoji_picker_flutter, **video_player 2.9.1** (cho reels), audioplayers, share_plus, path_provider, url_launcher, fl_chart, google_sign_in, **flutter_localizations** (SDK), **intl 0.20.2** (đa ngôn ngữ), **timeago 3.7.1**, **shared_preferences 2.3.3**.
- Backend: Firebase Emulator Suite; Firestore rules/indexes (firestore.rules, firestore.indexes.json); Cloud Functions TS (aggregates, search_tokens, leaderboard, suggest, chat, roles, report_moderation, social_notifs, planner_notifs, ai_*); Storage rules.
- Công cụ: Node LTS, firebase-tools, flutterfire_cli; Firebase Emulator UI; (flutter-analyze, deploy web hosting preview/live).

## 2.4 Phân tích yêu cầu hệ thống
- Chức năng:
  - Auth, role admin/mod/client (custom claims).
  - Post/Recipe CRUD, upload ảnh, tags/tokens; reaction 4 loại, comment, rating (recipe), share.
  - Tìm kiếm thống nhất (title/tags/searchTokens/ingredientsTokens), ranking theo match + rating/likes/shares; fallback suggestSearch (trending + gpt).
  - Chat realtime (DM cần bạn bè, Group có owner), thông báo FCM tùy chọn; friends/follows (trong rules).
  - Leaderboard tuần/tháng, điểm đóng góp, badges.
  - Planner & Shopping list: thêm recipe vào bữa, sinh danh sách mua sắm, macro dashboard.
  - AI: suggest recipes, enrich draft, nutrition, meal plan, Chef chatbot, AI search parser, moderation report/chat.
  - Admin: users, content, reports, chat violations, AI prompts, admin settings, audit logs.
- Phi chức năng:
  - Bảo mật: rules chi tiết, validate owner, audit logs, giới hạn text (≤4000), 1 reaction/rating/user.
  - Hiệu năng: indexes, array-contains-any, stream realtime, debounce search, aggregate counters.
  - Khả dụng: hỗ trợ emulator; fallback AI khi thiếu key.

## 2.5 Use Case & Activity tiêu biểu
- Đăng nhập; tạo post/recipe; reaction/comment/rating/share; tìm kiếm; chat DM/Group; add to meal plan; generate shopping list; xem leaderboard; gửi report; admin duyệt; chỉnh AI prompt; xem audit logs.
- Luồng mẫu:
  - MXH: Login → Feed stream → Create Recipe/Post (upload ảnh) → React/Comment → Functions aggregate → Leaderboard cập nhật.
  - Tìm kiếm: nhập từ khóa/ingredient → searchTokens/ingredientsTokens → nếu rỗng gọi suggestSearch (trending + gpt).
  - Chat: createDM (yêu cầu bạn bè) hoặc createGroup → gửi message (rules kiểm member) → onMessage cập nhật lastMessageAt + FCM.
  - Planner: RecipeDetail → Add to MealPlan → generate ShoppingList (merge items) → macro dashboard tính calories/protein/carb/fat.
  - AI: callable aiSuggestRecipesByIngredients, aiEnrichRecipeDraft, aiEstimateNutrition, aiGenerateMealPlan, aiChefChat; triggers ai_moderation, ai_chat_moderation.

## 2.6 Thiết kế cơ sở dữ liệu (Firestore)
- users: displayName, photoURL, bio, role, pantryTokens[], stats{posts,recipes,**reels**,comments,reactions,shares,weekScore,monthScore,badges}, follows, **preferredLocale (vi/en)**.
- posts/recipes: nội dung, tags, searchTokens/ingredientsTokens, counters (likes/comments/shares, ratings/avgRating), hidden/reportsCount, timestamps.
- **reels (Collection mới)**: Lưu trữ video ngắn dạng TikTok/Reels
  - Trường chính: authorId, videoUrl, thumbnailUrl, title, description, tags[], searchTokens[]
  - Counters: likesCount, commentsCount, sharesCount, viewsCount
  - Metadata: duration (giây), hidden (cho admin duyệt), createdAt, updatedAt
  - Subcollections: reactions/{uid}, comments/{id}, shares/{uid} (tương tự posts)
  - Indexes: createdAt DESC, viewsCount DESC (cho trending), searchTokens (array-contains-any)
- subcollections: reactions/comments/ratings/shares (doc id = uid cho reaction/rating/share). **Comments hỗ trợ imageUrl, replyTo, replyToName, isEdited**.
- chats/messages: chat dm|group, ownerId, memberIds, lastMessageAt; message {authorId,text,**imageUrl**,attachments[],createdAt}.
- leaderboards: weekly-YYYYWW, monthly-YYYYMM, top{uid,score,rank}, badges top1/top3/top10.
- reports: targetType post|recipe|**reel**|message|user, reason, reporterId, status, aiVerdict; auditLogs append-only.
- mealPlans/shoppingLists/bookmarks/notifications/aiConfigs/adminSettings/chatViolations phục vụ planner, AI, moderation.
- **Localization settings**: Lưu trong user preferences hoặc local storage, sync với localeProvider.
- Indexes: recipes.ingredientsTokens + createdAt; recipes.avgRating + createdAt; posts.searchTokens + createdAt; **reels.createdAt DESC; reels.viewsCount DESC** (firestore.indexes.json).

## 2.7 Phân tích so sánh
- So Cookpad/Tasty: dự án có chat realtime, planner + shopping, leaderboard, AI đa nhiệm, quản trị và rules chặt chẽ.
- So app meal planner: bổ sung cộng đồng, feed, reaction/comment, chia sẻ, vai trò admin/mod, quản lý prompt AI tập trung.
- Điểm mới: kết hợp social + AI + planner trên Firebase, stream realtime + callable AI.

## 2.8 Yêu cầu kỹ thuật và ràng buộc
- Môi trường: Flutter 3.x; Node LTS; firebase-tools; flutterfire_cli; emulator (Firestore 8080, Functions 5001, Hosting 5000, UI 4000).
- Bảo mật: Dùng Firebase Secrets cho Functions; có thể bổ sung App Check, rate-limit.
- Hiệu năng: giới hạn ~150 tokens/searchTokens; message ≤4000; AI payload giới hạn, cache config 60s; Storage <5MB/file (quy ước tên file ngắn, lowercase).

---

# CHƯƠNG 3: CÀI ĐẶT VÀ XÂY DỰNG ỨNG DỤNG

## 3.1 Kiến trúc tổng thể
- Client Flutter ↔ Firebase Auth (ID token + custom claims) ↔ Firestore (stream realtime), Storage (ảnh), Cloud Functions (logic/AI/search/aggregate/leaderboard/chat), FCM (thông báo), Hosting (web).
- Luồng chính:
  - MXH: Auth → Feed stream → Create Post/Recipe (upload Storage, ghi Firestore) → triggers aggregate (likes/comments/shares/ratings, user.stats) → leaderboard cron.
  - Search: generate searchTokens/ingredientsTokens qua Functions; query array-contains-any; nếu rỗng → suggestSearch (trending + gpt).
  - Chat: callable createDM/createGroup (DM yêu cầu bạn bè), stream messages, onMessage cập nhật lastMessageAt + FCM.
  - Planner/Shopping: mealPlans per user/day, shoppingLists merge items, macro dashboard đọc recipes.macros/estimatedMacros.
  - AI: callable aiSuggestRecipesByIngredients, aiEnrichRecipeDraft, aiEstimateNutrition, aiGenerateMealPlan, aiChefChat; triggers ai_moderation, ai_chat_moderation, ai_analyze_reports.

## 3.2 Cấu trúc dự án và công nghệ sử dụng
- Thư mục: `lib/features/*` (auth, home, feed, post, recipe, recipes, search, chat, planner, shopping, nutrition, notifications, ai, admin, report, leaderboard, profile, social, intro); `lib/app` (router, scaffold, theme); `lib/core/services`; `functions/src` (TS); `docs`; `.github`; `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`.
- Router (GoRouter): /splash, /signin,/register,/feed,/recipes,/search,/planner,/shopping,/chat(/:cid),/post/:id,/recipe/:id,/ai-assistant,/macro-dashboard,/notifications,/settings/notifications,/profile(/:uid),/create-post,/create-recipe,/ai-recipe-preview; admin: /admin/overview, users, content, reports, chats, ai-prompts, settings, audit-logs.
- State: Riverpod; repository pattern bọc Firestore/Functions/Storage; custom transition (fade + slide + scale).
- Dependencies (pubspec.yaml): chi tiết version như 14.8.1 (go_router), 2.5.1 (flutter_riverpod), 3.5.0 (firebase_core), 5.3.1 (firebase_auth), 5.4.0 (cloud_firestore), 12.2.0 (firebase_storage), 5.0.0 (cloud_functions), cùng cached_network_image, image_picker, google_fonts, emoji_picker_flutter, video_player, audioplayers, share_plus, path_provider, url_launcher, fl_chart, google_sign_in.
- Build: Flutter SDK >=3.5, version 1.0.0+1, publish_to none; nền tảng Android/Web.
- CI/CD: GitHub Actions `flutter-analyze.yml` (format + analyze), `deploy-web.yml` (build web, hosting preview PR, deploy live khi merge main).

## 3.3 Kết nối Firebase
- Cấu hình qua `firebase_options.dart` (flutterfire configure); Android đặt `google-services.json`; Web dùng dart-define.
- Emulator: Firestore 8080, Functions 5001, Hosting 5000; file `firebase_emulator.dart` hỗ trợ kết nối cục bộ.
- Secrets: `.env` (GPT_API_KEY); Functions đọc GPT_API_KEY từ Firebase Secrets (`firebase functions:secrets:set GPT_API_KEY`).
- Cách chạy: `flutter pub get`; `cd functions && npm install && npm run build`; `firebase emulators:start`; `cd functions && npm run seed` (dữ liệu mẫu); `flutter run -d chrome --dart-define-from-file=.env`.

## 3.4 Các module chức năng chính (từ code)
- Auth & Role: Firebase Auth (Email/Google); onUserCreate gán role=client; callable setRole cho admin; UI đổi theo custom claims.
- Feed/Post/Recipe: CRUD, upload ảnh, tags/tokens; reactions 4 loại, comment (hỗ trợ gửi ảnh + icon), share, rating (recipe); counters aggregate qua Functions.
- **Reels (Tính năng mới)**: Hệ thống video dạng TikTok/Instagram Reels hoàn chỉnh:
  - Tạo reel với video upload, thumbnail, title, description, tags, searchTokens
  - Xem feed reels theo thời gian, trending (most viewed 7 days), search
  - Tương tác: like, comment, share, save; đếm views tự động
  - Hiển thị trong Profile với tab riêng
  - Admin duyệt reels (ẩn/hiện qua trường `hidden`)
  - Video player tích hợp controls, auto-play
  - Repository: ReelRepository, ReelInteractionRepository với CRUD đầy đủ
- **Đa ngôn ngữ Vi/En (Tính năng mới)**: Hệ thống localization hoàn chỉnh
  - File `lib/app/l10n.dart` quản lý 345+ dòng strings
  - Hỗ trợ toàn bộ UI: navigation, auth, feed, planner, chat, profile, create post/recipe, notifications, errors
  - Provider `localeProvider` cho phép chuyển đổi ngôn ngữ realtime
  - Tất cả string đều có bản Vi và En, tự động theo locale device
- **Gửi ảnh và icon trong bình luận (Tính năng mới)**:
  - Comment model hỗ trợ trường `imageUrl` để đính kèm ảnh
  - _CommentCard hiển thị ảnh với ClipRRect, BoxConstraints maxHeight 250
  - Emoji picker tích hợp trong input comment
  - Upload ảnh vào Firebase Storage trước khi gửi comment
- **AI nhận diện nguồn gốc món ăn (Tính năng mới)**:
  - `FlippableDishCard`: Widget lật thẻ 3D (flip animation) trên ảnh món ăn
  - Khi tap → gọi AI Chef Service với prompt yêu cầu câu chuyện/nguồn gốc món (2-3 câu ngắn)
  - Hiển thị fun fact về món ăn theo ngôn ngữ Vi/En
  - Tích hợp trong RecipeDetailPage qua Hero animation
  - Sử dụng aiChefService.chat() để truy vấn thông tin
- **Upload avatar từ máy (Tính năng mới)**:
  - `ProfileStorageService.uploadProfileAvatar()`: upload ảnh từ ImagePicker
  - Lưu vào path `user_avatars/{userId}/avatar_{timestamp}.jpg`
  - Edit Profile cho phép chọn ảnh từ camera hoặc gallery
  - Tự động update `photoUrl` trong Firestore users collection
  - Xóa avatar cũ khi upload mới (deleteProfileAvatar)
- Search & Suggest: unified search (title/tags/tokens/ingredientsTokens) + ranking; fallback suggestSearch (trending + Gpt) khi rỗng.
- Chat realtime: DM (cần bạn bè), Group có owner + memberIds; stream messages; notifyOnMessage (FCM tùy chọn); text ≤4000; lastMessageAt cập nhật qua trigger.
- Leaderboard & Badges: điểm hoạt động (Post +2, Recipe +4, Comment +1, Reaction +0.5, Share +1, Rating +1); cron daily ghi leaderboards weekly/monthly, badges top1/top3/top10.
- Planner & Shopping & Nutrition: add recipe vào mealPlans/{uid}/days; generate shoppingLists merge items, tick/untick; macro dashboard tính calories/protein/carb/fat; AI estimate nutrition per serving; AI meal plan 7 ngày theo goal/macroTarget/favorites/allergies.
- AI & Prompts: aiConfigs quản lý model/temperature/systemPrompt/userPromptTemplate/enable; callable AI (suggest, enrich, nutrition, meal plan, chef chat, aiParseSearchQuery, **food origin story**); triggers moderation (report/chat) + ai_analyze_reports.
- Admin: Users (ban/unban, đổi role), Content (**bao gồm duyệt Reels**), Reports, Chat moderation, AI Prompts (bật/tắt, chỉnh prompt), Settings, Audit Logs.
- Notifications: Firestore `notifications/{uid}/items`, FCM tùy chọn (chat); Friends page; Profile/Settings Notifications.
- **UI/UX cải thiện toàn diện (Tính năng mới)**:
  - Modern components: GradientAvatar, FlippableCard, SortChips
  - Animation: flip 3D, fade/slide/scale transitions, loading states
  - Theme: primaryContainer, secondaryContainer gradients, responsive layout
  - Comment system: threaded replies với indent, inline tags, edit/delete
  - Profile tabs: Posts, Recipes, Reels, Saved items
  - Improved navigation: bottom nav với icons, language switcher
- UI hỗ trợ: image_picker (ảnh + avatar), emoji_picker_flutter (emoji), video_player/audioplayers (media + reels), share_plus (chia sẻ ngoài app), fl_chart (macro dashboard), intl & flutter_localizations (đa ngôn ngữ).

## 3.5 Bảo mật & phân quyền (từ FIRESTORE_RULES_SUMMARY và rules)
- Role: admin toàn quyền; moderator đọc/chỉnh nội dung, báo cáo, chat violations; user bị giới hạn theo owner.
- users: signed-in đọc, tạo hồ sơ, cập nhật hồ sơ của mình; bookmarks/plannerSettings/mealPlans/shoppingLists chỉ owner đọc/ghi.
- posts/recipes: đọc công khai; create cần signed-in + authorId==uid; update/delete chỉ owner hoặc admin/mod; hidden/isHiddenPendingReview phục vụ moderation.
- reactions/comments/ratings/shares: mỗi user 1 doc (id=uid); validate type/stars; createdAt == request.time.
- chats/messages: chỉ member đọc/ghi; createDM yêu cầu đã là bạn bè; text ≤4000; onMessage cập nhật lastMessageAt.
- leaderboards: read public; write chỉ Functions (claim).
- reports: user tạo/đọc của mình; admin/mod quản lý status; aiVerdict từ Functions; auditLogs chỉ admin đọc, Functions ghi append-only.
- aiConfigs/adminSettings/chatViolations: chỉ admin; chatViolations do AI moderation ghi.
- Index deploy: `firebase deploy --only firestore:rules,firestore:indexes`.

## 3.6 Thiết kế API (Cloud Functions)
- Triggers:
  - aggregates.ts: onReactionChange/onCommentChange/onRatingChange/onShareAdd; onAnyCreate cập nhật user.stats; onMessage cập nhật lastMessageAt.
  - search_tokens.ts: onWritePost/onWriteRecipe tạo searchTokens/ingredientsTokens.
  - leaderboard.ts: cron recomputeLeaderboard (week/month), gán badges.
  - report_moderation.ts: onReportCreate (reportsCount, isHiddenPendingReview, auditLogs).
  - social_notifs.ts, planner_notifs.ts: thông báo (nếu bật).
- Callable:
  - suggestSearch({q,tokens,type}); createDM({toUid}); createGroup({name,memberIds}); setRole; aiParseSearchQuery.
  - AI: aiSuggestRecipesByIngredients, aiEnrichRecipeDraft, aiEstimateNutrition, aiGenerateMealPlan, aiChefChat, aiAnalyzeReports; ai_chat_moderation (trigger onMessage), ai_moderation (trigger report).
- Seed & tiện ích: seed.ts (10 posts + 10 recipes + 2 chats + messages); setupEnv.ts (đọc .env local).

## 3.7 Giao diện người dùng (từ router/app_router.dart)
- Onboarding/Splash/SignIn/SignUp/ForgotPassword.
- Tabs: Feed, Recipes, Search, Chat, Planner, Shopping, Profile/Me, Notifications, Macro Dashboard.
- Detail: PostDetail, RecipeDetail (rating, ingredients, steps, photos).
- CreatePost/CreateRecipe (upload ảnh, tags; AI enrich/estimate nutrition; load từ AI suggestion).
- SearchResult + AI gợi ý khi không có kết quả.
- ChatRoom (DM/Group), Friends page, AI Assistant / Chef AI chatbot.
- Leaderboard tuần/tháng.
- Admin: Overview, Users, Content, Reports, Chat moderation, AI Prompts, Settings, Audit Logs.
- Animation chuyển trang: fade + slide + scale (CustomTransitionPage).

---

# CHƯƠNG 4: KIỂM THỬ VÀ ĐÁNH GIÁ

## 4.1 Mục tiêu kiểm thử
- Đảm bảo luồng chính hoạt động trên emulator và kết nối Firebase thật (khi có cấu hình).
- Xác nhận rules chặn truy cập trái phép; counters/leaderboard/AI ổn định.
- UI phản hồi đúng role (client/admin), trạng thái ban/lock.

## 4.2 Kế hoạch và kịch bản kiểm thử (từ code + checklist)
- Auth: đăng nhập Email/Google (web/android), role=client; đổi custom claims admin/mod.
- Post/Recipe: tạo/sửa/xóa với ảnh/tags/ingredientsTokens; reactions 4 loại 1 user 1 doc; comment, rating (recipe) cập nhật avgRating/ratingsCount; share tăng sharesCount.
- Search & Suggest: tìm “trứng hành” (ingredients) và “bún bò” (keyword) → có kết quả; rỗng → suggestSearch trả trending/AI gợi ý.
- Chat: createDM (yêu cầu bạn bè) + gửi tin; createGroup + nhiều member; non-member không đọc/ghi; lastMessageAt cập nhật; text >4000 bị chặn; FCM tùy chọn.
- Leaderboard: tạo hoạt động → weekScore/monthScore tăng; chạy cron (emulator/script) → leaderboards/{period} có top list, badges.
- Planner/Shopping/Nutrition: add recipe → mealPlans đúng schema; generate shopping list → items merge; macro dashboard tính đúng; AI estimateNutrition chạy.
- AI: aiSuggestRecipesByIngredients, aiEnrichRecipeDraft, aiGenerateMealPlan, aiChefChat; moderation onReportCreate (aiVerdict), ai_chat_moderation ghi chatViolations.
- Admin: xem reports, đổi status; xem chat violations, lock/unlock; chỉnh AI prompts; auditLogs ghi sự kiện.
- Security rules: user A không sửa mealPlans/shoppingLists/bookmarks của user B; chỉ owner update/delete post/recipe & subcollections; admin/mod có quyền; auditLogs chỉ admin đọc; chat member check.

## 4.3 Postman/Emulator test nhanh
- Base emulator: `http://localhost:5001/vuadaubep-<mssv>/us-central1`.
- Callable mẫu: POST /suggestSearch với header `Authorization: Bearer {{idToken}}`.
- Lấy idToken qua app web emulator hoặc `firebase auth:sign-in-with-email`.
- Biến môi trường Postman: projectId, base, idToken; không lưu secret thật.
- Checklist bàn giao nhanh:
  1) `firebase emulators:start` + `npm run build` functions.
  2) Đăng nhập, tạo Post/Recipe (tags/ingredientsTokens) → searchTokens sinh đúng.
  3) React/comment/rating/share cập nhật counters + user.stats.
  4) Search “trung hanh”, “bun bo” có kết quả; rỗng → suggestSearch trending.
  5) Chat: createDM/createGroup, chỉ member đọc/ghi; lastMessageAt cập nhật.
  6) Cron leaderboard sinh leaderboards/{period}, badges top1/top3/top10.
  7) flutter analyze pass; build web chạy với emulator.

## 4.4 Kiểm thử hiệu năng và kết nối
- Emulator Suite: Firestore 8080, Functions 5001, Hosting 5000, UI 4000; seed.ts tạo dữ liệu mẫu; test stream feed/search/chat.
- Indexes đảm bảo query searchTokens/ingredientsTokens + sort createdAt/avgRating; tải nhẹ với nhiều luồng đọc ghi đồng thời.

## 4.5 Đánh giá và phân tích
- Ưu điểm:
  - Kiến trúc rõ, phân tầng, repository pattern; router & role guard; CI/CD analyze + deploy web.
  - Tính năng phong phú: social + chat + planner/shopping + leaderboard + AI; admin đầy đủ (reports, chat violations, AI prompts).
  - Bảo mật chặt: rules chi tiết, custom claims, auditLogs, check bạn bè khi createDM, giới hạn text, 1 reaction/rating/user.
  - AI đa dụng: suggest, enrich, nutrition, meal plan, chatbot, moderation; prompt management tập trung.
- Hạn chế:
  - Phụ thuộc Firebase/Functions, chi phí tăng khi mở rộng; chưa hỗ trợ iOS; AI chi phí cao nếu không cache/fallback.
  - Planner/Shopping chưa offline-first; FCM tùy chọn; chưa có test e2e tự động.
  - Theo dõi chi phí/monitoring (Crashlytics/Analytics) chưa nêu bật.
- Hướng khắc phục:
  - Bổ sung test integration/e2e, performance profiling; tối ưu cache AI/trending; tối ưu Storage (resize ảnh).
  - Bổ sung App Check, rate-limit AI; hỗ trợ iOS/desktop; hoàn thiện monitoring/alert.

---

# CHƯƠNG 5: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

## 5.1 Kết luận
Đã hiện thực ứng dụng mạng xã hội ẩm thực đa nền tảng với luồng Auth, Feed, Post/Recipe, Search, Chat, Leaderboard, Planner/Shopping, AI hỗ trợ và moderation. Firebase + Cloud Functions đơn giản hóa backend; rules và audit tăng cường bảo mật.

## 5.2 Đánh giá kết quả
- Hoàn thành chức năng cốt lõi MVP: đăng nhập, tạo/chia sẻ công thức, tìm kiếm thống nhất, chat realtime, leaderboard, planner/shopping, AI đa nhiệm, admin quản trị.
- Bàn giao: flutter analyze pass; firebase.json/.firebaserc/functions/package.json sẵn; rules/indexes deploy; Functions chạy emulator; tài liệu chạy & kiểm thử đầy đủ.

## 5.3 Hướng phát triển
- Mở rộng iOS/desktop, tối ưu UI/UX (animation, theming), đa ngôn ngữ.
- Tăng offline-first/cache feed/search, đồng bộ nền shopping/planner.
- AI nâng cao: vector search, rerank, gợi ý cá nhân hóa; voice/vision (ảnh nguyên liệu).
- Tích hợp thanh toán/đặt món (nếu mở rộng thương mại), loyalty points.
- Tăng cường giám sát: logging tập trung, alert, rate-limit, App Check, quản trị chi phí Functions.

## 5.4 Tổng kết
Dự án chứng minh khả năng kết hợp Flutter, Firebase và AI để xây dựng sản phẩm cộng đồng giàu tính năng trong thời gian triển khai nhanh. Tài liệu, cấu trúc mã và CI/CD sẵn sàng chuyển giao, mở rộng.

---

# TÀI LIỆU THAM KHẢO / ĐÍNH KÈM
## Tài liệu online (tham khảo kiến trúc/AI/Flutter/Firebase)
[1] “Implementing MVVM architecture in Kotlin for maintainable apps”, Reintech.io (2023), URL: https://reintech.io/blog/implementing-mvvm-architecture-kotlin  
[2] “MVVM (Model View ViewModel) Architecture Pattern in Android”, GeeksforGeeks (2020), URL: https://www.geeksforgeeks.org/mvvm-model-view-viewmodel-architecturepattern-in-android/  
[3] “MVVM Architecture in Android Using Kotlin - A Comprehensive Guide”, CodersArts (2023), URL: https://www.codersarts.com/post/mvvm-architecture-in-android-using-kotlin  
[4] “Android-Clean-Architecture-MVVM-Kotlin”, Samad Talukder, GitHub (2022), URL: https://github.com/samadtalukder/Android-Clean-Architecture-MVVM-Kotlin  
[5] “Simple example of MVVM architecture in Kotlin”, Dev.to (2021), URL: https://dev.to/whatminjacodes/simple-example-of-mvvm-architecture-in-kotlin-4j5b  
[6] “MVVM Architecture in Kotlin for Android Development | Complete Beginner Guide”, GuruGuidance AI, YouTube (2025), URL: https://www.youtube.com/watch?v=qcjM4ekahRY  
[7] “Android - Build a Movie App using Retrofit and MVVM Architecture with Kotlin”, GeeksforGeeks (2022), URL: https://www.geeksforgeeks.org/android-build-a-movie-app-using-retrofit-andmvvm-architecturewith-kotlin/  
[8] Flutter official docs (routing, state, build): https://docs.flutter.dev/  
[9] Firebase official docs (Auth, Firestore, Storage, Functions, Emulator): https://firebase.google.com/docs  
[10] Riverpod documentation (state management): https://riverpod.dev/  
[11] GoRouter documentation (navigation): https://pub.dev/packages/go_router  
[12] Google Cloud Functions for Firebase (TypeScript): https://firebase.google.com/docs/functions  
[13] OpenAI API (JSON schema / safety best practices): https://platform.openai.com/docs/  

## Mã nguồn & cấu hình dự án (nội bộ)
- Flutter: `lib/*` (router app_router.dart; features auth, feed, post, recipe, search, chat, planner, shopping, nutrition, notifications, ai, admin, leaderboard, profile, social, intro; services; theme/scaffold).
- Functions TypeScript: `functions/src` (aggregates.ts, search_tokens.ts, leaderboard.ts, suggest.ts, chat.ts, roles.ts, report_moderation.ts, social_notifs.ts, planner_notifs.ts, ai_*.ts, seed.ts, index.ts).
- Cấu hình Firebase: `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `.firebaserc`.
- CI/CD: `.github/workflows/flutter-analyze.yml`, `deploy-web.yml`.
- Build/SDK: `pubspec.yaml` (Flutter >=3.5, version 1.0.0+1), `android/`, `web/`, `windows/` scaffolding.

## Hướng dẫn chạy nhanh (nhắc lại)
1) `flutter pub get`; `cd functions && npm install && npm run build`.  
2) `firebase emulators:start` (hoặc deploy: firestore rules/indexes, functions, hosting web).  
3) `cd functions && npm run seed` (tùy chọn dữ liệu mẫu).  
4) `flutter run -d chrome --dart-define-from-file=.env` (hoặc thiết bị khác).  
Lưu ý bảo mật: không commit .env/google-services.json/gpt_API_KEY; dùng Firebase Secrets cho Functions; kiểm tra .gitignore.

*File dùng để chuyển sang Word; khi xuất có thể chèn hình, mục lục tự động, số trang.*
