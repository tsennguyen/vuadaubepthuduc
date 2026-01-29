# Tinh nang chuyen nganh

- Feed Post/Recipe: tao, hien thi, phan ung 4 loai, comment, share, rating (recipe).
- Search hop nhat: normalize + tokens, uu tien ingredientsTokens cho tim nguyen lieu; array-contains-any searchTokens; ranking co trong so; fallback callable suggestSearch (trending + Gemini goi y).
- Chat realtime: DM voi cid = hash(uid1_uid2), Group co owner + memberIds; stream messages; notifyOnMessage (FCM) tuy chon.
- Cong hien & leaderboard: tinh diem hang ngay, cap nhat weekScore/monthScore, leaderboards, badges top1/top3/top10 tuan.
- Share: share_plus ngoai app + ghi shares/{uid} trong app de tang sharesCount va user.stats.
- Moderation & role: admin/mod an bai/xoa comment; user chi sua noi dung cua minh.
