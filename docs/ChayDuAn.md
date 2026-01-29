# Chay du an

1) `flutter pub get`
2) `npm install` trong `functions` va `npm run build`
3) `firebase emulators:start` (firestore 8080, functions 5001, hosting 5000, ui 4000)
4) `cd functions && npm run seed` de co du lieu mau
5) `flutter run -d chrome --dart-define-from-file=.env` (hoac thiet bi khac)
6) Neu dung auth Google/Facebook tren web, cau hinh redirect URL trong Firebase console; Android can SHA-1/256.
