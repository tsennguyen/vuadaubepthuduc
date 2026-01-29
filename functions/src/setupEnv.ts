// Load environment variables when running locally/emulator.
// This file should be imported in the main entry point (functions/src/index.ts)
import * as dotenv from "dotenv";

// Prefer .env.local for emulator-only secrets to avoid conflicts with deployed secrets.
dotenv.config({ path: ".env.local" });
dotenv.config({ path: ".env" });

// Note: In production, OPENAI_API_KEY is provided via Firebase secret manager.
