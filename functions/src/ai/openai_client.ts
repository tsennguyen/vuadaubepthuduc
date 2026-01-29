import * as functions from "firebase-functions";
import { HttpsError } from "firebase-functions/v2/https";
import OpenAI from "openai";
import { getOpenAiApiKey } from "../ai_common";

const DEFAULT_MODEL = "gpt-4o-mini";

let cachedClient: OpenAI | null = null;

function getClient(): OpenAI {
  const apiKey = getOpenAiApiKey();
  if (!cachedClient) {
    cachedClient = new OpenAI({ apiKey });
  }
  return cachedClient;
}

export interface OpenAITextOptions {
  system?: string;
  user: string;
  jsonSchema?: { name: string; schema: any };
  temperature?: number;
  model?: string;
  maxOutputTokens?: number;
}

type ChatMessage = { role: "system" | "user" | "assistant"; content: string };

export async function callOpenAIText(opts: OpenAITextOptions): Promise<string> {
  try {
    const messages: ChatMessage[] = [];

    if (opts.system) {
      messages.push({ role: "system", content: opts.system });
    }

    messages.push({ role: "user", content: opts.user });

    const completion = await getClient().chat.completions.create({
      model: opts.model ?? DEFAULT_MODEL,
      messages,
      temperature: opts.temperature,
      max_tokens: opts.maxOutputTokens,
      response_format: opts.jsonSchema
        ? { type: "json_schema", json_schema: opts.jsonSchema }
        : undefined,
    });

    const content = completion.choices[0]?.message?.content;
    const text = normalizeContent(content);
    if (!text) {
      throw new Error("Empty completion from OpenAI");
    }
    return text.toString();
  } catch (err: any) {
    functions.logger.error(
      "[OpenAI] call failed",
      {
        error: err?.response?.data ?? err?.message ?? err,
        status: err?.status,
        type: err?.type,
        model: opts.model ?? DEFAULT_MODEL,
      }
    );
    if (err instanceof HttpsError) {
      throw err;
    }
    // More specific error messages
    if (err?.status === 401) {
      throw new HttpsError(
        "unauthenticated",
        "OpenAI API key is invalid or expired"
      );
    }
    if (err?.status === 429) {
      throw new HttpsError(
        "resource-exhausted",
        "OpenAI API rate limit exceeded. Please try again later."
      );
    }
    if (err?.status === 404) {
      throw new HttpsError(
        "not-found",
        `OpenAI model not found: ${opts.model ?? DEFAULT_MODEL}`
      );
    }
    throw new HttpsError(
      "internal",
      "AI internal error. Please try again later."
    );
  }
}

export async function callOpenAIJson<T>(
  opts: OpenAITextOptions & { jsonSchema: { name: string; schema: any } }
): Promise<T> {
  const raw = await callOpenAIText(opts);
  try {
    return JSON.parse(raw) as T;
  } catch (err: any) {
    functions.logger.error("[OpenAI] JSON parse failed", {
      message: err?.message,
      preview: typeof raw === "string" ? raw.slice(0, 200) : "",
    });
    throw new HttpsError(
      "internal",
      "AI internal error. Please try again later."
    );
  }
}

function normalizeContent(content: any): string {
  if (!content) return "";
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") return part;
        if (part && typeof part.text === "string") return part.text;
        return "";
      })
      .filter(Boolean)
      .join("\n")
      .trim();
  }
  if (typeof content === "object" && typeof (content as any).text === "string") {
    return (content as any).text;
  }
  return "";
}
