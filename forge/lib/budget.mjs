// Bounded persistence: the system keeps trying until the mission is verified OR a
// hard limit trips. A tripped limit is an escalation to a human, never a silent stop.
import fs from "node:fs";
import { STOP_FILE } from "./config.mjs";

export class BudgetExceeded extends Error {
  constructor(limit, detail) {
    super(`Budget exceeded: ${limit} (${detail})`);
    this.limit = limit;
  }
}

export class Budget {
  constructor(limits) {
    this.limits = limits;
    this.startedAt = Date.now();
    this.iterations = 0;
    this.apiCalls = 0;
    this.outputTokens = 0;
    this.inputTokens = 0;
    this.verifyRuns = 0;
    this.spawnedAgents = 0;
  }
  checkStop() {
    if (fs.existsSync(STOP_FILE)) throw new BudgetExceeded("stop_file", `human placed ${STOP_FILE}`);
    const elapsed = Date.now() - this.startedAt;
    if (elapsed > this.limits.maxWallClockMs) throw new BudgetExceeded("wall_clock", `${Math.round(elapsed / 60000)} min`);
  }
  tickIteration() {
    this.checkStop();
    if (++this.iterations > this.limits.maxIterations) throw new BudgetExceeded("iterations", this.iterations);
  }
  tickApiCall(usage) {
    if (++this.apiCalls > this.limits.maxApiCalls) throw new BudgetExceeded("api_calls", this.apiCalls);
    if (usage) {
      this.outputTokens += usage.output_tokens || 0;
      this.inputTokens += usage.input_tokens || 0;
      if (this.outputTokens > this.limits.maxOutputTokens) throw new BudgetExceeded("output_tokens", this.outputTokens);
    }
  }
  tickVerify() {
    if (++this.verifyRuns > this.limits.maxVerifyRuns) throw new BudgetExceeded("verify_runs", this.verifyRuns);
  }
  tickSpawn() {
    if (++this.spawnedAgents > this.limits.maxSpawnedAgents) throw new BudgetExceeded("spawned_agents", this.spawnedAgents);
  }
  snapshot() {
    return {
      iterations: this.iterations, apiCalls: this.apiCalls,
      inputTokens: this.inputTokens, outputTokens: this.outputTokens,
      verifyRuns: this.verifyRuns, spawnedAgents: this.spawnedAgents,
      elapsedMs: Date.now() - this.startedAt, limits: this.limits,
    };
  }
}
