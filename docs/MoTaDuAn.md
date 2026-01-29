# Vua Dau Bep Thu Duc - Mo ta du an

## Tom tat
- MXH chia se bai viet va cong thuc nau an, ho tro phan ung, binh luan, chia se trong/ngoai app.
- Search hop nhat theo ten mon, nguyen lieu, tag, tac gia; goi y trending/AI khi khong co ket qua.
- Chat DM/Group realtime; diem cong hien, bang xep hang tuan/thang, huy hieu.
- Client Flutter (Android/Web) voi Riverpod + GoRouter; backend Firebase (Auth, Firestore, Storage, Functions TS, FCM, Hosting, Emulator).

## Pham vi MVP
- Dang nhap Google/Facebook/Email; tao/sua/xoa Post & Recipe voi anh, tags, ingredientsTokens.
- React 4 loai, comment, rating (recipe), share ghi nhan trong app va share_plus ngoai app.
- Search + suggest, chat DM/Group, leaderboard tuan/thang, badge tren profile.

## Kien truc
- App Flutter -> Firestore (posts, recipes, chats, leaderboards) + Storage anh + Cloud Functions (tong hop count, searchTokens, leaderboard, suggest, chat, roles) + FCM.
- CI/CD: GitHub Actions (flutter analyze, build web, hosting preview/live). Firebase emulator cho phat trien.

## Tieu chi ban giao
- flutter analyze pass; cau hinh firebase.json/.firebaserc/functions/package.json san.
- Rules + indexes deploy duoc; Functions chay tren emulator (npm run build && firebase emulators:start) va deploy.
- Co tai lieu test checklist, prompt phan cong, huong dan run & deploy.
