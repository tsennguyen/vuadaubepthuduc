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
const firestore_1 = require("firebase-functions/v2/firestore");
const logger = __importStar(require("firebase-functions/logger"));
const firebase_1 = require("./firebase");
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const FEATURE_ID = "report_moderation";
const LABELS = new Set([
    "ok",
    "spam",
    "maybe_nsfw",
    "hate_speech",
    "harassment",
    "other",
]);
const moderationSchema = {
    name: "ModerationVerdict",
    schema: {
        type: "object",
        properties: {
            label: {
                type: "string",
                enum: ["ok", "spam", "maybe_nsfw", "hate_speech", "harassment", "other"],
            },
            confidence: { type: "number" },
            notes: { type: "string" },
        },
        required: ["label", "confidence"],
    },
};
exports.onReportCreate = (0, firestore_1.onDocumentCreated)({
    region: REGION,
    document: "reports/{reportId}",
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const reportId = event.params.reportId;
    const data = snap.data();
    if (data?.aiVerdict) {
        return; // already processed
    }
    const targetType = (data?.targetType ?? "").toString();
    const targetId = (data?.targetId ?? "").toString();
    const chatId = (data?.chatId ?? "").toString();
    if (!targetType || !targetId) {
        logger.warn("Report missing targetType/targetId", { reportId });
        return;
    }
    const content = await fetchTargetContent(targetType, targetId, chatId);
    if (!content) {
        logger.warn("Target content not found for report", {
            reportId,
            targetType,
            targetId,
        });
        return;
    }
    const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
    if (!config.enabled) {
        logger.warn("AI moderation disabled, skipping verdict", { reportId, targetType });
        return;
    }
    const prompt = compactPrompt((0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
        targetType,
        targetId,
        content,
        reasonLine: data?.reason ? `User reason: ${data.reason}` : "",
        noteLine: data?.note ? `User note: ${data.note}` : "",
    }));
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
        logger.error("OpenAI moderation request error", {
            message: error?.message,
            reportId,
            targetType,
        });
        return;
    }
    if (!verdict) {
        logger.warn("Failed to parse AI verdict", {
            reportId,
            targetType,
        });
        return;
    }
    try {
        await firebase_1.db.collection("reports").doc(reportId).update({
            aiVerdict: verdict,
        });
    }
    catch (error) {
        logger.error("Failed to update aiVerdict", {
            reportId,
            error: error?.message,
        });
    }
});
async function fetchTargetContent(targetType, targetId, chatId) {
    try {
        if (targetType === "post") {
            const snap = await firebase_1.db.collection("posts").doc(targetId).get();
            if (!snap.exists)
                return null;
            const data = snap.data() || {};
            const title = stringify(data.title);
            const body = stringify(data.body ?? data.content ?? data.text);
            return [title, body].filter(Boolean).join("\n").trim() || null;
        }
        if (targetType === "recipe") {
            const snap = await firebase_1.db.collection("recipes").doc(targetId).get();
            if (!snap.exists)
                return null;
            const data = snap.data() || {};
            const title = stringify(data.title);
            const description = stringify(data.description);
            const tags = Array.isArray(data.tags) ? data.tags.join(", ") : "";
            return [title, description, tags ? `tags: ${tags}` : ""]
                .filter(Boolean)
                .join("\n")
                .trim() || null;
        }
        if (targetType === "comment") {
            const snap = await firebase_1.db.collection("comments").doc(targetId).get();
            if (!snap.exists)
                return null;
            const data = snap.data() || {};
            const text = stringify(data.text ?? data.body ?? data.content);
            return text || null;
        }
        if (targetType === "message") {
            if (!chatId)
                return null;
            const snap = await firebase_1.db
                .collection("chats")
                .doc(chatId)
                .collection("messages")
                .doc(targetId)
                .get();
            if (!snap.exists)
                return null;
            const data = snap.data() || {};
            const text = stringify(data.text ?? data.body ?? data.content ?? data.message);
            return text || null;
        }
    }
    catch (error) {
        logger.error("fetchTargetContent error", {
            targetType,
            targetId,
            message: error?.message,
        });
        return null;
    }
    return null;
}
function stringify(value) {
    if (value === null || value === undefined)
        return undefined;
    const text = String(value).trim();
    return text || undefined;
}
function sanitizeVerdict(candidate) {
    const labelRaw = String(candidate?.label ?? "").trim();
    const label = LABELS.has(labelRaw) ? labelRaw : "other";
    const confidence = clamp01(toNumber(candidate?.confidence));
    const notes = stringify(candidate?.notes);
    return {
        label,
        confidence,
        notes,
    };
}
function toNumber(value) {
    if (value === null || value === undefined)
        return undefined;
    if (typeof value === "number" && Number.isFinite(value))
        return value;
    const match = String(value).match(/-?\d+(\.\d+)?/);
    if (!match)
        return undefined;
    const num = Number(match[0]);
    return Number.isFinite(num) ? num : undefined;
}
function clamp01(value) {
    if (value === undefined || Number.isNaN(value))
        return 0;
    if (value < 0)
        return 0;
    if (value > 1)
        return 1;
    return value;
}
function compactPrompt(prompt) {
    return prompt
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line) => line.trim().length > 0)
        .join("\n");
}
//# sourceMappingURL=ai_moderation.js.map