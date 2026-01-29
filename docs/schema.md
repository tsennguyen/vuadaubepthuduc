# Firestore & Storage Schema

Tài liệu này bám theo code Flutter (repositories/models) và Cloud Functions hiện có. Các timestamp dùng `FieldValue.serverTimestamp()` khi ghi.

## users/{uid}

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| uid | string | id | Trùng doc id | Set khi tạo từ Auth |
| email | string | yes | Email đăng nhập | |
| displayName / fullName / name | string | yes | Tên hiển thị | Một trong các field có thể tồn tại |
| photoURL | string | no | Avatar URL | Upload tại `user_avatars/{uid}` |
| bio | string | no | Giới thiệu ngắn | |
| provider | string | no | password/google/facebook | Lưu khi tạo user |
| role | string | yes | admin\|moderator\|client | Default client (Functions `onUserCreate`) |
| createdAt | Timestamp | yes | Thời điểm tạo | |
| updatedAt | Timestamp | no | Thời điểm cập nhật | |
| lastLoginAt | Timestamp | no | Lần đăng nhập cuối | |
| plannerSettings | map | no | {enabled: bool, minutesBefore: number} | Dùng notification meal plan |
| macroTarget | map | no | {calories, protein, carbs, fat} (per day) | Dùng macro dashboard & AI meal plan |
| dietGoal | string | no | lose_weight\|maintain\|gain_muscle | Input cho AI meal plan |
| mealsPerDay | number | no | Số bữa mục tiêu | Input cho AI meal plan |
| favoriteIngredients | string[] | no | Nguyên liệu ưa thích | Input AI meal plan |
| allergies | string[] | no | Dị ứng cần tránh | Input AI meal plan |
| stats | map | no | {postCount, recipeCount, reactionCount, commentCount, shareCount, weekScore, monthScore} | Dùng Functions leaderboard |

Subcollection `users/{uid}/bookmarks/{rid}` (bookmark recipe):

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| recipeId | string | yes | ID recipe | trùng doc id |
| bookmarkedAt | Timestamp | yes | Thời điểm lưu | |

Ví dụ:

```json
{
  "uid": "u123",
  "email": "chef@example.com",
  "displayName": "Anh Đầu Bếp",
  "photoURL": "https://.../avatar.jpg",
  "role": "client",
  "provider": "google",
  "createdAt": "2025-01-10T12:00:00Z",
  "lastLoginAt": "2025-03-01T05:00:00Z",
  "plannerSettings": { "enabled": true, "minutesBefore": 30 },
  "dietGoal": "maintain",
  "macroTarget": { "calories": 2000, "protein": 90, "carbs": 250, "fat": 70 },
  "stats": { "postCount": 5, "recipeCount": 3, "weekScore": 40 }
}
```

## posts/{pid}

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| authorId | string | yes | UID tác giả | |
| title | string | yes | Tiêu đề bài viết | |
| body | string | yes | Nội dung | |
| photoURLs | string[] | no | Ảnh bài viết | Upload Storage `posts/{pid}/...` |
| tags | string[] | no | Tag tìm kiếm | |
| searchTokens | string[] | auto | Token tìm kiếm (Functions `search_tokens`) | |
| likesCount | number | yes | Tổng like | Cloud Function aggregate |
| commentsCount | number | yes | Tổng comment | Cloud Function aggregate |
| sharesCount | number | yes | Tổng share | Cloud Function aggregate |
| hidden | bool | yes | Đánh dấu ẩn | soft delete |
| reportsCount | number | no | Số report tích lũy | Functions `report_moderation` |
| isHiddenPendingReview | bool | no | Ẩn tạm khi bị report nhiều | Functions `report_moderation` |
| createdAt | Timestamp | yes | | |
| updatedAt | Timestamp | no | | |

Subcollections:

- `posts/{pid}/reactions/{uid}`: `{type: "like", createdAt}` (doc id = uid).
- `posts/{pid}/comments/{cid}`: `{authorId, content, createdAt}`.
- `posts/{pid}/shares/{uid}`: `{createdAt}` (doc id = uid).
- `posts/{pid}/ratings/{uid}`: không dùng cho UI hiện tại nhưng rules cho phép; schema: `{stars, createdAt, updatedAt}`.

Ví dụ:

```json
{
  "title": "Món gà nướng mật ong",
  "body": "Mình thử công thức này cuối tuần...",
  "authorId": "u123",
  "photoURLs": ["https://.../posts/p1/1700000000_0.jpg"],
  "tags": ["nuong", "ga"],
  "searchTokens": ["mon", "ga", "nuong"],
  "likesCount": 12,
  "commentsCount": 3,
  "sharesCount": 1,
  "hidden": false,
  "createdAt": "2025-03-01T08:00:00Z"
}
```

