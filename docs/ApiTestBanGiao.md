# API / Test ban giao

## Cloud Functions
- aggregates: onReactionChange/onCommentChange/onRatingChange/onShareAdd -> cap nhat counters; onAnyCreate cap nhat user.stats; onMessage update lastMessageAt.
- search_tokens: onWritePost/Recipe tao searchTokens tu title/tags/ingredientsTokens.
- leaderboard: cron daily tinh weekScore/monthScore, ghi leaderboards, gan badges.
- suggest: callable suggestSearch({q,tokens,type}) tra ket qua search hoac trending + Gemini goi y khi rong.
- chat: callable createDM({toUid}), createGroup({name,memberIds}), notifyOnMessage (FCM tuy chon).
- roles: setRole, onUserCreate gan client.

## Checklist ban giao nhanh (emulator)
1) `firebase emulators:start` va `npm run build` trong functions.
2) Dang nhap (Google/Email), tao Post/Recipe (co tags/ingredientsTokens); searchTokens sinh dung.
3) React/comment/rating/share -> counters va user.stats cap nhat.
4) Search "trung hanh" (ingredients) va "bun bo" (keyword) -> co ket qua; rong -> suggestSearch tra trending.
5) Chat: createDM + gui tin; createGroup + nhieu member; chi member doc/ghi; lastMessageAt cap nhat.
6) Leaderboard: chay cron thu cong (trigger emulator hoac script) -> leaderboards/{period} co top list, badges.
7) flutter analyze pass; build web chay voi emulator.

## Tai lieu kem
- Huong dan run: docs/runServer.md.
- Kiem thu chi tiet: docs/testApiKhuonMat.md.
