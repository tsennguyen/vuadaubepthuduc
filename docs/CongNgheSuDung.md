# Cong nghe su dung

## Client
- Flutter 3.x (Android/Web), Riverpod, GoRouter, cached_network_image, image_picker, share_plus.
- Firebase SDK: firebase_core, firebase_auth, cloud_firestore, cloud_functions, firebase_storage, firebase_messaging (FCM).
- State/data: repository stub theo features/*, stream Firestore cho feed/chat.

## Backend Firebase
- Firestore: collections users/posts/recipes/chats/leaderboards, subcollections reactions/comments/ratings/shares/messages.
- Cloud Functions (TypeScript): aggregates, search_tokens, leaderboard (cron), suggest (callable + Gemini), chat (callable + FCM), roles.
- Firebase Auth: Email/Google/Facebook; custom claims role admin/moderator/client.
- Hosting + Emulator; FCM cho notify message.

## Cong cu & CI/CD
- Node LTS + firebase-tools + flutterfire_cli.
- GitHub Actions: flutter-analyze, deploy-web (hosting preview/live).
- VSCode/Android Studio; Postman/Firebase Emulator UI cho kiem thu.
