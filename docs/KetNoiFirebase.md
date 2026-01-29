# Ket noi Firebase

- Config qua `firebase_options.dart` do `flutterfire configure` sinh; projectId chuan `vuadaubep-<mssv>`.
- Android: dat `google-services.json` vao android/app; iOS neu dung can GoogleService-Info.plist; Web dung firebase_options.dart.
- Emulator: Firestore localhost:8080, Functions:5001, Hosting:5000; bat connectWithEmulator trong code khi dev.
- Khong dung connection string SQL; moi giao tiep thong qua SDK hoac REST callable functions.
