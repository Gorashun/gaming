// Harness self-test. Runs offline (mock provider) and proves:
//  1. the verifier rejects a broken game and accepts a fixed one,
//  2. the orchestrator's premature "verified" claim is rejected,
//  3. a lesson and a spawned agent are persisted,
//  4. the budget trips and produces a blocked escalation instead of a loop.
import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { runMission } from "../lib/orchestrator.mjs";
import { verifyGame } from "../lib/verify.mjs";
import { MOCK_GAME_BROKEN } from "../lib/llm.mjs";
import { GAMES_DIR, AGENTS_DIR, LESSONS_DIR, RUNS_DIR, DATA_DIR, DEFAULTS } from "../lib/config.mjs";

process.env.FORGE_QUIET = "1";
const slug = "selftest-mock";
fs.rmSync(path.join(GAMES_DIR, slug), { recursive: true, force: true });
fs.rmSync(path.join(AGENTS_DIR, "level-designer.json"), { force: true });

// 1+2+3: full cycle
const out = await runMission({ mission: "Self-test mission", slug, mock: true });
assert.equal(out.status, "verified", "mission should end verified");
assert.equal(out.verifiedByHarness, true);
const events = fs.readFileSync(path.join(RUNS_DIR, out.runId, "events.jsonl"), "utf8").split("\n").filter(Boolean).map(JSON.parse);
const finishes = events.filter((e) => e.type === "tool" && e.name === "finish_mission");
assert.equal(finishes.length, 2, "two finish attempts");
assert.equal(finishes[0].ok, false, "first (premature) finish must be rejected");
assert.equal(finishes[1].ok, true);
const verifies = events.filter((e) => e.type === "verify");
assert.deepEqual(verifies.map((v) => v.passed), [false, true]);
assert.ok(fs.existsSync(path.join(AGENTS_DIR, "level-designer.json")), "spawned agent persisted");
assert.ok(fs.readdirSync(LESSONS_DIR).some((f) => f.includes("data-game-root")), "lesson persisted");
assert.ok(events.some((e) => e.type === "delegate_end" && e.agent === "builder"), "builder sub-agent ran");
console.log("✔ full cycle: broken → verify fail → lesson → premature claim rejected → fix → verify pass");

// verifier directly on broken content
fs.writeFileSync(path.join(GAMES_DIR, slug, "index.html"), MOCK_GAME_BROKEN);
const bad = await verifyGame({ slug });
assert.equal(bad.passed, false);
assert.ok(bad.errors.some((e) => e.includes("data-game-root")));
assert.ok(bad.errors.some((e) => e.includes("invalid action")));
console.log("✔ verifier rejects contract violations:", bad.errors.join(" | "));

// 4: budget trips → blocked, not an infinite loop
const saved = DEFAULTS.budget.maxIterations;
DEFAULTS.budget.maxIterations = 3;
const blocked = await runMission({ mission: "Budget trip test", slug: "selftest-budget", mock: true });
DEFAULTS.budget.maxIterations = saved;
assert.equal(blocked.status, "blocked");
assert.equal(blocked.limit, "iterations");
console.log("✔ budget trip → blocked escalation:", blocked.report.slice(0, 80));

// cleanup: leave no self-test residue in games/, agents/ or collected data
for (const s of [slug, "selftest-budget"]) fs.rmSync(path.join(GAMES_DIR, s), { recursive: true, force: true });
fs.rmSync(path.join(AGENTS_DIR, "level-designer.json"), { force: true });
const gamesJson = path.join(DATA_DIR, "games.json");
if (fs.existsSync(gamesJson)) { const g = JSON.parse(fs.readFileSync(gamesJson, "utf8")); delete g[slug]; delete g["selftest-budget"]; fs.writeFileSync(gamesJson, JSON.stringify(g, null, 2)); }
const vlog = path.join(DATA_DIR, "verifications.jsonl");
if (fs.existsSync(vlog)) fs.writeFileSync(vlog, fs.readFileSync(vlog, "utf8").split("\n").filter((l) => l && !l.includes('"game":"selftest-')).map((l) => l + "\n").join(""));
for (const s of [slug, "selftest-budget"]) for (const d of fs.readdirSync(RUNS_DIR)) if (d.endsWith("-" + s)) fs.rmSync(path.join(RUNS_DIR, d), { recursive: true, force: true });
console.log("all self-tests passed");
