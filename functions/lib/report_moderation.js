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
exports.onReportCreate = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
const REGION = "asia-southeast1";
/**
 * REPORT_THRESHOLD_HIDE:
 * - Khi `reportsCount` của target >= ngưỡng này => tự động set `isHiddenPendingReview = true`
 * - TODO: có thể đọc từ Remote Config / Functions config sau
 */
const REPORT_THRESHOLD_HIDE = 5;
/**
 * Moderation trigger cho schema reports (client + admin dùng chung).
 *
 * Phụ thuộc schema Firestore:
 * - `reports/{reportId}`: { targetType, targetId, chatId?, reasonCode, reasonText?, reporterId, createdAt, status }
 * - Targets:
 *   - `posts/{pid}`
 *   - `recipes/{rid}`
 *   - `chats/{cid}/messages/{mid}`
 *   - `users/{uid}` (tương lai)
 * - `auditLogs/{logId}`: log lịch sử moderation (đơn giản, append-only)
 *
 * Function này KHÔNG xoá target, chỉ update fields:
 * - `reportsCount`: number
 * - `isHiddenPendingReview`: bool (chỉ áp dụng cho post/recipe/message)
 */
exports.onReportCreate = functions.firestore.onDocumentCreated({
    region: REGION,
    document: "reports/{reportId}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data() || {};
    const targetType = data.targetType;
    const targetId = data.targetId;
    const chatId = data.chatId;
    const reporterId = data.reporterId;
    if (!targetType || !targetId) {
        console.warn("Report missing targetType/targetId", event.params.reportId);
        return;
    }
    let targetRef;
    if (targetType === "post") {
        targetRef = db.collection("posts").doc(targetId);
    }
    else if (targetType === "recipe") {
        targetRef = db.collection("recipes").doc(targetId);
    }
    else if (targetType === "message") {
        if (!chatId) {
            console.warn("Report missing chatId for message target", event.params.reportId, targetId);
            return;
        }
        targetRef = db
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .doc(targetId);
    }
    else if (targetType === "user") {
        targetRef = db.collection("users").doc(targetId);
    }
    else {
        console.warn("Unknown targetType for report", event.params.reportId, targetType);
        return;
    }
    await db.runTransaction(async (tx) => {
        const targetSnap = await tx.get(targetRef);
        if (!targetSnap.exists) {
            console.warn("Target doc not found for report", targetType, targetId);
            return;
        }
        const targetData = targetSnap.data() || {};
        const oldCountRaw = targetData.reportsCount;
        const oldCount = typeof oldCountRaw === "number" && Number.isFinite(oldCountRaw) ? oldCountRaw : 0;
        const newCount = oldCount + 1;
        const updateData = { reportsCount: newCount };
        if (targetType === "post" || targetType === "recipe" || targetType === "message") {
            if (newCount >= REPORT_THRESHOLD_HIDE) {
                updateData.isHiddenPendingReview = true;
            }
        }
        tx.update(targetRef, updateData);
        // Ghi audit log (append-only)
        const logRef = db.collection("auditLogs").doc();
        tx.set(logRef, {
            type: "reportCreated",
            reportId: event.params.reportId,
            targetType,
            targetId,
            chatId: chatId ?? null,
            reporterId: reporterId ?? null,
            newReportsCount: newCount,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
});
//# sourceMappingURL=report_moderation.js.map