/**
 * Musslor (DESIGN §14.3): intjäning och öppning. Ren logik, ingen Phaser: seedbar och testbar.
 * Inga dubbletter, ingen pity. Första musslan är alltid `cfg.firstRarity`.
 */
import type { Rng } from './rng';
import { AVATARS, RARITY, type AvatarDef, type Rarity } from '../data/avatarsIndex';
import { BOXES, type BoxConfig } from '../data/boxes';
import type { AvatarState } from './avatars';

/** Villkor för skicklighetsmusslorna. Alla är monotona, så varje ger exakt en mussla. */
export interface SkillFlags {
  maxLevelEver: number;
  doubleKlunks: number;
  anyShiny: boolean;
}

/** Tröskeln (ackumulerade merges) för mussla nummer k ≥ 1. */
export function boxThreshold(k: number, cfg: BoxConfig = BOXES): number {
  return Math.round(cfg.base * Math.pow(k, cfg.exp));
}

/** Antal intjänade musslor totalt: merge-kurvan plus skicklighetsmusslor. */
export function boxesEarnedFor(merges: number, cfg: BoxConfig = BOXES, skill?: SkillFlags): number {
  let k = 0;
  while (boxThreshold(k + 1, cfg) <= merges) k++;
  if (!skill) return k;
  for (const lvl of cfg.skillLevels) if (skill.maxLevelEver >= lvl) k++;
  if (skill.doubleKlunks >= 1) k++;
  if (skill.anyShiny) k++;
  return k;
}

/**
 * Bokför intjänade musslor (skillnad mot `boxesEarned`). Oöppnade musslor kapas till antalet
 * figurer som finns kvar, så att en mussla på hyllan alltid går att öppna. Returnerar nya musslor.
 */
export function grantBoxes(state: AvatarState, earned: number, total = AVATARS.length): number {
  const fresh = Math.max(0, earned - state.boxesEarned);
  state.boxesEarned = Math.max(state.boxesEarned, earned);
  const before = state.pendingBoxes;
  state.pendingBoxes = Math.min(before + fresh, total - state.owned.length);
  return Math.max(0, state.pendingBoxes - before);
}

/** Aktuella odds (andel 0–1) per raritet, omnormerade bland rariteter med figurer kvar. */
export function currentOdds(
  owned: readonly string[],
  avatars: readonly AvatarDef[] = AVATARS,
  odds: Readonly<Record<Rarity, number>> = RARITY.odds,
): Record<Rarity, number> {
  const out = {} as Record<Rarity, number>;
  let sum = 0;
  for (const r of RARITY.order) {
    const left = avatars.some((a) => a.rarity === r && !owned.includes(a.id));
    out[r] = left ? odds[r] : 0;
    sum += out[r];
  }
  for (const r of RARITY.order) out[r] = sum > 0 ? out[r] / sum : 0;
  return out;
}

/** Heltalsfördelning av n pärlor efter odds (största rest), för odds-burken. */
export function pearlCounts(odds: Readonly<Record<Rarity, number>>, n: number): Record<Rarity, number> {
  const out = {} as Record<Rarity, number>;
  const sum = RARITY.order.reduce((s, r) => s + odds[r], 0);
  if (sum <= 0) {
    for (const r of RARITY.order) out[r] = 0;
    return out;
  }
  let used = 0;
  const rest: [Rarity, number][] = [];
  for (const r of RARITY.order) {
    const exact = (odds[r] / sum) * n;
    out[r] = Math.floor(exact);
    used += out[r];
    rest.push([r, exact - out[r]]);
  }
  rest.sort((a, b) => b[1] - a[1]);
  for (let i = 0; used < n; i++, used++) out[rest[i][0]]++;
  return out;
}

export interface BoxResult {
  avatarId: string;
  rarity: Rarity;
}

/**
 * Öppnar en mussla och lägger figuren i inventariet (muterar `state`). Första avataren väljs
 * automatiskt. Returnerar null när alla figurer redan ägs.
 */
export function openBox(
  state: AvatarState,
  rng: Rng,
  avatars: readonly AvatarDef[] = AVATARS,
  cfg: BoxConfig = BOXES,
): BoxResult | null {
  const odds = currentOdds(state.owned, avatars);
  let rarity: Rarity | null = null;
  if (state.owned.length === 0 && odds[cfg.firstRarity] > 0) {
    rarity = cfg.firstRarity;
  } else {
    const roll = rng.next();
    let acc = 0;
    for (const r of RARITY.order) {
      if (odds[r] <= 0) continue;
      acc += odds[r];
      rarity = r;
      if (roll < acc) break;
    }
  }
  if (!rarity) return null;
  const pool = avatars.filter((a) => a.rarity === rarity && !state.owned.includes(a.id));
  const a = rng.pick(pool);
  state.owned.push(a.id);
  state.xp[a.id] = 0;
  state.level[a.id] = 1;
  state.boxesOpened++;
  state.pendingBoxes = Math.max(0, state.pendingBoxes - 1);
  if (!state.equipped) state.equipped = a.id;
  return { avatarId: a.id, rarity };
}
