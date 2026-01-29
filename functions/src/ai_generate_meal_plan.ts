import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./firebase";
import {
  handleAiError,
  OPENAI_API_KEY,
} from "./ai_common";
import { callOpenAIJson } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const FEATURE_ID = "meal_plan";

const ALLOWED_MEAL_TYPES = new Set([
  "breakfast",
  "lunch",
  "dinner",
  "snack",
]);

type DietGoal = "lose_weight" | "maintain" | "gain_muscle";

export interface AiGenerateMealPlanInput {
  userId?: string;
  weekStartIso: string; // ISO string; day-only portion will be used
}

interface MacroTarget {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

interface MealPlanMeal {
  mealType: "breakfast" | "lunch" | "dinner" | "snack";
  title?: string;
  recipeId?: string;
  note?: string;
  servings: number;
  estimatedMacros: MacroTarget;
}

interface MealPlanDay {
  date: string; // YYYY-MM-DD
  meals: MealPlanMeal[];
}

export interface AiGenerateMealPlanResult {
  ok: true;
  message: string;
  weekStartIso: string;
  daysCount: number;
  mealsCount: number;
}

const DEFAULT_MACROS: MacroTarget = {
  calories: 2000,
  protein: 90,
  carbs: 250,
  fat: 70,
};

type WeekDate = { iso: string; date: Date };

const mealPlanSchema = {
  name: "MealPlan",
  schema: {
    type: "object",
    properties: {
      days: {
        type: "array",
        items: {
          type: "object",
          properties: {
            date: { type: "string" },
            meals: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  mealType: {
                    type: "string",
                    enum: ["breakfast", "lunch", "dinner", "snack"],
                  },
                  title: { type: "string" },
                  recipeId: { type: "string" },
                  note: { type: "string" },
                  servings: { type: "number" },
                  estimatedMacros: {
                    type: "object",
                    properties: {
                      calories: { type: "number" },
                      protein: { type: "number" },
                      carbs: { type: "number" },
                      fat: { type: "number" },
                    },
                    required: ["calories", "protein", "carbs", "fat"],
                  },
                },
                required: ["mealType", "servings", "estimatedMacros"],
              },
            },
          },
          required: ["date", "meals"],
        },
      },
    },
    required: ["days"],
  },
};

export const aiGenerateMealPlan = onCall(
  {
    region: REGION,
    secrets: [OPENAI_API_KEY],
    memory: "256MiB",
    cpu: 0.25,
    maxInstances: 1,
  },
  async (request) => {
    try {
      // Authentication required
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      const { userId, weekStartIso } = validateInput(request);
      const weekDates = buildWeekDates(weekStartIso);

      const userSnap = await db.collection("users").doc(userId).get();
      if (!userSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "USER_PROFILE_NOT_FOUND"
        );
      }
      const profile = userSnap.data() as any;

      const dietGoal = sanitizeDietGoal(profile?.dietGoal);
      const macroTarget = sanitizeMacroTarget(profile?.macroTarget);
      const mealsPerDay = toPositiveInt(profile?.mealsPerDay) ?? 3;
      const favoriteIngredients = sanitizeStringArray(
        profile?.favoriteIngredients
      );
      const allergies = sanitizeStringArray(profile?.allergies);

      const config = await getAiConfigOrThrow(FEATURE_ID);
      if (!config.enabled) {
        throw new HttpsError(
          "failed-precondition",
          "AI meal plan generation is temporarily disabled"
        );
      }

      const systemPrompt = config.systemPrompt;
      const contextJson = JSON.stringify(
        {
          dietGoal,
          macroTargetPerDay: macroTarget,
          mealsPerDay,
          favoriteIngredients,
          allergies,
        },
        null,
        2
      );
      const userPrompt = compactPrompt(
        renderPromptTemplate(config.userPromptTemplate, {
          weekDates: weekDates.map((d) => d.iso).join(", "),
          contextJson,
        })
      );

      const plan = parseAiResponse(
        await callOpenAIJson<{ days: unknown[] }>({
          system: systemPrompt,
          user: userPrompt,
          jsonSchema: mealPlanSchema,
          temperature: config.temperature,
          model: config.model,
          maxOutputTokens: config.maxOutputTokens,
        }),
        new Set(weekDates.map((d) => d.iso))
      );
      if (!plan?.length) {
        logger.error("aiGenerateMealPlan parse error", {
          preview: userPrompt.slice(0, 120),
        });
        throw new HttpsError(
          "unavailable",
          "AI service is temporarily unavailable. Please try again later."
        );
      }

      await clearExistingWeek(userId, weekDates);
      const mealsCount = await saveMealPlan(userId, weekDates, plan);

      return {
        ok: true,
        message: "generated",
        weekStartIso,
        daysCount: plan.length,
        mealsCount,
      } satisfies AiGenerateMealPlanResult;
    } catch (err) {
      handleAiError(err, "aiGenerateMealPlan");
    }

  }
);

