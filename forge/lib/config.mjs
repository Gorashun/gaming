// Central configuration. Everything that bounds the system lives here on purpose:
// the limits are the product, not an afterthought.
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(here, "..", "..");
export const FORGE_DIR = path.join(ROOT, "forge");
export const GAMES_DIR = path.join(ROOT, "games");
export const KNOWLEDGE_DIR = path.join(FORGE_DIR, "knowledge");
export const LESSONS_DIR = path.join(KNOWLEDGE_DIR, "lessons");
export const DATA_DIR = path.join(KNOWLEDGE_DIR, "data");
export const AGENTS_DIR = path.join(FORGE_DIR, "agents");
export const RUNS_DIR = path.join(FORGE_DIR, "runs");
export const STOP_FILE = path.join(FORGE_DIR, "STOP");

export const CHROMIUM_PATH =
  process.env.FORGE_CHROMIUM ||
  (process.env.PLAYWRIGHT_BROWSERS_PATH
    ? path.join(process.env.PLAYWRIGHT_BROWSERS_PATH, "chromium-1194", "chrome-linux", "chrome")
    : undefined);

const int = (v, d) => (v && Number.isFinite(+v) ? +v : d);

export const DEFAULTS = {
  model: process.env.FORGE_MODEL || "claude-opus-5",
  subagentModel: process.env.FORGE_SUBAGENT_MODEL || process.env.FORGE_MODEL || "claude-opus-5",
  effort: process.env.FORGE_EFFORT || "high",
  maxTokensPerCall: int(process.env.FORGE_MAX_TOKENS, 32000),
  // Hard budget. When any limit is hit the mission is marked "blocked" and a
  // human is asked to review. Bounded persistence, not unbounded persistence.
  budget: {
    maxIterations: int(process.env.FORGE_MAX_ITER, 60),        // orchestrator + subagent turns combined
    maxApiCalls: int(process.env.FORGE_MAX_CALLS, 80),
    maxOutputTokens: int(process.env.FORGE_MAX_OUT, 400_000),
    maxWallClockMs: int(process.env.FORGE_MAX_MINUTES, 45) * 60_000,
    maxVerifyRuns: int(process.env.FORGE_MAX_VERIFY, 20),
    maxSpawnedAgents: int(process.env.FORGE_MAX_AGENTS, 6),
  },
  writableRoots: [GAMES_DIR, KNOWLEDGE_DIR],
  maxFileBytes: 400_000,
  fallbacks: process.env.FORGE_NO_FALLBACK ? null : "default",
};
