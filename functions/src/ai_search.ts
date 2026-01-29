import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { OPENAI_API_KEY } from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const FEATURE_ID = "search";

export interface AiParseSearchInput {
  q: string;
}

export interface AiSearchFilters {
  keywords: string[];
  tags: string[];
  filters: {
    maxTime?: number;
    minTime?: number;
    maxCalories?: number;
    minCalories?: number;
    servings?: number;
    mealType?: string; // breakfast/lunch/dinner/snack
    difficulty?: string; // easy/medium/hard
  };
}

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

export const aiParseSearchQuery = onCall(
  {
    region: REGION,
    secrets: [OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (request) => {
    try {
      // Authentication required
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      const data = (request.data || {}) as Partial<AiParseSearchInput>;
      const query = (data.q ?? "").toString().trim();

      if (!query) {
        return { keywords: [], tags: [], filters: {} } satisfies AiSearchFilters;
      }

      const config = await getAiConfigOrThrow(FEATURE_ID);
      if (!config.enabled) {
        throw new HttpsError(
          "failed-precondition",
          "AI search is temporarily disabled"
        );
      }

      const systemPrompt = config.systemPrompt;
      const userPrompt = compactPrompt(
        renderPromptTemplate(config.userPromptTemplate, { query })
      );

      try {
        const parsed = sanitizeAiOutput(
          await callOpenAIJson<AiSearchFilters>({
            system: systemPrompt,
            user: userPrompt,
            jsonSchema: searchSchema,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
          })
        );

        logger.log("aiParseSearchQuery parsed", {
          queryLength: query.length,
          keywords: parsed.keywords.length,
          tags: parsed.tags.length,
          filterKeys: Object.keys(parsed.filters).length,
        });
        return parsed;
      } catch (aiErr: any) {
        const fallback = buildFallback(query);
        logger.warn("aiParseSearchQuery fallback", {
          queryLength: query.length,
          error: aiErr instanceof Error ? aiErr.message : undefined,
          fallbackKeywords: fallback.keywords.length,
        });
        return fallback;
      }
    } catch (err) {
      console.error('[aiParseSearchQuery] error', err);
      if (err instanceof HttpsError) {
        throw err;
      }
      throw new HttpsError(
        'internal',
        'AI_INTERNAL_ERROR',
        err instanceof Error ? { message: err.message, stack: err.stack } : err
      );
    }
  }
);

function sanitizeAiOutput(data: any): AiSearchFilters {
  const keywords = Array.isArray(data?.keywords)
    ? uniqStrings(
      data.keywords
        .map((k: unknown) => normalizeToken(String(k || "")))
        .filter(Boolean)
    )
    : [];

  const tags = Array.isArray(data?.tags)
    ? uniqStrings(
      data.tags
        .map((t: unknown) => normalizeTag(String(t || "")))
        .filter(Boolean)
    )
    : [];

  const filtersInput = typeof data?.filters === "object" && data?.filters
    ? data.filters
    : {};

  const filters: AiSearchFilters["filters"] = {};

  const maxTime = toNumber(
    filtersInput.maxTime ??
    filtersInput.maxTimeMinutes ??
    filtersInput.timeMax ??
    filtersInput.cookTime
  );
  if (maxTime !== undefined) filters.maxTime = maxTime;

  const minTime = toNumber(filtersInput.minTime ?? filtersInput.timeMin);
  if (minTime !== undefined) filters.minTime = minTime;

  const maxCalories = toNumber(
    filtersInput.maxCalories ??
    filtersInput.caloriesMax ??
    filtersInput.maxKcal
  );
  if (maxCalories !== undefined) filters.maxCalories = maxCalories;

  const minCalories = toNumber(
    filtersInput.minCalories ??
    filtersInput.caloriesMin ??
    filtersInput.minKcal
  );
  if (minCalories !== undefined) filters.minCalories = minCalories;

  const servings = toNumber(
    filtersInput.servings ??
    filtersInput.portions ??
    filtersInput.people ??
    filtersInput.khauPhan
  );
  if (servings !== undefined) filters.servings = servings;

  const mealType = normalizeTag(
    filtersInput.mealType ??
    filtersInput.meal ??
    filtersInput.meal_type ??
    filtersInput.mealtype
  );
  if (mealType) filters.mealType = mealType;

  const difficulty = normalizeTag(
    filtersInput.difficulty ?? filtersInput.level
  );
  if (difficulty) filters.difficulty = difficulty;

  return {
    keywords,
    tags,
    filters,
  };
}

function buildFallback(query: string): AiSearchFilters {
  const normalized = removeAccents(query.toLowerCase());
  const tokens = normalized
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .map((t) => t.trim())
    .filter(
      (t) => t.length > 1 && !STOPWORDS.has(t)
    );

  return {
    keywords: uniqStrings(tokens),
    tags: [],
    filters: {},
  };
}

function normalizeToken(input: string): string {
  return removeAccents(input.toLowerCase())
    .replace(/[^a-z0-9\s]/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function normalizeTag(input: string): string {
  return normalizeToken(input).replace(/\s+/g, "_");
}

function removeAccents(input: string): string {
  return input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "d");
}

function uniqStrings(arr: string[]): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const item of arr) {
    const key = item.trim();
    if (key && !seen.has(key)) {
      seen.add(key);
      out.push(key);
    }
  }
  return out;
}

function toNumber(value: unknown): number | undefined {
  if (value === null || value === undefined) return undefined;
  const num = Number(value);
  return Number.isFinite(num) && num > 0 ? num : undefined;
}

function compactPrompt(prompt: string): string {
  return prompt
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line, index, arr) => line.trim().length > 0 || index === arr.length - 1)
    .join("\n")
    .trim();
}

// TODO: consider rate limiting per user to control AI cost and abuse.
