# Vua Đầu Bếp Thủ Đức - Project Handover Document

## 📦 Bản build mới nhất

**Release Date:** 2025-12-30  
**APK Location:** `build/app/outputs/flutter-apk/app-release.apk`  
**APK Size:** 66.7 MB  
**Version:** Check `pubspec.yaml` for current version

---

## 🛠️ Thiết lập môi trường phát triển

### 1. Yêu cầu hệ thống
- **Flutter SDK:** 3.x+
- **Dart SDK:** 3.x+ (đi kèm Flutter)
- **Android Studio** hoặc **VS Code**
- **Firebase CLI:** `npm install -g firebase-tools`
- **Git**

### 2. Cài đặt Flutter & Dart

#### Windows
```bash
# Download Flutter từ: https://flutter.dev/docs/get-started/install/windows
# Giải nén và thêm vào System PATH:
# Ví dụ: C:\src\flutter\bin

# Verify cài đặt
flutter doctor

# Dart đã tích hợp sẵn
dart --version
```

#### macOS
```bash
brew install flutter
flutter doctor
```

#### Linux
```bash
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.x.x-stable.tar.xz
tar xf flutter_linux_3.x.x-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor
```

### 3. Setup Project

```bash
# Clone repository
git clone <repository-url>
cd VuaDauBepThuDuc

# Cài dependencies
flutter pub get

# Nếu gặp lỗi
flutter clean
flutter pub get
```

---

## ▶️ Chạy ứng dụng

### Web (Development)
```bash
flutter run -d chrome
```

### Android
```bash
# Kết nối device/emulator
flutter devices

# Run
flutter run
```

### iOS (macOS only)
```bash
flutter run -d iPhone
```

---

## 🏗️ Build Production

### Android APK
```bash
# Clean build trước
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# Build split APK theo CPU architecture (nhỏ hơn)
flutter build apk --split-per-abi
# Output: app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk, app-x86_64-release.apk
```

###  App Bundle (Google Play)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS (macOS only)
```bash
flutter build ios --release
open ios/Runner.xcworkspace
# Archive và upload trong Xcode
```

### Web
```bash
flutter build web --release
# Output: build/web/

#Deploy lên Firebase Hosting
firebase deploy --only hosting
```

---

## 🐛 Debug & Fix lỗi

### Phân tích code
```bash
# Check lỗi
flutter analyze

# Tự động fix một số lỗi đơn giản
dart fix --apply
```

### Clean cache
```bash
flutter clean
flutter pub get
flutter run
```

### Xóa build cũ
```bash
# Windows
rmdir /s /q build

# macOS/Linux
rm -rf build
```

---

## 🔥 Firebase Configuration

### Login
```bash
firebase login
firebase use vuadaubepthuduc
```

### Deploy

#### Firestore Rules
```bash
firebase deploy --only firestore:rules
```

#### Cloud Functions
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

#### Storage Rules
```bash
firebase deploy --only storage
```

#### Hosting (Web)
```bash
flutter build web --release
firebase deploy --only hosting
```

#### Deploy tất cả
```bash
firebase deploy
```

---

## 🆕 Tính năng mới nhất - Phiên bản 2025

### 1. Hệ thống Reels (Video ngắn)
**Mô tả**: Tính năng chia sẻ video ngắn dạng TikTok/Instagram Reels

**Tính năng chính**:
- ✅ Tạo reel: Upload video, thumbnail, title, description, tags
- ✅ Feed reels: Xem theo thời gian, trending (7 ngày), search
- ✅ Tương tác đầy đủ: Like, Comment, Share, Save
- ✅ View counter: Đếm lượt xem tự động
- ✅ Profile integration: Tab Reels riêng trong profile
- ✅ **Admin moderation**: Duyệt/ẩn reels qua trường `hidden`
- ✅ Video player: Auto-play, controls, responsive

**Files quan trọng**:
```
lib/features/reels/
├── data/
│   ├── reel_model.dart (Model với videoUrl, thumbnailUrl, duration, viewsCount)
│   ├── reel_repository.dart (CRUD, trending, search)
│   ├── reel_interaction_repository.dart (Like, comment, share)
│   └── reel_storage_service.dart (Upload video/thumbnail)
├── application/
│   ├── reels_controller.dart (State management)
│   └── reel_form_controller.dart (Create/edit reels)
└── presentation/
    ├── reels_page.dart (Feed reels)
    ├── create_reel_page.dart (Tạo reel mới)
    └── widgets/reel_video_player.dart (Video player component)
```

