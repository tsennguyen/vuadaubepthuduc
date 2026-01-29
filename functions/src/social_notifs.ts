import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

type TargetType = "post" | "recipe" | "chat" | "profile";
type NotiType = "comment" | "like" | "follow" | "message";

interface NotificationPayload {
  type: NotiType;
  title: string;
  body: string;
  fromUid: string;
  targetType: TargetType;
  targetId: string;
}

async function getUserTokens(uid: string): Promise<string[]> {
  const snap = await db.collection("users").doc(uid).get();
  const data = snap.data() || {};
  const tokens = (data.fcmTokens as string[]) ?? [];
  return tokens.filter(Boolean);
}

async function pushNotification(
  toUid: string,
  payload: NotificationPayload,
): Promise<void> {
  const ref = db.collection("notifications").doc(toUid).collection("items").doc();
  await ref.set({
    ...payload,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
  });

  const tokens = await getUserTokens(toUid);
  if (!tokens.length) return;

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
export const onPostCommentCreated = functions.firestore
  .onDocumentCreated("posts/{postId}/comments/{cid}", async (event) => {
    const comment = event.data?.data();
    if (!comment) return;
    const authorId = comment.authorId as string | undefined;
    if (!authorId) return;

    const postSnap = await db.collection("posts").doc(event.params.postId).get();
    const post = postSnap.data() || {};
    const ownerId = post.authorId as string | undefined;
    if (!ownerId || ownerId === authorId) return;

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
export const onRecipeCommentCreated = functions.firestore
  .onDocumentCreated("recipes/{recipeId}/comments/{cid}", async (event) => {
    const comment = event.data?.data();
    if (!comment) return;
    const authorId = comment.authorId as string | undefined;
    if (!authorId) return;

    const recipeSnap = await db
      .collection("recipes")
      .doc(event.params.recipeId)
      .get();
    const recipe = recipeSnap.data() || {};
    const ownerId = recipe.authorId as string | undefined;
    if (!ownerId || ownerId === authorId) return;

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
export const onPostLikeCreated = functions.firestore
  .onDocumentCreated("posts/{postId}/reactions/{uid}", async (event) => {
    const uid = event.params.uid as string;
    const postSnap = await db.collection("posts").doc(event.params.postId).get();
    const post = postSnap.data() || {};
    const ownerId = post.authorId as string | undefined;
    if (!ownerId || ownerId === uid) return;

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
export const onRecipeLikeCreated = functions.firestore
  .onDocumentCreated("recipes/{recipeId}/reactions/{uid}", async (event) => {
    const uid = event.params.uid as string;
    const recipeSnap = await db
      .collection("recipes")
      .doc(event.params.recipeId)
      .get();
    const recipe = recipeSnap.data() || {};
    const ownerId = recipe.authorId as string | undefined;
    if (!ownerId || ownerId === uid) return;

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
export const onFollowCreated = functions.firestore
  .onDocumentCreated("follows/{targetUid}/followers/{followerUid}", async (event) => {
    const targetUid = event.params.targetUid as string;
    const followerUid = event.params.followerUid as string;
    if (!targetUid || !followerUid || targetUid === followerUid) return;

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
export const onMessageCreated = functions.firestore
  .onDocumentCreated("chats/{chatId}/messages/{mid}", async (event) => {
    const message = event.data?.data();
    if (!message) return;
    const authorId = message.senderId || message.authorId;
    const chatId = event.params.chatId as string;
    if (!chatId) return;

    const chatSnap = await db.collection("chats").doc(chatId).get();
    const chat = chatSnap.data() || {};
    const members = (chat.memberIds as string[]) ?? [];
    if (!members.length) return;

    const targets = members.filter((m) => m !== authorId);
    if (!targets.length) return;

    await Promise.all(
      targets.map((uid) =>
        pushNotification(uid, {
          type: "message",
          title: (chat.isGroup === true || chat.type === "group") ? chat.name ?? "Tin nhắn mới" : "Tin nhắn mới",
          body: message.text ? String(message.text).slice(0, 80) : "Bạn có tin nhắn mới",
          fromUid: authorId ?? "",
          targetType: "chat",
          targetId: chatId,
        }),
      ),
    );
  });

