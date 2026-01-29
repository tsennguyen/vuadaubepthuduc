# CHƯƠNG 3: CÀI ĐẶT VÀ XÂY DỰNG ỨNG DỤNG

## DANH SÁCH CHỤP ẢNH GIAO DIỆN - VUA ĐẦU BẾP THỦ ĐỨC

**Hướng dẫn**: Đánh dấu ✅ sau khi chụp ảnh mỗi màn hình. Lưu file ảnh vào `docs/images/screenshots/` với tên tương ứng.

---

## 3.1 KIẾN TRÚC TỔNG THỂ VÀ MÔI TRƯỜNG THỰC NGHIỆM

### 3.1.1 Kiến trúc hệ thống

Ứng dụng được xây dựng theo mô hình Client-Server hiện đại, tận dụng tối đa hệ sinh thái Firebase (Serverless) để đảm bảo tính thời gian thực và khả năng mở rộng. Client Flutter giao tiếp với Firebase Auth để xác thực, Firestore để cập nhật dữ liệu Realtime và Cloud Functions để xử lý các logic Business phức tạp và tích hợp AI.

- [ ] **Hình 3.1** - Sơ đồ kiến trúc tổng thể hệ thống Flutter - Firebase
  - File: `architecture_diagram.png` (Đã có sẵn trong `docs/images/`)
  - Nội dung: Kiến trúc 3 tầng Client-Functions-Data với luồng dữ liệu

### 3.1.2 Môi trường thực nghiệm

Nhóm sử dụng bộ công cụ Firebase Emulator Suite để giả lập môi trường server local, đảm bảo quá trình phát triển được an toàn và tối ưu hóa chi phí trước khi deploy thực tế.

- [ ] **Hình 3.2** - Giao diện quản lý các dịch vụ trên Firebase Emulator UI
  - Nội dung: Firebase Emulator Suite đang chạy (Firestore 8080, Functions 5001, UI 4000)
  - Cách chụp: Chạy `firebase emulators:start`, truy cập `localhost:4000`

---

## 3.2 CẤU TRÚC DỰ ÁN VÀ CÔNG NGHỆ SỬ DỤNG

### 3.2.1 Cấu trúc thư mục mã nguồn

Mã nguồn ứng dụng được tổ chức theo cấu trúc "Clean Architecture (Feature-driven)", phân chia rõ ràng các module như xác thực, reels, AI và admin nhằm dễ dàng bảo trì và mở rộng.

- [ ] **Hình 3.3** - Cấu trúc thư mục dự án được tổ chức theo Feature trong VS Code
  - Nội dung: Explorer view trong VS Code hiển thị `lib/features/` với các folders: auth, feed, reels, recipe, ai, admin...
  - Cách chụp: Mở VS Code, expand `lib/features/`

### 3.2.2 Các công nghệ và thư viện hỗ trợ

Để đạt được hiệu năng cao và tính năng thông minh, dự án khai báo các thư viện quan trọng như Riverpod (quản lý state), OpenAI (Trí tuệ nhân tạo) và Video Player (xử lý media).

- [ ] **Hình 3.4** - Khai báo các thư viện hỗ trợ trong tệp pubspec.yaml
  - Nội dung: File `pubspec.yaml` hiển thị dependencies (go_router, flutter_riverpod, firebase, video_player, intl...)
  - Cách chụp: Mở `pubspec.yaml` trong VS Code

---

## 3.3 KẾT NỐI VÀ BẢO MẬT DỮ LIỆU

### 3.3.1 Kết nối và bảo mật Firestore

Mọi truy cập dữ liệu đều thông qua lớp bảo mật Firestore Rules, đảm bảo tính riêng tư cho dữ liệu Meal Planner và chỉ cho phép người dùng chỉnh sửa nội dung do chính mình tạo ra.

