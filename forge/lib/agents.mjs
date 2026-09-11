// Agent registry. Seed roles ship with the system; the orchestrator can create
// new roles at runtime via spawn_agent. Every role is a JSON file a human can read,
// edit or delete. Roles never get more tools than the orchestrator itself has.
import fs from "node:fs";
import path from "node:path";
import { AGENTS_DIR } from "./config.mjs";

fs.mkdirSync(AGENTS_DIR, { recursive: true });

export const SUBAGENT_TOOL_MENU = ["read_file", "write_file", "list_files", "verify_game", "query_knowledge", "record_lesson"];

const SEED = {
  builder: {
    role: "Implements a complete, self-contained browser game that satisfies the contract and the plan it is given.",
    tools: ["read_file", "write_file", "list_files", "verify_game", "query_knowledge"],
    system: "You are the builder. Write the whole game into games/<slug>/index.html in one file (HTML+CSS+JS, no external resources). Implement window.GameAPI exactly per the contract. Prefer simple, deterministic game logic over flashy visuals. After writing, call verify_game once and fix what it reports. Report what you built and the last verification result.",
  },
  tester: {
    role: "Adversarially tests a game: runs the verifier, reads the code, hunts for state bugs, unreachable game-over, unfair rules, broken invariants.",
    tools: ["read_file", "list_files", "verify_game", "query_knowledge"],
    system: "You are the tester. You do not write game code. Run verify_game, read the source, and report concrete defects with evidence (line, reproduction, expected vs actual). Be skeptical of claims; only the verifier's output counts as proof.",
  },
  critic: {
    role: "Reviews whether the game is actually fun, fair and complete relative to the mission, and whether lessons learned are worth storing.",
    tools: ["read_file", "list_files", "query_knowledge"],
    system: "You are the critic. Judge the game against the mission: is there a real goal, real failure, real feedback, a learning curve? Return a short ranked list of the highest-leverage improvements and say which are must-fix versus nice-to-have.",
  },
};

export function listAgents() {
  const out = {};
  for (const [name, a] of Object.entries(SEED)) out[name] = { name, ...a, seed: true };
  for (const f of fs.readdirSync(AGENTS_DIR).filter((f) => f.endsWith(".json"))) {
    const a = JSON.parse(fs.readFileSync(path.join(AGENTS_DIR, f), "utf8"));
    out[a.name] = { ...a, seed: false };
  }
  return out;
}

export function getAgent(name) {
  const a = listAgents()[name];
  if (!a) throw new Error(`unknown agent "${name}". Known: ${Object.keys(listAgents()).join(", ")}`);
  return a;
}

export function spawnAgent({ name, role, system, tools, createdBy }) {
  const clean = String(name).toLowerCase().replace(/[^a-z0-9-]/g, "-");
  if (!clean || SEED[clean]) throw new Error("invalid or reserved agent name");
  const badTools = (tools || []).filter((t) => !SUBAGENT_TOOL_MENU.includes(t));
  if (badTools.length) throw new Error(`tools not available to subagents: ${badTools.join(", ")}`);
  const rec = { name: clean, role, system, tools: tools?.length ? tools : ["read_file", "list_files", "query_knowledge"], createdBy, createdAt: new Date().toISOString(), uses: 0 };
  fs.writeFileSync(path.join(AGENTS_DIR, `${clean}.json`), JSON.stringify(rec, null, 2));
  return rec;
}

export function bumpAgentUse(name) {
  const p = path.join(AGENTS_DIR, `${name}.json`);
  if (!fs.existsSync(p)) return;
  const a = JSON.parse(fs.readFileSync(p, "utf8"));
  a.uses = (a.uses || 0) + 1; a.lastUsed = new Date().toISOString();
  fs.writeFileSync(p, JSON.stringify(a, null, 2));
}
