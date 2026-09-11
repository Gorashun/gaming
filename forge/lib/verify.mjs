// Reality check. A game is not "done" because a model says so; it is done when a
// headless browser can load it, drive it through its own API, and nothing breaks.
// This module is deterministic and contains no model calls on purpose.
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";
import { CHROMIUM_PATH, GAMES_DIR } from "./config.mjs";

export const GAME_CONTRACT = `
Game contract (enforced by the verifier):
- One self-contained file: games/<slug>/index.html. No external network resources (no CDN scripts, fonts, images).
- A root element with attribute data-game-root.
- window.GameAPI = {
    name: string,
    reset(): void,                 // start a fresh game
    getState(): object,            // JSON-serializable; must include { over: boolean, score: number }
    actions(): string[],           // list of currently valid action ids ([] only when over === true)
    act(actionId: string): void    // apply one action; must throw on an invalid id
  }
- Every act() on a valid id must leave getState() serializable; the state must change at least once during a random playthrough.
- Zero console errors, zero uncaught exceptions, during load and a 60-action random playthrough.
- Optional mission-specific checks are run afterwards (text / state assertions).
`;

function seededRandom(seed) {
  let s = seed >>> 0 || 1;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

export async function verifyGame({ slug, checks = [], screenshotDir, steps = 60, seed = 42 }) {
  const errors = [];
  const metrics = { steps: 0, stateChanges: 0, reachedOver: false, externalRequests: 0, loadMs: 0 };
  const file = path.join(GAMES_DIR, slug, "index.html");
  if (!fs.existsSync(file)) return { passed: false, errors: [`missing file games/${slug}/index.html`], metrics };

  const browser = await chromium.launch({ executablePath: CHROMIUM_PATH });
  try {
    const page = await browser.newPage({ viewport: { width: 900, height: 700 } });
    page.on("console", (m) => { if (m.type() === "error") errors.push(`console.error: ${m.text()}`.slice(0, 300)); });
    page.on("pageerror", (e) => errors.push(`uncaught: ${e.message}`.slice(0, 300)));
    await page.route("**/*", (route) => {
      const url = route.request().url();
      if (url.startsWith("file://") || url.startsWith("data:") || url.startsWith("blob:")) return route.continue();
      metrics.externalRequests++;
      errors.push(`external request blocked: ${url}`.slice(0, 200));
      return route.abort();
    });
    const t0 = Date.now();
    await page.goto("file://" + file, { waitUntil: "load", timeout: 15000 });
    metrics.loadMs = Date.now() - t0;
    await page.waitForTimeout(150);

    const shape = await page.evaluate(() => {
      const api = window.GameAPI;
      const root = document.querySelector("[data-game-root]");
      return {
        root: !!root,
        api: !!api,
        name: api && typeof api.name === "string",
        reset: api && typeof api.reset === "function",
        getState: api && typeof api.getState === "function",
        actions: api && typeof api.actions === "function",
        act: api && typeof api.act === "function",
      };
    });
    if (!shape.root) errors.push("missing [data-game-root] element");
    if (!shape.api) errors.push("window.GameAPI is not defined");
    for (const k of ["name", "reset", "getState", "actions", "act"]) if (shape.api && !shape[k]) errors.push(`GameAPI.${k} missing or wrong type`);

    if (shape.api && shape.reset && shape.getState && shape.actions && shape.act) {
      const rnd = seededRandom(seed);
      const picks = Array.from({ length: steps }, () => rnd());
      const play = await page.evaluate(async ({ picks }) => {
        const out = { errors: [], steps: 0, stateChanges: 0, reachedOver: false, invalidRejected: null };
        const api = window.GameAPI;
        const ser = (s) => { try { return JSON.stringify(s); } catch (e) { out.errors.push("state not serializable: " + e.message); return null; } };
        try { api.reset(); } catch (e) { out.errors.push("reset threw: " + e.message); return out; }
        let st = api.getState();
        let prev = ser(st);
        if (!st || typeof st.over !== "boolean" || typeof st.score !== "number") out.errors.push("getState() must return {over:boolean, score:number, ...}");
        try { api.act("__definitely_invalid__"); out.invalidRejected = false; } catch { out.invalidRejected = true; }
        for (const p of picks) {
          const acts = api.actions();
          if (!Array.isArray(acts)) { out.errors.push("actions() must return an array"); break; }
          if (acts.length === 0) { if (api.getState().over) { out.reachedOver = true; break; } out.errors.push("actions() empty while game not over"); break; }
          const a = acts[Math.floor(p * acts.length)];
          try { api.act(a); } catch (e) { out.errors.push(`act(${JSON.stringify(a)}) threw: ${e.message}`); break; }
          await new Promise((r) => setTimeout(r, 0));
          const cur = ser(api.getState());
          if (cur === null) break;
          if (cur !== prev) out.stateChanges++;
          prev = cur; out.steps++;
          if (api.getState().over) { out.reachedOver = true; break; }
        }
        return out;
      }, { picks });
      errors.push(...play.errors);
      Object.assign(metrics, { steps: play.steps, stateChanges: play.stateChanges, reachedOver: play.reachedOver });
      if (play.invalidRejected === false) errors.push("act() must throw on an invalid action id");
      if (play.steps > 0 && play.stateChanges === 0) errors.push("state never changed during random playthrough");
    }

    for (const c of checks) {
      try {
        if (c.type === "text") {
          const txt = (await page.textContent(c.selector, { timeout: 2000 })) || "";
          if (!txt.includes(c.includes)) errors.push(`check text: ${c.selector} does not include ${JSON.stringify(c.includes)}`);
        } else if (c.type === "state") {
          const v = await page.evaluate((p) => p.split(".").reduce((o, k) => (o == null ? o : o[k]), window.GameAPI.getState()), c.path);
          if (JSON.stringify(v) !== JSON.stringify(c.equals)) errors.push(`check state: ${c.path} = ${JSON.stringify(v)}, expected ${JSON.stringify(c.equals)}`);
        } else if (c.type === "exists") {
          if (!(await page.$(c.selector))) errors.push(`check exists: ${c.selector} not found`);
        }
      } catch (e) { errors.push(`check failed: ${JSON.stringify(c)}: ${e.message}`.slice(0, 200)); }
    }

    if (screenshotDir) {
      fs.mkdirSync(screenshotDir, { recursive: true });
      await page.screenshot({ path: path.join(screenshotDir, `${slug}.png`) }).catch(() => {});
    }
  } catch (e) {
    errors.push(`verifier crashed: ${e.message}`.slice(0, 300));
  } finally {
    await browser.close();
  }
  return { passed: errors.length === 0, errors, metrics };
}
