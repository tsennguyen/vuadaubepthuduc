import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import { OPENAI_API_KEY, handleAiError } from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const FEATURE_ID = "recipe_enrich";

export interface AiEnrichRecipeDraftInput {
  title: string;
  description?: string;
  rawIngredients: string;
}

export interface EnrichedIngredient {
  name: string;
  quantity?: number;
  unit?: string;
  note?: string | null;
}

export interface AiEnrichRecipeDraftData {
  ingredients: EnrichedIngredient[];
  tags: string[];
  searchTokens: string[];
  ingredientsTokens: string[];
}

export interface AiEnrichRecipeDraftOutput
  extends AiEnrichRecipeDraftData {
  ok: true;
}

const enrichSchema = {
  name: "RecipeDraftEnrichment",
  schema: {
    type: "object",
    properties: {
      ingredients: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            quantity: { type: "number" },
            unit: { type: "string" },
            note: { type: ["string", "null"] },
          },
          required: ["name"],
        },
      },
      tags: { type: "array", items: { type: "string" } },
      searchTokens: { type: "array", items: { type: "string" } },
      ingredientsTokens: { type: "array", items: { type: "string" } },
    },
    required: ["ingredients", "tags", "searchTokens", "ingredientsTokens"],
  },
};

export const aiEnrichRecipeDraft = onCall(
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

      const { title, description = "", rawIngredients } = validateInput(request);
      if (!title && !description && !rawIngredients) {
        return emptyOutput();
      }

      const config = await getAiConfigOrThrow(FEATURE_ID);
      if (!config.enabled) {
        throw new HttpsError(
          "failed-precondition",
          "AI recipe enrichment is temporarily disabled"
        );
      }

      const systemPrompt = config.systemPrompt;
      const inputJson = JSON.stringify(
        { title, description, rawIngredients },
        null,
        2
      );
      const userPrompt = compactPrompt(
        renderPromptTemplate(config.userPromptTemplate, {
          inputJson,
          title,
          description,
          rawIngredients,
        })
      );

      const parsed = sanitizeOutput(
        await callOpenAIJson<AiEnrichRecipeDraftData>({
          system: systemPrompt,
          user: userPrompt,
          jsonSchema: enrichSchema,
          temperature: config.temperature,
          model: config.model,
          maxOutputTokens: config.maxOutputTokens,
        })
      );

      return {
        ok: true,
        ...parsed,
      };
    } catch (err) {
      handleAiError(err, "aiEnrichRecipeDraft");
    }
  }
);

function validateInput(
  request: CallableRequest<AiEnrichRecipeDraftInput>
): AiEnrichRecipeDraftInput {
  const data = (request.data || {}) as Partial<AiEnrichRecipeDraftInput>;
  return {
    title: (data.title ?? "").toString().trim(),
    description: (data.description ?? "").toString().trim(),
    rawIngredients: (data.rawIngredients ?? "").toString().trim(),
  };
}

function sanitizeOutput(data: any): AiEnrichRecipeDraftData {
  const ingredients = Array.isArray(data?.ingredients)
    ? data.ingredients
      .map((item: any) => sanitizeIngredient(item))
      .filter((item): item is EnrichedIngredient => Boolean(item))
    : [];

  const tags = normalizeStringArray(data?.tags);
  const searchTokens = normalizeStringArray(data?.searchTokens);
  const ingredientsTokens = normalizeStringArray(
    data?.ingredientsTokens ?? data?.ingredientTokens
  );

  return {
    ingredients,
    tags,
    searchTokens,
    ingredientsTokens,
  };
}

function sanitizeIngredient(raw: any): EnrichedIngredient | null {
  const name = normalizeText(raw?.name);
  if (!name) return null;

  const quantity = toNumber(raw?.quantity);
  const unit = normalizeText(raw?.unit);
  const note = normalizeText(raw?.note);

  const ingredient: EnrichedIngredient = {
    name,
    note: note ?? null,
  };
  if (quantity !== undefined) ingredient.quantity = quantity;
  if (unit) ingredient.unit = unit;

  return ingredient;
}

function normalizeStringArray(value: any): string[] {
  if (!Array.isArray(value)) return [];
  const out: string[] = [];
  const seen = new Set<string>();

  for (const item of value) {
    const normalized = normalizeToken(String(item ?? ""));
    if (normalized && !seen.has(normalized)) {
      seen.add(normalized);
      out.push(normalized);
    }
  }
  return out;
}

function normalizeToken(input: string): string {
  return removeAccents(input.toLowerCase())
    .replace(/[^a-z0-9\s]/g, " ")
    .trim()
    .replace(/\s+/g, "_");
}

function normalizeText(value: unknown): string | undefined {
  if (value === null || value === undefined) return undefined;
  const text = String(value).trim();
  return text || undefined;
}

function compactPrompt(prompt: string): string {
  return prompt
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.trim().length > 0)
    .join("\n");
}

function toNumber(value: unknown): number | undefined {
  if (value === null || value === undefined) return undefined;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const match = String(value).match(/-?\d+(\.\d+)?/);
  if (!match) return undefined;
  const num = Number(match[0]);
  return Number.isFinite(num) && num > 0 ? num : undefined;
}

function removeAccents(input: string): string {
  return input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\u0111/g, "d")
    .replace(/\u0110/g, "d");
}

function emptyOutput(): AiEnrichRecipeDraftOutput {
  return {
    ok: true,
    ingredients: [],
    tags: [],
    searchTokens: [],
    ingredientsTokens: [],
  };
}
