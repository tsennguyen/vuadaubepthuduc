import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import { OPENAI_API_KEY, handleAiError } from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const FEATURE_ID = "recipe_suggest";

export interface AiSuggestInput {
  ingredients: string[];
  userPrefs?: AiSuggestUserPrefs;
}

export interface AiSuggestUserPrefs {
  servings?: number;
  maxTimeMinutes?: number;
  allergies?: string[];
  dietTags?: string[];
}

export interface AiRecipeIdea {
  title: string;
  shortDescription: string;
  ingredients: string[];
  steps: string[];
  tags: string[];
}

export interface AiSuggestOutput {
  ok: true;
  ideas: AiRecipeIdea[];
}

const suggestionsSchema = {
  name: "RecipeIdeas",
  schema: {
    type: "object",
    properties: {
      ideas: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            shortDescription: { type: "string" },
            ingredients: { type: "array", items: { type: "string" } },
            steps: { type: "array", items: { type: "string" } },
            tags: { type: "array", items: { type: "string" } },
          },
          required: ["title"],
        },
      },
    },
    required: ["ideas"],
  },
};

export const aiSuggestRecipesByIngredients = onCall(
  {
    region: REGION,
    secrets: [OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (request) => {
    try {
      // Authentication check
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      // Validate and sanitize input
      const { ingredients, userPrefs } = validateInput(request);
      if (!ingredients.length) {
        // Return empty result gracefully
        return { ok: true, ideas: [] } satisfies AiSuggestOutput;
      }

      const config = await getAiConfigOrThrow(FEATURE_ID);
      if (!config.enabled) {
        throw new HttpsError(
          "failed-precondition",
          "AI recipe suggestions are temporarily disabled"
        );
      }

      const systemPrompt = config.systemPrompt;
      const userPrompt = compactPrompt(
        renderPromptTemplate(config.userPromptTemplate, {
          ingredients: ingredients.join(", "),
          servingsLine: userPrefs.servings
            ? `Khau phan uoc tinh: ${userPrefs.servings} nguoi`
            : "",
          maxTimeLine: userPrefs.maxTimeMinutes
            ? `Thoi gian toi da: ${userPrefs.maxTimeMinutes} phut`
            : "",
          allergiesLine: userPrefs.allergies?.length
            ? `Tranh cac nguyen lieu: ${userPrefs.allergies.join(", ")}`
            : "",
          dietTagsLine: userPrefs.dietTags?.length
            ? `Uu tien phu hop che do: ${userPrefs.dietTags.join(", ")}`
            : "",
        })
      );

      const ideas = parseAiResponse(
        await callOpenAIJson<{ ideas: unknown[] }>({
          system: systemPrompt,
          user: userPrompt,
          jsonSchema: suggestionsSchema,
          temperature: config.temperature,
          model: config.model,
          maxOutputTokens: config.maxOutputTokens,
        })
      ) ?? [];

      return {
        ok: true,
        ideas,
      } satisfies AiSuggestOutput;
    } catch (err) {
      handleAiError(err, "aiSuggestRecipesByIngredients");
    }
  }
);

function validateInput(
  request: CallableRequest<AiSuggestInput>
): { ingredients: string[]; userPrefs: AiSuggestUserPrefs } {
  const data = (request.data || {}) as Partial<AiSuggestInput>;
  // Ensure ingredients is an array of non-empty strings
  const ingredients = sanitizeStringList(data.ingredients);
  const prefs = sanitizePrefs(data.userPrefs);
  return { ingredients, userPrefs: prefs };
}

function sanitizePrefs(input: AiSuggestUserPrefs | undefined): AiSuggestUserPrefs {
  if (!input) return {};
  const prefs: AiSuggestUserPrefs = {};
  const servings = toPositiveInt(input.servings);
  if (servings) prefs.servings = servings;

  const maxTimeMinutes = toPositiveInt(input.maxTimeMinutes);
  if (maxTimeMinutes) prefs.maxTimeMinutes = maxTimeMinutes;

  const allergies = sanitizeStringList(input.allergies);
  if (allergies.length) prefs.allergies = allergies;

  const dietTags = sanitizeStringList(input.dietTags);
  if (dietTags.length) prefs.dietTags = dietTags;

  return prefs;
}

function sanitizeStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    const text = normalizeText(item);
    if (text && !seen.has(text)) {
      seen.add(text);
      out.push(text);
    }
  }
  return out;
}

function parseAiResponse(data: any): AiRecipeIdea[] | null {
  const ideasInput = Array.isArray(data?.ideas) ? data.ideas : [];

  const ideas: AiRecipeIdea[] = [];
  for (const raw of ideasInput) {
    const idea = sanitizeIdea(raw);
    if (idea) ideas.push(idea);
  }

  return ideas;
}

function sanitizeIdea(raw: any): AiRecipeIdea | null {
  const title = normalizeText(raw?.title);
  if (!title) return null;

  const shortDescription =
    normalizeText(raw?.shortDescription) ??
    normalizeText(raw?.description) ??
    "";

  const ingredients = sanitizeStringList(raw?.ingredients);
  const steps = sanitizeStringList(raw?.steps);
  const tags = sanitizeStringList(raw?.tags);

  return {
    title,
    shortDescription,
    ingredients,
    steps,
    tags,
  };
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

function toPositiveInt(value: unknown): number | undefined {
  if (value === null || value === undefined) return undefined;
  const num = Number(value);
  if (!Number.isFinite(num)) return undefined;
  if (num <= 0) return undefined;
  return Math.round(num);
}
