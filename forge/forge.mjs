#!/usr/bin/env node
// Forge CLI.
//   node forge/forge.mjs run "<mission>" --slug <slug> [--mock] [--checks checks.json]
//   node forge/forge.mjs resume <runId> [--mock]
//   node forge/forge.mjs verify <slug>
//   node forge/forge.mjs knowledge | agents | stop | go
import fs from "node:fs";
import path from "node:path";
import { runMission } from "./lib/orchestrator.mjs";
import { verifyGame } from "./lib/verify.mjs";
import { knowledgeSummary, listLessons } from "./lib/knowledge.mjs";
import { listAgents } from "./lib/agents.mjs";
import { RUNS_DIR, STOP_FILE, DEFAULTS } from "./lib/config.mjs";

const args = process.argv.slice(2);
const cmd = args.shift();
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args.splice(i, 2)[1] : undefined; };
const has = (n) => { const i = args.indexOf(n); return i >= 0 ? (args.splice(i, 1), true) : false; };
const slugify = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "").slice(0, 40);

async function main() {
  switch (cmd) {
    case "run": {
      const mock = has("--mock");
      const slug = flag("--slug");
      const checksFile = flag("--checks");
      const mission = args.join(" ").trim();
      if (!mission) throw new Error('usage: run "<mission>" --slug <slug>');
      const checks = checksFile ? JSON.parse(fs.readFileSync(checksFile, "utf8")) : [];
      if (!mock && !process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) console.error("note: no ANTHROPIC_API_KEY in env; the SDK will try an `ant auth login` profile.");
      const out = await runMission({ mission, slug: slug || slugify(mission), checks, mock });
      print(out); break;
    }
    case "resume": {
      const mock = has("--mock");
      const runId = args[0];
      const prev = JSON.parse(fs.readFileSync(path.join(RUNS_DIR, runId, "result.json"), "utf8"));
      const out = await runMission({ mission: prev.mission, slug: prev.slug, mock, priorReport: prev.report });
      print(out); break;
    }
    case "verify": {
      const r = await verifyGame({ slug: args[0], screenshotDir: path.join(RUNS_DIR, "_manual") });
      console.log(JSON.stringify(r, null, 2)); process.exitCode = r.passed ? 0 : 1; break;
    }
    case "knowledge": {
      console.log(JSON.stringify(knowledgeSummary(), null, 2));
      for (const l of listLessons()) console.log(`- ${l.summary}  [${l.tags.join(", ")}]`);
      break;
    }
    case "agents": console.log(JSON.stringify(Object.values(listAgents()).map(({ name, role, tools, seed, uses }) => ({ name, role, tools, seed, uses })), null, 2)); break;
    case "stop": fs.writeFileSync(STOP_FILE, `stopped by human ${new Date().toISOString()}\n`); console.log("STOP file placed; running missions will halt at their next turn."); break;
    case "go": fs.rmSync(STOP_FILE, { force: true }); console.log("STOP file removed."); break;
    case "config": console.log(JSON.stringify(DEFAULTS, null, 2)); break;
    default:
      console.log(`Forge – bounded self-improving game builder
  run "<mission>" --slug <slug> [--mock] [--checks file.json]
  resume <runId> [--mock]
  verify <slug>
  knowledge | agents | config | stop | go`);
  }
}
function print(out) {
  console.log(`\n=== ${out.status.toUpperCase()} (${out.runId}) verifier=${out.verifiedByHarness ? "pass" : "no pass"} ===\n${out.report}\n`);
  console.log(`budget: ${JSON.stringify({ iterations: out.budget.iterations, apiCalls: out.budget.apiCalls, out: out.budget.outputTokens, verify: out.budget.verifyRuns, minutes: Math.round(out.budget.elapsedMs / 6000) / 10 })}`);
  process.exitCode = out.status === "verified" ? 0 : 2;
}
main().catch((e) => { console.error(e.stack || e.message); process.exit(1); });
