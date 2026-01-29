"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onRecipeUpdatedTokens = exports.onRecipeCreatedTokens = exports.onPostUpdatedTokens = exports.onPostCreatedTokens = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const firebase_1 = require("./firebase");
const REGION = "asia-southeast1";
const normalizeText = (value) => {
    return value
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-z0-9\s]/g, " ")
        .replace(/\s+/g, " ")
        .trim();
};
const buildTokens = (doc) => {
    const parts = [];
    if (doc.title)
        parts.push(doc.title);
    if (Array.isArray(doc.tags))
        parts.push(...doc.tags);
    if (Array.isArray(doc.ingredients))
        parts.push(...doc.ingredients);
    const tokens = new Set();
    for (const part of parts) {
        const normalized = normalizeText(String(part));
        normalized.split(" ").forEach((token) => {
            if (token.length > 1)
                tokens.add(token);
        });
    }
    return Array.from(tokens);
};
const arraysEqual = (a, b) => {
    if (!a && !b)
        return true;
    if (!a || !b)
        return false;
    if (a.length !== b.length)
        return false;
    const setA = new Set(a);
    return b.every((item) => setA.has(item));
};
const updateSearchTokens = async (collection, id, data) => {
    const searchTokens = buildTokens(data);
    if (arraysEqual(searchTokens, data.searchTokens))
        return;
    try {
        await firebase_1.db.collection(collection).doc(id).update({ searchTokens });
    }
    catch (error) {
        firebase_functions_1.logger.error("Failed to update searchTokens", { collection, id, error });
    }
};
exports.onPostCreatedTokens = (0, firestore_1.onDocumentCreated)({
    region: REGION,
    document: "posts/{pid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
    await updateSearchTokens("posts", event.params.pid, data);
});
exports.onPostUpdatedTokens = (0, firestore_1.onDocumentUpdated)({
    region: REGION,
    document: "posts/{pid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const after = event.data?.after.data();
    if (!after)
        return;
    await updateSearchTokens("posts", event.params.pid, after);
});
exports.onRecipeCreatedTokens = (0, firestore_1.onDocumentCreated)({
    region: REGION,
    document: "recipes/{rid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
    await updateSearchTokens("recipes", event.params.rid, data);
});
exports.onRecipeUpdatedTokens = (0, firestore_1.onDocumentUpdated)({
    region: REGION,
    document: "recipes/{rid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after)
        return;
    if (JSON.stringify(before) === JSON.stringify(after))
        return;
    await updateSearchTokens("recipes", event.params.rid, after);
});
//# sourceMappingURL=search_tokens.js.map