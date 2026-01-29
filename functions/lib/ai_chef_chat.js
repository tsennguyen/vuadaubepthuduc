"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiChefChat = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const firebase_1 = require("./firebase");
const ai_common_1 = require("./ai_common");
const openai_client_1 = require("./ai/openai_client");
const ai_config_1 = require("./ai_config");
const REGION = "asia-southeast1";
const MAX_HISTORY = 6;
const MAX_MESSAGE_LENGTH = 2000;
const FEATURE_ID = "chef_chat";
exports.aiChefChat = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "1GiB",
    cpu: 1.0,
    maxInstances: 1,
}, async (request) => {
    try {
        const data = (request.data || {});
        const userId = (data.userId ?? "").toString().trim();
        const message = (data.message ?? "").toString().trim();
        const inputSessionId = (data.sessionId ?? "").toString().trim();
        if (!userId) {
            throw new https_1.HttpsError("invalid-argument", "userId is required");
        }
        if (!message) {
            throw new https_1.HttpsError("invalid-argument", "message is required");
        }
        if (message.length > MAX_MESSAGE_LENGTH) {
            throw new https_1.HttpsError("invalid-argument", "message too long");
        }
        const authUid = request.auth?.uid;
        if (!authUid || authUid !== userId) {
            throw new https_1.HttpsError("permission-denied", "Unauthorized");
        }
        const { sessionRef, sessionId } = await ensureSession(userId, inputSessionId, message);
        const history = await loadHistory(sessionRef);
        const config = await (0, ai_config_1.getAiConfigOrThrow)(FEATURE_ID);
        if (!config.enabled) {
            throw new https_1.HttpsError("failed-precondition", "AI chef chat is temporarily disabled");
        }
        // Check if user is asking for recipes
        const needsRecipeSearch = detectRecipeIntent(message);
        let recipeContext = "No recipes found in database.";
        if (needsRecipeSearch) {
            const recipes = await searchRelevantRecipes(message);
            if (recipes.length > 0) {
                recipeContext = formatRecipesForAI(recipes);
            }
        }
        const prompt = compactPrompt((0, ai_config_1.renderPromptTemplate)(config.userPromptTemplate, {
            history: history.length
                ? history.map((msg) => {
                    const speaker = msg.role === "assistant" ? "Assistant" : "User";
                    return `${speaker}: ${msg.content}`;
                }).join("\n")
                : "Conversation history: (none)",
            message: message,
            recipeContext: recipeContext,
        }));
        const reply = (await (0, openai_client_1.callOpenAIText)({
            system: config.systemPrompt,
            user: prompt,
            temperature: config.temperature,
            model: config.model,
            maxOutputTokens: config.maxOutputTokens,
        })).trim();
        if (!reply) {
            throw new https_1.HttpsError("unavailable", "AI service is temporarily unavailable. Please try again later.");
        }
        await saveMessages(sessionRef, message, reply);
        return { reply, sessionId };
    }
    catch (err) {
        (0, ai_common_1.handleAiError)(err, "aiChefChat");
    }
});
function buildPrompt(latestMessage, history, template) {
    const historyText = history.length
        ? history
            .map((msg) => {
            const speaker = msg.role === "assistant" ? "Assistant" : "User";
            return `${speaker}: ${msg.content}`;
        })
            .join("\n")
        : "Conversation history: (none)";
    return (0, ai_config_1.renderPromptTemplate)(template, {
        history: historyText,
        message: latestMessage,
    });
}
async function ensureSession(userId, inputSessionId, initialMessage) {
    const sessions = firebase_1.db
        .collection("aiChats")
        .doc(userId)
        .collection("sessions");
    if (inputSessionId) {
        const ref = sessions.doc(inputSessionId);
        const snap = await ref.get();
        if (snap.exists) {
            return { sessionRef: ref, sessionId: inputSessionId };
        }
    }
    const ref = sessions.doc();
    await ref.set({
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        title: initialMessage.slice(0, 60),
    });
    return { sessionRef: ref, sessionId: ref.id };
}
async function loadHistory(sessionRef) {
    const snap = await sessionRef
        .collection("messages")
        .orderBy("createdAt", "desc")
        .limit(MAX_HISTORY)
        .get();
    const messages = snap.docs
        .map((doc) => doc.data())
        .filter((d) => d?.role && d?.content)
        .reverse(); // oldest first
    return messages.map((m) => ({
        role: (m.role === "assistant" ? "assistant" : "user"),
        content: String(m.content),
    }));
}
async function saveMessages(sessionRef, userMessage, assistantReply) {
    const messagesRef = sessionRef.collection("messages");
    const batch = firebase_1.db.batch();
    const now = firestore_1.FieldValue.serverTimestamp();
    const userDoc = messagesRef.doc();
    batch.set(userDoc, {
        role: "user",
        content: userMessage,
        createdAt: now,
    });
    const aiDoc = messagesRef.doc();
    batch.set(aiDoc, {
        role: "assistant",
        content: assistantReply,
        createdAt: now,
    });
    batch.update(sessionRef, { lastMessageAt: now });
    await batch.commit();
}
function compactPrompt(prompt) {
    return prompt
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line) => line.trim().length > 0)
        .join("\n");
}
/**
 * Detect if user message requires recipe search
 */
