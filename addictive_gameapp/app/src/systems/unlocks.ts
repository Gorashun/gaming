/**
 * Upplåsning av temaset (DESIGN §13.3). Ren logik, ingen Phaser: seedbar och testbar.
 * Två spår, det som kommer först: set nummer k (utöver grundsetet) låses upp när
 * tidsspåret ELLER skicklighetsspåret har nått sitt k:e steg. Högst ett set per anrop.
 */
import type { Rng } from './rng';
import { UNLOCKS } from '../data/unlocks';
import { SLOTS_PER_PAGE } from '../data/collection';
import { THEME_SET_IDS } from '../data/themes';
import { filledSlots, type Collection } from './collection';

export interface UnlockStats {
  /** Ackumulerade merges, alla rundor. */
  merges: number;
  /** Högsta nivå som någonsin funnits i burken. */
  maxLevelEver: number;
  /** Antal gånger två nivå 10 slagits ihop. */
  doubleKlunks: number;
}

/** Steg på tidsspåret: antal passerade merge-trösklar. */
export function timeSteps(merges: number): number {
  let n = 0;
  for (const t of UNLOCKS.mergeThresholds) if (merges >= t) n++;
  return n;
}

/** Steg på skicklighetsspåret: antal uppfyllda villkor. */
export function skillSteps(stats: UnlockStats, collection: Collection): number {
  const s = UNLOCKS.skill;
  let n = 0;
  for (const lvl of s.levels) if (stats.maxLevelEver >= lvl) n++;
  if (stats.doubleKlunks >= s.doubleKlunks) n++;
  if (s.fullPage && Object.values(collection).some((p) => filledSlots(p) >= SLOTS_PER_PAGE)) n++;
  return n;
}

export function evaluateUnlocks(
  stats: UnlockStats,
  collection: Collection,
  unlockedSets: readonly string[],
  rng: Rng,
  allSets: readonly string[] = THEME_SET_IDS,
): { newSet?: string } {
  const remaining = allSets.filter((id) => !unlockedSets.includes(id));
  if (remaining.length === 0) return {};
  const earned = Math.max(timeSteps(stats.merges), skillSteps(stats, collection));
  // Grundsetet räknas inte: med k intjänade steg ska 1 + k set vara upplåsta.
  if (unlockedSets.length - 1 >= earned) return {};
  return { newSet: rng.pick(remaining) };
}

/**
 * Stapeln mot nästa set visar bara tidsspåret (DESIGN §13.6): 0..1 mellan föregående och
 * nästa tröskel. null när allt är upplåst.
 */
export function nextSetProgress(merges: number, unlockedCount: number, total = THEME_SET_IDS.length): number | null {
  if (unlockedCount >= total) return null;
  const t = UNLOCKS.mergeThresholds;
  const i = Math.min(unlockedCount - 1, t.length - 1);
  const from = i > 0 ? t[i - 1] : 0;
  const v = (merges - from) / (t[i] - from);
  return v < 0 ? 0 : v > 1 ? 1 : v;
}