- [ ] **Hình 3.5** - Thiết lập hệ thống bảo mật Firestore Rules cho dữ liệu và nội dung
  - File: `firestore_security_rules.png` (Đã có sẵn trong `docs/images/`)
  - Nội dung: Sơ đồ rules với 3 roles (Admin/Moderator/User) và permissions

---

## 3.4 CÁC MODULE CHỨC NĂNG CHÍNH (GIAO DIỆN NGƯỜI DÙNG)

### 3.4.1 Module giới thiệu (Intro/Trailer) và Xác thực

Ngay khi khởi động, ứng dụng hiển thị đoạn Trailer (Intro) giới thiệu hệ sinh thái giúp người dùng nắm bắt nhanh các tính năng đột phá. Sau đó, hệ thống cung cấp giao diện Đăng nhập/Đăng ký chuyên nghiệp qua Email hoặc Google.

#### Màn hình Khởi động và Giới thiệu

- [ ] **Hình 3.6a** - Splash Screen (Màn hình khởi động)
  - Path: `/splash`
  - File: `SplashPage`
  - Nội dung: Logo "Vua Đầu Bếp Thủ Đức" và loading indicator

- [ ] **Hình 3.6b** - Intro Slide 1 - "Chào mừng đến với Vua Đầu Bếp Thủ Đức"
  - Path: `/intro`
  - File: `IntroScreen` - Slide 1
  - Nội dung: Welcome screen với hình minh họa, nút "Bỏ qua" và "Bắt đầu"

- [ ] **Hình 3.6c** - Intro Slide 2 - "Khám phá công thức"
  - File: `IntroScreen` - Slide 2
  - Nội dung: Giới thiệu tính năng recipes và search

- [ ] **Hình 3.6d** - Intro Slide 3 - "Nấu ăn dễ dàng"
  - File: `IntroScreen` - Slide 3
  - Nội dung: Hướng dẫn từng bước với ảnh minh họa

- [ ] **Hình 3.6e** - Intro Slide 4 - "Chia sẻ đam mê"
  - File: `IntroScreen` - Slide 4
  - Nội dung: Mạng xã hội, reels, community

#### Xác thực người dùng

- [ ] **Hình 3.7a** - Giao diện Đăng nhập (Login)
  - Path: `/signin`
  - File: `LoginScreen`
  - Nội dung: Email/Password fields, button "Đăng nhập", "Đăng nhập với Google", link "Đăng ký ngay"

- [ ] **Hình 3.7b** - Giao diện Đăng ký (Register)
  - Path: `/signup`
  - File: `RegisterScreen`
  - Nội dung: Form đăng ký với email, password, display name

- [ ] **Hình 3.7c** - Giao diện Quên mật khẩu
  - Path: `/forgot-password`
  - File: `ForgotPasswordScreen`
  - Nội dung: Email input để reset password

---

### 3.4.2 Hệ thống Bảng tin (Feed) và Mạng xã hội

Bảng tin chính hiển thị các bài đăng của cộng đồng dưới dạng dòng thời gian realtime. Người dùng có thể bày tỏ 4 loại biểu cảm (Like, Love, Haha, Wow) và bình luận chi tiết hỗ trợ hình ảnh kèm biểu tượng emoji.

#### Bảng tin chính (Feed)

- [ ] **Hình 3.8a** - Feed - Bộ lọc "Mới nhất" (Latest)
  - Path: `/feed`
  - File: `FeedPage`
  - Nội dung: Stream posts mới nhất, tabs filter (Latest/Hot/Following)

- [ ] **Hình 3.8b** - Feed - Card Post với ảnh
  - Nội dung: Post card hiển thị avatar tác giả, tên, thời gian, ảnh post, 4 reaction buttons, comment count

- [ ] **Hình 3.8c** - Feed - 4 loại Reaction (Like/Love/Haha/Wow)
  - Nội dung: Popup chọn reaction hoặc hiển thị reaction count

