import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "./firebase";
import { OPENAI_API_KEY } from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const FEATURE_ID = "report_moderation";

type TargetType = "post" | "recipe" | "comment" | "message";

const LABELS = new Set([
  "ok",
  "spam",
  "maybe_nsfw",
  "hate_speech",
  "harassment",
  "other",
]);

interface AiVerdict {
  label: "ok" | "spam" | "maybe_nsfw" | "hate_speech" | "harassment" | "other";
  confidence: number;
  notes?: string;
}

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

export const onReportCreate = onDocumentCreated(
  {
    region: REGION,
    document: "reports/{reportId}",
    secrets: [OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const reportId = event.params.reportId;
    const data = snap.data() as any;

    if (data?.aiVerdict) {
      return; // already processed
    }

    const targetType = (data?.targetType ?? "").toString() as TargetType;
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

    const config = await getAiConfigOrThrow(FEATURE_ID);
    if (!config.enabled) {
      logger.warn("AI moderation disabled, skipping verdict", { reportId, targetType });
      return;
    }

    const prompt = compactPrompt(
      renderPromptTemplate(config.userPromptTemplate, {
        targetType,
        targetId,
        content,
        reasonLine: data?.reason ? `User reason: ${data.reason}` : "",
        noteLine: data?.note ? `User note: ${data.note}` : "",
      })
    );

    let verdict: AiVerdict | null = null;
    try {
      verdict = sanitizeVerdict(
        await callOpenAIJson<AiVerdict>({
          system: config.systemPrompt,
          user: prompt,
          jsonSchema: moderationSchema,
          temperature: config.temperature,
          model: config.model,
          maxOutputTokens: config.maxOutputTokens,
        })
      );
    } catch (error) {
      logger.error("OpenAI moderation request error", {
        message: (error as Error)?.message,
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
      await db.collection("reports").doc(reportId).update({
        aiVerdict: verdict,
      });
    } catch (error) {
      logger.error("Failed to update aiVerdict", {
        reportId,
        error: (error as Error)?.message,
      });
    }
  }
);

async function fetchTargetContent(
  targetType: TargetType,
  targetId: string,
  chatId?: string
): Promise<string | null> {
  try {
    if (targetType === "post") {
      const snap = await db.collection("posts").doc(targetId).get();
      if (!snap.exists) return null;
      const data = snap.data() || {};
      const title = stringify(data.title);
      const body = stringify(data.body ?? data.content ?? data.text);
      return [title, body].filter(Boolean).join("\n").trim() || null;
    }

    if (targetType === "recipe") {
      const snap = await db.collection("recipes").doc(targetId).get();
      if (!snap.exists) return null;
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
      const snap = await db.collection("comments").doc(targetId).get();
      if (!snap.exists) return null;
      const data = snap.data() || {};
      const text = stringify(data.text ?? data.body ?? data.content);
      return text || null;
    }

    if (targetType === "message") {
      if (!chatId) return null;
      const snap = await db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(targetId)
        .get();
      if (!snap.exists) return null;
      const data = snap.data() || {};
      const text = stringify(data.text ?? data.body ?? data.content ?? data.message);
      return text || null;
    }
  } catch (error) {
    logger.error("fetchTargetContent error", {
      targetType,
      targetId,
      message: (error as Error)?.message,
    });
    return null;
  }

  return null;
}

function stringify(value: unknown): string | undefined {
  if (value === null || value === undefined) return undefined;
  const text = String(value).trim();
  return text || undefined;
}

function sanitizeVerdict(candidate: any): AiVerdict | null {
  const labelRaw = String(candidate?.label ?? "").trim();
  const label = LABELS.has(labelRaw) ? (labelRaw as AiVerdict["label"]) : "other";

  const confidence = clamp01(toNumber(candidate?.confidence));
  const notes = stringify(candidate?.notes);

  return {
    label,
    confidence,
    notes,
  };
}

function toNumber(value: unknown): number | undefined {
  if (value === null || value === undefined) return undefined;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const match = String(value).match(/-?\d+(\.\d+)?/);
  if (!match) return undefined;
  const num = Number(match[0]);
  return Number.isFinite(num) ? num : undefined;
}

function clamp01(value: number | undefined): number {
  if (value === undefined || Number.isNaN(value)) return 0;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function compactPrompt(prompt: string): string {
  return prompt
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.trim().length > 0)
    .join("\n");
}
