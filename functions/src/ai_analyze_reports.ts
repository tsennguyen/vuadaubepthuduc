import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { OPENAI_API_KEY, handleAiError } from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const FEATURE_ID = "report_summary";

export interface ReportSummaryInput {
    reports: Array<{
        id: string;
        targetType: string;
        targetId: string;
        reason: string;
        note?: string;
        reporterId: string;
        createdAt: string;
    }>;
}

export interface ReportSummaryOutput {
    summary: string;
    priorityCounts: {
        urgent: number;
        high: number;
        medium: number;
        low: number;
    };
    topReports: Array<{
        reportId: string;
        severity: string;
        reason: string;
    }>;
}

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
export const aiAnalyzeReports = onCall(
    {
        region: REGION,
        secrets: [OPENAI_API_KEY],
        memory: "256MiB",
        cpu: 0.25,
        maxInstances: 2,
    },
    async (request) => {
        try {
            // TEMPORARY: Disabled admin check for testing
            // TODO: Re-enable this in production!
            // if (!request.auth?.token?.isAdmin) {
            //   throw new HttpsError(
            //     "permission-denied",
            //     "Only admins can analyze reports"
            //   );
            // }

            const data = (request.data || {}) as Partial<ReportSummaryInput>;
            const reports = Array.isArray(data.reports) ? data.reports : [];

            if (reports.length === 0) {
                logger.log("aiAnalyzeReports: no reports provided");
                return {
                    summary: "Không có báo cáo nào để phân tích.",
                    priorityCounts: { urgent: 0, high: 0, medium: 0, low: 0 },
                    topReports: [],
                };
            }

            const config = await getAiConfigOrThrow(FEATURE_ID);
            if (!config.enabled) {
                throw new HttpsError(
                    "failed-precondition",
                    "AI report analysis is temporarily disabled"
                );
            }

            const systemPrompt = config.systemPrompt;
            const reportsJson = JSON.stringify(reports, null, 2);
            const userPrompt = renderPromptTemplate(config.userPromptTemplate, {
                reportCount: reports.length.toString(),
                reportsJson,
            });

            const result = await callOpenAIJson<ReportSummaryOutput>({
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
        } catch (err) {
            handleAiError(err, "aiAnalyzeReports");
        }
    }
);