- [ ] **Hình 3.8d** - Feed - Tạo bài viết mới
  - Path: `/create-post`
  - File: `CreatePostPage`
  - Nội dung: Form nhập title, content, upload ảnh, tags

#### Chi tiết bài viết và Bình luận

- [ ] **Hình 3.9a** - Post Detail - Toàn bộ bài viết
  - Path: `/post/{id}`
  - File: `PostDetailPage`
  - Nội dung: Full post với ảnh lớn, reactions, comments section

- [ ] **Hình 3.9b** - Post Detail - Danh sách bình luận đa tầng
  - Nội dung: Comments list với threaded replies, indent, "Đang trả lời..." tag

- [ ] **Hình 3.9c** - Post Detail - Input comment với ảnh và emoji
  - Nội dung: Comment input box với button chọn ảnh, emoji picker icon, send button

- [ ] **Hình 3.9d** - Post Detail - Comment với ảnh đính kèm
  - Nội dung: Comment card hiển thị text + ảnh attachment (maxHeight 250px)

---

### 3.4.3 Module Video ngắn (Reels) hiện đại

Tính năng Reels mang lại trải nghiệm xem video nấu ăn dọc mượt mà, hỗ trợ tương tác sidebar và đếm lượt xem tự động nhằm kích thích sự sáng tạo của người dùng.

#### Xem Reels

- [ ] **Hình 3.10a** - Reels - Video đang phát full screen
  - Path: `/reels`
  - File: `ReelsPage`
  - Nội dung: Video player chiếm toàn màn hình, swipe vertical để next

- [ ] **Hình 3.10b** - Reels - Sidebar tương tác
  - Nội dung: Icons bên phải (Like với count, Comment, Share, Save), avatar tác giả

- [ ] **Hình 3.10c** - Reels - Thông tin video
  - Nội dung: Phía dưới hiển thị author name, title, description, hashtags

- [ ] **Hình 3.10d** - Reels - Video controls
  - Nội dung: Play/pause button, progress bar, mute/unmute

#### Tạo Reel

- [ ] **Hình 3.10e** - Create Reel - Form upload
  - Path: `/create-reel`
  - File: `CreateReelPage`
  - Nội dung: Upload video button, thumbnail preview, title/description input, tags

---

### 3.4.4 Chi tiết Công thức và Thẻ lật thông minh

Màn hình cung cấp hướng dẫn nấu ăn chuyên sâu với nguyên liệu và quy trình chi tiết. Đặc biệt, widget FlippableDishCard (thẻ lật 3D) mang lại kiến thức thú vị về nguồn gốc món ăn do AI Chef hỗ trợ cung cấp.

#### Danh sách công thức

- [ ] **Hình 3.11a** - Recipes Grid - Tổng quan
  - Path: `/recipes`
  - File: `RecipeGridPage`
  - Nội dung: Grid layout 2-3 columns, recipe cards với ảnh, title, rating, cookTime

- [ ] **Hình 3.11b** - Recipe Card trong Grid
  - Nội dung: Card compact với cover image, title, star rating, difficulty badge

#### Widget FlippableDishCard - Thẻ lật 3D

- [ ] **Hình 3.12a** - FlippableDishCard - Mặt trước (Ảnh món ăn)
  - File: `FlippableDishCard` widget
  - Nội dung: Ảnh món ăn full width, hint "Chạm để xem nguồn gốc", icon ✨

- [ ] **Hình 3.12b** - FlippableDishCard - Animation đang lật
  - Nội dung: 3D flip animation mid-way

- [ ] **Hình 3.12c** - FlippableDishCard - Mặt sau (AI Story)
  - Nội dung: Card đã lật, gradient background, tiêu đề "Có thể bạn chưa biết", AI fun fact text (2-3 câu), hint "Chạm để lật lại"

#### Chi tiết công thức đầy đủ

