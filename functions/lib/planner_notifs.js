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
exports.plannerReminder = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
// Reuse the default app initialized elsewhere
const db = admin.firestore();
async function getPlannerSettings(uid) {
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.data() || {};
    return data.plannerSettings ?? {};
}
async function getUserTokens(uid) {
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.data() || {};
    const tokens = data.fcmTokens ?? [];
    return tokens.filter(Boolean);
}
function minutesBeforeForUser(settings) {
    const value = settings.minutesBefore ?? 30;
    if (value <= 0)
        return 30;
    return value;
}
exports.plannerReminder = (0, scheduler_1.onSchedule)({
    region: "asia-southeast1",
    schedule: "every 5 minutes",
    timeZone: "Asia/Bangkok",
}, async () => {
    const now = admin.firestore.Timestamp.now();
    const windowEnd = admin.firestore.Timestamp.fromDate(new Date(now.toDate().getTime() + 60 * 60 * 1000)); // look ahead 60 minutes max
    // Query collectionGroup on plannedFor to find upcoming meals.
    const snap = await db
        .collectionGroup("meals")
        .where("plannedFor", ">=", now)
        .where("plannedFor", "<=", windowEnd)
        .limit(200)
        .get();
    if (snap.empty)
        return;
    const messaging = admin.messaging();
    await Promise.all(snap.docs.map(async (doc) => {
        const data = doc.data();
        const plannedTs = data.plannedFor;
        if (!plannedTs)
            return;
        // Extract uid from path: mealPlans/{uid}/days/{dayId}/meals/{mealId}
        const dayDoc = doc.ref.parent.parent; // days/{dayId}
        const userDoc = dayDoc?.parent?.parent; // mealPlans/{uid}
        const uid = userDoc?.id;
        if (!uid)
            return;
        const settings = await getPlannerSettings(uid);
        if (settings.enabled === false)
            return;
        const minutesBefore = minutesBeforeForUser(settings);
        const plannedDate = plannedTs.toDate().getTime();
        const nowMs = Date.now();
        const diffMinutes = (plannedDate - nowMs) / 60000;
        // Send if we're within [0, window] and close to user's threshold.
        if (diffMinutes < 0)
            return;
        if (diffMinutes > minutesBefore + 5)
            return;
        if (diffMinutes < minutesBefore - 5)
            return;
        const tokens = await getUserTokens(uid);
        if (!tokens.length)
            return;
        const mealType = data.mealType ?? "meal";
        const recipeTitle = data.recipeId ?? "Bữa ăn";
        const plannedTime = new Date(plannedDate);
        const hh = plannedTime.getHours().toString().padStart(2, "0");
        const mm = plannedTime.getMinutes().toString().padStart(2, "0");
        await db
            .collection("notifications")
            .doc(uid)
            .collection("items")
            .add({
            type: "mealReminder",
            title: `Sắp đến giờ nấu: ${recipeTitle}`,
            body: `Bữa ${mealType} lúc ${hh}:${mm} — chuẩn bị nấu nhé!`,
            fromUid: uid,
            targetType: "mealPlan",
            targetId: doc.ref.path,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
        });
        await messaging.sendMulticast({
            tokens,
            notification: {
                title: `Sắp đến giờ nấu: ${recipeTitle}`,
                body: `Bữa ${mealType} lúc ${hh}:${mm} — chuẩn bị nấu nhé!`,
            },
            data: {
                type: "mealReminder",
                targetType: "mealPlan",
                targetId: doc.ref.path,
            },
        });
    }));
});
//# sourceMappingURL=planner_notifs.js.map