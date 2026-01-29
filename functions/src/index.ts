import * as admin from "firebase-admin";
import "./setupEnv"; // Load .env in local development

// Admin SDK must be initialized exactly once per instance.
// NOTE: Other modules may use the modular SDK; this ensures the default app exists.
admin.initializeApp();

export { aggregateEngagementCounts } from "./aggregates";
export {
  onPostCreatedTokens,
  onPostUpdatedTokens,
  onRecipeCreatedTokens,
  onRecipeUpdatedTokens,
} from "./search_tokens";
export { recomputeLeaderboard } from "./leaderboard";
export { createDM, createGroup, onMessage } from "./chat";
export { suggestSearch } from "./suggest";
export { aiParseSearchQuery } from "./ai_search";
export { onUserCreate, setRole } from "./roles";
export { onReportCreate } from "./report_moderation";
export { aiEnrichRecipeDraft } from "./ai_enrich_recipe_draft";
export { aiEstimateNutrition } from "./ai_nutrition";
export { aiGenerateMealPlan } from "./ai_generate_meal_plan";
export { aiSuggestRecipesByIngredients } from "./ai_suggest_recipes";
export { onReportCreate as onReportCreateAiVerdict } from "./ai_moderation";
export { aiChefChat } from "./ai_chef_chat";
export { onChatMessageCreatedModeration } from "./ai_chat_moderation";
export { aiAnalyzeReports } from "./ai_analyze_reports";