- [ ] **Hình 3.13a** - Recipe Detail - Header với FlippableDishCard
  - Path: `/recipe/{id}`
  - File: `RecipeDetailPage`
  - Nội dung: FlippableDishCard ở top, recipe title, author info

- [ ] **Hình 3.13b** - Recipe Detail - Thông tin tổng quan
  - Nội dung: Row hiển thị Difficulty, Cook time (phút), Servings, Tags

- [ ] **Hình 3.13c** - Recipe Detail - Danh sách nguyên liệu
  - Nội dung: Ingredients section với checkbox list, "Thêm vào Shopping List"

- [ ] **Hình 3.13d** - Recipe Detail - Các bước thực hiện có ảnh
  - Nội dung: Steps numbered (1, 2, 3...) với description và ảnh minh họa

- [ ] **Hình 3.13e** - Recipe Detail - Giá trị dinh dưỡng
  - Nội dung: Nutrition info (Calo, Protein, Carbs, Fat) với icon, "AI Estimate" badge

- [ ] **Hình 3.13f** - Recipe Detail - Ratings và Comments
  - Nội dung: Star rating (avgRating), rating distribution, comments section

#### Tạo/Chỉnh sửa công thức

- [ ] **Hình 3.13g** - Create Recipe - Form chính
  - Path: `/create-recipe`
  - File: `CreateRecipePage`
  - Nội dung: Title, description, cover image upload, difficulty dropdown

- [ ] **Hình 3.13h** - Create Recipe - Thêm nguyên liệu
  - Nội dung: Ingredients list với add/remove buttons

- [ ] **Hình 3.13i** - Create Recipe - AI Estimate Nutrition
  - Nội dung: Button "AI Ước lượng", loading state, kết quả nutrition

---

### 3.4.5 Module Trợ lý Chef AI và Hệ thống đa ngôn ngữ

Người dùng trò chuyện trực tiếp với Chef AI để nhận tư vấn thực đơn. Để tiếp cận người dùng toàn cầu, ứng dụng cho phép chuyển đổi tức thì giữa Tiếng Việt và English ngay trên giao diện cài đặt.

#### Chef AI Assistant

- [ ] **Hình 3.14a** - AI Assistant - Giao diện chat chính
  - Path: `/ai-assistant`
  - File: `AiAssistantPage`
  - Nội dung: Chat interface với Chef AI, message bubbles, input box

- [ ] **Hình 3.14b** - AI Assistant - Hỏi về thay thế nguyên liệu
  - Nội dung: User message: "Thay thế bơ bằng gì?", AI response với suggestions

- [ ] **Hình 3.14c** - AI Assistant - Gợi ý món ăn từ pantry
  - Nội dung: User: "Tôi có trứng, cà chua, hành", AI: recipe suggestions list

- [ ] **Hình 3.14d** - AI Assistant - Tư vấn dinh dưỡng
  - Nội dung: Conversation về nutrition advice theo goal (weight loss, muscle gain...)

#### Đa ngôn ngữ Vi/En

- [ ] **Hình 3.15a** - Settings - Language Switcher
  - Nội dung: Settings page với option "Ngôn ngữ / Language", dropdown Vi/En với flags

- [ ] **Hình 3.15b** - Giao diện Tiếng Việt
  - Nội dung: Feed page với tất cả text là Tiếng Việt (Bảng tin, Mới nhất, Bình luận...)

- [ ] **Hình 3.15c** - Giao diện English
  - Nội dung: Cùng Feed page nhưng text là English (Feed, Latest, Comments...)

---

### 3.4.6 Module Quản lý: Planner, Shopping List và Macro Dashboard

Hệ thống Planner hỗ trợ lập thực đơn tuần, kết hợp với Shopping List tự động tổng hợp nguyên liệu. Toàn bộ các thông số Calo, Protein... được biểu thị trực quan qua biểu đồ Dashboard.

#### Meal Planner

