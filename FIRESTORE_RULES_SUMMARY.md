# Firestore Security Rules - Collection Permissions Summary

## Quick Reference Table

| Collection | Path | User (thường) | Admin/Mod | Functions (Backend) | Notes |
|-----------|------|---------------|-----------|---------------------|-------|
| **users** | `users/{uid}` | ✅ Read all (signed-in)<br>✅ Create own<br>✅ Update own | ✅ Full access | ✅ Full (service account) | Public profiles for signed-in users |
| **bookmarks** | `users/{uid}/bookmarks/{rid}` | ✅ Read/Write own | ❌ | ❌ | Saved recipes per user |
| **plannerSettings** | `users/{uid}/plannerSettings/{docId}` | ✅ Read/Write own | ❌ | ❌ | Meal planner settings |
| **mealPlans** | `mealPlans/{uid}/days/{dayId}/meals/{mealId}` | ✅ Read/Write own | ❌ | ❌ | Personal meal planning |
| **shoppingLists** | `shoppingLists/{uid}/items/{itemId}` | ✅ Read/Write own | ❌ | ❌ | Personal shopping list |
| **posts** | `posts/{pid}` | ✅ Read (public)<br>✅ Create<br>✅ Update/Delete own | ✅ Update/Delete any | ✅ Full | Public feed posts |
| **post reactions** | `posts/{pid}/reactions/{uid}` | ✅ Read/Write own | ✅ Delete any | ❌ | Like/reactions on posts |
| **post comments** | `posts/{pid}/comments/{cid}` | ✅ Read/Write own | ✅ Delete any | ❌ | Comments on posts |
| **post shares** | `posts/{pid}/shares/{uid}` | ✅ Read/Write own | ✅ Delete any | ❌ | Share tracking |
| **recipes** | `recipes/{rid}` | ✅ Read (public)<br>✅ Create<br>✅ Update/Delete own | ✅ Update/Delete any | ✅ Full | Public recipe library |
| **recipe reactions** | `recipes/{rid}/reactions/{uid}` | ✅ Read/Write own | ✅ Delete any | ❌ | Like/reactions on recipes |
| **recipe comments** | `recipes/{rid}/comments/{cid}` | ✅ Read/Write own | ✅ Delete any | ❌ | Comments on recipes |
| **recipe ratings** | `recipes/{rid}/ratings/{uid}` | ✅ Read/Write own | ✅ Delete any | ❌ | Star ratings (1-5) |
| **recipe shares** | `recipes/{rid}/shares/{uid}` | ✅ Read/Write own | ✅ Delete any | ❌ | Share tracking |
| **chats** | `chats/{cid}` | ✅ Read if member<br>✅ Create (with validation)<br>✅ Update if member | ✅ Read all<br>✅ Update all<br>✅ Delete all | ✅ Full | DM requires friends, Group open |
| **messages** | `chats/{cid}/messages/{mid}` | ✅ Read if member<br>✅ Create own<br>✅ Update/Delete own | ✅ Full access | ✅ Full | Chat messages |
| **friendRequests** | `friendRequests/{rid}` | ✅ Read own requests<br>✅ Create<br>✅ Update (accept/reject/cancel) | ✅ Full access | ❌ | Pending friend invitations |
| **friends** | `friends/{uid}/items/{friendUid}` | ✅ Read/Write if owner or friend | ✅ Full access | ❌ | Bidirectional friendships |
| **follows** | `follows/{uid}/targets/{targetUid}` | ✅ Read/Write if owner or target | ✅ Full access | ❌ | One-way following |
| **reports** | `reports/{rid}` | ✅ Read own<br>✅ Create | ✅ Full access | ✅ Full | User-generated content reports |
| **auditLogs** | `auditLogs/{lid}` | ❌ | ✅ Read only | ✅ Write only (append) | System audit trail |
| **leaderboards** | `leaderboards/{lid}` | ✅ Read (public) | ✅ Read | ✅ Write (with claim) | Public leaderboards |
| **aiConfigs** | `aiConfigs/{cid}` | ✅ Read | ✅ Full (admin only) | ✅ Full | AI prompt configurations |
| **adminSettings** | `adminSettings/{docId}` | ❌ | ✅ Full access | ✅ Full | App-wide admin settings |
| **chatViolations** | `chatViolations/{vid}` | ❌ | ✅ Full access | ✅ Write (AI moderation) | Chat moderation violations |
| **notifications** | `notifications/{nid}` | ✅ Read own<br>✅ Update own (mark read) | ✅ Full access | ✅ Create/Delete | User notifications |

## Key Validation Rules

### DM Chat Creation
- **Requirement**: Must have exactly 2 members who are **already friends** (bidirectional check)
- **Validation**: Uses `areFriends(uidA, uidB)` helper function
- **Implementation**: Checks existence of `friends/{uidA}/items/{uidB}` AND `friends/{uidB}/items/{uidA}`

