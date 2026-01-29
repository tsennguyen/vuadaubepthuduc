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
exports.aiSummarizeReel = exports.aiAnalyzeReports = exports.onChatMessageCreatedModeration = exports.aiChefChat = exports.onReportCreateAiVerdict = exports.aiSuggestRecipesByIngredients = exports.aiGenerateMealPlan = exports.aiEstimateNutrition = exports.aiEnrichRecipeDraft = exports.onReportCreate = exports.setRole = exports.onUserCreate = exports.aiParseSearchQuery = exports.suggestSearch = exports.onMessage = exports.createGroup = exports.createDM = exports.recomputeLeaderboard = exports.onRecipeUpdatedTokens = exports.onRecipeCreatedTokens = exports.onPostUpdatedTokens = exports.onPostCreatedTokens = exports.aggregateEngagementCounts = void 0;
const admin = __importStar(require("firebase-admin"));
require("./setupEnv"); // Load .env in local development
// Admin SDK must be initialized exactly once per instance.
// NOTE: Other modules may use the modular SDK; this ensures the default app exists.
admin.initializeApp();
var aggregates_1 = require("./aggregates");
Object.defineProperty(exports, "aggregateEngagementCounts", { enumerable: true, get: function () { return aggregates_1.aggregateEngagementCounts; } });
var search_tokens_1 = require("./search_tokens");
Object.defineProperty(exports, "onPostCreatedTokens", { enumerable: true, get: function () { return search_tokens_1.onPostCreatedTokens; } });
Object.defineProperty(exports, "onPostUpdatedTokens", { enumerable: true, get: function () { return search_tokens_1.onPostUpdatedTokens; } });
Object.defineProperty(exports, "onRecipeCreatedTokens", { enumerable: true, get: function () { return search_tokens_1.onRecipeCreatedTokens; } });
Object.defineProperty(exports, "onRecipeUpdatedTokens", { enumerable: true, get: function () { return search_tokens_1.onRecipeUpdatedTokens; } });
var leaderboard_1 = require("./leaderboard");
Object.defineProperty(exports, "recomputeLeaderboard", { enumerable: true, get: function () { return leaderboard_1.recomputeLeaderboard; } });
var chat_1 = require("./chat");
Object.defineProperty(exports, "createDM", { enumerable: true, get: function () { return chat_1.createDM; } });
Object.defineProperty(exports, "createGroup", { enumerable: true, get: function () { return chat_1.createGroup; } });
Object.defineProperty(exports, "onMessage", { enumerable: true, get: function () { return chat_1.onMessage; } });
var suggest_1 = require("./suggest");
Object.defineProperty(exports, "suggestSearch", { enumerable: true, get: function () { return suggest_1.suggestSearch; } });
var ai_search_1 = require("./ai_search");
Object.defineProperty(exports, "aiParseSearchQuery", { enumerable: true, get: function () { return ai_search_1.aiParseSearchQuery; } });
var roles_1 = require("./roles");
Object.defineProperty(exports, "onUserCreate", { enumerable: true, get: function () { return roles_1.onUserCreate; } });
Object.defineProperty(exports, "setRole", { enumerable: true, get: function () { return roles_1.setRole; } });
var report_moderation_1 = require("./report_moderation");
Object.defineProperty(exports, "onReportCreate", { enumerable: true, get: function () { return report_moderation_1.onReportCreate; } });
var ai_enrich_recipe_draft_1 = require("./ai_enrich_recipe_draft");
Object.defineProperty(exports, "aiEnrichRecipeDraft", { enumerable: true, get: function () { return ai_enrich_recipe_draft_1.aiEnrichRecipeDraft; } });
var ai_nutrition_1 = require("./ai_nutrition");
Object.defineProperty(exports, "aiEstimateNutrition", { enumerable: true, get: function () { return ai_nutrition_1.aiEstimateNutrition; } });
var ai_generate_meal_plan_1 = require("./ai_generate_meal_plan");
Object.defineProperty(exports, "aiGenerateMealPlan", { enumerable: true, get: function () { return ai_generate_meal_plan_1.aiGenerateMealPlan; } });
var ai_suggest_recipes_1 = require("./ai_suggest_recipes");
Object.defineProperty(exports, "aiSuggestRecipesByIngredients", { enumerable: true, get: function () { return ai_suggest_recipes_1.aiSuggestRecipesByIngredients; } });
var ai_moderation_1 = require("./ai_moderation");
Object.defineProperty(exports, "onReportCreateAiVerdict", { enumerable: true, get: function () { return ai_moderation_1.onReportCreate; } });
var ai_chef_chat_1 = require("./ai_chef_chat");
Object.defineProperty(exports, "aiChefChat", { enumerable: true, get: function () { return ai_chef_chat_1.aiChefChat; } });
var ai_chat_moderation_1 = require("./ai_chat_moderation");
Object.defineProperty(exports, "onChatMessageCreatedModeration", { enumerable: true, get: function () { return ai_chat_moderation_1.onChatMessageCreatedModeration; } });
var ai_analyze_reports_1 = require("./ai_analyze_reports");
Object.defineProperty(exports, "aiAnalyzeReports", { enumerable: true, get: function () { return ai_analyze_reports_1.aiAnalyzeReports; } });
var ai_reels_summary_1 = require("./ai_reels_summary");
Object.defineProperty(exports, "aiSummarizeReel", { enumerable: true, get: function () { return ai_reels_summary_1.aiSummarizeReel; } });
//# sourceMappingURL=index.js.map