- [ ] **Hình 3.16a** - Planner - Lịch tuần (Weekly view)
  - Path: `/planner`
  - File: `PlannerPage`
  - Nội dung: Calendar 7 ngày (Mon-Sun), tabs Breakfast/Lunch/Dinner/Snack

- [ ] **Hình 3.16b** - Planner - Ngày có món ăn
  - Nội dung: Day cell với recipe cards assigned (ảnh thumbnail, title)

- [ ] **Hình 3.16c** - Planner - Add meal dialog
  - Nội dung: Modal chọn recipe để add vào meal slot

- [ ] **Hình 3.16d** - Planner - Buttons (Prev Week, This Week, Next Week)
  - Nội dung: Navigation buttons, "AI Plan" để generate meal plan

- [ ] **Hình 3.16e** - Planner - Generate Shopping List
  - Nội dung: Button "Tạo danh sách mua sắm" → redirect to Shopping List

#### Shopping List

- [ ] **Hình 3.16f** - Shopping List - Danh sách đầy đủ
  - Path: `/shopping`
  - File: `ShoppingListPage`
  - Nội dung: Categorized list (Rau củ, Thịt, Hải sản...), checkboxes

- [ ] **Hình 3.16g** - Shopping List - Filter chips
  - Nội dung: Tabs "Tất cả / Chưa mua / Đã mua"

- [ ] **Hình 3.16h** - Shopping List - Tick items
  - Nội dung: Items với checkbox checked/unchecked, strikethrough text

#### Macro Dashboard

- [ ] **Hình 3.17a** - Macro Dashboard - Weekly overview
  - Path: `/macro-dashboard`
  - File: `MacroDashboardPage`
  - Nội dung: Bar chart hoặc line chart (fl_chart) hiển thị Calories, Protein, Carbs, Fat theo 7 ngày

- [ ] **Hình 3.17b** - Macro Dashboard - Daily breakdown
  - Nội dung: Pie chart hoặc breakdown table cho 1 ngày cụ thể

---

### 3.4.7 Bảng xếp hạng đóng góp và Hồ sơ (Leaderboard & Profile)

Hệ thống vinh danh thành viên năng nổ trên Leaderboard với các huy hiệu Badge danh giá, đồng thời tab Profile cung cấp công cụ quản lý các Video Reels và bài đăng riêng tư.

#### Leaderboard

- [ ] **Hình 3.18a** - Leaderboard - Top tuần (Weekly)
  - Nội dung: List top users với rank (1, 2, 3...), avatar, name, score, badge icons (🥇🥈🥉)

- [ ] **Hình 3.18b** - Leaderboard - Top tháng (Monthly)
  - Nội dung: Monthly leaderboard với cùng format

- [ ] **Hình 3.18c** - Leaderboard - Badges showcase
  - Nội dung: Badge icons và descriptions (Top 1, Top 3, Top 10)

- [ ] **Hình 3.18d** - Leaderboard - Current user highlight
  - Nội dung: User's own position được highlight

#### Profile & Tabs

- [ ] **Hình 3.19a** - Profile - Own profile header
  - Path: `/profile` hoặc `/me`
  - File: `ProfilePage`
  - Nội dung: Avatar (lớn), Display name, Bio, Stats (Posts/Recipes/Reels counts), Edit button

- [ ] **Hình 3.19b** - Profile - Upload Avatar dialog (MỚI ⭐)
  - Nội dung: Bottom sheet với options "Chụp ảnh" (camera icon) và "Từ thư viện" (gallery icon)

- [ ] **Hình 3.19c** - Profile - Tab Posts
  - Nội dung: Grid của user's posts

- [ ] **Hình 3.19d** - Profile - Tab Recipes
  - Nội dung: Grid của user's recipes

- [ ] **Hình 3.19e** - Profile - Tab Reels (MỚI ⭐)
  - Nội dung: Grid vertical của user's reels (thumbnail + views count)

