import { describe, expect, it } from 'vitest';
import { AVATARS, RARITY, oddsPearls, type Rarity } from '../../src/data/avatarsIndex';
import { ECONOMY, type ShellType } from '../../src/data/economy';
import { mulberry32 } from '../../src/systems/rng';
import { defaultAvatars } from '../../src/systems/avatars';
import { currentOdds, drawShell, shellOdds } from '../../src/systems/boxes';
import { buyShell, defaultEconomy, freeShellsFor, shellAvailable } from '../../src/systems/economy';

/**
 * QA (fas 1): oddsburkarna i butiken ska spegla den kvarvarande poolen genom hela samlandet,
 * och det musslan faktiskt ger ska alltid finnas i burken (DESIGN §14.3, §16.2, §16.4).
 */

const TYPES: ShellType[] = ['common', 'silver', 'gold'];
const idx = (r: Rarity): number => RARITY.order.indexOf(r);

function remainingOf(owned: readonly string[]): Record<Rarity, number> {
  const out = {} as Record<Rarity, number>;
  for (const r of RARITY.order) out[r] = AVATARS.filter((a) => a.rarity === r && !owned.includes(a.id)).length;
  return out;
}

/** Samma regel som ui/friendsShop.ts drawJar: första musslan i livet visar bara sällsynt. */
function jarFor(owned: readonly string[], type: ShellType): Record<Rarity, number> {
  const weights =
    ECONOMY.firstShellRare && owned.length === 0
      ? ({ common: 0, uncommon: 0, rare: 1, epic: 0, legendary: 0, mythic: 0 } as Record<Rarity, number>)
      : shellOdds(type);
  return oddsPearls(remainingOf(owned), 25, weights);
}

function checkJar(owned: readonly string[], type: ShellType): void {
  const jar = jarFor(owned, type);
  const rem = remainingOf(owned);
  const floor = idx(ECONOMY.shells[type].floor);
  const total = RARITY.order.reduce((s, r) => s + jar[r], 0);
  const available = owned.length === 0 || RARITY.order.some((r) => idx(r) >= floor && rem[r] > 0);
  expect(total, `${type} ${owned.length}`).toBe(available ? 25 : 0);
  for (const r of RARITY.order) {
    if (jar[r] > 0) {
      expect(rem[r], `${type}: ${r} i burken men ingen kvar`).toBeGreaterThan(0);
      if (owned.length > 0) expect(idx(r), `${type}: ${r} under golvet`).toBeGreaterThanOrEqual(floor);
    }
    if (owned.length > 0 && rem[r] > 0 && idx(r) >= floor) expect(jar[r], `${type}: ${r} kvar men saknas i burken`).toBeGreaterThanOrEqual(1);
  }
  if (owned.length === 0 || !available) return;
  // Proportionerna följer de omnormerade oddsen (±1 pärla avrundning, plus minst-en-regeln).
  const odds = currentOdds(owned, AVATARS, shellOdds(type));
  const bumped = RARITY.order.filter((r) => jar[r] === 1 && odds[r] * 25 < 1).length;
  for (const r of RARITY.order) expect(Math.abs(jar[r] - odds[r] * 25), `${type} ${r}`).toBeLessThanOrEqual(1 + bumped);
}

describe('QA: oddsburkarna mot poolen', () => {
  it('genom hela samlandet i blandad ordning: burken visar exakt de rariteter musslan kan ge', () => {
    for (const seed of [1, 2, 3, 4, 5]) {
      const rng = mulberry32(seed);
      const state = { economy: { ...defaultEconomy(), pearls: 1e6, sand: 1e6 }, avatars: defaultAvatars() };
      let guard = 0;
      while (state.avatars.owned.length < AVATARS.length && guard++ < 200) {
        for (const t of TYPES) checkJar(state.avatars.owned, t);
        const open = TYPES.filter((t) => shellAvailable(state.avatars, t));
        const type = open[Math.floor(rng.next() * open.length)];
        const jar = jarFor(state.avatars.owned, type);
        const r = buyShell(state, type, rng);
        expect(r, `seed ${seed}`).not.toBeNull();
        expect(jar[r!.rarity], `${type} gav ${r!.rarity} som inte fanns i burken`).toBeGreaterThan(0);
        if (state.avatars.owned.length === 1) expect(r!.rarity).toBe('rare');
      }
      expect(new Set(state.avatars.owned).size).toBe(AVATARS.length);
      for (const t of TYPES) expect(shellAvailable(state.avatars, t)).toBe(false);
    }
  });

  it('dragningen följer burkens proportioner (Monte Carlo, silver efter första)', () => {
    const owned = [AVATARS.find((a) => a.rarity === 'rare')!.id];
    const odds = currentOdds(owned, AVATARS, shellOdds('silver'));
    const n = 20000;
    const hits = Object.fromEntries(RARITY.order.map((r) => [r, 0])) as Record<Rarity, number>;
    const rng = mulberry32(99);
    for (let i = 0; i < n; i++) {
      const av = defaultAvatars();
      av.owned.push(...owned);
      hits[drawShell(av, rng, 'silver')!.rarity]++;
    }
    for (const r of RARITY.order) expect(Math.abs(hits[r] / n - odds[r]), r).toBeLessThan(0.012);
    expect(hits.common).toBe(0);
  });

  it('gratismusslornas schema: 120, 400, 1 150, 1 900 … (DESIGN §16.2)', () => {
    expect([0, 119, 120, 399, 400, 1149, 1150, 1899, 1900, 2650].map(freeShellsFor)).toEqual([0, 0, 1, 1, 2, 2, 3, 3, 4, 5]);
  });
});
