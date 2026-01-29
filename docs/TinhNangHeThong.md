# Tinh nang he thong

## Auth & Role
- Firebase Auth: Email/Google/Facebook; onUserCreate gan role=client; Cloud Function setRole cho admin.
- Custom claims role dung cho UI va security rules.

## Security rules (tom tat)
- posts/recipes: read cong khai; create yeu cau signed-in, authorId==uid, createdAt==request.time; update/delete owner hoac mod/admin.
- reactions/comments/ratings/shares: user chi ghi doc cua minh; validate type/stars; createdAt==request.time.
- chats/messages: chi member doc/ghi; text <=4000; createdAt==request.time.
- leaderboards: chi read; helpers signedIn(), isOwner(), isMod()/isAdmin().

## CI/CD & kiem thu
- GitHub Actions: flutter-analyze, deploy-web (hosting preview PR, live khi merge main).
- Emulator: firestore 8080, functions 5001, hosting 5000, ui 4000; seed.ts dung du lieu mau.
- Truoc PR: flutter format ., flutter analyze, chay app voi emulator, chup screenshot.