- [ ] **Hình 3.19f** - Profile - Tab Saved
  - Nội dung: Bookmarked recipes

- [ ] **Hình 3.19g** - Profile - Other user's profile
  - Path: `/profile/{uid}`
  - Nội dung: Profile header với Follow/Friend button thay vì Edit

#### Notifications và Friends

- [ ] **Hình 3.19h** - Notifications Page
  - Path: `/notifications`
  - File: `NotificationsPage`
  - Nội dung: List notifications (Like, Comment, Share, Follow, Friend Request), "Mark all as read"

- [ ] **Hình 3.19i** - Friends Page
  - Path: `/friends`
  - File: `FriendsPage`
  - Nội dung: Friends list, pending friend requests với Accept/Reject

#### Chat & Messaging

- [ ] **Hình 3.19j** - Chat List
  - Path: `/chat`
  - File: `ChatListPage`
  - Nội dung: Recent conversations (DM + Group), last message preview, timestamp

- [ ] **Hình 3.19k** - Chat Room - DM
  - Path: `/chat/{cid}`
  - File: `ChatRoomPage`
  - Nội dung: 1-1 chat với peer, messages, input box

- [ ] **Hình 3.19l** - Chat Room - Group
  - Nội dung: Group chat với multiple members, group name, member avatars

- [ ] **Hình 3.19m** - Chat Room - Send image
  - Nội dung: Message với ảnh attachment

---

## 3.5 GIAO DIỆN QUẢN TRỊ VIÊN (ADMIN PANEL)

Hệ thống cung cấp một bảng điều khiển trung tâm giúp Quản trị viên duyệt và ẩn bài viết vi phạm, xử lý các báo cáo cộng đồng và hiệu chỉnh trực tiếp các câu lệnh (Prompt) cho Chef AI.

### Admin Dashboard và Quản lý

- [ ] **Hình 3.20a** - Admin Dashboard - Overview
  - Path: `/admin/overview`
  - File: `AdminHomePage`
  - Nội dung: Stats cards (Total Users, Posts, Recipes, Reels), charts, quick actions

- [ ] **Hình 3.20b** - Admin Users - Quản lý người dùng
  - Path: `/admin/users`
  - File: `AdminUsersPage`
  - Nội dung: User table với columns (Email, Role, Status), Ban/Unban buttons, Change Role dropdown

- [ ] **Hình 3.20c** - Admin Content - Quản lý Posts/Recipes/Reels
  - Path: `/admin/content`
  - File: `AdminContentPage`
  - Nội dung: Content table với tabs (Posts/Recipes/Reels), Hide/Show, Delete actions

- [ ] **Hình 3.20d** - Admin Content - Duyệt Reels (MỚI ⭐)
  - Nội dung: Reels tab với video thumbnails, hidden status, approve/reject buttons

- [ ] **Hình 3.20e** - Admin Reports - Báo cáo vi phạm
  - Path: `/admin/reports`
  - File: `AdminReportsPage`
  - Nội dung: Reports table (Reporter, Target, Reason, Status, AI Verdict), Resolve/Dismiss actions

- [ ] **Hình 3.20f** - Admin Chat Moderation
  - Path: `/admin/chats`
  - File: `AdminChatModerationPage`
  - Nội dung: Chat violations list, Lock/Unlock chat buttons, View messages

- [ ] **Hình 3.20g** - Admin AI Prompts - Quản lý AI configs
  - Path: `/admin/ai-prompts`
  - File: `AdminAiPromptsPage`
  - Nội dung: AI configs list (Config name, Model, Status), Edit button

- [ ] **Hình 3.20h** - Admin AI Prompts - Edit dialog
  - Nội dung: Form edit model, temperature, systemPrompt, userPromptTemplate, enable/disable

- [ ] **Hình 3.20i** - Admin Settings - Cài đặt chung
  - Path: `/admin/settings`
  - File: `AdminSettingsPage`
  - Nội dung: App-level settings (Maintenance mode, Features toggles...)

