# Kế hoạch cải thiện Admin Panel

## Vấn đề đã phát hiện:

### 1. ✅ Tìm kiếm không hoạt động
**Status**: Code search đã hoạt động đúng
**Giải pháp**: Không cần sửa, search đang hoạt động bình thường

### 2. ❌ User bị khóa vẫn login được
**Vấn đề**: Sau khi admin đặt `disabled: true` hoặc `isBanned: true`, user vẫn có thể login
**Nguyên nhân**: Firebase Auth không tự động check Firestore fields
**Giải pháp**: 
- Thêm middleware check sau mỗi lần login
- Kiểm tra `disabled` và `isBanned` từ Firestore
- Force signOut nếu user bị ban

### 3. ❌ Thiếu tính năng quản lý user đầy đủ
**Cần thêm**:
- View user details/stats
- Reset password
- Delete account
- View user activity logs
- Send notification to user
- Temporary ban (với thời gian)
- Permanent ban
- View reported content by user

## Implementation Plan:

### Phase 1: Fix Login Ban Check ⚠️ CRITICAL
**Files to modify:**
- `lib/features/auth/data/firebase_auth_repository.dart`
- `lib/features/auth/application/auth_controller.dart` (if exists)

**Changes:**
```dart
// After successful login, check Firestore
Future<void> _checkUserStatus(String uid) async {
  final doc = await _firestore.collection('users').doc(uid).get();
  final data = doc.data();
  
  if (data?['disabled'] == true) {
    await signOut();
    throw AuthException('Tài khoản của bạn đã bị khóa bởi quản trị viên.');
  }
  
  if (data?['isBanned'] == true) {
    await signOut();
    final banReason = data?['banReason'] as String?;
    final banUntil = (data?['banUntil'] as Timestamp?)?.toDate();
    
    if (banUntil != null && DateTime.now().isAfter(banUntil)) {
      // Unban automatically
      await _firestore.collection('users').doc(uid).update({
        'isBanned': false,
        'banReason': null,
        'banUntil': null,
      });
      return;
    }
    
    await signOut();
    throw AuthException(
      'Tài khoản bị cấm${banReason != null ? ": $banReason" : ""}.'
    );
  }
}
```

### Phase 2: Enhanced User Management UI
**Files to create/modify:**
- `lib/features/admin/presentation/user_detail_page.dart` (NEW)
- `lib/features/admin/presentation/admin_users_page.dart` (MODIFY)
- `lib/features/admin/data/admin_user_repository.dart` (MODIFY)

**New features:**
1. **User Detail Page**:
   - User info card
   - Account status
   - Activity stats (posts, recipes, comments)
   - Recent activity timeline
   - Action buttons (ban, reset password, delete)

2. **Enhanced Users List**:
   - Filter by: All, Active, Banned, Admin, Moderator
   - Bulk actions
   - Export user list

3. **Ban Dialog**:
   - Ban reason (required)
   - Ban duration (permanent / temporary)
   - Confirmation

### Phase 3: Advanced Admin Features
**New repositories/services:**
- User analytics service
- Activity log service
- Notification service for admins

**Features:**
- Dashboard with user growth charts
- Most active users
- Recently registered users
- Flagged accounts
- Content moderation queue

## Priority:
1. **Phase 1** - URGENT (security issue)
2. **Phase 2** - HIGH (core admin functionality)
3. **Phase 3** - MEDIUM (nice to have)

## Files Structure:
```
lib/features/admin/
├── data/
│   ├── admin_user_repository.dart (update)
│   ├── admin_analytics_repository.dart (new)
│   └── admin_activity_repository.dart (new)
├── application/
│   ├── admin_users_controller.dart (new)
│   └── admin_analytics_controller.dart (new)
└── presentation/
    ├── admin_users_page.dart (update)
    ├── user_detail_page.dart (new)
    ├── widgets/
    │   ├── ban_user_dialog.dart (new)
    │   ├── user_stats_card.dart (new)
    │   └── user_activity_timeline.dart (new)
```

## Next Steps:
1. Implement Phase 1 first (ban check on login)
2. Test thoroughly
3. Then move to Phase 2

Bạn muốn tôi bắt đầu implement Phase nào trước?
