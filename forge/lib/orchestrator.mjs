// The mission loop. One orchestrator agent with tools; sub-agents run in nested
// loops on the same budget. History is append-only (never edited), every turn is
// logged, and "done" is decided by the verifier, not by the model.
import fs from "node:fs";
import path from "node:path";
import Anthropic from "@anthropic-ai/sdk";
import { DEFAULTS, RUNS_DIR, FORGE_DIR } from "./config.mjs";
import { Budget, BudgetExceeded } from "./budget.mjs";
import { RunLog } from "./log.mjs";
import { toolsFor, executeTool } from "./tools.mjs";
import { getAgent, bumpAgentUse } from "./agents.mjs";
import { knowledgeSummary } from "./knowledge.mjs";
import { GAME_CONTRACT } from "./verify.mjs";
import { createProvider } from "./llm.mjs";

export const ORCHESTRATOR_TOOLS = ["query_knowledge", "record_lesson", "list_agents", "spawn_agent", "delegate", "read_file", "write_file", "list_files", "verify_game", "send_to_user", "finish_mission"];

const ORCHESTRATOR_SYSTEM = `You are Forge, an autonomous system that builds real, playable browser games and improves from its own mistakes.

Operating principles
- The mission is done only when verify_game passes for the target slug. Your own opinion of the code is not evidence; the verifier's output is.
- Never give up on a mission by silence: either the verifier passes, or you finish with status=blocked and state precisely what decision or resource a human must provide. Running out of budget is an escalation, not a failure to hide.
- Before building, query_knowledge for relevant lessons. After every failure, record_lesson with the concrete cause and the fix, so the next mission starts smarter. Update an existing lesson rather than writing a duplicate. Don't store what the code already says.
- Delegate independent work to sub-agents (builder, tester, critic, or roles you spawn) and keep coordinating. Give them full context: slug, plan, contract, what evidence you need back. Sub-agents share your budget; don't delegate trivial steps.
- Spawn a new agent role only when a recurring need isn't covered by the existing roles. Roles persist across missions.
- Before reporting progress, audit each claim against a tool result from this run. Only report work you can point to evidence for.
- Don't add features, refactor, or introduce abstractions beyond what the mission requires. Do the simplest thing that works well.
- When you have enough information to act, act. Do not narrate options you will not pursue.

Boundaries (hard)
- You can only write under games/** and forge/knowledge/**. There is no shell and no network. Games must be single self-contained HTML files.
- Never claim status=verified without a passing verify_game in this run; the harness will reject it.

${GAME_CONTRACT}`;

const SUBAGENT_PREAMBLE = `You are a sub-agent inside Forge, a system that builds verified browser games. Only the verifier's output is proof that something works. Audit every claim in your final report against a tool result. Boundaries: writes only under games/** and forge/knowledge/**; no shell, no network; games are single self-contained HTML files.

${GAME_CONTRACT}`;

const textOf = (msg) => msg.content.filter((b) => b.type === "text").map((b) => b.text).join("\n").trim();

async function runLoop({ loopId, agentName, system, toolNames, userText, model, effort, ctx }) {
  const messages = [{ role: "user", content: userText }];
  const tools = toolsFor(toolNames);
  let nudges = 0;
  for (;;) {
    ctx.budget.tickIteration();
    const msg = await ctx.provider.complete({ loopId, agentName, model, effort, system, messages, tools, maxTokens: DEFAULTS.maxTokensPerCall });
    ctx.budget.tickApiCall(msg.usage);
    const toolUses = msg.content.filter((b) => b.type === "tool_use");
    ctx.log.event("model_turn", { loopId, agent: agentName, model: msg.model, stop: msg.stop_reason, tools: toolUses.map((t) => t.name), text: textOf(msg).slice(0, 300), usage: msg.usage });

    if (msg.stop_reason === "refusal") {
      const why = msg.stop_details ? `${msg.stop_details.category}: ${msg.stop_details.explanation}` : "no details";
      ctx.log.event("refusal", { loopId, agent: agentName, why });
      return { text: `Model declined this request (${why}).`, refusal: true };
    }
    messages.push({ role: "assistant", content: msg.content });
    if (msg.stop_reason === "pause_turn") continue;

    if (toolUses.length === 0) {
      if (msg.stop_reason === "max_tokens" && nudges++ < 2) { messages.push({ role: "user", content: "Your output was cut off. Continue from where you stopped." }); continue; }
      return { text: textOf(msg) };
    }

    const results = [];
    let final = null;
    for (const use of toolUses) {
      let r;
      try { r = await executeTool(use.name, use.input, { ...ctx, agentName }); }
      catch (e) { if (e instanceof BudgetExceeded) throw e; r = { error: e.message }; }
      ctx.log.event("tool", { loopId, agent: agentName, name: use.name, input: JSON.stringify(use.input).slice(0, 400), ok: !r.error, result: JSON.stringify(r).slice(0, 400) });
      if (r.final) final = r;
      results.push({ type: "tool_result", tool_use_id: use.id, content: JSON.stringify(r), is_error: !!r.error });
    }
    messages.push({ role: "user", content: results });
    if (final) return { final };
  }
}

