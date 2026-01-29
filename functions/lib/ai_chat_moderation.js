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
exports.onChatMessageCreatedModeration = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const logger = __importStar(require("firebase-functions/logger"));
const firestore_2 = require("firebase-admin/firestore");
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const firebase_1 = require("./firebase");
const REGION = "asia-southeast1";
const FEATURE_ID = "chat_moderation";
const CATEGORY_WHITELIST = new Set([
    "hate",
    "harassment",
    "sexual",
    "self_harm",
    "violence",
    "spam",
    "other",
    "none",
]);
const SEVERITY_WHITELIST = new Set(["low", "medium", "high", "critical"]);
const moderationSchema = {
    name: "ChatModerationVerdict",
    schema: {
        type: "object",
        properties: {
            categories: {
                type: "array",
                items: {
                    type: "string",
                    enum: Array.from(CATEGORY_WHITELIST),
                },
                description: 'List of violation categories. Use ["none"] if no violation detected.',
            },
            severity: {
                type: "string",
                enum: Array.from(SEVERITY_WHITELIST),
            },
            safeSummary: {
                type: "string",
                description: "Short masked summary safe for admins. Must not include sensitive words verbatim.",
            },
            flagged: { type: "boolean" },
        },
        required: ["categories", "severity", "safeSummary"],
    },
};
exports.onChatMessageCreatedModeration = (0, firestore_1.onDocumentCreated)({
    region: REGION,
    document: "chats/{cid}/messages/{mid}",
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "256MiB",
    cpu: 0.5,
    maxInstances: 2,
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const { cid, mid } = event.params;
    const data = snap.data();
    const senderId = stringOrEmpty(data.senderId) || stringOrEmpty(data.authorId);
    const type = data.type?.trim().toLowerCase() || "text";
    const text = stringOrEmpty(data.text) ||
        stringOrEmpty(data.body) ||
        stringOrEmpty(data.content) ||
        stringOrEmpty(data.message) ||
        "";
    const attachmentUrl = stringOrEmpty(data.attachmentUrl) || undefined;
    if (!senderId) {
        logger.warn("Message missing senderId, skip moderation", { cid, mid });
        return;
    }
    const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
    if (!config.enabled) {
        logger.debug("Chat moderation disabled, skipping", { cid, mid });
        return;
    }
    const now = firestore_2.Timestamp.now();
    const prompt = (0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
        chatId: cid,
        messageId: mid,
        senderId,
        messageType: type,
        messageText: text || `[${type} message]`,
        attachmentUrl: attachmentUrl ?? "",
        sentAt: data.createdAt?.toDate().toISOString() ??
            new Date(now.toMillis()).toISOString(),
    });
    let verdict = null;
    try {
        verdict = sanitizeVerdict(await (0, openai_client_1.callOpenAIJson)({
            system: config.systemPrompt,
            user: prompt,
            jsonSchema: moderationSchema,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
        }));
    }
    catch (error) {
        logger.error("Chat moderation AI error", {
            cid,
            mid,
            error: error?.message,
        });
        return;
    }
    if (!verdict || verdict.categories.length === 0) {
        logger.warn("Chat moderation returned empty verdict", { cid, mid });
        return;
    }
    const isClean = verdict.categories.length === 1 && verdict.categories[0] === "none";
    if (isClean) {
        return; // no violation -> do not store
    }
    const violationRef = firebase_1.db.collection("chatViolations").doc();
    try {
        await violationRef.set({
            chatId: cid,
            messageId: mid,
            offenderId: senderId,
            type,
            violationCategories: verdict.categories,
            severity: verdict.severity,
            messageSummary: verdict.safeSummary,
            createdAt: now,
            reviewedAt: null,
            reviewedBy: null,
            status: "pending",
            notes: null,
        });
    }
    catch (error) {
        logger.error("Failed to write chatViolations", {
            cid,
            mid,
            error: error?.message,
        });
        return;
    }
    try {
        const since = firestore_2.Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);
        const countSnap = await firebase_1.db
            .collection("chatViolations")
            .where("chatId", "==", cid)
            .where("createdAt", ">=", since)
            .count()
            .get();
        await firebase_1.db.collection("chats").doc(cid).set({
            lastViolationAt: now,
            violationCount24h: countSnap.data().count ?? 1,
        }, { merge: true });
    }
    catch (error) {
        logger.error("Failed to update chat violation counters", {
            cid,
            mid,
            error: error?.message,
        });
    }
});
function sanitizeVerdict(candidate) {
    if (!candidate)
        return null;
    const categories = Array.from(new Set((candidate.categories ?? [])
        .map((c) => c?.toString().trim().toLowerCase())
        .filter((c) => CATEGORY_WHITELIST.has(c))));
    if (categories.length === 0)
        categories.push("other");
    const severityRaw = candidate.severity?.toString().trim().toLowerCase();
    const severity = SEVERITY_WHITELIST.has(severityRaw)
        ? severityRaw
        : "medium";
    const summary = (candidate.safeSummary ?? "").toString().trim();
    return {
        categories,
        severity,
        safeSummary: summary.length > 0 ? summary : "[summary missing]",
        flagged: candidate.flagged,
    };
}
function stringOrEmpty(value) {
    if (value === null || value === undefined)
        return "";
    const text = String(value).trim();
    return text;
}
//# sourceMappingURL=ai_chat_moderation.js.map