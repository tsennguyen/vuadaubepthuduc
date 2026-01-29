Ngữ cảnh (Context)
- Dự án: Flutter app “Vua Đầu Bếp Thủ Đức”, chạy Android + Web.
- Tech stack: Flutter, Dart, Firebase (Auth, Firestore, Storage, Functions, Hosting, FCM).
- Firebase project đã có:
  - Project ID = vuadaubepthuduc
  - Android appId/packageName = com.vuadaubepthuduc
  - Đã bật Firestore, Storage, Authentication, Functions, Hosting (có thể chưa init đầy đủ file).
- FlutterFire CLI đã được cài global bằng:
  - dart pub global activate flutterfire_cli
- Tôi muốn có hướng dẫn + khung code init Firebase chuẩn, dễ dùng cho cả team.

Mục tiêu (Goal)
- Cấu hình kết nối giữa Flutter và Firebase bằng FlutterFire cho project vuadaubepthuduc.
- Khởi tạo Firebase trong main.dart (support Android + Web).
- Hướng dẫn chạy app với emulator (Firestore, Functions, Hosting) và file .env (không lộ secret).

Yêu cầu chi tiết (Details)
1) Lệnh CLI
   - Liệt kê đầy đủ lệnh cần chạy:
     - Cài FlutterFire CLI (nếu chưa): 
       - dart pub global activate flutterfire_cli
     - Chạy cấu hình cho project:
       - flutterfire configure --project=vuadaubepthuduc --platforms=android,web
       - (Nếu muốn, ghi thêm cách chạy bằng dart pub global run flutterfire_cli:flutterfire ...)
   - Hướng dẫn cách thêm SHA1/SHA256 cho Android:
     - Command mẫu keytool (không cần giá trị thật, chỉ command).

2) Cấu trúc mã nguồn
   - File `lib/firebase_options.dart` sẽ do FlutterFire sinh ra (assume là đã tồn tại).
   - Viết code đầy đủ cho `lib/main.dart`:
     - Gọi `WidgetsFlutterBinding.ensureInitialized()`.
     - Gọi `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
     - Chuẩn bị sẵn chỗ bọc `ProviderScope` (Riverpod) nhưng chỉ stub (không cần code Riverpod chi tiết).
   - Nếu cần, có thể tách thêm file helper:
     - `lib/bootstrap.dart` hoặc tương tự, nhưng phải ghi rõ đường dẫn và nội dung.

3) .env & dart-define
   - Hướng dẫn tạo file `.env` tại root project Flutter (không commit git):
     - Ví dụ key:
       - GEMINI_API_KEY=
       - FACEBOOK_APP_ID=
       - FACEBOOK_CLIENT_TOKEN=
   - Ghi rõ cách chạy app với file .env:
     - flutter run -d chrome --dart-define-from-file=.env
   - Nhắc lại: `.env` phải được ignore trong `.gitignore`.

4) Emulator
   - Hướng dẫn app kết nối tới Firebase Emulator Suite (Firestore, Functions, Auth nếu cần):
     - Firestore:
       - FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
     - Functions:
       - FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
     - Nếu có Auth emulator thì gợi ý cách config tương tự.
   - Viết một helper:
     - `Future<void> initFirebaseEmulatorIfNeeded()`:
       - Nhận tham số hoặc dựa vào một biến bool (vd: kDebugMode or ENV) để quyết định có dùng emulator hay không.
   - Ghi rõ chỗ gọi helper này trong `main()`.

Ràng buộc (Constraints)
- Không hard-code API key, appId, projectId thật trong code; nếu cần demo thì dùng placeholder rõ ràng (VD: "<API_KEY>").
- Code phải compile được với Flutter stable mới (ghi rõ version SDK nếu cần).
- Ngôn ngữ giải thích: tiếng Việt, có thể xen English cho tên hàm/class.
- Không thêm package ngoài `firebase_core` (và các package Firebase khác) nếu không thực sự cần cho phần init.

Output mong muốn (Deliverables)
- 1 đoạn hướng dẫn CLI (shell) rõ ràng, copy-paste chạy được.
- Code hoàn chỉnh cho `lib/main.dart` (bao gồm đầy đủ import).
- Nếu có thêm file helper (VD: `lib/firebase_emulator.dart`), ghi rõ:
  - Đường dẫn file.
  - Nội dung đầy đủ file.