**Firestore Collection**:
```
reels/{reelId}
├── authorId: string
├── videoUrl: string
├── thumbnailUrl: string
├── title: string
├── description: string
├── tags: array<string>
├── searchTokens: array<string>
├── duration: number (seconds)
├── hidden: boolean (cho admin)
├── likesCount, commentsCount, sharesCount, viewsCount: number
├── createdAt, updatedAt: timestamp
└── subcollections: reactions/{uid}, comments/{id}, shares/{uid}
```

### 2. Đa ngôn ngữ Vi/En (Localization)
**Mô tả**: Hỗ trợ đầy đủ Tiếng Việt và English trong toàn bộ ứng dụng

**Tính năng**:
- ✅ 345+ strings được localize trong `lib/app/l10n.dart`
- ✅ Tự động theo ngôn ngữ thiết bị
- ✅ Chuyển đổi ngôn ngữ realtime qua `localeProvider`
- ✅ Hỗ trợ toàn bộ: Navigation, Auth, Feed, Chat, Profile, Create Post/Recipe, Notifications, Errors

**Sử dụng**:
```dart
import 'package:vua_dau_bep_thu_duc/app/l10n.dart';
import 'package:vua_dau_bep_thu_duc/app/language_controller.dart';

// Trong widget
final s = S(ref.watch(localeProvider));
Text(s.feed); // "Bảng tin" (vi) hoặc "Feed" (en)

// Đổi ngôn ngữ
ref.read(localeProvider.notifier).state = Locale('en');
```

**Files**:
- `lib/app/l10n.dart` - Tất cả strings
- `lib/app/language_controller.dart` - Provider quản lý locale
- `pubspec.yaml` - flutter_localizations, intl dependencies

### 3. AI nhận diện nguồn gốc món ăn
**Mô tả**: Widget lật thẻ 3D để xem câu chuyện/nguồn gốc món ăn qua AI

**Tính năng**:
- ✅ `FlippableDishCard`: Flip animation 3D trên ảnh món ăn
- ✅ Tap để xem fun fact về món (2-3 câu ngắn)
- ✅ AI Chef Service tự động lấy thông tin theo ngôn ngữ Vi/En
- ✅ Hero animation tích hợp trong RecipeDetailPage

**Sử dụng**:
```dart
FlippableDishCard(
  imageUrl: recipe.coverImageUrl,
  dishName: recipe.title,
  heroTag: 'recipe-${recipe.id}-cover',
  onFlip: (isFlipped) => print('Card flipped: $isFlipped'),
)
```

**Files**:
- `lib/features/recipe/presentation/widgets/flippable_dish_card.dart`
- Tích hợp trong `RecipeDetailPage`

### 4. Upload Avatar từ máy
**Mô tả**: Tải lên ảnh đại diện từ camera hoặc thư viện

**Tính năng**:
- ✅ Chọn từ Camera hoặc Gallery
- ✅ Upload lên Firebase Storage: `user_avatars/{userId}/avatar_{timestamp}.jpg`
- ✅ Tự động update `photoUrl` trong Firestore users
- ✅ Xóa avatar cũ khi upload mới

**Files**:
- `lib/features/profile/data/profile_storage_service.dart`
- Method: `uploadProfileAvatar(userId, imageFile)`
- Tích hợp trong Edit Profile dialog

### 5. Gửi ảnh và icon trong bình luận
**Mô tả**: Hỗ trợ đính kèm ảnh và emoji trong comment

**Tính năng**:
- ✅ Comment model có trường `imageUrl`
- ✅ Upload ảnh vào Storage trước khi gửi
- ✅ Hiển thị ảnh với ClipRRect, maxHeight 250px
- ✅ Emoji picker tích hợp
- ✅ Thread replies với indent và inline tags

**Files**:
- `lib/features/post/presentation/widgets/comments_list_widget.dart`
- `lib/features/post/data/comment_model.dart`
- Edit/Delete comment support

### 6. Cải tiến UI/UX toàn diện
**Tính năng**:

**Modern Components**:
- ✅ `GradientAvatar`: Avatar với gradient border
- ✅ `FlippableCard`: 3D flip animation
- ✅ `SortChips`: Filter chips với icons
- ✅ Threaded comments với indent visual

**Animations**:
- ✅ Flip 3D animation (FlippableDishCard)
- ✅ Page transitions: fade + slide + scale
- ✅ Loading skeleton states
- ✅ Hero animations across pages

**Theme & Layout**:
- ✅ Gradient backgrounds: primaryContainer, secondaryContainer
- ✅ Responsive: Mobile và Web adaptive
- ✅ Dark mode support
- ✅ Improved spacing và padding

