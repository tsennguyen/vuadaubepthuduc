"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.suggestSearch = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const firebase_1 = require("./firebase");
const ai_common_1 = require("./ai_common");
const REGION = "asia-southeast1";
const getTrending = async (collection) => {
    const snap = await firebase_1.db
        .collection(collection)
        .orderBy("likeCount", "desc")
        .limit(5)
        .get();
    return snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
};
exports.suggestSearch = (0, https_1.onCall)({
    region: REGION,
    secrets: [ai_common_1.OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (request) => {
    const { q = "", tokens = [], type = "posts" } = (request.data || {});
    if (type !== "posts" && type !== "recipes") {
        throw new https_1.HttpsError("invalid-argument", "type must be posts or recipes");
    }
    const collection = type;
    const keywords = Array.from(new Set([
        ...tokens,
        ...q
            .toLowerCase()
            .split(/\s+/)
            .filter((t) => t.length > 1),
    ].filter(Boolean))).slice(0, 10);
    let matches = [];
    if (keywords.length > 0) {
        const snap = await firebase_1.db
            .collection(collection)
            .where("searchTokens", "array-contains-any", keywords)
            .limit(10)
            .get();
        matches = snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
    }
    const trending = matches.length > 0 ? [] : await getTrending(collection);
    const aiKeyAvailable = Boolean(process.env.OPENAI_API_KEY ?? ai_common_1.OPENAI_API_KEY.value());
    const aiSuggestions = aiKeyAvailable
        ? keywords.slice(0, 3).map((k) => `Try exploring ${k}`)
        : [];
    firebase_functions_1.logger.log("suggestSearch", {
        collection,
        keywordCount: keywords.length,
        matched: matches.length,
    });
    return {
        matches,
        trending,
        aiSuggestions,
    };
});
//# sourceMappingURL=suggest.js.map