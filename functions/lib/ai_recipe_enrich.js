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
exports.aiEnrichRecipeDraft = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const node_fetch_1 = __importDefault(require("node-fetch"));
const REGION = "asia-southeast1";
const MODEL_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
exports.aiEnrichRecipeDraft = (0, https_1.onCall)({ region: REGION }, async (request) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "GEMINI_API_KEY is not set");
    }
    const data = (request.data || {});
    const title = (data.title ?? "").toString().trim();
    const description = (data.description ?? "").toString().trim();
    const rawIngredients = (data.rawIngredients ?? "").toString().trim();
    if (!title && !description && !rawIngredients) {
        return emptyOutput();
    }
    const systemPrompt = buildSystemPrompt();
    const userPrompt = buildUserPrompt({ title, description, rawIngredients });
    let rawText = "";
    try {
        const resp = await (0, node_fetch_1.default)(`${MODEL_URL}?key=${apiKey}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
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
            logger.error("Gemini enrich request failed", {
                status: resp.status,
                bodyPreview: bodyPreview.slice(0, 200),
            });
            throw new https_1.HttpsError("internal", "AI enrichment failed");
        }
        const json = (await resp.json());
        rawText = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    }
    catch (error) {
        logger.error("Gemini enrich request error", {
            message: error?.message,
            inputLength: title.length + description.length + rawIngredients.length,
        });
        throw new https_1.HttpsError("internal", "AI enrichment failed");
    }
    const parsed = parseAiResponse(rawText);
    if (parsed) {
        return parsed;
    }
    logger.warn("aiEnrichRecipeDraft parse failed, returning fallback", {
        rawLength: rawText?.length ?? 0,
    });
    return emptyOutput();
});
function buildSystemPrompt() {
    return [
        "Ban la tro ly phan tich cong thuc nau an tieng Viet.",
        "Nhiem vu: nhan title, description va rawIngredients (text tho) de tach danh sach nguyen lieu va goi y tags/tokens.",
        "Chi tra ve JSON dung schema duoi day, khong giai thich hay markdown.",
        "ingredients: array cac object co fields name (bat buoc), quantity (number neu suy ra), unit (vi du g, ml, cup, muong canh, muong cafe, trai, cai), note (ghi chu them, co the null).",
        "tags: chuoi khong dau, lowercase, snake_case hoac viet lien, mo ta loai mon (vd: vietnamese, soup, noodle, spicy, vegetarian, keto).",
        "searchTokens: tu khoa khong dau tu title + description, dung snake_case hoac viet lien (vd: bun, bo, sa_te, an_sang).",
        "ingredientsTokens: tu khoa khong dau lien quan truc tiep den nguyen lieu (vd: thit_bo, hanh_tay, ca_rot).",
        'Schema JSON bat buoc: {"ingredients":[...],"tags":[...],"searchTokens":[...],"ingredientsTokens":[...]}.',
    ].join("\n");
}
function buildUserPrompt(input) {
    return [
        "Day la input JSON:",
        JSON.stringify({
            title: input.title,
            description: input.description,
            rawIngredients: input.rawIngredients,
        }, null, 2),
        "Hay phan tich va chi tra JSON dung schema tren.",
    ].join("\n");
}
function parseAiResponse(text) {
    if (typeof text !== "string" || !text.trim()) {
        return null;
    }
    const candidate = tryParseJson(text);
    if (!candidate) {
        return null;
    }
    return sanitizeOutput(candidate);
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
        ingredients: [],
        tags: [],
        searchTokens: [],
        ingredientsTokens: [],
    };
}
//# sourceMappingURL=ai_recipe_enrich.js.map