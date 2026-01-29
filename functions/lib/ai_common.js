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
exports.OPENAI_API_KEY = void 0;
exports.getOpenAiApiKey = getOpenAiApiKey;
exports.handleAiError = handleAiError;
const params_1 = require("firebase-functions/params");
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
exports.OPENAI_API_KEY = (0, params_1.defineSecret)("OPENAI_API_KEY");
function getOpenAiApiKey() {
    const apiKey = process.env.OPENAI_API_KEY ?? exports.OPENAI_API_KEY.value();
    if (!apiKey) {
        logger.error("OPENAI_API_KEY is not set");
        throw new https_1.HttpsError("failed-precondition", "OPENAI_API_KEY is not configured on server");
    }
    return apiKey;
}
function handleAiError(err, context) {
    logger.error(`${context} failed`, err);
    if (err instanceof https_1.HttpsError) {
        throw err;
    }
    throw new https_1.HttpsError("internal", "AI internal error. Please try again later.");
}
//# sourceMappingURL=ai_common.js.map