// Append-only audit log. Every model call, tool call and verification lands here
// so a human can reconstruct exactly what the system did and why.
import fs from "node:fs";
import path from "node:path";
import { RUNS_DIR } from "./config.mjs";

export class RunLog {
  constructor(runId) {
    this.runId = runId;
    this.dir = path.join(RUNS_DIR, runId);
    fs.mkdirSync(this.dir, { recursive: true });
    this.file = path.join(this.dir, "events.jsonl");
    this.quiet = !!process.env.FORGE_QUIET;
  }
  event(type, data = {}) {
    const rec = { t: new Date().toISOString(), type, ...data };
    fs.appendFileSync(this.file, JSON.stringify(rec) + "\n");
    if (!this.quiet) {
      const short = JSON.stringify(data).slice(0, 220);
      process.stderr.write(`[${type}] ${short}\n`);
    }
  }
  write(name, content) {
    const p = path.join(this.dir, name);
    fs.writeFileSync(p, typeof content === "string" ? content : JSON.stringify(content, null, 2));
    return p;
  }
}
