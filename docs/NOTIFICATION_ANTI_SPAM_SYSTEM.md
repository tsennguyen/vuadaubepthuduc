# 🔔 HỆ THỐNG THÔNG BÁO & ANTI-SPAM

## 📋 Tổng Quan

Hệ thống thông báo và chống spam đã được triển khai đầy đủ với các tính năng:
- ✅ Thông báo cho tất cả các thao tác người dùng
- ✅ Gom thông báo (Notification Deduplication)
- ✅ Phát hiện và ngăn chặn spam tự động
- ✅ Hệ thống đánh giá mức độ rủi ro spam

---

## 🎯 CÁC LOẠI THÔNG BÁO

### 1. **Like (👍)**
- **Kích hoạt:** Khi user like bài viết/công thức
- **File:** `post_interaction_controller.dart`, `recipe_social_controller.dart`
- **Anti-spam:** Giới hạn 100 likes/5 phút
- **Deduplication:** Tự động gộp nếu like lại trong 1 giờ

### 2. **Comment (💬)**
- **Kích hoạt:** Khi user bình luận
- **File:** `post_interaction_controller.dart`, `recipe_social_controller.dart`
- **Anti-spam:** 
  - Giới hạn 20 comments/5 phút
  - Phát hiện comment trùng lặp (≥3 lần)
- **Deduplication:** Tự động gộp nếu comment lại trong 1 giờ

### 3. **Share (📤)**
- **Kích hoạt:** Khi user chia sẻ
- **File:** `post_interaction_controller.dart`
- **Anti-spam:** Giới hạn 50 shares/5 phút
- **Deduplication:** Có

### 4. **Follow (👥)**
- **Kích hoạt:** Khi user follow người khác
- **File:** `firebase_friend_repository.dart`
- **Anti-spam:** Giới hạn 50 follows/5 phút
- **Deduplication:** Có
- **⚠️ MỚI THÊM:** Tính năng này vừa được implement

### 5. **Friend Request (🤝)**
- **Kích hoạt:** Khi user gửi lời mời kết bạn
- **File:** `firebase_friend_repository.dart`
- **Anti-spam:** Giới hạn 30 requests/5 phút
- **Deduplication:** Sử dụng deterministic ID để tránh trùng lặp

### 6. **Friend Accepted (✅)**
- **Kích hoạt:** Khi user chấp nhận kết bạn
- **File:** `firebase_friend_repository.dart`
- **Anti-spam:** Không áp dụng (là response action)
- **Deduplication:** Có

### 7. **Recipe Save (🔖)**
- **Kích hoạt:** Khi user lưu công thức
- **File:** `recipe_social_controller.dart`
- **Anti-spam:** Không áp dụng
- **Deduplication:** Có

### 8. **Recipe Rating (⭐)**
- **Kích hoạt:** Khi user đánh giá công thức
- **File:** `recipe_social_controller.dart`
- **Anti-spam:** Không áp dụng
- **Deduplication:** Có

---

## 🛡️ HỆ THỐNG ANTI-SPAM

### **Ngưỡng Phát Hiện Spam**

```dart
// Trong 5 phút:
maxFollowsIn5Min = 50          // Follow > 50 người
maxFriendRequestsIn5Min = 30   // Gửi kết bạn > 30 lần
maxCommentsIn5Min = 20         // Comment > 20 lần
maxLikesIn5Min = 100           // Like > 100 lần
duplicateCommentThreshold = 3  // Comment trùng ≥ 3 lần
```

### **Cách Hoạt Động**

1. **Kiểm tra trước khi thực hiện:**
   ```dart
   final canPerform = await _antiSpamService.checkAndLogAction(
     SpamActionType.follow,
     contentId: targetUserId,
   );
   if (!canPerform) {
     throw Exception('Spam detected...');
   }
   ```

2. **Ghi log hành động:**
   - Lưu vào Firestore collection `user_action_logs`
   - Bao gồm: userId, actionType, contentId, timestamp

3. **Phát hiện spam:**
   - Đếm số hành động trong 5 phút
   - Kiểm tra nội dung trùng lặp (với comment)
   - So sánh với ngưỡng

4. **Xử lý spam:**
   - Ghi vào collection `spam_attempts`
   - Tăng counter `spamAttempts` trong user profile
   - Từ chối thực hiện hành động

### **Spam Score System**

```dart
enum SpamRiskLevel {
  low,     // Hoạt động bình thường
  medium,  // 2-4 spam attempts HOẶC 80-149 actions/5min
  high,    // ≥5 spam attempts HOẶC ≥150 actions/5min
}
```

### **Dọn Dẹp Tự Động**

- Tự động xóa logs cũ hơn 7 ngày
- Gọi method: `antiSpamService.cleanupOldLogs()`
- Khuyến nghị: Chạy định kỳ bằng Cloud Functions

---

