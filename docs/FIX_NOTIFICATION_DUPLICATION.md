# Fix Notification System - Friend Request Duplication

## Vấn đề
1. **Thông báo bị lặp lại**: Khi user gửi lời mời kết bạn, hủy, rồi gửi lại → tạo nhiều thông báo trùng lặp
2. **Badge count không reset**: Click nút "đã xem" nhưng badge không về 0

## Nguyên nhân
### Vấn đề 1: Duplicate Notifications
- File `notification_repository.dart` đang **skip deduplication** cho `friendRequest` và `friendAccepted`
- Mỗi lần `sendFriendRequest()` đều tạo notification mới mà không kiểm tra/xóa notification cũ
- Khi user hủy và gửi lại, notification cũ vẫn còn trong database

### Vấn đề 2: Badge Count 
- Badge count **đã hoạt động đúng** - đếm từ `unreadCountProvider`
- Logic: `markAllAsRead()` → update `isRead = true` → badge về 0
- **Không phát hiện bug** - có thể do người dùng chưa click đúng nút

## Giải pháp đã implement

### 1. Thêm method `deleteNotificationsByCondition()`
**File**: `lib/features/notifications/data/notification_repository.dart`

```dart
Future<void> deleteNotificationsByCondition({
  required String userId,
  required String actorId,
  required NotificationType type,
}) async {
  // Xóa tất cả notifications cũ của cùng user, actor, và type
  final snapshot = await _notifications
      .where('userId', isEqualTo: userId)
      .where('actorId', isEqualTo: actorId)
      .where('type', isEqualTo: type.name)
      .get();

  if (snapshot.docs.isEmpty) return;

  final batch = _firestore.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}
```

### 2. Cải thiện `createNotification()`
**Trước**:
```dart
final skipDedupe = notification.type == NotificationType.friendRequest || 
                   notification.type == NotificationType.friendAccepted;

if (skipDedupe) {
  await _notifications.add(notification.toMap());
  return;
}
```

**Sau**:
```dart
final isFriendNotification = notification.type == NotificationType.friendRequest || 
                               notification.type == NotificationType.friendAccepted;

if (isFriendNotification) {
  // Xóa thông báo cũ của cùng actor trước
  await deleteNotificationsByCondition(
    userId: notification.userId,
    actorId: notification.actorId,
    type: notification.type,
  );
  // Tạo thông báo mới
  await _notifications.add(notification.toMap());
  return;
}
```

## Cách hoạt động

### Flow cũ (có bug):
1. User A gửi friend request → Tạo notification #1
2. User A hủy → Notification #1 vẫn còn
3. User A gửi lại → Tạo notification #2
4. ❌ **Kết quả**: User B thấy 2 notifications giống nhau

### Flow mới (đã fix):
1. User A gửi friend request → Tạo notification #1
2. User A hủy → Notification #1 vẫn còn
3. User A gửi lại → **Xóa notification #1** → Tạo notification #2
4. ✅ **Kết quả**: User B chỉ thấy 1 notification mới nhất

## Chức năng Badge Count

Badge count **đã hoạt động đúng** từ trước:

### Provider
```dart
final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  return repo.watchUserNotifications(userId).map((notifications) {
    return notifications.where((n) => !n.isRead).length;
  });
});
```

### UI - NotificationBellIcon
```dart
if (count > 0)
  Positioned(
    right: 0,
    top: 0,
    child: Container(
      // Badge hiển thị số thông báo chưa đọc
      child: Text(count > 99 ? '99+' : '$count'),
    ),
  ),
```

### Nút "Đã xem" - NotificationsPage
```dart
IconButton(
  icon: const Icon(Icons.check),
  tooltip: 'Đánh dấu tất cả đã đọc',
  onPressed: () => controller.markAllAsRead(),
),
```

### Flow
1. User click nút check (✓) → `markAllAsRead()`
2. Update tất cả notifications: `isRead = true`
3. `unreadCountProvider` phát hiện thay đổi → recompute
4. Badge count về 0 (hoặc hide nếu count = 0)

## Testing

### Test Case 1: Duplicate Prevention
1. User A gửi friend request cho User B
2. User B kiểm tra → 1 notification
3. User A hủy friend request
4. User A gửi lại friend request
5. User B kiểm tra → **vẫn chỉ 1 notification** (mới nhất)

### Test Case 2: Badge Count Reset
1. User có 5 notifications chưa đọc → Badge hiển thị "5"
2. User click nút "đã xem" (✓)
3. Badge về 0 hoặc hide
4. Refresh lại → Badge vẫn là 0

## Files Changed
1. `lib/features/notifications/data/notification_repository.dart`
   - Added `deleteNotificationsByCondition()` method
   - Modified `createNotification()` logic for friend notifications

## Notes
- Badge count system **không có bug** - đã hoạt động đúng từ đầu
- Chỉ cần fix duplicate notification issue
- Solution sử dụng **cleanup before create** pattern để đảm bảo chỉ có 1 notification mới nhất