### Group Chat Creation
- **Requirement**: Current user must be in `memberIds`
- **No friendship requirement** (unlike DM)

### Message Creation
- **Requirements**:
  1. Must be a member of the chat (`isChatMember(cid)`)
  2. `senderId` must match `request.auth.uid`
  3. `createdAt` must equal `request.time` (server timestamp)

### Post/Recipe Subcollections
- **Document ID**: For reactions/ratings/shares, document ID must equal user's UID (`sid == request.auth.uid`)
- **Comments**: `authorId` field must match user's UID
- **This prevents users from creating multiple reactions/ratings**

### Reports
- **Target Types**: `post`, `recipe`, `message`, `user`
- **Reason Codes**: `spam`, `inappropriate`, `violence`, `fake_info`, `hate`, `other`
- **Special**: If `targetType == 'message'`, then `chatId` is required

## Admin/Moderator Privileges

### Admin (`role == 'admin'`)
- Full access to all collections (read/write/delete)
- Can update any user's profile
- Can delete any content
- Can manage AI configs
- Can manage admin settings

### Moderator (`role == 'moderator'`)
- Can read all chats and messages
- Can read/update reports
- Can read/update chat violations
- Can update posts/recipes (moderation)
- Can read audit logs
- **Cannot** manage AI configs
- **Cannot** delete users

## Flow Compatibility Checklist

### ✅ Regular User Flows
- [x] Sign up / Sign in (create user profile)
- [x] View/create/edit/delete own posts
- [x] View/create/edit/delete own recipes
- [x] Like/comment/rate/share posts and recipes
- [x] Send/accept/reject friend requests
- [x] Follow/unfollow users
- [x] Create DM with friends (friends check enforced)
- [x] Create/join group chats
- [x] Send/read messages (text, image, video, audio)
- [x] Manage meal plans (personal)
- [x] Manage shopping lists (personal)
- [x] Bookmark recipes
- [x] Submit reports

### ✅ Admin Dashboard Flows
- [x] View all users (admin user repository)
- [x] Ban/unban users
- [x] Change user roles
- [x] View all reports (admin report repository)
- [x] Update report statuses
- [x] View chat violations (admin chat moderation)
- [x] Lock/unlock chats
- [x] View/update admin settings
- [x] View/update AI configs (admin only)
- [x] View audit logs (read-only)
- [x] View leaderboards

### ✅ Backend (Firebase Functions) Flows
- [x] Create DM via `createdm` callable function (service account)
- [x] AI chat moderation (write to `chatViolations`)
- [x] Update chat violation counts
- [x] Write to audit logs (append-only)
- [x] Update leaderboards (with custom claim)
- [x] Aggregate engagement metrics

## Breaking Changes from Previous Rules

### What Changed
1. **Added `adminSettings` and `chatViolations` collections** - These were missing and causing admin permission-denied errors
2. **Relaxed message update rules** - Now admin/mod can update messages (for moderation)
3. **Added `bookmarks` and `plannerSettings` subcollections** - Under `users/{uid}`
4. **Fixed follow rules** - Now both owner and target can write (for mutual follow on friend accept)
5. **Added notifications collection** - For future use

### What Stayed the Same
1. **DM creation still requires friendship** - This is the correct business logic
2. **Chat member checks** - Still using `isChatMember()` helper
3. **Least-privilege principle** - Users can only access their own data unless explicitly shared

## Testing Recommendations

### Critical Paths to Test
1. **Chat Flow**: Create DM with friend → Send message → Edit message → React to message
2. **Admin Dashboard**: View reports → Update status → View chat violations → Update settings
3. **Social Flow**: Create post → Like → Comment → Share → Report
4. **Recipe Flow**: Create recipe → Rate → Comment → Bookmark → Add to meal plan → Generate shopping list

### Expected Behaviors
- ❌ **Should FAIL**: User tries to create DM with non-friend
- ✅ **Should PASS**: User creates DM with friend (after accepting friend request)
- ✅ **Should PASS**: Admin reads any chat/message
- ✅ **Should PASS**: Admin updates adminSettings/aiConfigs
- ✅ **Should PASS**: User creates report on inappropriate content
- ❌ **Should FAIL**: Regular user tries to read chatViolations

## Rule Deployment

To deploy these rules to Firebase:

```bash
firebase deploy --only firestore:rules
```

Or use the Firebase Console:
1. Go to Firestore Database → Rules
2. Copy the contents of `firestore.rules`
3. Publish

---

**Last Updated**: Based on code analysis of Flutter repositories and admin features (2025-12-23)
**Version**: Comprehensive rewrite to support all features
**Status**: ✅ Ready for deployment
