import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { OPENAI_API_KEY, handleAiError } from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const FEATURE_ID = "nutrition";

export interface IngredientInput {
  name: string;
  quantity?: number;
  unit?: string;
}

export interface AiEstimateNutritionInput {
  ingredients: IngredientInput[];
  servings?: number;
}

export interface NutritionOutput {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

const zeroMacros = (): NutritionOutput => ({
  calories: 0,
  protein: 0,
  carbs: 0,
  fat: 0,
});

const nutritionSchema = {
  name: "NutritionEstimate",
  schema: {
    type: "object",
    properties: {
      calories: { type: "number" },
      protein: { type: "number" },
      carbs: { type: "number" },
      fat: { type: "number" },
    },
    required: ["calories", "protein", "carbs", "fat"],
  },
};

/**
 * Callable to estimate macros per serving based on a normalized ingredient list.
 * Flutter usage (Create/Edit Recipe):
 * `FirebaseFunctions.instance.httpsCallable('aiEstimateNutrition').call({'ingredients': [...], 'servings': 2});`
 */
export const aiEstimateNutrition = onCall(
  {
    region: REGION,
    secrets: [OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (request) => {
    try {
      const data = (request.data || {}) as Partial<AiEstimateNutritionInput>;
      const ingredients = Array.isArray(data.ingredients)
        ? data.ingredients
            .map(sanitizeIngredient)
            .filter((item): item is IngredientInput => Boolean(item))
        : [];

      if (!ingredients.length) {
        logger.log("aiEstimateNutrition: no ingredients, return zeros");
        return zeroMacros();
      }

      const servings = sanitizeServings(data.servings);
      const config = await getAiConfigOrThrow(FEATURE_ID);
      if (!config.enabled) {
        throw new HttpsError(
          "failed-precondition",
          "AI nutrition estimation is temporarily disabled"
        );
      }

      const systemPrompt = config.systemPrompt;
      const ingredientsJson = JSON.stringify(
        { ingredients, servings },
        null,
        2
      );
      const userPrompt = compactPrompt(
        renderPromptTemplate(config.userPromptTemplate, {
          ingredientsJson,
          servings: servings.toString(),
        })
      );

      const parsed = sanitizeOutput(
        await callOpenAIJson<NutritionOutput>({
          system: systemPrompt,
          user: userPrompt,
          jsonSchema: nutritionSchema,
          temperature: config.temperature,
          model: config.model,
          maxOutputTokens: config.maxOutputTokens,
        })
      );

      return parsed;
    } catch (err) {
      handleAiError(err, "aiEstimateNutrition");
    }
  }
);

function sanitizeOutput(data: any): NutritionOutput {
  // If AI misses or returns invalid numbers, default to 0 to keep the client predictable.
  const calories = normalizeMacro(data?.calories);
  const protein = normalizeMacro(data?.protein);
  const carbs = normalizeMacro(data?.carbs);
  const fat = normalizeMacro(data?.fat);

  return { calories, protein, carbs, fat };
}

function sanitizeIngredient(raw: any): IngredientInput | null {
  const name = normalizeText(raw?.name);
  if (!name) return null;

  const quantity = toNumber(raw?.quantity);
  const unit = normalizeText(raw?.unit);

  const ingredient: IngredientInput = { name };
  if (quantity !== undefined) ingredient.quantity = quantity;
  if (unit) ingredient.unit = unit;
  return ingredient;
}

function sanitizeServings(value: unknown): number {
  const num = toNumber(value);
  if (num && num > 0) return num;
  return 1;
}

function normalizeText(value: unknown): string | undefined {
  if (value === null || value === undefined) return undefined;
  const text = String(value).trim();
  return text || undefined;
}

function toNumber(value: unknown): number | undefined {
  if (value === null || value === undefined) return undefined;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const match = String(value).match(/-?\d+(\.\d+)?/);
  if (!match) return undefined;
  const num = Number(match[0]);
  return Number.isFinite(num) ? num : undefined;
}

function normalizeMacro(value: unknown): number {
  const num = toNumber(value);
  if (num === undefined) return 0;
  return num < 0 ? 0 : num;
}

function compactPrompt(prompt: string): string {
  return prompt
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.trim().length > 0)
    .join("\n");
}
