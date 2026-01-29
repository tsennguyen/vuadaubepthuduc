"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onMessageCreated = exports.onFollowCreated = exports.onRecipeLikeCreated = exports.onPostLikeCreated = exports.onRecipeCommentCreated = exports.onPostCommentCreated = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
async function getUserTokens(uid) {
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.data() || {};
    const tokens = data.fcmTokens ?? [];
    return tokens.filter(Boolean);
}
async function pushNotification(toUid, payload) {
    const ref = db.collection("notifications").doc(toUid).collection("items").doc();
    await ref.set({
        ...payload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
    });
    const tokens = await getUserTokens(toUid);
    if (!tokens.length)
        return;
    await admin.messaging().sendMulticast({
        tokens,
        notification: {
            title: payload.title,
            body: payload.body,
        },
        data: {
            type: payload.type,
            targetType: payload.targetType,
            targetId: payload.targetId,
            fromUid: payload.fromUid,
        },
    });
}
// Comment on post
exports.onPostCommentCreated = functions.firestore
    .onDocumentCreated("posts/{postId}/comments/{cid}", async (event) => {
    const comment = event.data?.data();
    if (!comment)
        return;
    const authorId = comment.authorId;
    if (!authorId)
        return;
    const postSnap = await db.collection("posts").doc(event.params.postId).get();
    const post = postSnap.data() || {};
    const ownerId = post.authorId;
    if (!ownerId || ownerId === authorId)
        return;
    await pushNotification(ownerId, {
        type: "comment",
        title: "Bình luận mới",
        body: `${comment.authorName ?? "Ai đó"} đã bình luận bài viết của bạn`,
        fromUid: authorId,
        targetType: "post",
        targetId: event.params.postId,
    });
});
// Comment on recipe
exports.onRecipeCommentCreated = functions.firestore
    .onDocumentCreated("recipes/{recipeId}/comments/{cid}", async (event) => {
    const comment = event.data?.data();
    if (!comment)
        return;
    const authorId = comment.authorId;
    if (!authorId)
        return;
    const recipeSnap = await db
        .collection("recipes")
        .doc(event.params.recipeId)
        .get();
    const recipe = recipeSnap.data() || {};
    const ownerId = recipe.authorId;
    if (!ownerId || ownerId === authorId)
        return;
    await pushNotification(ownerId, {
        type: "comment",
        title: "Bình luận mới",
        body: `${comment.authorName ?? "Ai đó"} đã bình luận công thức của bạn`,
        fromUid: authorId,
        targetType: "recipe",
        targetId: event.params.recipeId,
    });
});
// Like (reaction) on post
exports.onPostLikeCreated = functions.firestore
    .onDocumentCreated("posts/{postId}/reactions/{uid}", async (event) => {
    const uid = event.params.uid;
    const postSnap = await db.collection("posts").doc(event.params.postId).get();
    const post = postSnap.data() || {};
    const ownerId = post.authorId;
    if (!ownerId || ownerId === uid)
        return;
    await pushNotification(ownerId, {
        type: "like",
        title: "Có người thích bài viết",
        body: "Bài viết của bạn vừa được thả tim.",
        fromUid: uid,
        targetType: "post",
        targetId: event.params.postId,
    });
});
// Like on recipe
exports.onRecipeLikeCreated = functions.firestore
    .onDocumentCreated("recipes/{recipeId}/reactions/{uid}", async (event) => {
    const uid = event.params.uid;
    const recipeSnap = await db
        .collection("recipes")
        .doc(event.params.recipeId)
        .get();
    const recipe = recipeSnap.data() || {};
    const ownerId = recipe.authorId;
    if (!ownerId || ownerId === uid)
        return;
    await pushNotification(ownerId, {
        type: "like",
        title: "Có người thích công thức",
        body: "Công thức của bạn vừa được thích.",
        fromUid: uid,
        targetType: "recipe",
        targetId: event.params.recipeId,
    });
});
// Follow: follows/{targetUid}/followers/{followerUid}
exports.onFollowCreated = functions.firestore
    .onDocumentCreated("follows/{targetUid}/followers/{followerUid}", async (event) => {
    const targetUid = event.params.targetUid;
    const followerUid = event.params.followerUid;
    if (!targetUid || !followerUid || targetUid === followerUid)
        return;
    await pushNotification(targetUid, {
        type: "follow",
        title: "Có người theo dõi bạn",
        body: "Bạn có một follower mới.",
        fromUid: followerUid,
        targetType: "profile",
        targetId: targetUid,
    });
});
// New message: chats/{cid}/messages/{mid}
exports.onMessageCreated = functions.firestore
    .onDocumentCreated("chats/{chatId}/messages/{mid}", async (event) => {
    const message = event.data?.data();
    if (!message)
        return;
    const authorId = message.senderId || message.authorId;
    const chatId = event.params.chatId;
    if (!chatId)
        return;
    const chatSnap = await db.collection("chats").doc(chatId).get();
    const chat = chatSnap.data() || {};
    const members = chat.memberIds ?? [];
    if (!members.length)
        return;
    const targets = members.filter((m) => m !== authorId);
    if (!targets.length)
        return;
    await Promise.all(targets.map((uid) => pushNotification(uid, {
        type: "message",
        title: (chat.isGroup === true || chat.type === "group") ? chat.name ?? "Tin nhắn mới" : "Tin nhắn mới",
        body: message.text ? String(message.text).slice(0, 80) : "Bạn có tin nhắn mới",
        fromUid: authorId ?? "",
        targetType: "chat",
        targetId: chatId,
    })));
});
//# sourceMappingURL=social_notifs.js.map