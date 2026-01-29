import { defineSecret } from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

export const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

export function getOpenAiApiKey(): string {
  const apiKey = process.env.OPENAI_API_KEY ?? OPENAI_API_KEY.value();
  if (!apiKey) {
    logger.error("OPENAI_API_KEY is not set");
    throw new HttpsError(
      "failed-precondition",
      "OPENAI_API_KEY is not configured on server"
    );
  }
  return apiKey as string;
}

export function handleAiError(err: unknown, context: string): never {
  logger.error(`${context} failed`, err);
  if (err instanceof HttpsError) {
    throw err;
  }
  throw new HttpsError(
    "internal",
    "AI internal error. Please try again later."
  );
}
