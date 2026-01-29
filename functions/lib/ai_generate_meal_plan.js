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
exports.aiGenerateMealPlan = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const firestore_1 = require("firebase-admin/firestore");
const firebase_1 = require("./firebase");
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const FEATURE_ID = "meal_plan";
const ALLOWED_MEAL_TYPES = new Set([
    "breakfast",
    "lunch",
    "dinner",
    "snack",
]);
const DEFAULT_MACROS = {
    calories: 2000,
    protein: 90,
    carbs: 250,
    fat: 70,
};
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
exports.aiGenerateMealPlan = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "256MiB",
    cpu: 0.25,
    maxInstances: 1,
}, async (request) => {
    try {
        // Authentication required
        if (!request.auth || !request.auth.uid) {
            throw new https_1.HttpsError('unauthenticated', 'Authentication required');
        }
        const { userId, weekStartIso } = validateInput(request);
        const weekDates = buildWeekDates(weekStartIso);
        const userSnap = await firebase_1.db.collection("users").doc(userId).get();
        if (!userSnap.exists) {
            throw new https_1.HttpsError("failed-precondition", "USER_PROFILE_NOT_FOUND");
        }
        const profile = userSnap.data();
        const dietGoal = sanitizeDietGoal(profile?.dietGoal);
        const macroTarget = sanitizeMacroTarget(profile?.macroTarget);
        const mealsPerDay = toPositiveInt(profile?.mealsPerDay) ?? 3;
        const favoriteIngredients = sanitizeStringArray(profile?.favoriteIngredients);
        const allergies = sanitizeStringArray(profile?.allergies);
        const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
        if (!config.enabled) {
            throw new https_1.HttpsError("failed-precondition", "AI meal plan generation is temporarily disabled");
        }
        const systemPrompt = config.systemPrompt;
        const contextJson = JSON.stringify({
            dietGoal,
            macroTargetPerDay: macroTarget,
            mealsPerDay,
            favoriteIngredients,
            allergies,
        }, null, 2);
        const userPrompt = compactPrompt((0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
            weekDates: weekDates.map((d) => d.iso).join(", "),
            contextJson,
        }));
        const plan = parseAiResponse(await (0, openai_client_1.callOpenAIJson)({
            system: systemPrompt,
            user: userPrompt,
            jsonSchema: mealPlanSchema,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
        }), new Set(weekDates.map((d) => d.iso)));
        if (!plan?.length) {
            logger.error("aiGenerateMealPlan parse error", {
                preview: userPrompt.slice(0, 120),
            });
            throw new https_1.HttpsError("unavailable", "AI service is temporarily unavailable. Please try again later.");
        }
        await clearExistingWeek(userId, weekDates);
        const mealsCount = await saveMealPlan(userId, weekDates, plan);
        return {
            ok: true,
            message: "generated",
            weekStartIso,
            daysCount: plan.length,
            mealsCount,
        };
    }
    catch (err) {
        (0, ai_common_1.handleAiError)(err, "aiGenerateMealPlan");
    }
});
function validateInput(request) {
    const data = (request.data || {});
    const authUid = request.auth?.uid;
    const isAdmin = Boolean(request.auth?.token?.admin);
    const userId = (data.userId ?? authUid ?? "").toString().trim();
    const weekStartIso = normalizeIsoDateString((data.weekStartIso ?? data.weekStart ?? "").toString());
    if (!authUid) {
        throw new https_1.HttpsError("unauthenticated", "AUTH_REQUIRED");
    }
    if (!userId) {
        throw new https_1.HttpsError("invalid-argument", "USER_ID_REQUIRED");
    }
    if (!isAdmin && authUid !== userId) {
        throw new https_1.HttpsError("permission-denied", "UNAUTHORIZED_USER");
    }
    if (!weekStartIso) {
        throw new https_1.HttpsError("invalid-argument", "WEEK_START_INVALID");
    }
    return { userId, weekStartIso };
}
function parseAiResponse(candidate, allowedDates) {
    const daysInput = Array.isArray(candidate?.days) ? candidate.days : [];
    const days = [];
    for (const rawDay of daysInput) {
        const date = normalizeDate(rawDay?.date);
        if (!date || !allowedDates.has(date))
            continue;
        const mealsInput = Array.isArray(rawDay?.meals) ? rawDay.meals : [];
        const meals = [];
        for (const rawMeal of mealsInput) {
            const meal = sanitizeMeal(rawMeal);
            if (meal)
                meals.push(meal);
        }
        if (meals.length) {
            days.push({ date, meals });
        }
    }
    return days.length ? days : null;
}
function compactPrompt(prompt) {
    return prompt
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line) => line.trim().length > 0)
        .join("\n");
}
function sanitizeMeal(raw) {
    const mealType = normalizeMealType(raw?.mealType);
    if (!mealType)
        return null;
    const title = normalizeText(raw?.title) ?? normalizeText(raw?.name);
    const recipeId = normalizeText(raw?.recipeId);
    if (!title && !recipeId)
        return null;
    const servings = toPositiveInt(raw?.servings) ?? 1;
    const estimatedMacros = sanitizeMacroTarget(raw?.estimatedMacros);
    const note = normalizeText(raw?.note);
    const meal = {
        mealType,
        servings,
        estimatedMacros,
    };
    if (title)
        meal.title = title;
    if (recipeId)
        meal.recipeId = recipeId;
    if (note)
        meal.note = note;
    return meal;
}
function sanitizeDietGoal(value) {
    const goal = String(value ?? "").trim();
    if (goal === "lose_weight" ||
        goal === "maintain" ||
        goal === "gain_muscle") {
        return goal;
    }
    return "maintain";
}
function sanitizeMacroTarget(value) {
    const calories = normalizeMacroNumber(value?.calories);
    const protein = normalizeMacroNumber(value?.protein);
    const carbs = normalizeMacroNumber(value?.carbs);
    const fat = normalizeMacroNumber(value?.fat);
    if (calories === undefined ||
        protein === undefined ||
        carbs === undefined ||
        fat === undefined) {
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
function normalizeMacroNumber(value) {
    const num = toNumber(value);
    if (num === undefined)
        return undefined;
    return num < 0 ? 0 : num;
}
function sanitizeStringArray(value) {
    if (!Array.isArray(value))
        return [];
    const out = [];
    const seen = new Set();
    for (const item of value) {
        const normalized = normalizeToken(String(item ?? ""));
        if (normalized && !seen.has(normalized)) {
            seen.add(normalized);
            out.push(normalized);
        }
    }
    return out;
}
function normalizeToken(input) {
    return removeAccents(input.toLowerCase())
        .replace(/[^a-z0-9\s]/g, " ")
        .trim()
        .replace(/\s+/g, "_");
}
function normalizeText(value) {
    if (value === null || value === undefined)
        return undefined;
    const text = String(value).trim();
    return text || undefined;
}
function normalizeMealType(value) {
    const text = normalizeToken(String(value ?? ""));
    return ALLOWED_MEAL_TYPES.has(text) ? text : null;
}
function normalizeDate(value) {
    if (typeof value !== "string")
        return null;
    const match = value.trim().match(/^(\d{4})-(\d{2})-(\d{2})/);
    return match ? `${match[1]}-${match[2]}-${match[3]}` : null;
}
function normalizeIsoDateString(value) {
    const trimmed = value.trim();
    if (!trimmed)
        return "";
    const direct = normalizeDate(trimmed);
    if (direct)
        return direct;
    const parsed = new Date(trimmed);
    if (Number.isNaN(parsed.getTime())) {
        return "";
    }
    return parsed.toISOString().slice(0, 10);
}
function toNumber(value) {
    if (value === null || value === undefined)
        return undefined;
    if (typeof value === "number" && Number.isFinite(value))
        return value;
    const match = String(value).match(/-?\d+(\.\d+)?/);
    if (!match)
        return undefined;
    const num = Number(match[0]);
    return Number.isFinite(num) ? num : undefined;
}
function toPositiveInt(value) {
    const num = toNumber(value);
    if (num === undefined || num <= 0)
        return undefined;
    return Math.round(num);
}
function removeAccents(input) {
    return input
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/\u0111/g, "d")
        .replace(/\u0110/g, "d");
}
function buildWeekDates(weekStartIso) {
    const [year, month, day] = weekStartIso.split("-").map((s) => Number(s));
    const base = new Date(Date.UTC(year, month - 1, day, 12, 0, 0, 0));
    if (Number.isNaN(base.getTime())) {
        throw new https_1.HttpsError("invalid-argument", "WEEK_START_INVALID");
    }
    const days = [];
    for (let i = 0; i < 7; i++) {
        const d = new Date(base.getTime() + i * 24 * 60 * 60 * 1000);
        days.push({ iso: formatIsoDate(d), date: d });
    }
    return days;
}
function formatIsoDate(date) {
    return date.toISOString().slice(0, 10);
}
async function clearExistingWeek(userId, weekDates) {
    for (const day of weekDates) {
        const mealsRef = firebase_1.db
            .collection("mealPlans")
            .doc(userId)
            .collection("days")
            .doc(day.iso)
            .collection("meals");
        const snap = await mealsRef.get();
        if (snap.empty)
            continue;
        const batch = firebase_1.db.batch();
        snap.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
    }
}
async function saveMealPlan(userId, weekDates, plan) {
    let mealsCount = 0;
    for (const day of plan) {
        const dayDate = weekDates.find((d) => d.iso === day.date)?.date ??
            new Date(`${day.date}T12:00:00Z`);
        const mealsRef = firebase_1.db
            .collection("mealPlans")
            .doc(userId)
            .collection("days")
            .doc(day.date)
            .collection("meals");
        const batch = firebase_1.db.batch();
        for (const meal of day.meals) {
            const ref = mealsRef.doc();
            const docData = {
                mealType: meal.mealType,
                servings: meal.servings,
                plannedFor: firestore_1.Timestamp.fromDate(dayDate),
                estimatedMacros: meal.estimatedMacros,
            };
            if (meal.title)
                docData.title = meal.title;
            if (meal.recipeId)
                docData.recipeId = meal.recipeId;
            if (meal.note)
                docData.note = meal.note;
            batch.set(ref, docData);
            mealsCount++;
        }
        await batch.commit();
    }
    return mealsCount;
}
//# sourceMappingURL=ai_generate_meal_plan.js.map