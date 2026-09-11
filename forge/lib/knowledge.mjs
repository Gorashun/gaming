// Knowledge base: one lesson per markdown file (one-line summary on top), plus
// collected data (every verification result, per-game statistics).
import fs from "node:fs";
import path from "node:path";
import { LESSONS_DIR, DATA_DIR } from "./config.mjs";

fs.mkdirSync(LESSONS_DIR, { recursive: true });
fs.mkdirSync(DATA_DIR, { recursive: true });

const slugify = (s) => s.toLowerCase().replace(/[^a-z0-9åäö]+/g, "-").replace(/(^-|-$)/g, "").slice(0, 60);

export function listLessons() {
  return fs.readdirSync(LESSONS_DIR).filter((f) => f.endsWith(".md")).map((f) => {
    const text = fs.readFileSync(path.join(LESSONS_DIR, f), "utf8");
    const [first, ...rest] = text.split("\n");
    const tags = (text.match(/^tags:\s*(.*)$/m)?.[1] || "").split(/[,\s]+/).filter(Boolean);
    return { file: f, summary: first.replace(/^#\s*/, ""), body: rest.join("\n"), tags };
  });
}

export function recordLesson({ summary, detail, tags = [], source = "forge" }) {
  if (!summary || summary.length < 8) throw new Error("summary too short");
  const slug = slugify(summary);
  const file = path.join(LESSONS_DIR, `${slug}.md`);
  const existed = fs.existsSync(file);
  const now = new Date().toISOString();
  const body = [
    `# ${summary.trim()}`,
    `tags: ${tags.join(", ")}`,
    `source: ${source}`,
    `${existed ? "updated" : "created"}: ${now}`,
    "",
    detail.trim(),
    "",
  ].join("\n");
  fs.writeFileSync(file, body);
  return { file: path.basename(file), updated: existed };
}

export function queryKnowledge(query, limit = 8) {
  const terms = query.toLowerCase().split(/[^a-z0-9åäö]+/).filter((t) => t.length > 2);
  const scored = listLessons().map((l) => {
    const hay = (l.summary + " " + l.tags.join(" ") + " " + l.body).toLowerCase();
    let score = 0;
    for (const t of terms) {
      if (l.summary.toLowerCase().includes(t)) score += 3;
      if (l.tags.some((g) => g.toLowerCase() === t)) score += 2;
      if (hay.includes(t)) score += 1;
    }
    return { ...l, score };
  }).filter((l) => l.score > 0).sort((a, b) => b.score - a.score).slice(0, limit);
  return scored.map(({ file, summary, tags, body, score }) => ({ file, summary, tags, score, body: body.slice(0, 1200) }));
}

// ---- collected data ----
const GAMES_JSON = path.join(DATA_DIR, "games.json");
const VERIF_LOG = path.join(DATA_DIR, "verifications.jsonl");

export function readGamesData() {
  return fs.existsSync(GAMES_JSON) ? JSON.parse(fs.readFileSync(GAMES_JSON, "utf8")) : {};
}

export function recordVerification(gameSlug, result, runId) {
  const rec = { t: new Date().toISOString(), runId, game: gameSlug, passed: result.passed, errors: result.errors.slice(0, 5), metrics: result.metrics };
  fs.appendFileSync(VERIF_LOG, JSON.stringify(rec) + "\n");
  const all = readGamesData();
  const g = all[gameSlug] || { attempts: 0, passes: 0, fails: 0, firstSeen: rec.t };
  g.attempts++;
  if (result.passed) g.passes++; else g.fails++;
  g.lastResult = result.passed ? "pass" : "fail";
  g.lastErrors = result.errors.slice(0, 3);
  g.lastMetrics = result.metrics;
  g.lastSeen = rec.t;
  all[gameSlug] = g;
  fs.writeFileSync(GAMES_JSON, JSON.stringify(all, null, 2));
  return g;
}

export function knowledgeSummary() {
  const lessons = listLessons();
  const games = readGamesData();
  return {
    lessons: lessons.length,
    games: Object.keys(games).length,
    recentLessons: lessons.slice(-10).map((l) => l.summary),
    games: Object.fromEntries(Object.entries(games).map(([k, g]) => [k, { attempts: g.attempts, passes: g.passes, fails: g.fails, last: g.lastResult }])),
  };
}
