# Prompt phan chia cong viec

## Quy uoc chung
- Nhanh goc develop; PR < 400 dong, pass flutter analyze, co screenshot/clip, khong secret.
- Du an: Flutter + Firebase (Auth, Firestore, Storage, Functions TS, FCM, Hosting, Emulator).
- ProjectId chuan: `vuadaubep-<mssv>`; secrets khong commit.

## A1 ? Nguyen Viet Thanh (feat/cloud-core-social)
- firestore.rules cho users/posts/recipes/chats/reactions/comments/ratings/shares/leaderboards; role admin|moderator|client.
- firestore.indexes.json cho posts.searchTokens, recipes.ingredientsTokens + createdAt, recipes.avgRating + createdAt.
- Functions TS: aggregates.ts, search_tokens.ts, leaderboard.ts, suggest.ts, chat.ts, roles.ts, index.ts; firebase.json, .firebaserc, functions/package.json scripts.

## A2 ? Phan Truc Giang (feat/ui-social-feed)
- Router: /signin,/feed,/post/:id,/recipe/:id,/create-post,/create-recipe,/chat,/chat/:cid,/leaderboard.
- UI: SignIn, Feed tabs, PostDetail, RecipeDetail (rating), CreatePost, CreateRecipe, ChatList/ChatRoom, Leaderboard; react 4 loai, share_plus.

## A3 ? Do Thanh Hiep (feat/search-unified)
- Utils normalize/toTokens/rankScore; repo searchRecipesByIngredients + searchUnified; UI SearchBar + SearchResultPage; goi suggestSearch khi rong; <300 dong.

## A4 ? Ngo Minh Hung (chore/emulator-ci-templates)
- firebase.json + .firebaserc + functions/package.json scripts (build/serve/deploy/seed).
- seed.ts demo 10 posts + 10 recipes + 2 chats + messages.
- GitHub Actions flutter-analyze.yml, deploy-web.yml; templates PR/Issue; docs/test-checklist.md.
