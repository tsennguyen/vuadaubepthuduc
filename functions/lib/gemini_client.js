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
exports.callGeminiText = callGeminiText;
const node_fetch_1 = __importDefault(require("node-fetch"));
const logger = __importStar(require("firebase-functions/logger"));
const https_1 = require("firebase-functions/v2/https");
const ai_common_1 = require("./ai_common");
async function callGeminiText({ functionName, modelUrl, body, }) {
    const apiKey = (0, ai_common_1.getGeminiApiKey)();
    let resp;
    try {
        resp = await (0, node_fetch_1.default)(`${modelUrl}?key=${apiKey}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body),
        });
    }
    catch (error) {
        logger.error(`${functionName} fetch error`, {
            message: error?.message,
            stack: error?.stack,
        });
        throw new https_1.HttpsError("unavailable", "AI service temporarily unavailable. Please try again later.");
    }
    if (!resp.ok) {
        const preview = await resp.text();
        logger.error(`${functionName} Gemini request failed`, {
            status: resp.status,
            bodyPreview: preview.slice(0, 200),
        });
        if (resp.status === 400) {
            throw new https_1.HttpsError("invalid-argument", "Invalid AI request. Please check your input.");
        }
        if (resp.status === 429 || resp.status === 503) {
            throw new https_1.HttpsError("unavailable", "AI service temporarily unavailable. Please try again later.");
        }
        throw new https_1.HttpsError("internal", "AI internal error. Please try again later.");
    }
    const json = (await resp.json());
    const text = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    if (typeof text !== "string") {
        throw new https_1.HttpsError("internal", "Invalid AI response. Please try again later.");
    }
    return text;
}
//# sourceMappingURL=gemini_client.js.map