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
exports.aiAnalyzeReports = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const FEATURE_ID = "report_summary";
const responseSchema = {
    name: "ReportSummaryAnalysis",
    schema: {
        type: "object",
        properties: {
            summary: { type: "string" },
            priorityCounts: {
                type: "object",
                properties: {
                    urgent: { type: "number" },
                    high: { type: "number" },
                    medium: { type: "number" },
                    low: { type: "number" },
                },
                required: ["urgent", "high", "medium", "low"],
            },
            topReports: {
                type: "array",
                items: {
                    type: "object",
                    properties: {
                        reportId: { type: "string" },
                        severity: { type: "string" },
                        reason: { type: "string" },
                    },
                    required: ["reportId", "severity", "reason"],
                },
            },
        },
        required: ["summary", "priorityCounts", "topReports"],
    },
};
/**
 * AI-powered report summary for admin moderation dashboard
 * Analyzes multiple reports and provides priority classification
 */
exports.aiAnalyzeReports = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "256MiB",
    cpu: 0.25,
    maxInstances: 2,
}, async (request) => {
    try {
        // TEMPORARY: Disabled admin check for testing
        // TODO: Re-enable this in production!
        // if (!request.auth?.token?.isAdmin) {
        //   throw new HttpsError(
        //     "permission-denied",
        //     "Only admins can analyze reports"
        //   );
        // }
        const data = (request.data || {});
        const reports = Array.isArray(data.reports) ? data.reports : [];
        if (reports.length === 0) {
            logger.log("aiAnalyzeReports: no reports provided");
            return {
                summary: "Không có báo cáo nào để phân tích.",
                priorityCounts: { urgent: 0, high: 0, medium: 0, low: 0 },
                topReports: [],
            };
        }
        const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
        if (!config.enabled) {
            throw new https_1.HttpsError("failed-precondition", "AI report analysis is temporarily disabled");
        }
        const systemPrompt = config.systemPrompt;
        const reportsJson = JSON.stringify(reports, null, 2);
        const userPrompt = (0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
            reportCount: reports.length.toString(),
            reportsJson,
        });
        const result = await (0, openai_client_1.callOpenAIJson)({
            system: systemPrompt,
            user: userPrompt,
            jsonSchema: responseSchema,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
        });
        logger.log("aiAnalyzeReports: success", {
            reportCount: reports.length,
            urgent: result.priorityCounts.urgent,
            high: result.priorityCounts.high,
        });
        return result;
    }
    catch (err) {
        (0, ai_common_1.handleAiError)(err, "aiAnalyzeReports");
    }
});
//# sourceMappingURL=ai_analyze_reports.js.map