# Comment System Upgrade

## Features Added
1. **Like Comments**: Users can like/unlike comments
2. **Reply to Comments**: Nested comment replies with @mentions
3. **Sort Comments**: 
   - Mới nhất (Newest first)
   - Cũ nhất (Oldest first)  
   - Nhiều like nhất (Most liked)

## Data Structure

### Comment Document Fields
```json
{
  "authorId": "string",
  "content": "string",
  "createdAt": "timestamp",
  "likes": ["userId1", "userId2"],  // NEW
  "likesCount": 0,                  // NEW
  "replyTo": "commentId",          // NEW (optional)
  "replyToName": "userName"        // NEW (optional)
}
```

## Migration for Existing Comments

If you have existing comments without `likes` and `likesCount` fields, run this Firestore script:

```javascript
// Run in Firebase Console > Firestore > Rules tab or use Firebase Admin SDK

const admin = require('firebase-admin');
const db = admin.firestore();

async function migrateComments() {
  // Get all posts
  const postsSnapshot = await db.collection('posts').get();
  
  for (const postDoc of postsSnapshot.docs) {
    const commentsRef = postDoc.ref.collection('comments');
    const commentsSnapshot = await commentsRef.get();
    
    const batch = db.batch();
    let count = 0;
    
    for (const commentDoc of commentsSnapshot.docs) {
      const data = commentDoc.data();
      
      // Only update if fields don't exist
      if (!data.hasOwnProperty('likes') || !data.hasOwnProperty('likesCount')) {
        batch.update(commentDoc.ref, {
          likes: [],
          likesCount: 0
        });
        count++;
      }
      
      // Batch commit every 500 operations (Firestore limit)
      if (count >= 500) {
        await batch.commit();
        count = 0;
      }
    }
    
    // Commit remaining
    if (count > 0) {
      await batch.commit();
    }
    
    console.log(`Migrated comments for post: ${postDoc.id}`);
  }
  
  // Do the same for recipes
  const recipesSnapshot = await db.collection('recipes').get();
  // ... repeat similar logic
  
  console.log('Migration complete!');
}

migrateComments().catch(console.error);
```

## OR Simple Manual Fix (if few comments):

In Firebase Console, go to each comment and add fields:
- `likes`: [] (empty array)
- `likesCount`: 0 (number)

## Usage

Users can now:
1. **Like comments** - Click heart icon
2. **Reply to comments** - Click "Trả lời" button
3. **Sort comments** - Use filter chips at top
4. **See reply context** - Shows "Trả lời [Username]" tag

## UI Components

### Sort Chips
- Mới nhất (newest) - Default
- Cũ nhất (oldest)
- Nhiều like (most liked)

### Comment Card
- User avatar & name
- Timestamp
- Reply indicator (if reply)
- Like count & button
- Reply button
- Comment content
