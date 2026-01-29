"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setRole = exports.onUserCreate = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const auth_1 = require("firebase-admin/auth");
const firebase_1 = require("./firebase");
const REGION = "asia-southeast1";
const VALID_ROLES = new Set(["admin", "moderator", "client"]);
exports.onUserCreate = (0, firestore_1.onDocumentCreated)({
    region: REGION,
    document: "users/{uid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const { uid } = event.params;
    const data = event.data?.data() || {};
    if (data.role)
        return;
    try {
        await firebase_1.db.collection("users").doc(uid).set({
            role: "client",
        }, { merge: true });
        firebase_functions_1.logger.log("Default role set for user", { uid });
    }
    catch (error) {
        firebase_functions_1.logger.error("Failed to set default role", { uid, error });
    }
});
const ensureAdmin = async (uid, token) => {
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Bạn cần đăng nhập.");
    if (token && token["admin"] === true)
        return true;
    const userDoc = await firebase_1.db.collection("users").doc(uid).get();
    if (userDoc.exists && userDoc.data()?.role === "admin") {
        return true;
    }
    throw new https_1.HttpsError("permission-denied", "Admin only.");
};
exports.setRole = (0, https_1.onCall)({ region: REGION, memory: "128MiB", cpu: 0.166, maxInstances: 1 }, async (request) => {
    const callerUid = request.auth?.uid;
    await ensureAdmin(callerUid, request.auth?.token);
    const { uid, role } = (request.data || {});
    if (!uid || !role) {
        throw new https_1.HttpsError("invalid-argument", "uid and role are required");
    }
    if (!VALID_ROLES.has(role)) {
        throw new https_1.HttpsError("invalid-argument", "role must be admin|moderator|client");
    }
    await Promise.all([
        firebase_1.db.collection("users").doc(uid).set({ role }, { merge: true }),
        (0, auth_1.getAuth)().setCustomUserClaims(uid, { role, admin: role === "admin", moderator: role === "moderator" }),
    ]);
    firebase_functions_1.logger.log("Role updated", { by: callerUid, uid, role });
    return { success: true, uid, role };
});
//# sourceMappingURL=roles.js.map