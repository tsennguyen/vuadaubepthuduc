# Vua Đầu Bếp Thủ Đức - Flutter App

## 📱 Giới thiệu
Ứng dụng mạng xã hội chia sẻ công thức nấu ăn với tích hợp AI, chat, và quản lý thực đơn.

## 🛠️ Yêu cầu hệ thống

### Flutter SDK
- **Version:** Flutter 3.x trở lên
- **Dart SDK:** 3.0+

### Cài đặt Flutter & Dart SDK

#### Windows
```bash
# Download Flutter SDK từ: https://flutter.dev/docs/get-started/install/windows
# Giải nén và thêm vào PATH:
# C:\path\to\flutter\bin

# Kiểm tra cài đặt
flutter doctor

# Dart SDK đã đi kèm với Flutter, không cần cài riêng
dart --version
```

#### macOS
```bash
# Sử dụng Homebrew
brew install flutter

# Hoặc download từ: https://flutter.dev/docs/get-started/install/macos
flutter doctor
```

#### Linux
```bash
# Download và giải nén
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.x.x-stable.tar.xz
tar xf flutter_linux_3.x.x-stable.tar.xz

# Thêm vào PATH trong ~/.bashrc hoặc ~/.zshrc
export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor
```

### Firebase
- Tài khoản Firebase (project: `vuadaubepthuduc`)
- Firebase CLI: `npm install -g firebase-tools`

## 🚀 Cài đặt & Chạy Project

### 1. Clone Repository
```bash
git clone <repository-url>
cd VuaDauBepThuDuc
```

### 2. Cài đặt Dependencies
```bash
# Cài đặt tất cả packages
flutter pub get

# Nếu gặp lỗi, thử clean trước
flutter clean
flutter pub get
```

### 3. Cấu hình Firebase
```bash
# Login Firebase CLI
firebase login

# Chọn project
firebase use vuadaubepthuduc
```

### 4. Chạy ứng dụng

#### Web (Chrome)
```bash
flutter run -d chrome
```

#### Android Emulator
```bash
flutter run -d emulator-5554
```

#### iOS Simulator (macOS only)
```bash
flutter run -d iPhone
```

#### Physical Device
```bash
# Kết nối thiết bị qua USB và bật USB Debugging
flutter devices  # Xem danh sách thiết bị
flutter run -d <device-id>
```

## 🔧 Lệnh thường dùng

### Phân tích & Fix lỗi
```bash
# Phân tích code để tìm lỗi
flutter analyze

# Tự động fix một số lỗi (cẩn thận!)
dart fix --apply
```

### Clean & Rebuild
```bash
# Xóa build cache và dependencies cũ
flutter clean

# Cài lại packages
flutter pub get

# Rebuild từ đầu
flutter run
```

### Build Production

#### Android APK
```bash
# Build APK release
flutter build apk --release

# Build APK split theo ABI (file nhỏ hơn)
flutter build apk --split-per-abi

# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle (Google Play)
```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

#### iOS (macOS only)
```bash
flutter build ios --release

# Sau đó mở Xcode để archive và upload lên App Store
open ios/Runner.xcworkspace
```

#### Web
```bash
flutter build web --release

# Output: build/web/
# Deploy bằng: firebase deploy --only hosting
```

### Firebase Deploy
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Cloud Functions
cd functions
npm install
cd ..
firebase deploy --only functions

# Deploy Hosting (Web)
flutter build web --release
firebase deploy --only hosting

# Deploy tất cả
firebase deploy
```

## 📂 Cấu trúc Project

```
lib/
├── core/                 # Core utilities, themes, constants
├── features/             # Feature modules
│   ├── auth/            # Authentication
│   ├── recipe/          # Recipe management
│   ├── post/            # Social posts
│   ├── chat/            # Messaging
│   ├── notifications/   # Notifications
│   ├── profile/         # User profiles
│   ├── search/          # Search & AI
│   ├── planner/         # Meal planner
│   └── admin/           # Admin panel
└── main.dart            # App entry point

functions/               # Firebase Cloud Functions
├── src/
│   ├── ai/             # AI integration (Gemini)
│   └── moderation/     # Content moderation
```

## 🐛 Troubleshooting

### Lỗi: "Dart SDK not found"
```bash
# Kiểm tra PATH
echo $PATH  # macOS/Linux
echo %PATH% # Windows

# Thêm Flutter bin vào PATH
export PATH="$PATH:/path/to/flutter/bin"  # Thêm vào ~/.bashrc
```

### Lỗi: "CocoaPods not installed" (iOS)
```bash
# macOS only
sudo gem install cocoapods
pod setup
```

### Lỗi: "Gradle build failed" (Android)
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Lỗi: "Version solving failed"
```bash
# Update dependencies
flutter pub upgrade

# Hoặc xóa pubspec.lock và cài lại
rm pubspec.lock
flutter pub get
```

### Lỗi: Firebase configuration
```bash
# Re-download google-services.json (Android)
# Download từ Firebase Console → Project Settings → Android app

# Re-download GoogleService-Info.plist (iOS)
# Download từ Firebase Console → Project Settings → iOS app
```

## 📝 Git Workflow

```bash
# Tạo branch mới cho feature
git checkout -b feature/ten-feature

# Commit changes
git add .
git commit -m "feat: mô tả ngắn gọn"

# Push lên remote
git push origin feature/ten-feature

# Merge vào main (sau khi review)
git checkout main
git merge feature/ten-feature
git push origin main
```

## 🔑 Environment Variables

Các biến môi trường quan trọng (không commit vào Git):
- Firebase API keys → `google-services.json`, `GoogleService-Info.plist`
- OpenAI API key → Firebase Functions environment
- Gemini API key → Firebase Functions environment

## 📱 Test Accounts

### Admin
- Email: `admin@test.com`
- Password: (liên hệ project owner)

### Regular User
- Email: `user@test.com`
- Password: (liên hệ project owner)

## 🚀 Deployment Checklist

### Trước khi release:
- [ ] `flutter analyze` - không có error
- [ ] `flutter test` - tất cả test pass (nếu có)
- [ ] Update version trong `pubspec.yaml`
- [ ] Update Firebase rules nếu có thay đổi database schema
- [ ] Deploy Cloud Functions nếu có thay đổi backend
- [ ] Test trên real device (iOS + Android)
- [ ] Check performance (no memory leaks)
- [ ] Review security rules (Firestore, Storage)

### Build & Deploy:
```bash
# 1. Clean build
flutter clean
flutter pub get

# 2. Build APK/AAB
flutter build apk --release --split-per-abi
# hoặc
flutter build appbundle --release

# 3. Test APK trên device thật
flutter install --release

# 4. Deploy Firebase
firebase deploy

# 5. Upload lên Play Store/App Store
```

## 📞 Liên hệ

- **Project Owner:** [Tên của bạn]
- **Email:** [Email của bạn]
- **Firebase Project:** vuadaubepthuduc

## 📄 License

[Thêm license nếu cần]

---

**Last Updated:** 2025-12-30
**Flutter Version:** 3.x
**Dart Version:** 3.x
