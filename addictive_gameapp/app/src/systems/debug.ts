/**
 * Rundlogg för speltest (PLAYTEST.md §3, P5.1a). Ren logik, ingen Phaser: testbar.
 * Game samlar råvärden under rundan (utan allokeringar i update) och sammanfattar vid rundslut.
 */
import { DEBUG } from '../data/debug';
import { AVATARS } from '../data/avatarsIndex';
import { APP_VERSION } from '../data/version';

export type ModeTriple = { drought: number; flow: number; kick: number };

/** En sparad runda. Tider i ms. Latenser: [P50, P90], null när inga drop fanns. */
export interface RunLog {
  startedAt: number;
  durationMs: number;
  drops: number;
  merges: number;
  autoDrops: number;
  latency: { all: [number, number] | null; flow: [number, number] | null; drought: [number, number] | null };
  firstMergeMs: number | null;
  /** Förlustskärmen visas → spelaren trycker (PLAYTEST: "återstart inom 3 s"). null = ingen omstart. */
  restartMs: number | null;
  /** Trycket → ny runda spelbar. */
  restartReadyMs: number | null;
  /** Andel drop per regissörsläge (0–1). */
  modeShare: ModeTriple;
  boxesEarned: number;
  score: number;
  maxLevel: number;
  activeSet: string;
  equipped: string;
  pacingMode: string;
  calm: boolean;
  /** 'loss' = förlust, 'quit' = bakåtknappen mitt i rundan. */
  ended: 'loss' | 'quit';
}

/** Råvärden från rundan. `latencies[i]` hör till läget `latencyModes[i]` (index i DEBUG.modes). */
export interface RunSample extends Omit<RunLog, 'latency' | 'modeShare' | 'restartMs' | 'restartReadyMs'> {
  latencies: readonly number[];
  latencyModes: readonly number[];
  /** Antal drop per läge, index i DEBUG.modes. */
  modeDrops: readonly number[];
}

export interface DebugState {
  runs: RunLog[];
  /** Auto-drop avstängd från panelen (A/B med vuxna). */
  autoDropOff: boolean;
}

export function defaultDebug(): DebugState {
  return { runs: [], autoDropOff: false };
}

/** Percentil med närmaste rang (p i 0–100). null för tom lista. */
export function percentile(values: readonly number[], p: number): number | null {
  if (values.length === 0) return null;
  const s = values.slice().sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.max(0, Math.ceil((p / 100) * s.length) - 1))];
}

function p5090(values: readonly number[]): [number, number] | null {
  if (values.length === 0) return null;
  return [Math.round(percentile(values, 50)!), Math.round(percentile(values, 90)!)];
}

/** Nyckeltalen för en runda. */
export function summarizeRun(s: RunSample): RunLog {
  const { latencies, latencyModes, modeDrops, ...rest } = s;
  const byMode = (m: number): number[] => latencies.filter((_, i) => latencyModes[i] === m);
  const total = modeDrops.reduce((a, b) => a + b, 0);
  const share = (i: number): number => (total > 0 ? Math.round((modeDrops[i] / total) * 1000) / 1000 : 0);
  const mi = (m: (typeof DEBUG.modes)[number]): number => DEBUG.modes.indexOf(m);
  return {
    ...rest,
    latency: { all: p5090(latencies), flow: p5090(byMode(mi('flow'))), drought: p5090(byMode(mi('drought'))) },
    modeShare: { drought: share(mi('drought')), flow: share(mi('flow')), kick: share(mi('kick')) },
    restartMs: null,
    restartReadyMs: null,
  };
}

/** Ringbuffer: lägger till sist och kastar de äldsta över `cap`. */
export function pushRun(runs: RunLog[], r: RunLog, cap: number = DEBUG.maxRuns): void {
  runs.push(r);
  if (runs.length > cap) runs.splice(0, runs.length - cap);
}

/** Omstart efter förlust: skrivs på senaste rundan. */
export function setRestart(runs: RunLog[], afterLossMs: number, readyMs: number): void {
  const last = runs[runs.length - 1];
  if (!last || last.ended !== 'loss' || last.restartMs !== null) return;
  last.restartMs = Math.round(afterLossMs);
  last.restartReadyMs = Math.round(readyMs);
}

/** Tål gamla/korrupta sparfiler: bara objekt, högst `maxRuns`. */
export function normalizeDebug(raw: unknown): DebugState {
  const src = (raw && typeof raw === 'object' ? raw : {}) as Partial<DebugState>;
  const runs = Array.isArray(src.runs) ? src.runs.filter((r) => r && typeof r === 'object').slice(-DEBUG.maxRuns) : [];
  return { runs: runs as RunLog[], autoDropOff: src.autoDropOff === true };
}

/**
 * "Ge kompis": nästa raritet i cykeln (sällsynt → mytisk) som har en figur kvar, och dess första
 * ej ägda figur i AVATARS-ordning. Returnerar null när alla med förmåga ägs.
 */
export function nextGift(owned: readonly string[], k: number): { id: string; k: number } | null {
  const order = DEBUG.giftOrder;
  for (let i = 0; i < order.length; i++) {
    const idx = (k + i) % order.length;
    const a = AVATARS.find((x) => x.rarity === order[idx] && !owned.includes(x.id));
    if (a) return { id: a.id, k: idx + 1 };
  }
  return null;
}

/** Omstart: förlustskärmens tryck registreras här och läses av nästa runda. */
let pendingRestart: { tapAt: number; afterLossMs: number } | null = null;

export function markRestartTap(afterLossMs: number, tapAt: number): void {
  pendingRestart = { tapAt, afterLossMs };
}

export function takeRestartTap(): { tapAt: number; afterLossMs: number } | null {
  const r = pendingRestart;
  pendingRestart = null;
  return r;
}

/** Det som "Kopiera JSON" ger: rundloggen plus det som behövs för sammanställningen (PLAYTEST §6). */
export function exportJson(d: {
  debug: DebugState;
  highscore: number;
  stats: { runs: number; merges: number };
  settings: object;
  activeSet: string;
  unlockedSets: string[];
  avatars: { owned: string[]; equipped: string; boxesEarned: number; boxesOpened: number };
}): string {
  return JSON.stringify({
    app: 'klunk',
    format: 1,
    version: APP_VERSION,
    exportedAt: new Date().toISOString(),
    highscore: d.highscore,
    stats: { runs: d.stats.runs, merges: d.stats.merges },
    settings: d.settings,
    activeSet: d.activeSet,
    unlockedSets: d.unlockedSets,
    avatars: {
      owned: d.avatars.owned,
      equipped: d.avatars.equipped,
      boxesEarned: d.avatars.boxesEarned,
      boxesOpened: d.avatars.boxesOpened,
    },
    autoDropOff: d.debug.autoDropOff,
    runs: d.debug.runs,
  });
}
