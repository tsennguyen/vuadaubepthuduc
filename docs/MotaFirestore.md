# Mo ta chi tiet Firestore

## users
- displayName, photoURL, bio, role (admin/moderator/client), pantryTokens[], joinedAt (timestamp).
- stats: posts, recipes, comments, reactions, shares, weekScore, monthScore, badges[]
- follows/{uid2}: true neu theo doi.

## posts & recipes
- posts: title/body/photoURLs/tags/searchTokens + counters (likes/comments/shares) + hidden.
- recipes: title/description/steps/ingredientsTokens/searchTokens/tags/photoURL + counters + ratingsCount/avgRating + hidden.
- reactions: {type in like|love|yum|wow} (1 user 1 doc).
- comments: {authorId, content, createdAt, hidden}; shares: {createdAt}; ratings: {stars 1..5}.
- Cac doc chua createdAt/updatedAt timestamp de sap xep va chong sua lich su.

## chats/messages
- chats: type dm|group, name (group), ownerId, memberIds[], createdAt, lastMessageAt.
- messages: authorId, text, attachments[], createdAt; text toi da 4000 ky tu.

## leaderboards
- leaderboards/{period}: period = weekly-YYYYWW hoac monthly-YYYYMM; top[] {uid,score,rank}; generatedAt.
- Diem: Post +2, Recipe +4, Comment +1, Reaction +0.5, Share +1, Rating +1.
