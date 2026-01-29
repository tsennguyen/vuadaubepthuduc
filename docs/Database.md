# Database (Firestore)

## Tom tat mo hinh
- users/{uid}: displayName, photoURL, role, bio, pantryTokens[], stats{posts,recipes,comments,reactions,shares,weekScore,monthScore,badges[]}, joinedAt, follows/{uid2}.
- posts/{pid}: authorId, title, body, photoURLs[], tags[], searchTokens[], likesCount, commentsCount, sharesCount, createdAt, updatedAt, hidden.
- recipes/{rid}: title, description, steps[], ingredientsTokens[], tags[], searchTokens[], authorId, photoURL, likesCount, commentsCount, ratingsCount, avgRating, sharesCount, createdAt, updatedAt, hidden.
- reactions/comments/ratings/shares subcollections duoi posts|recipes.
- chats/{cid}: type, name, ownerId, memberIds[], createdAt, lastMessageAt; messages subcollection.
- leaderboards/{period}: top[{uid,score,rank}], generatedAt.

## Chi muc
- recipes: ingredientsTokens array-contains + createdAt desc; avgRating desc + createdAt desc.
- posts: searchTokens array-contains + createdAt desc.
- Cac chi muc nay da khai bao trong firestore.indexes.json.

## Search tokens
- searchTokens chuan hoa (lowercase, bo dau, tach tu) tu title + tags (+ ingredientsTokens cua recipe).
- Gioi han ~150 token/ban ghi; dung array-contains-any de search hop nhat.
