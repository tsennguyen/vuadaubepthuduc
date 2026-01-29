# Kiến trúc hệ thống

## 1. Tổng quan

- Client: Flutter (Android + Web) với Riverpod + GoRouter. Lớp `presentation` → `application` (controller/service) → `data` (repository).
- Backend: Firebase Auth, Firestore, Storage, Cloud Functions (Gemini + logic), FCM, Hosting (web).
- Realtime: Firestore stream cho feed, chat, planner, shopping list, notifications.

```mermaid
graph TD
  U[User] -->|login| Auth[Firebase Auth]
  U --> App[Flutter App]
  App -->|read/write| FS[Firestore]
  App -->|upload/download| ST[Storage]
  App -->|callable| CF[Cloud Functions]
  CF -->|Gemini API| AI[Gemini]
  CF --> FS
  CF --> ST
  CF --> FCM[FCM]
  FCM --> App
  App -->|web build| Hosting[Firebase Hosting]
```

## 2. Luồng nghiệp vụ chính

### Luồng 1: MXH (Login → Feed → Create Recipe → Like/Comment → Report → Admin xử lý → AuditLogs)

```mermaid
sequenceDiagram
  participant User
  participant App as Flutter App
  participant Auth as Firebase Auth
  participant FS as Firestore
  participant ST as Storage
  participant CF as Cloud Functions
  participant Admin

  User->>Auth: Đăng nhập (Email/Google/Facebook)
  Auth-->>App: Token + uid
  App->>FS: Stream feed (posts/recipes)
  User->>App: Tạo recipe + ảnh
  App->>ST: Upload cover/photo
  App->>FS: Ghi recipes/{rid} (+searchTokens auto)
  User->>App: Like/Comment/Rating/Share
  App->>FS: Ghi subcollection reactions/comments/ratings/shares
  CF-->>FS: Aggregate counts
  User->>App: Report nội dung
  App->>FS: Ghi reports/{id}
  CF-->>FS: report_moderation (tăng reportsCount, ẩn tạm), ai_moderation (aiVerdict), auditLogs
  Admin->>FS: Đọc /admin (reports, auditLogs)
  Admin->>FS: Update status report (resolved/ignored)
```

### Luồng 2: Planner → Shopping List → Macro Dashboard

```mermaid
sequenceDiagram
  participant User
  participant App as Flutter App
  participant FS as Firestore
  participant CF as Cloud Functions

  User->>App: Xem RecipeDetail
  User->>App: Add to Meal Plan
  App->>FS: Ghi mealPlans/{uid}/days/{date}/meals/{mealId}
  User->>App: AI tạo meal plan tuần (tùy chọn)
  App->>CF: call aiGenerateMealPlan(userId, weekStart)
  CF->>FS: Clear & ghi meals cho tuần
  User->>App: Generate shopping list từ mealPlans
  App->>FS: upsert shoppingLists/{uid}/items (client merge)
  User->>App: Tick/untick item
  App->>FS: Update checked
  User->>App: Mở Macro Dashboard
  App->>FS: Đọc meals + recipes.macros
  App-->>User: Hiển thị tổng calories/protein/carb/fat
```

## 3. Module Flutter (`lib/features/*`)

- auth: đăng nhập, đăng ký, đồng bộ profile user (`users/{uid}`).
- feed: render post/recipe card stream, pagination.
- post: tạo/sửa/xóa post, upload ảnh, like/comment/share.
- recipe: tạo/sửa/xóa recipe, upload ảnh, rating/bookmark, detail page.
- recipes: danh sách recipe (grid/list, summary).
- search: tìm kiếm theo token/tag, có AI search parser (Functions).
- chat: DM/group, typing, read receipt, trigger Functions createDM/createGroup.
- planner: quản lý mealPlans, AI generate meal plan, generate shopping list.
- shopping: CRUD shoppingLists items, tick/untick, clear checked.
- nutrition: macro calculator/dashboard đọc recipes.macros + estimatedMacros từ mealPlans.
- report: gửi report; admin module đọc & xử lý.
- admin: màn hình báo cáo, audit logs, user/content moderation.
- leaderboard: hiển thị top tuần/tháng (Firestore `leaderboards/{period}`).
- notifications: FCM + Firestore `notifications/{uid}/items`.
- core/app: router, theme, analytics, common widgets; data layer sử dụng repository pattern (Firestore/Functions/Storage adapters).
- backend: `functions/src/*` (search_tokens, aggregates, ai_*, chat, leaderboard, report_moderation, planner_notifs/social_notifs).

Phụ thuộc: UI → controller/service (application) → repository (data) → Firebase SDK / Cloud Functions. State quản lý bằng Riverpod, điều hướng bằng GoRouter.

