# Kich ban kiem thu nhanh

## Auth
- Dang nhap Google/Facebook/Email (web/android) thanh cong; role=client mac dinh.
- Thu custom claims admin/mod, dam bao UI va rules doi theo.

## Post/Recipe
- Tao/sua/xoa Post & Recipe voi anh, tags, ingredientsTokens; searchTokens sinh va searchable.
- React 4 loai 1 user 1 doc; counters likes/comments/shares cap nhat dung.
- Comment, rating (recipe) luu dung authorId; avgRating/ratingCount cap nhat.

## Search & Suggest
- Query nguyen lieu (vi du: "trung hanh") -> tra recipes theo ingredientsTokens.
- Query tu khoa (vi du: "bun bo") -> tra post/recipe theo searchTokens; ranking uu tien matchCount + rating/likes/shares.
- Khong ket qua -> callable suggestSearch tra trending + goi y AI (hoac mock neu chua co GEMINI_API_KEY).

## Chat
- createDM -> chi 1 cid tai su dung; gui/nhan message realtime; text >4000 bi chan.
- createGroup -> owner them thanh vien; non-member khong doc/ghi; lastMessageAt cap nhat.

## Leaderboard
- Sinh hoat dong (post/recipe/comment/reaction/share/rating) -> weekScore/monthScore tang.
- Chay cron leaderboard -> leaderboards/{period} co top list, badges top1/top3/top10.
