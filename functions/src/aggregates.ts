import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { db } from "./firebase";

const REGION = "asia-southeast1";

const parentCollections = new Set(["posts", "recipes"]);
const counterFields: Record<string, string> = {
  reactions: "likesCount",
  comments: "commentsCount",
  ratings: "ratingsCount",
  shares: "sharesCount",
};

/**
 * Aggregate reactions/comments/ratings/shares counts for posts and recipes.
 * Uses count() aggregation to avoid downloading subcollection documents.
 */
export const aggregateEngagementCounts = onDocumentWritten(
  {
    region: REGION,
    document: "{collectionId}/{docId}/{subcollection}/{subId}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const { collectionId, docId, subcollection } = event.params;
    if (!parentCollections.has(collectionId) || !(subcollection in counterFields)) {
      return;
    }

    const parentRef = db.collection(collectionId).doc(docId);
    const counterField = counterFields[subcollection];

    try {
      const countSnap = await parentRef.collection(subcollection).count().get();
      const count = countSnap.data().count;

      await parentRef.update({ [counterField]: count });
    } catch (error) {
      logger.error("Failed to aggregate counts", {
        collectionId,
        subcollection,
        docId,
        error,
      });
    }
  }
);

/**
 * Update chat lastMessageAt on any message write.
 * Exported for reuse in chat.ts to avoid duplicate trigger logic.
 */
export const updateChatLastMessage = onDocumentWritten(
  {
    region: REGION,
    document: "chats/{cid}/messages/{mid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const { cid } = event.params;
    const chatRef = db.collection("chats").doc(cid);
    const afterData = event.data?.after?.data();
    const type = (afterData?.type as string | undefined)?.toLowerCase();
    const rawText = (afterData?.text as string | undefined)?.trim();
    const lastMessageText =
      rawText && rawText.length > 0
        ? rawText
        : type
          ? {
              image: "[Image]",
              video: "[Video]",
              audio: "[Audio]",
              file: "[File]",
              system: "[System]",
            }[type]
          : undefined;
    const lastMessageSenderId =
      (afterData?.senderId as string | undefined) ??
      (afterData?.authorId as string | undefined);
    try {
      await chatRef.update({
        lastMessageAt: event.time,
        updatedAt: event.time,
        ...(lastMessageText ? { lastMessageText } : {}),
        ...(lastMessageSenderId ? { lastMessageSenderId } : {}),
      });
    } catch (error) {
      logger.error("Failed to update lastMessageAt", { cid, error });
    }
  }
);
