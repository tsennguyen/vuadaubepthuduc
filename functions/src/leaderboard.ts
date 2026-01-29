import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { db } from "./firebase";

const REGION = "asia-southeast1";

type UserStats = {
  stats?: {
    postCount?: number;
    recipeCount?: number;
    reactionCount?: number;
    commentCount?: number;
    shareCount?: number;
    weekScore?: number;
    monthScore?: number;
  };
};

const computeScore = (stats: UserStats["stats"] | undefined) => {
  if (!stats) return 0;
  const {
    postCount = 0,
    recipeCount = 0,
    reactionCount = 0,
    commentCount = 0,
    shareCount = 0,
  } = stats;

  // Simple weighting example; adjust as needed.
  return postCount * 5 + recipeCount * 5 + commentCount * 2 + reactionCount * 1 + shareCount * 3;
};

export const recomputeLeaderboard = onSchedule(
  {
    region: REGION,
    schedule: "every 24 hours",
    timeZone: "Asia/Ho_Chi_Minh",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async () => {
    const usersSnap = await db.collection("users").get();
    const batch = db.batch();
    const leaderboardWeek: Record<string, number> = {};
    const leaderboardMonth: Record<string, number> = {};

    usersSnap.forEach((doc) => {
      const data = doc.data() as UserStats;
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
      db.collection("leaderboards").doc("week").set({
        updatedAt: now,
        scores: leaderboardWeek,
      }),
      db.collection("leaderboards").doc("month").set({
        updatedAt: now,
        scores: leaderboardMonth,
      }),
    ]);

    logger.log("Leaderboard recomputed", {
      userCount: usersSnap.size,
    });
  }
);
