# Firebase Storage Rules Configuration

## Vấn đề hiện tại
Lỗi: `[firebase_storage/unauthorized] User is not authorized to perform the desired action.`

Người dùng không có quyền upload ảnh lên Firebase Storage.

## Giải pháp

### Bước 1: Truy cập Firebase Console
1. Vào https://console.firebase.google.com
2. Chọn project **VuaDauBepThuDuc**
3. Trong menu bên trái, chọn **Storage**
4. Chọn tab **Rules**

### Bước 2: Cập nhật Storage Rules
Thay thế rules hiện tại bằng code sau:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Profile avatars - chỉ user được upload vào folder của mình
    match /profiles/{userId}/{allPaths=**} {
      allow read: if true;  // Ai cũng có thể xem
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Posts - user đã login có thể upload
    match /posts/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Recipes - user đã login có thể upload
    match /recipes/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### Bước 3: Publish Rules
1. Nhấn nút **Publish** màu xanh
2. Đợi vài giây để rules được apply

### Bước 4: Test lại
1. Reload app Flutter
2. Vào Profile → Chỉnh sửa
3. Nhấn icon camera để chọn ảnh
4. Upload sẽ thành công! ✅

## Giải thích Rules

- **profiles/{userId}/** - Mỗi user chỉ upload được vào folder của mình
- **posts/** và **recipes/** - User đã đăng nhập có thể upload
- **allow read: if true** - Tất cả mọi người có thể xem ảnh (public read)
- **request.auth != null** - Kiểm tra user đã đăng nhập
- **request.auth.uid == userId** - Đảm bảo user chỉ upload vào folder của mình

## Lưu ý bảo mật

⚠️ **QUAN TRỌNG**: Rules trên phù hợp cho development và production. 

Nếu cần thêm giới hạn:
- Giới hạn kích thước file: `request.resource.size < 5 * 1024 * 1024` (5MB)
- Chỉ cho phép ảnh: `request.resource.contentType.matches('image/.*')`

## Ví dụ Rules có giới hạn:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profiles/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null 
                   && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024  // Max 5MB
                   && request.resource.contentType.matches('image/.*'); // Chỉ ảnh
    }
    
    match /posts/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024; // Max 10MB
    }
    
    match /recipes/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024;
    }
  }
}
```

## Troubleshooting

### Lỗi vẫn còn sau khi update rules?
1. Đợi 30s - 1 phút để rules được propagate
2. Hard refresh app (hot restart)
3. Kiểm tra user đã đăng nhập chưa (Firebase Auth)
4. Xem tab Console trong Firebase để xem logs

### Kiểm tra user đã đăng nhập?
```dart
final currentUser = FirebaseAuth.instance.currentUser;
print('User: ${currentUser?.uid}'); // Phải có UID
```
