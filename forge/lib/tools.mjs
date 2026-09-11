// Tool definitions (what the model sees) and the executor (what actually runs).
// Dedicated tools rather than bash on purpose: every action is typed, sandboxed
// and auditable. There is no shell, no network, no path outside the sandbox.
import fs from "node:fs";
import path from "node:path";
import { ROOT, GAMES_DIR, DEFAULTS } from "./config.mjs";
import { verifyGame } from "./verify.mjs";
import { recordLesson, queryKnowledge, recordVerification } from "./knowledge.mjs";
import { listAgents, spawnAgent, SUBAGENT_TOOL_MENU } from "./agents.mjs";

const obj = (properties, required) => ({ type: "object", properties, required, additionalProperties: false });

export const TOOL_DEFS = {
  read_file: {
    description: "Read a text file inside the repository (games/, forge/knowledge/, forge/CONTRACT.md, index.html).",
    input_schema: obj({ path: { type: "string", description: "Repo-relative path" } }, ["path"]),
  },
  write_file: {
    description: "Create or overwrite a text file. Only games/** and forge/knowledge/** are writable. Write complete files, never fragments.",
    input_schema: obj({ path: { type: "string" }, content: { type: "string" } }, ["path", "content"]),
  },
  list_files: {
    description: "List files under a repo-relative directory (games/ or forge/knowledge/).",
    input_schema: obj({ path: { type: "string" } }, ["path"]),
  },
  verify_game: {
    description: "Run the deterministic browser verifier on games/<slug>/index.html. Returns passed, errors and metrics. This is the only proof a game works.",
    input_schema: obj({
      slug: { type: "string" },
      checks: { type: "array", description: "Optional extra assertions", items: { type: "object", properties: { type: { type: "string", enum: ["text", "state", "exists"] }, selector: { type: "string" }, includes: { type: "string" }, path: { type: "string" }, equals: {} }, required: ["type"], additionalProperties: false } },
    }, ["slug"]),
  },
  query_knowledge: {
    description: "Search stored lessons by keywords. Always do this before building or after a failure.",
    input_schema: obj({ query: { type: "string" } }, ["query"]),
  },
  record_lesson: {
    description: "Store a lesson learned (one lesson per file). Record corrections and confirmed approaches alike, with why they mattered. Update rather than duplicate.",
    input_schema: obj({ summary: { type: "string", description: "One line" }, detail: { type: "string" }, tags: { type: "array", items: { type: "string" } } }, ["summary", "detail"]),
  },
  spawn_agent: {
    description: `Create a new reusable agent role (persisted for future missions). Use when a recurring need is not covered by builder/tester/critic. Allowed tools: ${SUBAGENT_TOOL_MENU.join(", ")}.`,
    input_schema: obj({ name: { type: "string" }, role: { type: "string", description: "One-line purpose" }, system: { type: "string", description: "System prompt for the role" }, tools: { type: "array", items: { type: "string", enum: SUBAGENT_TOOL_MENU } } }, ["name", "role", "system"]),
  },
  delegate: {
    description: "Run a sub-agent on a task and get its final report. Sub-agents share your budget. Give full context: slug, plan, the contract requirements, and what evidence you need back.",
    input_schema: obj({ agent: { type: "string" }, task: { type: "string" } }, ["agent", "task"]),
  },
  list_agents: {
    description: "List available agent roles.",
    input_schema: obj({}, []),
  },
  send_to_user: {
    description: "Show a message verbatim to the human (progress with specific numbers, or a decision they must make later).",
    input_schema: obj({ message: { type: "string" } }, ["message"]),
  },
  finish_mission: {
    description: "End the mission. status=verified requires a passing verify_game for the target slug during this run; the harness rejects unbacked claims. status=blocked means you need a human decision: say exactly what.",
    input_schema: obj({ status: { type: "string", enum: ["verified", "blocked"] }, slug: { type: "string" }, report: { type: "string" } }, ["status", "report"]),
  },
};

export function toolsFor(names) {
  return names.map((n) => ({ name: n, ...TOOL_DEFS[n], strict: true }));
}

