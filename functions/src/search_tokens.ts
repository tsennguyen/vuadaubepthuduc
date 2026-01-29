import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { db } from "./firebase";

const REGION = "asia-southeast1";

type TextualDoc = {
  title?: string;
  tags?: string[];
  ingredients?: string[];
  searchTokens?: string[];
};

const normalizeText = (value: string): string => {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
};

const buildTokens = (doc: TextualDoc): string[] => {
  const parts: string[] = [];
  if (doc.title) parts.push(doc.title);
  if (Array.isArray(doc.tags)) parts.push(...doc.tags);
  if (Array.isArray(doc.ingredients)) parts.push(...doc.ingredients);

  const tokens = new Set<string>();
  for (const part of parts) {
    const normalized = normalizeText(String(part));
    normalized.split(" ").forEach((token) => {
      if (token.length > 1) tokens.add(token);
    });
  }
  return Array.from(tokens);
};

const arraysEqual = (a?: string[], b?: string[]) => {
  if (!a && !b) return true;
  if (!a || !b) return false;
  if (a.length !== b.length) return false;
  const setA = new Set(a);
  return b.every((item) => setA.has(item));
};

const updateSearchTokens = async (
  collection: "posts" | "recipes",
  id: string,
  data: TextualDoc
) => {
  const searchTokens = buildTokens(data);
  if (arraysEqual(searchTokens, data.searchTokens)) return;
  try {
    await db.collection(collection).doc(id).update({ searchTokens });
  } catch (error) {
    logger.error("Failed to update searchTokens", { collection, id, error });
  }
};

export const onPostCreatedTokens = onDocumentCreated(
  {
    region: REGION,
    document: "posts/{pid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const data = event.data?.data() as TextualDoc | undefined;
    if (!data) return;
    await updateSearchTokens("posts", event.params.pid, data);
  }
);

export const onPostUpdatedTokens = onDocumentUpdated(
  {
    region: REGION,
    document: "posts/{pid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const after = event.data?.after.data() as TextualDoc | undefined;
    if (!after) return;
    await updateSearchTokens("posts", event.params.pid, after);
  }
);

export const onRecipeCreatedTokens = onDocumentCreated(
  {
    region: REGION,
    document: "recipes/{rid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const data = event.data?.data() as TextualDoc | undefined;
    if (!data) return;
    await updateSearchTokens("recipes", event.params.rid, data);
  }
);

export const onRecipeUpdatedTokens = onDocumentUpdated(
  {
    region: REGION,
    document: "recipes/{rid}",
    memory: "128MiB",
    cpu: 0.166,
    maxInstances: 1,
  },
  async (event) => {
    const before = event.data?.before.data() as TextualDoc | undefined;
    const after = event.data?.after.data() as TextualDoc | undefined;
    if (!after) return;
    if (JSON.stringify(before) === JSON.stringify(after)) return;
    await updateSearchTokens("recipes", event.params.rid, after);
  }
);
