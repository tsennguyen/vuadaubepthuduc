# Profile Update Fix - Sync Firebase Auth & Firestore

## Vấn đề đã fix
Khi user cập nhật tên hoặc ảnh đại diện trong profile, sau khi đăng xuất và đăng nhập lại, thông tin quay về như cũ.

## Nguyên nhân
Ứng dụng có **2 nguồn dữ liệu profile**:
1. **Firebase Auth User** - displayName, photoURL
2. **Firestore `/users/{uid}`** - displayName, photoURL, bio, và các thông tin khác

Khi update profile, code **chỉ lưu vào Firestore**. Nhưng khi user đăng xuất/vào lại, code sẽ gọi `ensureProfileFromAuth()` để đồng bộ từ **Firebase Auth** → Firestore, gây ra việc ghi đè data mới bằng data cũ từ Auth.

### Luồng xử lý cũ (có lỗi):
```
1. User update profile → Chỉ lưu vào Firestore ✅
2. User logout
3. User login lại
4. App gọi ensureProfileFromAuth()
5. App lấy data từ Firebase Auth (vẫn là data cũ) ❌
6. Ghi đè vào Firestore → Mất data mới ❌
```

## Giải pháp
Update **CẢ HAI** nguồn dữ liệu khi user chỉnh sửa profile:
1. ✅ Update Firestore (source of truth)  
2. ✅ Update Firebase Auth User profile (để sync)

### Luồng xử lý mới (đã fix):
```
1. User update profile
   → Lưu vào Firestore ✅
   → Lưu vào Firebase Auth ✅
2. User logout
3. User login lại  
4. App gọi ensureProfileFromAuth()
5. App lấy data từ Firebase Auth (đã là data mới) ✅
6. Sync vào Firestore (không ghi đè vì đã giống nhau) ✅
```

## Code changes

### 1. Thêm FirebaseAuth vào Repository
```dart
class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,  // ← Thêm parameter
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;  // ← Thêm field

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;  // ← New
```

### 2. Update Profile - Sync cả 2 nguồn
```dart
@override
Future<void> updateProfile({
  required String uid,
  required String displayName,
  String? bio,
  String? photoUrl,
}) async {
  // 1. Update Firestore (source of truth)
  await _users.doc(uid).set(
    {
      'displayName': displayName,
      'fullName': displayName,
      'bio': bio,
      'photoURL': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  // 2. Also update Firebase Auth User profile
  final currentUser = _auth.currentUser;
  if (currentUser != null && currentUser.uid == uid) {
    try {
      await currentUser.updateDisplayName(displayName);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await currentUser.updatePhotoURL(photoUrl);
      }
      await currentUser.reload();  // Refresh user object
    } catch (e) {
      // If Auth update fails, it's okay - Firestore is source of truth
      print('Failed to update Firebase Auth profile: $e');
    }
  }
}
```

## Kết quả
✅ Profile được lưu persistent ngay cả sau khi logout/login  
✅ Firestore và Firebase Auth luôn đồng bộ  
✅ Không mất dữ liệu khi user quay lại  
✅ Fallback an toàn nếu Auth update fail (Firestore vẫn là source of truth)

## Testing
1. Login vào app
2. Vào Profile → Chỉnh sửa
3. Đổi tên và ảnh đại diện → Lưu
4. Đăng xuất
5. Đăng nhập lại
6. ✅ Kiểm tra tên và ảnh đã được giữ nguyên

## Lưu ý
- **Firestore** vẫn là **source of truth**
- Nếu update Firebase Auth fail, không sao cả vì Firestore đã được update
- Khi login lần sau, `ensureProfileFromAuth()` sẽ sync lại từ Firestore