## recipes/{rid}

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| authorId | string | yes | UID tác giả | |
| title | string | yes | Tên món | |
| description | string | yes | Mô tả | |
| cookTimeMinutes | number | no | Thời gian nấu | |
| difficulty | string | no | easy/medium/hard? | UI tự do |
| ingredients | string[] | yes | Danh sách nguyên liệu (thô) | |
| steps | string[] | yes | Các bước | |
| tags | string[] | no | Tags | |
| coverURL | string | yes | Ảnh cover | Storage `recipes/{rid}/cover.jpg` |
| photoURLs | string[] | no | Thư viện ảnh | Storage `recipes/{rid}/photo_i.jpg` |
| ingredientsTokens | string[] | auto/AI | Token nguyên liệu | AI enrich + search_tokens |
| searchTokens | string[] | auto | Token tìm kiếm | Functions `search_tokens` |
| macros | map | no | {calories, protein, carbs, fat} per serving | Lưu sau AI nutrition (nếu dùng) |
| likesCount | number | yes | | aggregate |
| commentsCount | number | yes | | aggregate |
| ratingsCount | number | yes | | aggregate |
| avgRating | number | yes | | aggregate |
| sharesCount | number | yes | | aggregate |
| hidden | bool | yes | Soft delete | |
| reportsCount | number | no | Số report | Functions `report_moderation` |
| isHiddenPendingReview | bool | no | Ẩn tạm | |
| createdAt | Timestamp | yes | | |
| updatedAt | Timestamp | no | | |

Subcollections:

- `recipes/{rid}/reactions/{uid}`: `{type: "like", createdAt}`.
- `recipes/{rid}/comments/{cid}`: `{authorId, content, createdAt}`.
- `recipes/{rid}/ratings/{uid}`: `{stars (1-5), createdAt, updatedAt}`.
- `recipes/{rid}/shares/{uid}`: `{createdAt}`.

Ví dụ:

```json
{
  "title": "Phở bò nhanh",
  "description": "Phiên bản phở bò nấu nhanh 30 phút.",
  "authorId": "u123",
  "ingredients": ["500g thịt bò", "1 gói bánh phở", "hành tây"],
  "steps": ["Sơ chế thịt", "Nấu nước dùng", "Trụng bánh phở"],
  "tags": ["pho", "vietnamese"],
  "coverURL": "https://.../recipes/r1/cover.jpg",
  "photoURLs": ["https://.../recipes/r1/photo_0.jpg"],
  "cookTimeMinutes": 30,
  "difficulty": "medium",
  "ingredientsTokens": ["thit_bo", "banh_pho", "hanh_tay"],
  "searchTokens": ["pho", "bo", "nhanh"],
  "likesCount": 20,
  "commentsCount": 5,
  "ratingsCount": 4,
  "avgRating": 4.5,
  "hidden": false,
  "createdAt": "2025-02-20T02:00:00Z"
}
```

## chats/{cid}

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| type | string | yes | "dm" \| "group" | |
| name | string | no | Tên group | group chat |
| ownerId | string | no | Người tạo | |
| createdBy | string | no | Người tạo (Functions) | |
| memberIds | string[] | yes | Thành viên | dùng rule isChatMember |
| lastMessageAt | Timestamp | no | Thời điểm tin nhắn cuối | trigger aggregate |
| lastMessageText | string | no | Preview | |
| typing | map | no | {uid: bool} trạng thái gõ | |
| createdAt | Timestamp | no | | |

Subcollection `chats/{cid}/messages/{mid}`:

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| senderId | string | yes | UID người gửi | |
| text | string | yes | Nội dung | |
| attachments | any[] | no | Reserved | hiện để trống |
| readBy | string[] | yes | UID đã đọc | mặc định chứa sender |
| createdAt | Timestamp | yes | | |

Ví dụ chat:

```json
{
  "type": "group",
  "name": "Team Ẩm thực",
  "memberIds": ["u123", "u456"],
  "ownerId": "u123",
  "lastMessageAt": "2025-03-01T09:00:00Z",
  "lastMessageText": "Giao recipe mới nhé!",
  "createdAt": "2025-03-01T08:50:00Z"
}
```

## reports/{id}

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| targetType | string | yes | "post"\|"recipe"\|"message"\|"user" | |
| targetId | string | yes | ID target | |
| chatId | string | conditional | Bắt buộc nếu targetType=message | |
| reasonCode | string | yes | spam\|inappropriate\|violence\|fake_info\|hate\|other | |
| reasonText | string | no | Mô tả thêm | |
| reporterId | string | yes | UID người report | |
| status | string | yes | pending\|resolved\|ignored | admin cập nhật |
| createdAt | Timestamp | yes | | |
| aiVerdict | map | no | {label, confidence, notes} | Functions `ai_moderation` |