function validateInput(
  request: CallableRequest<AiGenerateMealPlanInput>
): { userId: string; weekStartIso: string } {
  const data = (request.data || {}) as Partial<AiGenerateMealPlanInput>;
  const authUid = request.auth?.uid;
  const isAdmin = Boolean(request.auth?.token?.admin);

  const userId = (data.userId ?? authUid ?? "").toString().trim();
  const weekStartIso = normalizeIsoDateString(
    (data.weekStartIso ?? (data as any).weekStart ?? "").toString()
  );

  if (!authUid) {
    throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
  }
  if (!userId) {
    throw new HttpsError("invalid-argument", "USER_ID_REQUIRED");
  }
  if (!isAdmin && authUid !== userId) {
    throw new HttpsError("permission-denied", "UNAUTHORIZED_USER");
  }
  if (!weekStartIso) {
    throw new HttpsError("invalid-argument", "WEEK_START_INVALID");
  }

  return { userId, weekStartIso };
}

function parseAiResponse(
  candidate: any,
  allowedDates: Set<string>
): MealPlanDay[] | null {
  const daysInput = Array.isArray(candidate?.days) ? candidate.days : [];

  const days: MealPlanDay[] = [];
  for (const rawDay of daysInput) {
    const date = normalizeDate(rawDay?.date);
    if (!date || !allowedDates.has(date)) continue;

    const mealsInput = Array.isArray(rawDay?.meals) ? rawDay.meals : [];
    const meals: MealPlanMeal[] = [];
    for (const rawMeal of mealsInput) {
      const meal = sanitizeMeal(rawMeal);
      if (meal) meals.push(meal);
    }
    if (meals.length) {
      days.push({ date, meals });
    }
  }

  return days.length ? days : null;
}

function compactPrompt(prompt: string): string {
  return prompt
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.trim().length > 0)
    .join("\n");
}

function sanitizeMeal(raw: any): MealPlanMeal | null {
  const mealType = normalizeMealType(raw?.mealType);
  if (!mealType) return null;

  const title = normalizeText(raw?.title) ?? normalizeText(raw?.name);
  const recipeId = normalizeText(raw?.recipeId);
      if (!title && !recipeId) return null;

      const servings = toPositiveInt(raw?.servings) ?? 1;
      const estimatedMacros = sanitizeMacroTarget(raw?.estimatedMacros);
      const note = normalizeText(raw?.note);

      const meal: MealPlanMeal = {
        mealType,
        servings,
        estimatedMacros,
      };
      if (title) meal.title = title;
      if (recipeId) meal.recipeId = recipeId;
      if (note) meal.note = note;

      return meal;
    }

function sanitizeDietGoal(value: unknown): DietGoal {
  const goal = String(value ?? "").trim();
  if (
    goal === "lose_weight" ||
    goal === "maintain" ||
    goal === "gain_muscle"
  ) {
    return goal;
  }
  return "maintain";
}