**Navigation**:
- ✅ Bottom nav bar với icons
- ✅ Language switcher trong settings
- ✅ Profile tabs: Posts, Recipes, Reels, Saved

---

## 📂 Cấu trúc dự án


```
lib/
├── core/                     # Core utilities, theme, constants
│   ├── themes/
│   ├── utils/
│   └── constants/
├── features/                 # Feature modules (by domain)
│   ├── auth/                # Authentication & authorization
│   │   ├── data/           # Repository, models
│   │   ├── application/    # Business logic, controllers
│   │   └── presentation/   # UI, widgets
│   ├── recipe/              # Recipe management
│   ├── post/                # Social posts
│   ├── reels/               # **Video reels (mới)**
│   ├── chat/                # Messaging system
│   ├── notifications/       # Push notifications
│   ├── profile/             # User profiles
│   ├── search/              # Search & AI suggestions
│   ├── planner/             # Meal planner
│   ├── shopping/            # Shopping list
│   └── admin/               # Admin panel
├── router/                   # Navigation & routing
└── main.dart                # Entry point

functions/                    # Firebase Cloud Functions
├── src/
│   ├── ai/                  # AI integrations (Gemini, OpenAI)
│   ├── moderation/          # Content moderation
│   └── index.ts            # Functions export
```

---

## 🔑 Tệp cấu hình quan trọng

### Firebase
- `google-services.json` (Android) - Trong `android/app/`
- `GoogleService-Info.plist` (iOS) - Trong `ios/Runner/`
- `firestore.rules` - Security rules cho Firestore
- `storage.rules` - Security rules cho Storage
- `functions/` - Cloud Functions code

### Flutter
- `pubspec.yaml` - Dependencies và app metadata
- `analysis_options.yaml` - Linter rules
- `android/app/build.gradle` - Android build config
- `ios/Runner.xcodeproj` - iOS build config

---

## 🚨 Lỗi thường gặp và cách fix

### 1. "Dart SDK not found"
```bash
# Check PATH
echo $PATH  # macOS/Linux
echo %PATH% # Windows

# Thêm Flutter bin vào PATH
export PATH="$PATH:/path/to/flutter/bin"
```

### 2. "CocoaPods not installed" (iOS, macOS only)
```bash
sudo gem install cocoapods
pod setup
cd ios
pod install
```

### 3. "Gradle build failed" (Android)
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

###4. "Version solving failed"
```bash
flutter clean
rm pubspec.lock
flutter pub get
```

### 5. "Permission denied" (Firebase)
```bash
# Re-deploy Firestore rules
firebase deploy --only firestore:rules

# Check rules trong Firebase Console
# https://console.firebase.google.com/project/vuadaubepthuduc/firestore/rules
```

### 6. Build APK lỗi symlink (Windows)
```bash
# Nếu gặp lỗi "ERROR_INVALID_FUNCTION"
# Move project về cùng drive với Flutter SDK
# Hoặc chạy VS Code/Terminal với quyền Administrator
```

---

## 📱 Test Accounts

### Admin
- **Email:** admin@test.com
- **Password:** (hỏi project owner)

### Regular User
- **Email:** user@test.com
- **Password:** (hỏi project owner)

---

## 🚀 Quy trình phát triển

### Git Workflow
```bash
# Tạo branch mới
git checkout -b feature/ten-feature

# Commit thường xuyên
git add .
git commit -m "feat: mô tả ngắn gọn"

# Push lên remote
git push origin feature/ten-feature

# Tạo Pull Request để review code
# Sau khi approved, merge vào main
```

### Commit Message Convention
```
feat: Thêm tính năng mới
fix: Sửa lỗi
docs: Cập nhật tài liệu
style: Format code
refactor: Tái cấu trúc code
test: Thêm test
chore: Cập nhật dependencies, config
```

---

## 📋 Checklist trước khi release

- [ ] `flutter analyze` - Không có error
- [ ] Test trên real device (Android + iOS nếu có)
- [ ] Update version trong `pubspec.yaml`
- [ ] Update Firebase rules nếu có thay đổi schema
- [ ] Deploy Cloud Functions nếu có thay đổi backend
- [ ] Test tất cả features chính:
  - [ ] Login/Register
  - [ ] Create/View recipes
  - [ ] Create/View posts
  - [ ] **Create/View/Interact Reels (mới)**
  - [ ] **Test đa ngôn ngữ Vi/En (mới)**
  - [ ] **Upload avatar từ camera/gallery (mới)**
  - [ ] **Comment với ảnh và emoji (mới)**
  - [ ] **AI food origin story (flip card) (mới)**
  - [ ] Chat messaging
  - [ ] Notifications
  - [ ] Search
  - [ ] AI suggestions
  - [ ] Meal planner
