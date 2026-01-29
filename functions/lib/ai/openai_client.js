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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.callOpenAIText = callOpenAIText;
exports.callOpenAIJson = callOpenAIJson;
const functions = __importStar(require("firebase-functions"));
const https_1 = require("firebase-functions/v2/https");
const openai_1 = __importDefault(require("openai"));
const ai_common_1 = require("../ai_common");
const DEFAULT_MODEL = "gpt-4o-mini";
let cachedClient = null;
function getClient() {
    const apiKey = (0, ai_common_1.getOpenAiApiKey)();
    if (!cachedClient) {
        cachedClient = new openai_1.default({ apiKey });
    }
    return cachedClient;
}
async function callOpenAIText(opts) {
    try {
        const messages = [];
        if (opts.system) {
            messages.push({ role: "system", content: opts.system });
        }
        messages.push({ role: "user", content: opts.user });
        const completion = await getClient().chat.completions.create({
            model: opts.model ?? DEFAULT_MODEL,
            messages,
            temperature: opts.temperature,
            max_tokens: opts.maxOutputTokens,
            response_format: opts.jsonSchema
                ? { type: "json_schema", json_schema: opts.jsonSchema }
                : undefined,
        });
        const content = completion.choices[0]?.message?.content;
        const text = normalizeContent(content);
        if (!text) {
            throw new Error("Empty completion from OpenAI");
        }
        return text.toString();
    }
    catch (err) {
        functions.logger.error("[OpenAI] call failed", {
            error: err?.response?.data ?? err?.message ?? err,
            status: err?.status,
            type: err?.type,
            model: opts.model ?? DEFAULT_MODEL,
        });
        if (err instanceof https_1.HttpsError) {
            throw err;
        }
        // More specific error messages
        if (err?.status === 401) {
            throw new https_1.HttpsError("unauthenticated", "OpenAI API key is invalid or expired");
        }
        if (err?.status === 429) {
            throw new https_1.HttpsError("resource-exhausted", "OpenAI API rate limit exceeded. Please try again later.");
        }
        if (err?.status === 404) {
            throw new https_1.HttpsError("not-found", `OpenAI model not found: ${opts.model ?? DEFAULT_MODEL}`);
        }
        throw new https_1.HttpsError("internal", "AI internal error. Please try again later.");
    }
}
async function callOpenAIJson(opts) {
    const raw = await callOpenAIText(opts);
    try {
        return JSON.parse(raw);
    }
    catch (err) {
        functions.logger.error("[OpenAI] JSON parse failed", {
            message: err?.message,
            preview: typeof raw === "string" ? raw.slice(0, 200) : "",
        });
        throw new https_1.HttpsError("internal", "AI internal error. Please try again later.");
    }
}
function normalizeContent(content) {
    if (!content)
        return "";
    if (typeof content === "string")
        return content;
    if (Array.isArray(content)) {
        return content
            .map((part) => {
            if (typeof part === "string")
                return part;
            if (part && typeof part.text === "string")
                return part.text;
            return "";
        })
            .filter(Boolean)
            .join("\n")
            .trim();
    }
    if (typeof content === "object" && typeof content.text === "string") {
        return content.text;
    }
    return "";
}
//# sourceMappingURL=openai_client.js.map