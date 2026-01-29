"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiSuggestRecipesByIngredients = void 0;
const https_1 = require("firebase-functions/v2/https");
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const FEATURE_ID = "recipe_suggest";
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
exports.aiSuggestRecipesByIngredients = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (request) => {
    try {
        // Authentication check
        if (!request.auth || !request.auth.uid) {
            throw new https_1.HttpsError('unauthenticated', 'Authentication required');
        }
        // Validate and sanitize input
        const { ingredients, userPrefs } = validateInput(request);
        if (!ingredients.length) {
            // Return empty result gracefully
            return { ok: true, ideas: [] };
        }
        const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
        if (!config.enabled) {
            throw new https_1.HttpsError("failed-precondition", "AI recipe suggestions are temporarily disabled");
        }
        const systemPrompt = config.systemPrompt;
        const userPrompt = compactPrompt((0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
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
        }));
        const ideas = parseAiResponse(await (0, openai_client_1.callOpenAIJson)({
            system: systemPrompt,
            user: userPrompt,
            jsonSchema: suggestionsSchema,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
        })) ?? [];
        return {
            ok: true,
            ideas,
        };
    }
    catch (err) {
        (0, ai_common_1.handleAiError)(err, "aiSuggestRecipesByIngredients");
    }
});
function validateInput(request) {
    const data = (request.data || {});
    // Ensure ingredients is an array of non-empty strings
    const ingredients = sanitizeStringList(data.ingredients);
    const prefs = sanitizePrefs(data.userPrefs);
    return { ingredients, userPrefs: prefs };
}
function sanitizePrefs(input) {
    if (!input)
        return {};
    const prefs = {};
    const servings = toPositiveInt(input.servings);
    if (servings)
        prefs.servings = servings;
    const maxTimeMinutes = toPositiveInt(input.maxTimeMinutes);
    if (maxTimeMinutes)
        prefs.maxTimeMinutes = maxTimeMinutes;
    const allergies = sanitizeStringList(input.allergies);
    if (allergies.length)
        prefs.allergies = allergies;
    const dietTags = sanitizeStringList(input.dietTags);
    if (dietTags.length)
        prefs.dietTags = dietTags;
    return prefs;
}
function sanitizeStringList(value) {
    if (!Array.isArray(value))
        return [];
    const out = [];
    const seen = new Set();
    for (const item of value) {
        const text = normalizeText(item);
        if (text && !seen.has(text)) {
            seen.add(text);
            out.push(text);
        }
    }
    return out;
}
function parseAiResponse(data) {
    const ideasInput = Array.isArray(data?.ideas) ? data.ideas : [];
    const ideas = [];
    for (const raw of ideasInput) {
        const idea = sanitizeIdea(raw);
        if (idea)
            ideas.push(idea);
    }
    return ideas;
}
function sanitizeIdea(raw) {
    const title = normalizeText(raw?.title);
    if (!title)
        return null;
    const shortDescription = normalizeText(raw?.shortDescription) ??
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
function normalizeText(value) {
    if (value === null || value === undefined)
        return undefined;
    const text = String(value).trim();
    return text || undefined;
}
function compactPrompt(prompt) {
    return prompt
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line) => line.trim().length > 0)
        .join("\n");
}
function toPositiveInt(value) {
    if (value === null || value === undefined)
        return undefined;
    const num = Number(value);
    if (!Number.isFinite(num))
        return undefined;
    if (num <= 0)
        return undefined;
    return Math.round(num);
}
//# sourceMappingURL=ai_suggest_recipes.js.map