- [ ] **Hình 3.20j** - Admin Audit Logs - Nhật ký hoạt động
  - Path: `/admin/audit-logs`
  - File: `AdminAuditLogsPage`
  - Nội dung: Activity logs table (Timestamp, User, Action, Target), read-only

---

## 📊 TỔNG KẾT VÀ LƯU Ý

### Tổng số hình minh họa: **75+ ảnh** cho Chương 3

**Phân bổ theo section**:
- 3.1 Kiến trúc: 2 ảnh
- 3.2 Cấu trúc: 2 ảnh
- 3.3 Bảo mật: 1 ảnh (có sẵn)
- 3.4 Giao diện chính: ~55 ảnh
  - Intro & Auth: 8 ảnh
  - Feed & Social: 8 ảnh
  - Reels: 5 ảnh ⭐
  - Recipes & FlippableDishCard: 12 ảnh ⭐
  - AI Assistant & i18n: 7 ảnh ⭐
  - Planner & Shopping: 8 ảnh
  - Leaderboard & Profile: 13 ảnh
- 3.5 Admin Panel: 10 ảnh

### Lưu ý khi chụp ảnh:

1. **Chất lượng ảnh**:
   - Resolution: Tối thiểu 1080p
   - Format: PNG hoặc JPG
   - Nén phù hợp cho file Word (< 500KB/ảnh nếu được)

2. **Dữ liệu mẫu**:
   - ✅ Sử dụng tên món ăn Việt Nam thật (Phở, Bún bò, Bánh mì...)
   - ✅ Ảnh món ăn đẹp, professional
   - ✅ Avatar réalistic
   - ✅ Comments có ý nghĩa, không spam

3. **Ngôn ngữ**:
   - Ưu tiên chụp giao diện **Tiếng Việt** cho báo cáo
   - Chụp thêm **English** cho Hình 3.15c để so sánh

4. **State của UI**:
   - Feed có nhiều posts (5-10 posts visible)
   - Comments có threaded replies
   - Profile có data đầy đủ (stats, posts, recipes, reels)
   - Admin tables có nhiều rows để thể hiện functionality

5. **Thứ tự ưu tiên chụp**:
   - **Cao nhất**: 3.6-3.7 (Intro/Auth), 3.8-3.9 (Feed/Social), 3.12-3.13 (FlippableDishCard, Recipe Detail)
   - **Trung bình**: 3.10 (Reels), 3.14-3.15 (AI, i18n), 3.16-3.17 (Planner)
   - **Thấp**: 3.20 (Admin) - có thể chụp sau

6. **Đặt tên file**:
   - Format: `H3_{số_thứ_tự}_{mô_tả_ngắn}.png`
   - Ví dụ: `H3_6a_splash_screen.png`, `H3_12c_flippable_card_back_ai_story.png`
   - Lưu vào: `docs/images/screenshots/`

7. **Đánh dấu hoàn thành**:
   - Sau khi chụp, đánh dấu ✅ vào checkbox
   - Ghi chú nếu cần retake: ❌ (reason)

### Tips để chụp ảnh đẹp:

- 📱 Sử dụng emulator Android (Pixel 5, API 33) hoặc Chrome responsive mode
- 🎨 Đảm bảo theme consistent (light mode hoặc dark mode)
- 🖼️ Crop ảnh sao cho không có white space thừa
- 📐 Giữ aspect ratio chuẩn mobile (9:16 hoặc 9:19.5)
- 🔍 Zoom in các phần quan trọng nếu cần (ví dụ: FlippableDishCard)

---

**Cập nhật lần cuối**: 2026-01-04  
**Dự án**: Vua Đầu Bếp Thủ Đức - Báo cáo Cuối kỳ  
**Chương**: 3 - Cài đặt và Xây dựng Ứng dụng
