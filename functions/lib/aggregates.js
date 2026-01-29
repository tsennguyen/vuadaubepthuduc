"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateChatLastMessage = exports.aggregateEngagementCounts = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const firebase_1 = require("./firebase");
const REGION = "asia-southeast1";
const parentCollections = new Set(["posts", "recipes"]);
const counterFields = {
    reactions: "likesCount",
    comments: "commentsCount",
    ratings: "ratingsCount",
    shares: "sharesCount",
};
/**
 * Aggregate reactions/comments/ratings/shares counts for posts and recipes.
 * Uses count() aggregation to avoid downloading subcollection documents.
 */
exports.aggregateEngagementCounts = (0, firestore_1.onDocumentWritten)({
    region: REGION,
    document: "{collectionId}/{docId}/{subcollection}/{subId}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const { collectionId, docId, subcollection } = event.params;
    if (!parentCollections.has(collectionId) || !(subcollection in counterFields)) {
        return;
    }
    const parentRef = firebase_1.db.collection(collectionId).doc(docId);
    const counterField = counterFields[subcollection];
    try {
        const countSnap = await parentRef.collection(subcollection).count().get();
        const count = countSnap.data().count;
        await parentRef.update({ [counterField]: count });
    }
    catch (error) {
        firebase_functions_1.logger.error("Failed to aggregate counts", {
            collectionId,
            subcollection,
            docId,
            error,
        });
    }
});
/**
 * Update chat lastMessageAt on any message write.
 * Exported for reuse in chat.ts to avoid duplicate trigger logic.
 */
exports.updateChatLastMessage = (0, firestore_1.onDocumentWritten)({
    region: REGION,
    document: "chats/{cid}/messages/{mid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const { cid } = event.params;
    const chatRef = firebase_1.db.collection("chats").doc(cid);
    const afterData = event.data?.after?.data();
    const type = afterData?.type?.toLowerCase();
    const rawText = afterData?.text?.trim();
    const lastMessageText = rawText && rawText.length > 0
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
    const lastMessageSenderId = afterData?.senderId ??
        afterData?.authorId;
    try {
        await chatRef.update({
            lastMessageAt: event.time,
            updatedAt: event.time,
            ...(lastMessageText ? { lastMessageText } : {}),
            ...(lastMessageSenderId ? { lastMessageSenderId } : {}),
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Failed to update lastMessageAt", { cid, error });
    }
});
//# sourceMappingURL=aggregates.js.map