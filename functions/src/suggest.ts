import { HttpsError, onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { db } from "./firebase";
import { OPENAI_API_KEY } from "./ai_common";

const REGION = "asia-southeast1";

type SuggestInput = {
  q?: string;
  tokens?: string[];
  type?: "posts" | "recipes";
};

const getTrending = async (collection: "posts" | "recipes") => {
  const snap = await db
    .collection(collection)
    .orderBy("likeCount", "desc")
    .limit(5)
    .get();
  return snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
};

export const suggestSearch = onCall(
  {
    region: REGION,
    secrets: [OPENAI_API_KEY],
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (request) => {
    const { q = "", tokens = [], type = "posts" } = (request.data || {}) as SuggestInput;
    if (type !== "posts" && type !== "recipes") {
      throw new HttpsError("invalid-argument", "type must be posts or recipes");
    }

    const collection = type;
    const keywords = Array.from(
      new Set(
        [
          ...tokens,
          ...q
            .toLowerCase()
            .split(/\s+/)
            .filter((t) => t.length > 1),
        ].filter(Boolean)
      )
    ).slice(0, 10);

    let matches: Array<Record<string, unknown>> = [];

    if (keywords.length > 0) {
      const snap = await db
        .collection(collection)
        .where("searchTokens", "array-contains-any", keywords)
        .limit(10)
        .get();
      matches = snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
    }

    const trending = matches.length > 0 ? [] : await getTrending(collection);

    const aiKeyAvailable = Boolean(
      process.env.OPENAI_API_KEY ?? OPENAI_API_KEY.value()
    );
    const aiSuggestions: string[] = aiKeyAvailable
        ? keywords.slice(0, 3).map((k) => `Try exploring ${k}`)
        : [];

    logger.log("suggestSearch", {
      collection,
      keywordCount: keywords.length,
      matched: matches.length,
    });

    return {
      matches,
      trending,
      aiSuggestions,
    };
  }
);
