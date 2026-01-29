import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { Timestamp } from "firebase-admin/firestore";

import { OPENAI_API_KEY } from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";
import { db } from "./firebase";

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

type ModerationVerdict = {
  categories: string[];
  severity: string;
  safeSummary: string;
  flagged?: boolean;
};

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
        description:
          'List of violation categories. Use ["none"] if no violation detected.',
      },
      severity: {
        type: "string",
        enum: Array.from(SEVERITY_WHITELIST),
      },
      safeSummary: {
        type: "string",
        description:
          "Short masked summary safe for admins. Must not include sensitive words verbatim.",
      },
      flagged: { type: "boolean" },
    },
    required: ["categories", "severity", "safeSummary"],
  },
};

export const onChatMessageCreatedModeration = onDocumentCreated(
  {
    region: REGION,
    document: "chats/{cid}/messages/{mid}",
    secrets: [OPENAI_API_KEY],
    memory: "256MiB",
    cpu: 0.5,
    maxInstances: 2,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const { cid, mid } = event.params;
    const data = snap.data() as Record<string, any>;

    const senderId = stringOrEmpty(data.senderId) || stringOrEmpty(data.authorId);
    const type = (data.type as string | undefined)?.trim().toLowerCase() || "text";
    const text =
      stringOrEmpty(data.text) ||
      stringOrEmpty(data.body) ||
      stringOrEmpty(data.content) ||
      stringOrEmpty(data.message) ||
      "";
    const attachmentUrl = stringOrEmpty(data.attachmentUrl) || undefined;

    if (!senderId) {
      logger.warn("Message missing senderId, skip moderation", { cid, mid });
      return;
    }

    const config = await getAiConfigOrThrow(FEATURE_ID);
    if (!config.enabled) {
      logger.debug("Chat moderation disabled, skipping", { cid, mid });
      return;
    }

    const now = Timestamp.now();
    const prompt = renderPromptTemplate(config.userPromptTemplate, {
      chatId: cid,
      messageId: mid,
      senderId,
      messageType: type,
      messageText: text || `[${type} message]`,
      attachmentUrl: attachmentUrl ?? "",
      sentAt: (data.createdAt as Timestamp | undefined)?.toDate().toISOString() ??
        new Date(now.toMillis()).toISOString(),
    });

    let verdict: ModerationVerdict | null = null;
    try {
      verdict = sanitizeVerdict(
        await callOpenAIJson<ModerationVerdict>({
          system: config.systemPrompt,
          user: prompt,
          jsonSchema: moderationSchema,
          temperature: config.temperature,
          model: config.model,
          maxOutputTokens: config.maxOutputTokens,
        })
      );
    } catch (error) {
      logger.error("Chat moderation AI error", {
        cid,
        mid,
        error: (error as Error)?.message,
      });
      return;
    }

    if (!verdict || verdict.categories.length === 0) {
      logger.warn("Chat moderation returned empty verdict", { cid, mid });
      return;
    }

    const isClean =
      verdict.categories.length === 1 && verdict.categories[0] === "none";
    if (isClean) {
      return; // no violation -> do not store
    }

    const violationRef = db.collection("chatViolations").doc();

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
    } catch (error) {
      logger.error("Failed to write chatViolations", {
        cid,
        mid,
        error: (error as Error)?.message,
      });
      return;
    }

    try {
      const since = Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);
      const countSnap = await db
        .collection("chatViolations")
        .where("chatId", "==", cid)
        .where("createdAt", ">=", since)
        .count()
        .get();

      await db.collection("chats").doc(cid).set(
        {
          lastViolationAt: now,
          violationCount24h: countSnap.data().count ?? 1,
        },
        { merge: true }
      );
    } catch (error) {
      logger.error("Failed to update chat violation counters", {
        cid,
        mid,
        error: (error as Error)?.message,
      });
    }
  }
);

function sanitizeVerdict(candidate: ModerationVerdict | null): ModerationVerdict | null {
  if (!candidate) return null;

  const categories = Array.from(
    new Set(
      (candidate.categories ?? [])
        .map((c) => c?.toString().trim().toLowerCase())
        .filter((c) => CATEGORY_WHITELIST.has(c))
    )
  );

  if (categories.length === 0) categories.push("other");

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

function stringOrEmpty(value: unknown): string {
  if (value === null || value === undefined) return "";
  const text = String(value).trim();
  return text;
}
