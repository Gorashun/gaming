/**
 * Musslor (DESIGN §16.2): öppning, en funktion med odds och golv per typ. Ren logik, ingen
 * Phaser: seedbar och testbar. Inga dubbletter, ingen pity. Första musslan i livet är alltid
 * sällsynt. Intjäning och köp: systems/economy.ts.
 */
import type { Rng } from './rng';
import { AVATARS, RARITY, type AvatarDef, type Rarity } from '../data/avatarsIndex';
import { ECONOMY, type ShellType } from '../data/economy';
import type { AvatarState } from './avatars';

/** Typens vikter per raritet, noll under golvet (DESIGN §16.2). */
export function shellOdds(type: ShellType = 'common'): Record<Rarity, number> {
  const def = ECONOMY.shells[type];
  const floor = RARITY.order.indexOf(def.floor);
  const out = {} as Record<Rarity, number>;
  RARITY.order.forEach((r, i) => (out[r] = i >= floor ? def.odds[i] ?? 0 : 0));
  return out;
}

/** Aktuella odds (andel 0–1) per raritet, omnormerade bland rariteter med figurer kvar. */
export function currentOdds(
  owned: readonly string[],
  avatars: readonly AvatarDef[] = AVATARS,
  odds: Readonly<Record<Rarity, number>> = shellOdds('common'),
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
 * Drar en figur ur musslan av typen och lägger den i inventariet (muterar `state`). Första
 * avataren väljs automatiskt. Returnerar null när inget finns kvar över typens golv.
 */
export function drawShell(
  state: AvatarState,
  rng: Rng,
  type: ShellType = 'common',
  avatars: readonly AvatarDef[] = AVATARS,
): BoxResult | null {
  const odds = currentOdds(state.owned, avatars, shellOdds(type));
  let rarity: Rarity | null = null;
  if (ECONOMY.firstShellRare && state.owned.length === 0 && avatars.some((a) => a.rarity === ECONOMY.firstRarity)) {
    rarity = ECONOMY.firstRarity;
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
  addOwned(state, a.id);
  return { avatarId: a.id, rarity };
}

/** Lägger till en figur på nivå I. Första avataren väljs automatiskt. */
export function addOwned(state: AvatarState, id: string): void {
  state.owned.push(id);
  state.level[id] = 1;
  state.boxesOpened++;
  if (!state.fresh.includes(id)) state.fresh.push(id);
  if (!state.equipped) state.equipped = id;
}

/** Öppnar en mussla från hyllan (vanlig typ, DESIGN §16.2). Returnerar null när alla figurer ägs. */
export function openBox(state: AvatarState, rng: Rng, avatars: readonly AvatarDef[] = AVATARS): BoxResult | null {
  const r = drawShell(state, rng, 'common', avatars);
  state.pendingBoxes = Math.max(0, state.pendingBoxes - 1);
  return r;
}
