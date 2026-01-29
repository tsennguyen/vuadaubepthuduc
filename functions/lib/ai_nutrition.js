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
exports.aiEstimateNutrition = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const FEATURE_ID = "nutrition";
const zeroMacros = () => ({
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
exports.aiEstimateNutrition = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (request) => {
    try {
        const data = (request.data || {});
        const ingredients = Array.isArray(data.ingredients)
            ? data.ingredients
                .map(sanitizeIngredient)
                .filter((item) => Boolean(item))
            : [];
        if (!ingredients.length) {
            logger.log("aiEstimateNutrition: no ingredients, return zeros");
            return zeroMacros();
        }
        const servings = sanitizeServings(data.servings);
        const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
        if (!config.enabled) {
            throw new https_1.HttpsError("failed-precondition", "AI nutrition estimation is temporarily disabled");
        }
        const systemPrompt = config.systemPrompt;
        const ingredientsJson = JSON.stringify({ ingredients, servings }, null, 2);
        const userPrompt = compactPrompt((0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
            ingredientsJson,
            servings: servings.toString(),
        }));
        const parsed = sanitizeOutput(await (0, openai_client_1.callOpenAIJson)({
            system: systemPrompt,
            user: userPrompt,
            jsonSchema: nutritionSchema,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
        }));
        return parsed;
    }
    catch (err) {
        (0, ai_common_1.handleAiError)(err, "aiEstimateNutrition");
    }
});
function sanitizeOutput(data) {
    // If AI misses or returns invalid numbers, default to 0 to keep the client predictable.
    const calories = normalizeMacro(data?.calories);
    const protein = normalizeMacro(data?.protein);
    const carbs = normalizeMacro(data?.carbs);
    const fat = normalizeMacro(data?.fat);
    return { calories, protein, carbs, fat };
}
function sanitizeIngredient(raw) {
    const name = normalizeText(raw?.name);
    if (!name)
        return null;
    const quantity = toNumber(raw?.quantity);
    const unit = normalizeText(raw?.unit);
    const ingredient = { name };
    if (quantity !== undefined)
        ingredient.quantity = quantity;
    if (unit)
        ingredient.unit = unit;
    return ingredient;
}
function sanitizeServings(value) {
    const num = toNumber(value);
    if (num && num > 0)
        return num;
    return 1;
}
function normalizeText(value) {
    if (value === null || value === undefined)
        return undefined;
    const text = String(value).trim();
    return text || undefined;
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
function normalizeMacro(value) {
    const num = toNumber(value);
    if (num === undefined)
        return 0;
    return num < 0 ? 0 : num;
}
function compactPrompt(prompt) {
    return prompt
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line) => line.trim().length > 0)
        .join("\n");
}
//# sourceMappingURL=ai_nutrition.js.map