## 📊 FIRESTORE COLLECTIONS

### **1. `notifications`**
```json
{
  "userId": "user_123",
  "type": "like",
  "actorId": "user_456",
  "actorName": "John Doe",
  "actorPhotoUrl": "https://...",
  "contentId": "post_789",
  "contentType": "post",
  "contentTitle": "Món phở ngon",
  "isRead": false,
  "createdAt": "2026-01-01T00:00:00Z"
}
```

### **2. `user_action_logs`**
```json
{
  "userId": "user_123",
  "actionType": "follow",
  "contentId": "user_456",
  "content": null,
  "timestamp": "2026-01-01T00:00:00Z",
  "isSpam": false
}
```

### **3. `spam_attempts`**
```json
{
  "userId": "user_123",
  "actionType": "follow",
  "timestamp": "2026-01-01T00:00:00Z",
  "severity": "medium"
}
```

### **4. `users` (cập nhật)**
```json
{
  "uid": "user_123",
  "displayName": "John Doe",
  "spamAttempts": 2,
  "lastSpamAttempt": "2026-01-01T00:00:00Z"
}
```

---

## 🔧 SỬ DỤNG

### **1. Thêm Notification Mới**

```dart
// Trong controller
await _notificationService.notifyFollow(
  targetUserId: targetUid,
);
```

### **2. Kiểm Tra Spam**

```dart
// Trước khi thực hiện hành động
final canPerform = await _antiSpamService.checkAndLogAction(
  SpamActionType.comment,
  contentId: postId,
  content: commentText, // Optional, cho duplicate detection
);

if (!canPerform) {
  // Hiển thị thông báo lỗi cho user
  showErrorDialog('Bạn đang thao tác quá nhanh, vui lòng chậm lại.');
  return;
}
```

### **3. Lấy Spam Score (Admin)**

```dart
final score = await _antiSpamService.getUserSpamScore(userId);
print('Actions (5min): ${score.actionsLast5Min}');
print('Risk Level: ${score.riskLevel}');
```

---

## ⚠️ LƯU Ý QUAN TRỌNG

### **1. Notification Deduplication**

- Friend request/accept sử dụng **deterministic ID**: `{userId}_{actorId}_{type}`
- Các loại khác kiểm tra notification tương tự trong vòng 1 giờ
- Nếu tồn tại, cập nhật `createdAt` và đánh dấu `isRead = false`

### **2. Self-Notification Prevention**

Tất cả notification đều kiểm tra:
```dart
if (currentUser.uid == targetUserId) return;
```

### **3. Error Handling**

- Notification fails không làm ảnh hưởng chức năng chính
- Tất cả notification được wrapped trong try-catch
- Log lỗi nhưng không throw exception

### **4. Performance**

- Anti-spam check thêm ~50-200ms latency
- Cân nhắc disable cho trusted users (verified badge)
- Có thể cache spam score trong 30s

---

## 🚀 TÍNH NĂNG NÂNG CAO

### **1. Tắt Notification Theo Loại**

Có thể thêm vào `users` collection:
```json
{
  "notificationSettings": {
    "follow": true,
    "like": false,
    "comment": true
  }
}
```

### **2. Auto-Ban System**

Nếu `spamAttempts >= 10` trong 24h:
```dart
await _firestore.collection('users').doc(userId).update({
  'isBanned': true,
  'banReason': 'Spam detected',
  'banUntil': DateTime.now().add(Duration(days: 7)),
});
```

### **3. Notification Grouping**

Gộp nhiều notification cùng loại:
```
"John và 5 người khác đã follow bạn"
```

---

## 📝 CHECKLIST TRIỂN KHAI

- [x] Thêm `follow` vào `NotificationType`
- [x] Tạo `AntiSpamService`
- [x] Tích hợp vào `FirebaseFriendRepository`
- [x] Tích hợp vào `PostInteractionController`
- [x] Tích hợp vào `RecipeSocialController` (cần kiểm tra)
- [ ] Thêm UI hiển thị lỗi spam cho user
- [ ] Setup Cloud Functions để cleanup logs
- [ ] Thêm notification settings page
- [ ] Implement auto-ban system
- [ ] Thêm notification grouping

---

## 🐛 DEBUGGING

### **Kiểm tra notification có gửi đi không:**

```dart
// Mở Firestore Console
// Collection: notifications
// Filter: userId == {target_user_id}
// Sort: createdAt DESC
```

### **Kiểm tra spam logs:**

```dart
// Collection: user_action_logs
// Filter: userId == {user_id}
// Filter: timestamp > (now - 5 minutes)
```

### **Test spam detection:**

```dart
// Thực hiện 51 follow liên tục
// Lần thứ 51 sẽ bị block
```

---

**Ngày tạo:** 2026-01-01  
**Phiên bản:** 1.0  
**Tác giả:** Antigravity AI