function sanitizeMacroTarget(value: any): MacroTarget {
  const calories = normalizeMacroNumber(value?.calories);
  const protein = normalizeMacroNumber(value?.protein);
  const carbs = normalizeMacroNumber(value?.carbs);
  const fat = normalizeMacroNumber(value?.fat);

  if (
    calories === undefined ||
    protein === undefined ||
    carbs === undefined ||
    fat === undefined
  ) {
    // Fallback to defaults if any field is missing to keep prompt stable.
    return { ...DEFAULT_MACROS };
  }

  return {
    calories,
    protein,
    carbs,
    fat,
  };
}

function normalizeMacroNumber(value: unknown): number | undefined {
  const num = toNumber(value);
  if (num === undefined) return undefined;
  return num < 0 ? 0 : num;
}

function sanitizeStringArray(value: unknown): string[] {
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

function normalizeMealType(value: unknown):
  | "breakfast"
  | "lunch"
  | "dinner"
  | "snack"
  | null {
  const text = normalizeToken(String(value ?? ""));
  return ALLOWED_MEAL_TYPES.has(text as any) ? (text as any) : null;
}

function normalizeDate(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const match = value.trim().match(/^(\d{4})-(\d{2})-(\d{2})/);
  return match ? `${match[1]}-${match[2]}-${match[3]}` : null;
}

function normalizeIsoDateString(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return "";
  const direct = normalizeDate(trimmed);
  if (direct) return direct;

  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }
  return parsed.toISOString().slice(0, 10);
}

function toNumber(value: unknown): number | undefined {
  if (value === null || value === undefined) return undefined;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const match = String(value).match(/-?\d+(\.\d+)?/);
  if (!match) return undefined;
  const num = Number(match[0]);
  return Number.isFinite(num) ? num : undefined;
}

function toPositiveInt(value: unknown): number | undefined {
  const num = toNumber(value);
  if (num === undefined || num <= 0) return undefined;
  return Math.round(num);
}

function removeAccents(input: string): string {
  return input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\u0111/g, "d")
    .replace(/\u0110/g, "d");
}

function buildWeekDates(weekStartIso: string): WeekDate[] {
  const [year, month, day] = weekStartIso.split("-").map((s) => Number(s));
  const base = new Date(Date.UTC(year, month - 1, day, 12, 0, 0, 0));
  if (Number.isNaN(base.getTime())) {
    throw new HttpsError("invalid-argument", "WEEK_START_INVALID");
  }
  const days: WeekDate[] = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(base.getTime() + i * 24 * 60 * 60 * 1000);
    days.push({ iso: formatIsoDate(d), date: d });
  }
  return days;
}

function formatIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

async function clearExistingWeek(
  userId: string,
  weekDates: WeekDate[]
): Promise<void> {
  for (const day of weekDates) {
    const mealsRef = db
      .collection("mealPlans")
      .doc(userId)
      .collection("days")
      .doc(day.iso)
      .collection("meals");
    const snap = await mealsRef.get();
    if (snap.empty) continue;
    const batch = db.batch();
    snap.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function saveMealPlan(
  userId: string,
  weekDates: WeekDate[],
  plan: MealPlanDay[]
): Promise<number> {
  let mealsCount = 0;
  for (const day of plan) {
    const dayDate =
      weekDates.find((d) => d.iso === day.date)?.date ??
      new Date(`${day.date}T12:00:00Z`);
    const mealsRef = db
      .collection("mealPlans")
      .doc(userId)
      .collection("days")
      .doc(day.date)
      .collection("meals");

    const batch = db.batch();
    for (const meal of day.meals) {
      const ref = mealsRef.doc();
      const docData: Record<string, unknown> = {
        mealType: meal.mealType,
        servings: meal.servings,
        plannedFor: Timestamp.fromDate(dayDate),
        estimatedMacros: meal.estimatedMacros,
      };
      if (meal.title) docData.title = meal.title;
      if (meal.recipeId) docData.recipeId = meal.recipeId;
      if (meal.note) docData.note = meal.note;

      batch.set(ref, docData);
      mealsCount++;
    }
    await batch.commit();
  }
  return mealsCount;
}