export async function runMission({ mission, slug, checks = [], mock = false, priorReport = null }) {
  const runId = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19) + "-" + slug;
  const log = new RunLog(runId);
  const budget = new Budget(DEFAULTS.budget);
  const provider = createProvider({ mock });
  const ctx = { runId, log, budget, provider, evidence: { targetSlug: slug, verified: new Set() } };
  let subLoops = 0;

  ctx.runSubagent = async (name, task) => {
    const agent = getAgent(name);
    bumpAgentUse(name);
    const loopId = `${runId}/sub${++subLoops}-${name}`;
    log.event("delegate_start", { loopId, agent: name, task: task.slice(0, 300) });
    const r = await runLoop({
      loopId, agentName: name,
      system: `${SUBAGENT_PREAMBLE}\n\nYour role: ${agent.role}\n\n${agent.system}`,
      toolNames: agent.tools, userText: task,
      model: agent.model || DEFAULTS.subagentModel, effort: agent.effort || DEFAULTS.effort, ctx,
    });
    log.event("delegate_end", { loopId, agent: name, report: (r.text || "").slice(0, 300) });
    return r.text || (r.final ? r.final.report : "(no report)");
  };

  const userText = [
    `Mission: ${mission}`,
    `Target slug: ${slug}   (file: games/${slug}/index.html)`,
    checks.length ? `Mission checks the verifier will also run: ${JSON.stringify(checks)}` : "",
    priorReport ? `\nThis is a RESUMED mission. Previous run ended blocked with this report:\n${priorReport}\nA human has reviewed it and asked you to continue.` : "",
    `\nKnowledge base right now: ${JSON.stringify(knowledgeSummary())}`,
    `Budget for this run: ${JSON.stringify(DEFAULTS.budget)}`,
    `\nStart by querying knowledge, then plan, delegate, verify, learn. Finish with finish_mission.`,
  ].filter(Boolean).join("\n");

  log.event("mission_start", { runId, mission, slug, provider: provider.name, model: DEFAULTS.model, budget: DEFAULTS.budget });
  let outcome;
  try {
    const r = await runLoop({ loopId: `${runId}/main`, agentName: "orchestrator", system: ORCHESTRATOR_SYSTEM, toolNames: ORCHESTRATOR_TOOLS, userText, model: DEFAULTS.model, effort: DEFAULTS.effort, ctx });
    if (r.final) outcome = { status: r.final.status, report: r.final.report, slug: r.final.slug || slug };
    else outcome = { status: "blocked", report: `Orchestrator ended without finish_mission. Last text: ${r.text || "(none)"}`, slug };
  } catch (e) {
    if (e instanceof BudgetExceeded) outcome = { status: "blocked", report: `${e.message}. Human review needed: raise the limit, narrow the mission, or resume with guidance. Evidence so far: verified=${[...ctx.evidence.verified].join(",") || "none"}.`, slug, limit: e.limit };
    else if (e instanceof Anthropic.APIError) outcome = { status: "blocked", report: `API error ${e.status}: ${e.message}`, slug, error: true };
    else { log.event("crash", { error: e.stack }); outcome = { status: "blocked", report: `Harness crash: ${e.message}`, slug, error: true }; }
  }
  // Ground truth wins over the model's claim, in both directions.
  outcome.verifiedByHarness = ctx.evidence.verified.has(slug);
  if (outcome.status === "verified" && !outcome.verifiedByHarness) outcome.status = "blocked";
  outcome.runId = runId;
  outcome.budget = budget.snapshot();
  outcome.mission = mission;
  log.event("mission_end", outcome);
  log.write("result.json", outcome);
  log.write("report.md", `# Forge run ${runId}\n\nMission: ${mission}\nSlug: ${slug}\nStatus: **${outcome.status}** (verifier: ${outcome.verifiedByHarness ? "pass" : "no pass"})\n\n${outcome.report}\n\n## Budget\n\`\`\`json\n${JSON.stringify(outcome.budget, null, 2)}\n\`\`\`\n`);
  fs.mkdirSync(RUNS_DIR, { recursive: true });
  fs.writeFileSync(path.join(FORGE_DIR, "LAST_RUN.md"), fs.readFileSync(path.join(log.dir, "report.md")));
  return outcome;
}
