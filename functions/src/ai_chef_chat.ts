import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
  DocumentReference,
} from "firebase-admin/firestore";
import { db } from "./firebase";
import {
  handleAiError,
  OPENAI_API_KEY,
} from "./ai_common";
import { callOpenAIText } from "./ai/openai_client";
import { getAiConfigOrThrow, renderPromptTemplate } from "./ai_config";

const REGION = "asia-southeast1";
const MAX_HISTORY = 6;
const MAX_MESSAGE_LENGTH = 2000;
const FEATURE_ID = "chef_chat";

export interface AiChefChatInput {
  userId: string;
  sessionId?: string;
  message: string;
}

export interface AiChefChatOutput {
  reply: string;
  sessionId: string;
}

type ChatRole = "user" | "assistant";

export const aiChefChat = onCall(
  {
    region: REGION,
    secrets: [OPENAI_API_KEY],
    memory: "1GiB",
    cpu: 1.0,
    maxInstances: 1,
  },
  async (request): Promise<AiChefChatOutput> => {
    try {
      const data = (request.data || {}) as Partial<AiChefChatInput>;
      const userId = (data.userId ?? "").toString().trim();
      const message = (data.message ?? "").toString().trim();
      const inputSessionId = (data.sessionId ?? "").toString().trim();

      if (!userId) {
        throw new HttpsError("invalid-argument", "userId is required");
      }
      if (!message) {
        throw new HttpsError("invalid-argument", "message is required");
      }
      if (message.length > MAX_MESSAGE_LENGTH) {
        throw new HttpsError(
          "invalid-argument",
          "message too long"
        );
      }

      const authUid = request.auth?.uid;
      if (!authUid || authUid !== userId) {
        throw new HttpsError("permission-denied", "Unauthorized");
      }

      const { sessionRef, sessionId } = await ensureSession(
        userId,
        inputSessionId,
        message
      );
      const history = await loadHistory(sessionRef);
      const config = await getAiConfigOrThrow(FEATURE_ID);
      if (!config.enabled) {
        throw new HttpsError(
          "failed-precondition",
          "AI chef chat is temporarily disabled"
        );
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

      const prompt = compactPrompt(
        renderPromptTemplate(config.userPromptTemplate, {
          history: history.length
            ? history.map((msg) => {
              const speaker = msg.role === "assistant" ? "Assistant" : "User";
              return `${speaker}: ${msg.content}`;
            }).join("\n")
            : "Conversation history: (none)",
          message: message,
          recipeContext: recipeContext,
        })
      );

      const reply = (await callOpenAIText({
        system: config.systemPrompt,
        user: prompt,
        temperature: config.temperature,
        model: config.model,
        maxOutputTokens: config.maxOutputTokens,
      })).trim();
      if (!reply) {
        throw new HttpsError(
          "unavailable",
          "AI service is temporarily unavailable. Please try again later."
        );
      }

      await saveMessages(sessionRef, message, reply);

      return { reply, sessionId };
    } catch (err) {
      handleAiError(err, "aiChefChat");
    }
  }
);

function buildPrompt(
  latestMessage: string,
  history: { role: ChatRole; content: string }[],
  template: string
): string {
  const historyText = history.length
    ? history
      .map((msg) => {
        const speaker = msg.role === "assistant" ? "Assistant" : "User";
        return `${speaker}: ${msg.content}`;
      })
      .join("\n")
    : "Conversation history: (none)";

  return renderPromptTemplate(template, {
    history: historyText,
    message: latestMessage,
  });
}

async function ensureSession(
  userId: string,
  inputSessionId: string,
  initialMessage: string
): Promise<{ sessionRef: DocumentReference; sessionId: string }> {
  const sessions = db
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
    createdAt: FieldValue.serverTimestamp(),
    lastMessageAt: FieldValue.serverTimestamp(),
    title: initialMessage.slice(0, 60),
  });

  return { sessionRef: ref, sessionId: ref.id };
}

async function loadHistory(
  sessionRef: DocumentReference
): Promise<{ role: ChatRole; content: string }[]> {
  const snap = await sessionRef
    .collection("messages")
    .orderBy("createdAt", "desc")
    .limit(MAX_HISTORY)
    .get();

  const messages = snap.docs
    .map((doc) => doc.data() as any)
    .filter((d) => d?.role && d?.content)
    .reverse(); // oldest first

  return messages.map((m) => ({
    role: (m.role === "assistant" ? "assistant" : "user") as ChatRole,
    content: String(m.content),
  }));
}

async function saveMessages(
  sessionRef: DocumentReference,
  userMessage: string,
  assistantReply: string
): Promise<void> {
  const messagesRef = sessionRef.collection("messages");
  const batch = db.batch();
  const now = FieldValue.serverTimestamp();

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

function compactPrompt(prompt: string): string {
  return prompt
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.trim().length > 0)
    .join("\n");
}

/**
 * Detect if user message requires recipe search
 */
function detectRecipeIntent(message: string): boolean {
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
async function searchRelevantRecipes(query: string): Promise<any[]> {
  try {
    const recipesRef = db.collection("recipes");

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
  } catch (err) {
    return [];
  }
}

/**
 * Extract keywords from user query
 */
function extractKeywords(query: string): string[] {
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

  const found: string[] = [];
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
function calculateRelevanceScore(recipe: any, keywords: string[]): number {
  let score = 0;

  const title = (recipe.title || "").toLowerCase();
  const description = (recipe.description || "").toLowerCase();
  const tags = (recipe.tags || []).map((t: string) => t.toLowerCase());
  const searchTokens = (recipe.searchTokens || []).map((t: string) => t.toLowerCase());
  const ingredientsTokens = (recipe.ingredientsTokens || []).map((t: string) => t.toLowerCase());

  for (const keyword of keywords) {
    if (title.includes(keyword)) score += 10;
    if (description.includes(keyword)) score += 5;
    if (tags.some((t: string) => t.includes(keyword))) score += 5;
    if (searchTokens.some((t: string) => t.includes(keyword))) score += 4;
    if (ingredientsTokens.some((t: string) => t.includes(keyword))) score += 3;
  }

  return score;
}

/**
 * Format recipes for AI context
 */
function formatRecipesForAI(recipes: any[]): string {
  const formatted = recipes.map((r, index) => {
    const ingredientsList = (r.ingredients || [])
      .slice(0, 8)
      .map((ing: any) => `- ${ing.name} (${ing.quantity || ""} ${ing.unit || ""})`)
      .join("\n");

    const stepsList = (r.steps || [])
      .slice(0, 3)
      .map((step: any, i: number) => `${i + 1}. ${step.description || step}`)
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