Ví dụ:

```json
{
  "targetType": "recipe",
  "targetId": "r1",
  "reasonCode": "spam",
  "reasonText": "Nội dung quảng cáo",
  "reporterId": "u789",
  "status": "pending",
  "createdAt": "2025-03-01T10:00:00Z",
  "aiVerdict": { "label": "spam", "confidence": 0.82, "notes": "Lặp lại từ khóa quảng cáo" }
}
```

## mealPlans/{uid}/days/{yyyy-MM-dd}/meals/{mealId}

Day doc (`mealPlans/{uid}/days/{dayId}`): `{dayId, updatedAt}` (dùng để giữ chỗ).

Meal doc:

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| mealType | string | yes | breakfast\|lunch\|dinner\|snack | |
| recipeId | string | yes | recipes/{rid} | |
| title | string | no | Tên món hiển thị | AI có thể fill |
| note | string | no | Ghi chú | |
| servings | number | yes | Khẩu phần | |
| plannedFor | Timestamp | no | Thời điểm bữa ăn | |
| estimatedMacros | map | no | {calories, protein, carbs, fat} per serving | từ AI meal plan |
| createdAt | Timestamp | yes | | |
| updatedAt | Timestamp | no | | |

Ví dụ:

```json
{
  "mealType": "breakfast",
  "recipeId": "r1",
  "title": "Yến mạch chuối",
  "servings": 1,
  "plannedFor": "2025-03-10T07:30:00Z",
  "estimatedMacros": { "calories": 350, "protein": 18, "carbs": 45, "fat": 8 },
  "createdAt": "2025-03-05T03:00:00Z"
}
```

## shoppingLists/{uid}/items/{itemId}

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| name | string | yes | Tên nguyên liệu | |
| quantity | number | yes | Số lượng | cộng dồn khi sync |
| unit | string | yes | Đơn vị (g, ml, cái, ...) | |
| category | string | yes | veg\|meat\|condiments\|grain\|dairy\|other | fallback other |
| checked | bool | yes | Đã mua? | default false |
| sourceRecipeIds | string[] | yes | Recipe liên quan | arrayUnion khi upsert |
| updatedAt | Timestamp | yes | | |

Ví dụ:

```json
{
  "name": "Ức gà",
  "quantity": 500,
  "unit": "g",
  "category": "meat",
  "checked": false,
  "sourceRecipeIds": ["r1", "r9"],
  "updatedAt": "2025-03-02T12:00:00Z"
}
```

## leaderboards/{period}

`period` = "week" \| "month" (hoặc custom).

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| updatedAt | Timestamp | yes | Lần tính gần nhất | set bằng JS Date trong Functions |
| scores | map | yes | {uid: scoreNumber} | tính từ users.stats |

Ví dụ:

```json
{
  "updatedAt": "2025-03-01T00:00:00Z",
  "scores": {
    "u123": 120,
    "u456": 95
  }
}
```

## auditLogs/{id}

| fieldName | type | required? | mô tả | ghi chú |
| --- | --- | --- | --- | --- |
| type | string | yes | Loại sự kiện (reportCreated, adminAction, ...) | |
| actorId | string | no | UID tác nhân | admin hoặc "system" |
| targetType | string | no | post/recipe/message/user/report/... | |
| targetId | string | no | ID target | |
| metadata | map | no | Thông tin mở rộng | ví dụ chatId, reportId, newReportsCount |
| createdAt | Timestamp | yes | | append-only |

Ví dụ:

```json
{
  "type": "reportCreated",
  "actorId": "system",
  "targetType": "recipe",
  "targetId": "r1",
  "metadata": { "reportId": "rep123", "chatId": null, "newReportsCount": 6 },
  "createdAt": "2025-03-01T10:00:05Z"
}
```

## Storage structure

- `user_avatars/{uid}/avatar.jpg`: avatar người dùng (≤5MB, image/*).
- `posts/{pid}/{timestamp}_{i}.jpg`: ảnh post, upload qua PostStorageService.
- `recipes/{rid}/cover.jpg`: ảnh cover recipe.
- `recipes/{rid}/photo_{i}.jpg`: album ảnh recipe.

Quy ước: giữ tên file ngắn, lowercase; tránh khoảng trắng; dùng timestamp/index để tránh trùng.

## Collection bổ trợ (đang có trong code)

- `notifications/{uid}/items/{id}`: `{type, title, body, fromUid, targetType, targetId, read, createdAt}`.
- `aiChats/{uid}/sessions/{sessionId}/messages/{mid}`: AI “Đầu bếp ảo” lịch sử chat `{role: "user"|"assistant", content, createdAt}`.

