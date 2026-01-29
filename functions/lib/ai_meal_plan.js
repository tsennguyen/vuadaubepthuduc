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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiGenerateMealPlan = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const node_fetch_1 = __importDefault(require("node-fetch"));
const firestore_1 = require("firebase-admin/firestore");
const firebase_1 = require("./firebase");
const REGION = "asia-southeast1";
const MODEL_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
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
exports.aiGenerateMealPlan = (0, https_1.onCall)({ region: REGION, cors: true }, async (request) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "GEMINI_API_KEY is not set");
    }
    const data = (request.data || {});
    const userId = (data.userId ?? "").toString().trim();
    const weekStart = (data.weekStart ?? "").toString().trim();
    if (!userId) {
        throw new https_1.HttpsError("invalid-argument", "userId is required");
    }
    if (!weekStart || !/^\d{4}-\d{2}-\d{2}$/.test(weekStart)) {
        throw new https_1.HttpsError("invalid-argument", "weekStart must be YYYY-MM-DD");
    }
    const authUid = request.auth?.uid;
    const isAdmin = Boolean(request.auth?.token?.admin);
    if (!authUid || (!isAdmin && authUid !== userId)) {
        throw new https_1.HttpsError("permission-denied", "Unauthorized");
    }
    const weekDates = buildWeekDates(weekStart);
    const userSnap = await firebase_1.db.collection("users").doc(userId).get();
    if (!userSnap.exists) {
        throw new https_1.HttpsError("failed-precondition", "User profile not found");
    }
    const profile = userSnap.data();
    const dietGoal = sanitizeDietGoal(profile?.dietGoal);
    const macroTarget = sanitizeMacroTarget(profile?.macroTarget);
    const mealsPerDay = toPositiveInt(profile?.mealsPerDay) ?? 3;
    const favoriteIngredients = sanitizeStringArray(profile?.favoriteIngredients);
    const allergies = sanitizeStringArray(profile?.allergies);
    const systemPrompt = buildSystemPrompt();
    const userPrompt = buildUserPrompt({
        dietGoal,
        macroTarget,
        mealsPerDay,
        weekDates: weekDates.map((d) => d.iso),
        favoriteIngredients,
        allergies,
    });
    let rawText = "";
    try {
        const resp = await (0, node_fetch_1.default)(`${MODEL_URL}?key=${apiKey}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                systemInstruction: {
                    role: "system",
                    parts: [{ text: systemPrompt }],
                },
                contents: [
                    {
                        role: "user",
                        parts: [{ text: userPrompt }],
                    },
                ],
                generationConfig: {
                    temperature: 0.2,
                },
            }),
        });
        if (!resp.ok) {
            const bodyPreview = await resp.text();
            logger.error("Gemini meal plan request failed", {
                status: resp.status,
                bodyPreview: bodyPreview.slice(0, 200),
            });
            throw new https_1.HttpsError("internal", "AI meal plan request failed");
        }
        const json = (await resp.json());
        rawText = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    }
    catch (error) {
        logger.error("Gemini meal plan request error", {
            message: error?.message,
            userId,
        });
        throw new https_1.HttpsError("internal", "AI meal plan generation failed");
    }
    const plan = parseAiResponse(rawText, new Set(weekDates.map((d) => d.iso)));
    if (!plan?.length) {
        logger.error("aiGenerateMealPlan parse error", {
            preview: rawText.slice(0, 120),
        });
        throw new https_1.HttpsError("internal", "AI response parse error");
    }
    await clearExistingWeek(userId, weekDates);
    const mealsCount = await saveMealPlan(userId, weekDates, plan);
    return {
        weekStart,
        daysCount: plan.length,
        mealsCount,
    };
});
function buildSystemPrompt() {
    const example = `{
  "days": [
    {
      "date": "2025-03-10",
      "meals": [
        {
          "mealType": "breakfast",
          "title": "Yen mach chuoi",
          "servings": 1,
          "estimatedMacros": {
            "calories": 350,
            "protein": 20,
            "carbs": 45,
            "fat": 10
          }
        }
      ]
    }
  ]
}`;
    return [
        "You create 7-day meal plans in JSON for a Vietnamese cooking app.",
        "Use user goal, daily macro targets, meals per day, favorite ingredients, and allergies.",
        "Distribute macros per meal roughly macroTarget / mealsPerDay and align with diet goal.",
        "Respect allergies (avoid) and prefer favorite ingredients when possible.",
        "Output JSON ONLY with schema: {\"days\":[{date, meals:[{mealType, title, recipeId?, note?, servings, estimatedMacros:{calories, protein, carbs, fat}}]}]}",
        "Values: calories in kcal per serving; protein/carbs/fat in grams per serving.",
        "No explanations or markdown.",
        "Example:",
        example,
    ].join("\n");
}
function buildUserPrompt(input) {
    return [
        "Generate a 7-day meal plan for these dates:",
        input.weekDates.join(", "),
        "Context JSON:",
        JSON.stringify({
            dietGoal: input.dietGoal,
            macroTargetPerDay: input.macroTarget,
            mealsPerDay: input.mealsPerDay,
            favoriteIngredients: input.favoriteIngredients,
            allergies: input.allergies,
        }, null, 2),
        "Rules:",
        "- 2-4 meals/day depending on mealsPerDay.",
        "- Provide mealType (breakfast/lunch/dinner/snack), title, servings (>=1), estimatedMacros per serving.",
        "- If suggesting a known recipe, you may include recipeId or name-like string (optional).",
        "- Keep macros close to daily target spread across meals; adjust to fit dietGoal (lose_weight slightly below, gain_muscle protein-forward).",
        "Return JSON only.",
    ].join("\n");
}
function parseAiResponse(text, allowedDates) {
    if (typeof text !== "string" || !text.trim())
        return null;
    const candidate = tryParseJson(text);
    if (!candidate)
        return null;
    const daysInput = Array.isArray(candidate?.days)
        ? candidate.days
        : [];
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
function tryParseJson(text) {
    try {
        return JSON.parse(text);
    }
    catch (e) {
        // fall through
    }
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start !== -1 && end !== -1 && end > start) {
        try {
            return JSON.parse(text.slice(start, end + 1));
        }
        catch (e) {
            return null;
        }
    }
    return null;
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
function buildWeekDates(weekStart) {
    const [year, month, day] = weekStart.split("-").map((s) => Number(s));
    const base = new Date(Date.UTC(year, month - 1, day, 12, 0, 0, 0));
    if (Number.isNaN(base.getTime())) {
        throw new https_1.HttpsError("invalid-argument", "weekStart is invalid date");
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
            batch.set(ref, {
                mealType: meal.mealType,
                title: meal.title,
                recipeId: meal.recipeId,
                note: meal.note,
                servings: meal.servings,
                plannedFor: firestore_1.Timestamp.fromDate(dayDate),
                estimatedMacros: meal.estimatedMacros,
            });
            mealsCount++;
        }
        await batch.commit();
    }
    return mealsCount;
}
//# sourceMappingURL=ai_meal_plan.js.map