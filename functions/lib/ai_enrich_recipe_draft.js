"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiEnrichRecipeDraft = void 0;
const https_1 = require("firebase-functions/v2/https");
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const FEATURE_ID = "recipe_enrich";
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
exports.aiEnrichRecipeDraft = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (request) => {
    try {
        // Authentication required
        if (!request.auth || !request.auth.uid) {
            throw new https_1.HttpsError('unauthenticated', 'Authentication required');
        }
        const { title, description = "", rawIngredients } = validateInput(request);
        if (!title && !description && !rawIngredients) {
            return emptyOutput();
        }
        const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
        if (!config.enabled) {
            throw new https_1.HttpsError("failed-precondition", "AI recipe enrichment is temporarily disabled");
        }
        const systemPrompt = config.systemPrompt;
        const inputJson = JSON.stringify({ title, description, rawIngredients }, null, 2);
        const userPrompt = compactPrompt((0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
            inputJson,
            title,
            description,
            rawIngredients,
        }));
        const parsed = sanitizeOutput(await (0, openai_client_1.callOpenAIJson)({
            system: systemPrompt,
            user: userPrompt,
            jsonSchema: enrichSchema,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
        }));
        return {
            ok: true,
            ...parsed,
        };
    }
    catch (err) {
        (0, ai_common_1.handleAiError)(err, "aiEnrichRecipeDraft");
    }
});
function validateInput(request) {
    const data = (request.data || {});
    return {
        title: (data.title ?? "").toString().trim(),
        description: (data.description ?? "").toString().trim(),
        rawIngredients: (data.rawIngredients ?? "").toString().trim(),
    };
}
function sanitizeOutput(data) {
    const ingredients = Array.isArray(data?.ingredients)
        ? data.ingredients
            .map((item) => sanitizeIngredient(item))
            .filter((item) => Boolean(item))
        : [];
    const tags = normalizeStringArray(data?.tags);
    const searchTokens = normalizeStringArray(data?.searchTokens);
    const ingredientsTokens = normalizeStringArray(data?.ingredientsTokens ?? data?.ingredientTokens);
    return {
        ingredients,
        tags,
        searchTokens,
        ingredientsTokens,
    };
}
function sanitizeIngredient(raw) {
    const name = normalizeText(raw?.name);
    if (!name)
        return null;
    const quantity = toNumber(raw?.quantity);
    const unit = normalizeText(raw?.unit);
    const note = normalizeText(raw?.note);
    const ingredient = {
        name,
        note: note ?? null,
    };
    if (quantity !== undefined)
        ingredient.quantity = quantity;
    if (unit)
        ingredient.unit = unit;
    return ingredient;
}
function normalizeStringArray(value) {
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
function compactPrompt(prompt) {
    return prompt
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line) => line.trim().length > 0)
        .join("\n");
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
    return Number.isFinite(num) && num > 0 ? num : undefined;
}
function removeAccents(input) {
    return input
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/\u0111/g, "d")
        .replace(/\u0110/g, "d");
}
function emptyOutput() {
    return {
        ok: true,
        ingredients: [],
        tags: [],
        searchTokens: [],
        ingredientsTokens: [],
    };
}
//# sourceMappingURL=ai_enrich_recipe_draft.js.map