function safePath(rel, { write = false } = {}) {
  const abs = path.resolve(ROOT, rel);
  if (!abs.startsWith(ROOT + path.sep)) throw new Error("path escapes repository");
  if (write && !DEFAULTS.writableRoots.some((r) => abs.startsWith(r + path.sep))) throw new Error("write denied: only games/** and forge/knowledge/** are writable");
  if (abs.includes(`${path.sep}node_modules${path.sep}`) || abs.includes(`${path.sep}.git${path.sep}`)) throw new Error("path denied");
  return abs;
}

// ctx: { budget, log, runId, evidence, runSubagent, agentName }
export async function executeTool(name, input, ctx) {
  switch (name) {
    case "read_file": {
      const p = safePath(input.path);
      if (!fs.existsSync(p)) return { error: `not found: ${input.path}` };
      const text = fs.readFileSync(p, "utf8");
      return text.length > 120_000 ? { content: text.slice(0, 120_000), truncated: true } : { content: text };
    }
    case "write_file": {
      const p = safePath(input.path, { write: true });
      if (Buffer.byteLength(input.content) > DEFAULTS.maxFileBytes) return { error: "file too large" };
      fs.mkdirSync(path.dirname(p), { recursive: true });
      fs.writeFileSync(p, input.content);
      ctx.log.event("file_written", { path: input.path, bytes: Buffer.byteLength(input.content), by: ctx.agentName });
      return { ok: true, path: input.path, bytes: Buffer.byteLength(input.content) };
    }
    case "list_files": {
      const p = safePath(input.path);
      if (!fs.existsSync(p)) return { files: [] };
      const out = [];
      const walk = (d, depth) => { if (depth > 4) return; for (const e of fs.readdirSync(d, { withFileTypes: true })) { const f = path.join(d, e.name); if (e.isDirectory()) walk(f, depth + 1); else out.push(path.relative(ROOT, f)); } };
      walk(p, 0);
      return { files: out.slice(0, 300) };
    }
    case "verify_game": {
      ctx.budget.tickVerify();
      const slug = String(input.slug).replace(/[^a-z0-9-]/g, "");
      const result = await verifyGame({ slug, checks: input.checks || [], screenshotDir: path.join(ctx.log.dir, "screens") });
      recordVerification(slug, result, ctx.runId);
      if (result.passed) ctx.evidence.verified.add(slug); else ctx.evidence.verified.delete(slug);
      ctx.log.event("verify", { slug, passed: result.passed, errors: result.errors.length, metrics: result.metrics, by: ctx.agentName });
      return result;
    }
    case "query_knowledge": return { results: queryKnowledge(input.query) };
    case "record_lesson": {
      const r = recordLesson({ summary: input.summary, detail: input.detail, tags: input.tags || [], source: `${ctx.runId}/${ctx.agentName}` });
      ctx.log.event("lesson", { ...r, summary: input.summary });
      return r;
    }
    case "spawn_agent": {
      ctx.budget.tickSpawn();
      const rec = spawnAgent({ ...input, createdBy: ctx.runId });
      ctx.log.event("agent_spawned", { name: rec.name, role: rec.role, tools: rec.tools });
      return { ok: true, agent: rec };
    }
    case "list_agents": return { agents: Object.values(listAgents()).map(({ name, role, tools, seed, uses }) => ({ name, role, tools, seed, uses })) };
    case "delegate": {
      const report = await ctx.runSubagent(input.agent, input.task);
      return { agent: input.agent, report };
    }
    case "send_to_user": {
      ctx.log.event("to_user", { message: input.message });
      process.stdout.write(`\n>>> ${input.message}\n\n`);
      return { ok: true };
    }
    case "finish_mission": {
      if (input.status === "verified") {
        const slug = input.slug || ctx.evidence.targetSlug;
        if (!slug || !ctx.evidence.verified.has(slug)) {
          return { error: `Rejected: no passing verify_game for slug "${slug}" in this run. Run verify_game and make it pass, or finish with status=blocked and explain.` };
        }
      }
      return { ok: true, final: true, status: input.status, report: input.report, slug: input.slug };
    }
    default: return { error: `unknown tool ${name}` };
  }
}