- [ ] Test performance (no memory leaks, smooth scrolling)
- [ ] **Test video playback trên nhiều thiết bị (mới)**
- [ ] **Test localization strings không thiếu (mới)**
- [ ] Review security rules (Firestore, Storage)
- [ ] Create release notes

---

## 📞 Thông tin liên hệ

- **Firebase Project:** vuada ubepthuduc
- **Project Console:** https://console.firebase.google.com/project/vuadaubepthuduc
- **Repository:** [Add URL]
- **Project Owner:** [Your Name]
- **Email:** [Your Email]

---

## 📝 Ghi chú quan trọng

### Firebase Services đang sử dụng
- **Authentication:** Email/Password, Google Sign-In
- **Firestore:** Database
  - Collections chính: users, posts, recipes, **reels (mới)**, chats, messages, leaderboards, notifications, reports, aiConfigs
  - Subcollections: reactions, comments, ratings, shares, messages
- **Storage:** File uploads (images, videos, **reels videos/thumbnails**, **user avatars**)
  - Paths: `posts/{postId}/`, `recipes/{recipeId}/`, **`reels/{reelId}/`**, **`user_avatars/{userId}/`**
- **Cloud Functions:** AI integration, moderation, search tokens, aggregation
- **Hosting:** Web version
- **Analytics:** User tracking

### API Keys & Environment Variables
- Gemini API Key → Stored in Firebase Functions config
- OpenAI API Key → Stored in Firebase Functions config
- Firebase Config → `google-services.json`, `GoogleService-Info.plist`

**⚠️ KHÔNG commit API keys vào Git!**

### Các dependencies chính
- `flutter_riverpod` - State management
- `go_router` - Navigation
- `firebase_core`, `firebase_auth`, `cloud_firestore` - Firebase
- `google_sign_in` - Google authentication
- `fl_chart` - Charts & graphs
- `image_picker` - Image selection
- `cached_network_image` - Image caching
- `record` - Audio recording
- `audioplayers` - Audio playback
- **`video_player`** - Video playback (cho Reels)
- **`flutter_localizations`** - Localization framework
- **`intl`** - Internationalization (Vi/En)
- **`timeago`** - Relative time formatting
- **`shared_preferences`** - Local storage
- **`emoji_picker_flutter`** - Emoji picker trong comments

Để update dependencies:
```bash
flutter pub outdated
flutter pub upgrade
```

---

## 🎯 Roadmap & TODOs

### ✅ Completed (Phiên bản 2025)
- [x] **Hệ thống Reels hoàn chỉnh** - Video ngắn với tương tác đầy đủ
- [x] **Đa ngôn ngữ Vi/En** - 345+ strings localized
- [x] **AI nhận diện nguồn gốc món ăn** - FlippableDishCard với AI story
- [x] **Upload avatar từ máy** - Camera và Gallery support
- [x] **Comment với ảnh và emoji** - imageUrl field, emoji picker
- [x] **UI/UX cải tiến toàn diện** - Modern components, animations, gradients

### Known Issues
- [ ] Notification permissions vẫn còn lỗi trên một số trường hợp
- [ ] Hero animation duplicate tags cần clean up
- [ ] Web performance cần optimize (đặc biệt với video reels)
- [ ] **Video player performance trên Android low-end devices**
- [ ] **Localization một số error messages chưa đầy đủ**

### Future Improvements
- [ ] Implement FCM push notifications
- [ ] Add unit & widget tests
- [ ] Optimize image loading & caching
- [ ] Implement offline mode
- [ ] Add more AI features
- [ ] Improve search algorithm
- [ ] **Video compression before upload (giảm dung lượng reels)**
- [ ] **Thêm ngôn ngữ thứ 3 (English, Tiếng Pháp, v.v.)**
- [ ] **AI video analysis cho reels (tags tự động)**
- [ ] **Reels filters và effects (AR filters)**
- [ ] **Stories feature (24h expiry)**
- [ ] **Advanced analytics dashboard**
- [ ] **Export recipe to PDF với đa ngôn ngữ**

---

**Last Updated:** 2025-12-30  
**Build Version:** Latest release APK available in `build/app/outputs/flutter-apk/`

---

## 🙏 Lời kết

Project này đã được phát triển với tất cả tính năng cơ bản. Khi tiếp tục phát triển:

1. **Đọc kỹ README.md** cho instructions
2. **Check Git history** để hiểu thay đổi
3. **Follow coding conventions** đã có
4. **Test kỹ trước khi deploy**
5. **Keep documentation updated**

Good luck! 🚀
