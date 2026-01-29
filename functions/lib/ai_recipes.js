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
exports.aiSuggestRecipesByIngredients = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const node_fetch_1 = __importDefault(require("node-fetch"));
exports.aiSuggestRecipesByIngredients = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        logger.error("GEMINI_API_KEY is missing");
        throw new https_1.HttpsError("failed-precondition", "Gemini API key is not configured.");
    }
    const data = request.data;
    const ingredients = data.ingredients?.map((s) => String(s).trim()).filter(Boolean) ?? [];
    if (!ingredients.length) {
        return { ideas: [] };
    }
    const prefs = data.userPrefs ?? {};
    const prompt = buildPrompt(ingredients, prefs);
    const resp = await (0, node_fetch_1.default)("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" +
        apiKey, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            contents: [
                {
                    parts: [{ text: prompt }],
                },
            ],
            generationConfig: {
                temperature: 0.7,
            },
        }),
    });
    if (!resp.ok) {
        const text = await resp.text();
        logger.error("Gemini request failed", { status: resp.status, text });
        throw new https_1.HttpsError("internal", "AI suggestion failed");
    }
    const json = (await resp.json());
    const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") {
        logger.error("Gemini response missing text");
        throw new https_1.HttpsError("internal", "Invalid AI response");
    }
    let parsed = null;
    try {
        parsed = JSON.parse(text);
    }
    catch (e) {
        logger.error("Failed to parse AI JSON", { error: String(e), text });
        throw new https_1.HttpsError("internal", "AI response parse error");
    }
    if (!parsed?.ideas || !Array.isArray(parsed.ideas)) {
        logger.error("AI response missing ideas array");
        throw new https_1.HttpsError("internal", "AI response invalid format");
    }
    return parsed;
});
function buildPrompt(ingredients, prefs) {
    const lines = [
        "Bạn là trợ lý nấu ăn. Hãy gợi ý các công thức nấu ăn dựa trên danh sách nguyên liệu sau.",
        `Ingredients: ${ingredients.join(", ")}`,
    ];
    if (prefs.servings) {
        lines.push(`Khẩu phần: ${prefs.servings}`);
    }
    if (prefs.maxTimeMinutes) {
        lines.push(`Thời gian tối đa: ${prefs.maxTimeMinutes} phút`);
    }
    if (prefs.allergies?.length) {
        lines.push(`Tuyệt đối không dùng: ${prefs.allergies.map((a) => a.trim()).join(", ")}`);
    }
    if (prefs.dietTags?.length) {
        lines.push(`Ưu tiên phù hợp chế độ: ${prefs.dietTags.map((d) => d.trim()).join(", ")}`);
    }
    lines.push("Trả về JSON với schema:", `{
  "ideas": [
    {
      "title": "string",
      "shortDescription": "string",
      "ingredients": ["..."],
      "steps": ["..."],
      "tags": ["..."]
    }
  ]
}`, "Chỉ trả JSON, không thêm giải thích hay markdown.");
    return lines.join("\n");
}
//# sourceMappingURL=ai_recipes.js.map