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
exports.aiParseSearchQuery = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const FEATURE_ID = "search";
// Basic Vietnamese stopwords after accent removal to keep fallback tokens clean.
const STOPWORDS = new Set([
    "la",
    "va",
    "cua",
    "cho",
    "nhung",
    "mot",
    "nhieu",
    "it",
    "trong",
    "cai",
    "mon",
    "an",
    "do",
    "cac",
]);
const searchSchema = {
    name: "SearchQueryParse",
    schema: {
        type: "object",
        properties: {
            keywords: { type: "array", items: { type: "string" } },
            tags: { type: "array", items: { type: "string" } },
            filters: {
                type: "object",
                properties: {
                    maxTime: { type: "number" },
                    minTime: { type: "number" },
                    maxCalories: { type: "number" },
                    minCalories: { type: "number" },
                    servings: { type: "number" },
                    mealType: { type: "string" },
                    difficulty: { type: "string" },
                },
                additionalProperties: true,
            },
        },
        required: ["keywords", "tags", "filters"],
    },
};
exports.aiParseSearchQuery = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (request) => {
    try {
        // Authentication required
        if (!request.auth || !request.auth.uid) {
            throw new https_1.HttpsError('unauthenticated', 'Authentication required');
        }
        const data = (request.data || {});
        const query = (data.q ?? "").toString().trim();
        if (!query) {
            return { keywords: [], tags: [], filters: {} };
        }
        const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
        if (!config.enabled) {
            throw new https_1.HttpsError("failed-precondition", "AI search is temporarily disabled");
        }
        const systemPrompt = config.systemPrompt;
        const userPrompt = compactPrompt((0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, { query }));
        try {
            const parsed = sanitizeAiOutput(await (0, openai_client_1.callOpenAIJson)({
                system: systemPrompt,
                user: userPrompt,
                jsonSchema: searchSchema,
                temperature: config.temperature,
                model: config.model,
                maxOutputTokens: config.maxOutputTokens,
            }));
            logger.log("aiParseSearchQuery parsed", {
                queryLength: query.length,
                keywords: parsed.keywords.length,
                tags: parsed.tags.length,
                filterKeys: Object.keys(parsed.filters).length,
            });
            return parsed;
        }
        catch (aiErr) {
            const fallback = buildFallback(query);
            logger.warn("aiParseSearchQuery fallback", {
                queryLength: query.length,
                error: aiErr instanceof Error ? aiErr.message : undefined,
                fallbackKeywords: fallback.keywords.length,
            });
            return fallback;
        }
    }
    catch (err) {
        console.error('[aiParseSearchQuery] error', err);
        if (err instanceof https_1.HttpsError) {
            throw err;
        }
        throw new https_1.HttpsError('internal', 'AI_INTERNAL_ERROR', err instanceof Error ? { message: err.message, stack: err.stack } : err);
    }
});
function sanitizeAiOutput(data) {
    const keywords = Array.isArray(data?.keywords)
        ? uniqStrings(data.keywords
            .map((k) => normalizeToken(String(k || "")))
            .filter(Boolean))
        : [];
    const tags = Array.isArray(data?.tags)
        ? uniqStrings(data.tags
            .map((t) => normalizeTag(String(t || "")))
            .filter(Boolean))
        : [];
    const filtersInput = typeof data?.filters === "object" && data?.filters
        ? data.filters
        : {};
    const filters = {};
    const maxTime = toNumber(filtersInput.maxTime ??
        filtersInput.maxTimeMinutes ??
        filtersInput.timeMax ??
        filtersInput.cookTime);
    if (maxTime !== undefined)
        filters.maxTime = maxTime;
    const minTime = toNumber(filtersInput.minTime ?? filtersInput.timeMin);
    if (minTime !== undefined)
        filters.minTime = minTime;
    const maxCalories = toNumber(filtersInput.maxCalories ??
        filtersInput.caloriesMax ??
        filtersInput.maxKcal);
    if (maxCalories !== undefined)
        filters.maxCalories = maxCalories;
    const minCalories = toNumber(filtersInput.minCalories ??
        filtersInput.caloriesMin ??
        filtersInput.minKcal);
    if (minCalories !== undefined)
        filters.minCalories = minCalories;
    const servings = toNumber(filtersInput.servings ??
        filtersInput.portions ??
        filtersInput.people ??
        filtersInput.khauPhan);
    if (servings !== undefined)
        filters.servings = servings;
    const mealType = normalizeTag(filtersInput.mealType ??
        filtersInput.meal ??
        filtersInput.meal_type ??
        filtersInput.mealtype);
    if (mealType)
        filters.mealType = mealType;
    const difficulty = normalizeTag(filtersInput.difficulty ?? filtersInput.level);
    if (difficulty)
        filters.difficulty = difficulty;
    return {
        keywords,
        tags,
        filters,
    };
}
function buildFallback(query) {
    const normalized = removeAccents(query.toLowerCase());
    const tokens = normalized
        .replace(/[^a-z0-9\s]/g, " ")
        .split(/\s+/)
        .map((t) => t.trim())
        .filter((t) => t.length > 1 && !STOPWORDS.has(t));
    return {
        keywords: uniqStrings(tokens),
        tags: [],
        filters: {},
    };
}
function normalizeToken(input) {
    return removeAccents(input.toLowerCase())
        .replace(/[^a-z0-9\s]/g, " ")
        .trim()
        .replace(/\s+/g, " ");
}
function normalizeTag(input) {
    return normalizeToken(input).replace(/\s+/g, "_");
}
function removeAccents(input) {
    return input
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "d");
}
function uniqStrings(arr) {
    const out = [];
    const seen = new Set();
    for (const item of arr) {
        const key = item.trim();
        if (key && !seen.has(key)) {
            seen.add(key);
            out.push(key);
        }
    }
    return out;
}
function toNumber(value) {
    if (value === null || value === undefined)
        return undefined;
    const num = Number(value);
    return Number.isFinite(num) && num > 0 ? num : undefined;
}
function compactPrompt(prompt) {
    return prompt
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line, index, arr) => line.trim().length > 0 || index === arr.length - 1)
        .join("\n")
        .trim();
}
// TODO: consider rate limiting per user to control AI cost and abuse.
//# sourceMappingURL=ai_search.js.map