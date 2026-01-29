# Cach deploy

## Chuan bi
- `npm i -g firebase-tools`
- `dart pub global activate flutterfire_cli`
- `firebase login`
- `firebase projects:create vuadaubep-<mssv>` (neu chua co)
- `flutterfire configure --project=vuadaubep-<mssv> --platforms=android,web`

## Deploy Firestore rules/indexes
- `firebase deploy --only firestore:rules,firestore:indexes`

## Deploy Functions
- `cd functions && npm install && npm run build`
- `firebase deploy --only functions`

## Deploy web hosting
- `flutter build web --release`
- `firebase deploy --only hosting`

## Emulator & seed
- `firebase emulators:start` (firestore 8080, functions 5001, hosting 5000, ui 4000)
- `cd functions && npm run seed` de tao du lieu mau.
