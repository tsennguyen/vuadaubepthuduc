"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onMessage = exports.createGroup = exports.createDM = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
const firebase_1 = require("./firebase");
const aggregates_1 = require("./aggregates");
const REGION = "asia-southeast1";
const ensureAuth = (uid) => {
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Bạn cần đăng nhập.");
    return uid;
};
exports.createDM = (0, https_1.onCall)({ region: REGION, memory: "128MiB", cpu: 0.166, maxInstances: 1 }, async (request) => {
    const callerUid = ensureAuth(request.auth?.uid);
    const { toUid } = (request.data || {});
    if (!toUid)
        throw new https_1.HttpsError("invalid-argument", "toUid is required");
    const memberIds = Array.from(new Set([callerUid, toUid])).sort();
    // Optional: avoid duplicate DM by checking existing chat with same members and type.
    const existing = await firebase_1.db
        .collection("chats")
        .where("type", "==", "dm")
        .where("memberIds", "==", memberIds)
        .limit(1)
        .get();
    if (!existing.empty) {
        return { chatId: existing.docs[0].id };
    }
    const now = firestore_1.FieldValue.serverTimestamp();
    const chatDoc = await firebase_1.db.collection("chats").add({
        isGroup: false,
        type: "dm",
        name: null,
        photoUrl: null,
        memberIds,
        adminIds: memberIds,
        createdAt: now,
        updatedAt: now,
        lastMessageAt: now,
        lastMessageText: "",
        lastMessageSenderId: null,
        isLocked: false,
        lastViolationAt: null,
        violationCount24h: 0,
        mutedBy: [],
        nicknames: {},
        theme: null,
    });
    firebase_functions_1.logger.log("DM created", { chatId: chatDoc.id, memberIds });
    return { chatId: chatDoc.id };
});
exports.createGroup = (0, https_1.onCall)({ region: REGION, memory: "128MiB", cpu: 0.166, maxInstances: 1 }, async (request) => {
    const callerUid = ensureAuth(request.auth?.uid);
    const { name, memberIds = [] } = (request.data || {});
    if (!name)
        throw new https_1.HttpsError("invalid-argument", "name is required");
    const uniqueMembers = Array.from(new Set([...memberIds, callerUid]));
    if (uniqueMembers.length < 2) {
        throw new https_1.HttpsError("invalid-argument", "Group must have at least 2 members");
    }
    const now = firestore_1.FieldValue.serverTimestamp();
    const chatDoc = await firebase_1.db.collection("chats").add({
        isGroup: true,
        type: "group",
        name,
        memberIds: uniqueMembers,
        adminIds: [callerUid],
        photoUrl: null,
        createdAt: now,
        updatedAt: now,
        lastMessageAt: now,
        lastMessageText: "",
        lastMessageSenderId: null,
        createdBy: callerUid,
        isLocked: false,
        lastViolationAt: null,
        violationCount24h: 0,
        mutedBy: [],
        nicknames: {},
        theme: null,
    });
    firebase_functions_1.logger.log("Group chat created", { chatId: chatDoc.id, memberIds: uniqueMembers });
    return { chatId: chatDoc.id };
});
// Firestore trigger to keep lastMessageAt current for chat documents.
exports.onMessage = aggregates_1.updateChatLastMessage;
//# sourceMappingURL=chat.js.map