function detectRecipeIntent(message) {
    const lowerMsg = message.toLowerCase();
    // Keywords that indicate recipe search
    const recipeKeywords = [
        "món", "công thức", "nấu", "làm", "recipe",
        "gợi ý", "tìm", "có món gì", "món ăn",
        "bún", "phở", "cơm", "canh", "soup",
        "thịt", "gà", "cá", "tôm", "rau",
        "chay", "ăn kiêng", "healthy", "diet"
    ];
    return recipeKeywords.some(keyword => lowerMsg.includes(keyword));
}
/**
 * Search recipes from Firestore based on user query
 */
async function searchRelevantRecipes(query) {
    try {
        const recipesRef = firebase_1.db.collection("recipes");
        // Extract keywords from query
        const keywords = extractKeywords(query);
        if (keywords.length === 0) {
            return [];
        }
        // Search recipes by status = public
        const snapshot = await recipesRef
            .where("status", "==", "public")
            .orderBy("createdAt", "desc")
            .limit(50)
            .get();
        if (snapshot.empty) {
            return [];
        }
        // Filter and score recipes
        const scoredRecipes = snapshot.docs
            .map(doc => {
            const data = doc.data();
            const score = calculateRelevanceScore(data, keywords);
            return { id: doc.id, data, score };
        })
            .filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score)
            .slice(0, 5); // Top 5 recipes
        return scoredRecipes.map(r => ({
            id: r.id,
            title: r.data.title,
            description: r.data.description,
            ingredients: r.data.ingredients || [],
            steps: r.data.steps || [],
            tags: r.data.tags || [],
            cookingTime: r.data.cookingTime,
            servings: r.data.servings,
        }));
    }
    catch (err) {
        return [];
    }
}
/**
 * Extract keywords from user query
 */
function extractKeywords(query) {
    const lowerQuery = query
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, ""); // Remove diacritics
    // Common food-related words in Vietnamese
    const foodWords = [
        "bun", "pho", "com", "canh", "soup", "salad",
        "thit", "ga", "ca", "tom", "rau", "cu",
        "bo", "heo", "vit", "de",
        "chay", "vegetarian", "vegan",
        "keto", "low carb", "healthy"
    ];
    const found = [];
    for (const word of foodWords) {
        if (lowerQuery.includes(word)) {
            found.push(word);
        }
    }
    return found;
}
/**
 * Calculate relevance score for a recipe
 */
function calculateRelevanceScore(recipe, keywords) {
    let score = 0;
    const title = (recipe.title || "").toLowerCase();
    const description = (recipe.description || "").toLowerCase();
    const tags = (recipe.tags || []).map((t) => t.toLowerCase());
    const searchTokens = (recipe.searchTokens || []).map((t) => t.toLowerCase());
    const ingredientsTokens = (recipe.ingredientsTokens || []).map((t) => t.toLowerCase());
    for (const keyword of keywords) {
        if (title.includes(keyword))
            score += 10;
        if (description.includes(keyword))
            score += 5;
        if (tags.some((t) => t.includes(keyword)))
            score += 5;
        if (searchTokens.some((t) => t.includes(keyword)))
            score += 4;
        if (ingredientsTokens.some((t) => t.includes(keyword)))
            score += 3;
    }
    return score;
}
/**
 * Format recipes for AI context
 */
function formatRecipesForAI(recipes) {
    const formatted = recipes.map((r, index) => {
        const ingredientsList = (r.ingredients || [])
            .slice(0, 8)
            .map((ing) => `- ${ing.name} (${ing.quantity || ""} ${ing.unit || ""})`)
            .join("\n");
        const stepsList = (r.steps || [])
            .slice(0, 3)
            .map((step, i) => `${i + 1}. ${step.description || step}`)
            .join("\n");
        return `
${index + 1}. ${r.title}
   Mô tả: ${r.description || "Không có mô tả"}
   Tags: ${(r.tags || []).join(", ")}
   Thời gian nấu: ${r.cookingTime || "N/A"} phút
   Khẩu phần: ${r.servings || "N/A"}
   
   Nguyên liệu chính:
   ${ingredientsList || "Không có danh sách"}
   
   Các bước (tóm tắt):
   ${stepsList || "Không có hướng dẫn"}
`.trim();
    }).join("\n\n");
    return `
Tìm thấy ${recipes.length} công thức trong database:

${formatted}

Hãy dùng những công thức này để đề xuất cụ thể cho người dùng.
`.trim();
}
//# sourceMappingURL=ai_chef_chat.js.map