import { HttpsError, onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { db } from "./firebase";
import { updateChatLastMessage } from "./aggregates";

const REGION = "asia-southeast1";

type CreateDMInput = { toUid: string };
type CreateGroupInput = { name: string; memberIds: string[] };

const ensureAuth = (uid?: string): string => {
  if (!uid) throw new HttpsError("unauthenticated", "Bạn cần đăng nhập.");
  return uid;
};

export const createDM = onCall(
  { region: REGION, memory: "128MiB", cpu: 0.166, maxInstances: 1 },
  async (request) => {
    const callerUid = ensureAuth(request.auth?.uid);
    const { toUid } = (request.data || {}) as CreateDMInput;
    if (!toUid) throw new HttpsError("invalid-argument", "toUid is required");

    const memberIds = Array.from(new Set([callerUid, toUid])).sort();

    // Optional: avoid duplicate DM by checking existing chat with same members and type.
    const existing = await db
      .collection("chats")
      .where("type", "==", "dm")
      .where("memberIds", "==", memberIds)
      .limit(1)
      .get();
    if (!existing.empty) {
      return { chatId: existing.docs[0].id };
    }

    const now = FieldValue.serverTimestamp();
    const chatDoc = await db.collection("chats").add({
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

    logger.log("DM created", { chatId: chatDoc.id, memberIds });
    return { chatId: chatDoc.id };
  }
);

export const createGroup = onCall(
  { region: REGION, memory: "128MiB", cpu: 0.166, maxInstances: 1 },
  async (request) => {
    const callerUid = ensureAuth(request.auth?.uid);
    const { name, memberIds = [] } = (request.data || {}) as CreateGroupInput;
    if (!name) throw new HttpsError("invalid-argument", "name is required");

    const uniqueMembers = Array.from(new Set([...memberIds, callerUid]));
    if (uniqueMembers.length < 2) {
      throw new HttpsError("invalid-argument", "Group must have at least 2 members");
    }

    const now = FieldValue.serverTimestamp();
    const chatDoc = await db.collection("chats").add({
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

    logger.log("Group chat created", { chatId: chatDoc.id, memberIds: uniqueMembers });
    return { chatId: chatDoc.id };
  }
);

// Firestore trigger to keep lastMessageAt current for chat documents.
export const onMessage = updateChatLastMessage;
