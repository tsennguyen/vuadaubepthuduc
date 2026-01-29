import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { getAuth } from "firebase-admin/auth";
import { db } from "./firebase";

const REGION = "asia-southeast1";
const VALID_ROLES = new Set(["admin", "moderator", "client"]);

export const onUserCreate = onDocumentCreated(
  {
    region: REGION,
    document: "users/{uid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const { uid } = event.params;
    const data = event.data?.data() || {};
    if (data.role) return;

    try {
      await db.collection("users").doc(uid).set(
        {
          role: "client",
        },
        { merge: true }
      );
      logger.log("Default role set for user", { uid });
    } catch (error) {
      logger.error("Failed to set default role", { uid, error });
    }
  }
);

const ensureAdmin = async (uid?: string, token?: Record<string, unknown>) => {
  if (!uid) throw new HttpsError("unauthenticated", "Bạn cần đăng nhập.");
  if (token && token["admin"] === true) return true;

  const userDoc = await db.collection("users").doc(uid).get();
  if (userDoc.exists && userDoc.data()?.role === "admin") {
    return true;
  }

  throw new HttpsError("permission-denied", "Admin only.");
};

type SetRoleInput = { uid: string; role: string };

export const setRole = onCall(
  { region: REGION, memory: "128MiB", cpu: 0.166, maxInstances: 1 },
  async (request) => {
    const callerUid = request.auth?.uid;
    await ensureAdmin(callerUid, request.auth?.token);

    const { uid, role } = (request.data || {}) as SetRoleInput;
    if (!uid || !role) {
      throw new HttpsError("invalid-argument", "uid and role are required");
    }
    if (!VALID_ROLES.has(role)) {
      throw new HttpsError("invalid-argument", "role must be admin|moderator|client");
    }

    await Promise.all([
      db.collection("users").doc(uid).set({ role }, { merge: true }),
      getAuth().setCustomUserClaims(uid, { role, admin: role === "admin", moderator: role === "moderator" }),
    ]);

    logger.log("Role updated", { by: callerUid, uid, role });
    return { success: true, uid, role };
  }
);
