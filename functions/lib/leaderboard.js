"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.recomputeLeaderboard = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firebase_functions_1 = require("firebase-functions");
const firebase_1 = require("./firebase");
const REGION = "asia-southeast1";
const computeScore = (stats) => {
    if (!stats)
        return 0;
    const { postCount = 0, recipeCount = 0, reactionCount = 0, commentCount = 0, shareCount = 0, } = stats;
    // Simple weighting example; adjust as needed.
    return postCount * 5 + recipeCount * 5 + commentCount * 2 + reactionCount * 1 + shareCount * 3;
};
exports.recomputeLeaderboard = (0, scheduler_1.onSchedule)({
    region: REGION,
    schedule: "every 24 hours",
    timeZone: "Asia/Ho_Chi_Minh",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
}, async () => {
    const usersSnap = await firebase_1.db.collection("users").get();
    const batch = firebase_1.db.batch();
    const leaderboardWeek = {};
    const leaderboardMonth = {};
    usersSnap.forEach((doc) => {
        const data = doc.data();
        const score = computeScore(data.stats);
        const userRef = doc.ref;
        batch.update(userRef, {
            "stats.weekScore": score,
            "stats.monthScore": score,
        });
        leaderboardWeek[doc.id] = score;
        leaderboardMonth[doc.id] = score;
    });
    await batch.commit();
    const now = new Date();
    await Promise.all([
        firebase_1.db.collection("leaderboards").doc("week").set({
            updatedAt: now,
            scores: leaderboardWeek,
        }),
        firebase_1.db.collection("leaderboards").doc("month").set({
            updatedAt: now,
            scores: leaderboardMonth,
        }),
    ]);
    firebase_functions_1.logger.log("Leaderboard recomputed", {
        userCount: usersSnap.size,
    });
});
//# sourceMappingURL=leaderboard.js.map