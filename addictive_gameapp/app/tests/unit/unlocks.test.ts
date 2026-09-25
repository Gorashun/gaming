import { describe, expect, it } from 'vitest';
import { UNLOCKS } from '../../src/data/unlocks';
import { DEFAULT_SET, LEVEL_COUNT, SLOTS_PER_PAGE } from '../../src/data/collection';
import { THEME_SET_IDS } from '../../src/data/themes';
import { emptyPage, filledSlots, type Collection } from '../../src/systems/collection';
import { evaluateUnlocks, nextSetProgress, type UnlockStats } from '../../src/systems/unlocks';
import { mergeWithDefaults } from '../../src/systems/save';
import { mulberry32 } from '../../src/systems/rng';

const stats = (s: Partial<UnlockStats> = {}): UnlockStats => ({ merges: 0, maxLevelEver: 0, doubleKlunks: 0, ...s });
const base = (): Collection => ({ [DEFAULT_SET]: emptyPage() });
const fullPage = (): Collection => {
  const p = emptyPage();
  p.caught.fill(true);
  p.shiny.fill(true);
  p.shiny[0] = false;
  return { [DEFAULT_SET]: p };
};

/** Kör upplåsning tills inget nytt kommer. Returnerar upplåsta set i ordning. */
function drain(s: UnlockStats, c: Collection, unlocked: string[], seed: number): string[] {
  const rng = mulberry32(seed);
  for (let guard = 0; guard < 20; guard++) {
    const r = evaluateUnlocks(s, c, unlocked, rng);
    if (!r.newSet) break;
    expect(unlocked).not.toContain(r.newSet);
    unlocked.push(r.newSet);
  }
  return unlocked;
}

describe('upplåsning (DESIGN §13.3)', () => {
  it('konfig: 200/600/1500/3000 merges, nivå 8 och 10, dubbel-Klunk, full sida', () => {
    expect(UNLOCKS.mergeThresholds).toEqual([200, 600, 1500, 3000]);
    expect(UNLOCKS.skill.levels).toEqual([8, 10]);
    expect(SLOTS_PER_PAGE).toBe(21);
    expect(filledSlots(fullPage()[DEFAULT_SET])).toBe(21);
  });

  it('inget nytt utan framsteg', () => {
    expect(evaluateUnlocks(stats({ merges: 199, maxLevelEver: 7 }), base(), [DEFAULT_SET], mulberry32(1))).toEqual({});
  });

  it('tidsspåret ensamt: ett set per tröskel', () => {
    const counts = [199, 200, 599, 600, 1500, 3000].map(
      (m) => drain(stats({ merges: m }), base(), [DEFAULT_SET], 3).length,
    );
    expect(counts).toEqual([1, 2, 2, 3, 4, 5]);
  });

  it.each([
    ['nivå 8', stats({ maxLevelEver: 8 }), base()],
    ['dubbel-Klunk', stats({ doubleKlunks: 1 }), base()],
    ['full sida', stats(), fullPage()],
  ])('skicklighetsspåret ensamt: %s ger ett set', (_n, s, c) => {
    expect(drain(s, c, [DEFAULT_SET], 5)).toHaveLength(2);
  });

  it('nivå 10 räknar två steg (första nivå 8 och första nivå 10)', () => {
    expect(drain(stats({ maxLevelEver: 10 }), base(), [DEFAULT_SET], 5)).toHaveLength(3);
  });

  it('båda spåren samtidigt ger bara ett set', () => {
    expect(drain(stats({ merges: 200, maxLevelEver: 8 }), base(), [DEFAULT_SET], 9)).toHaveLength(2);
  });

  it('högst ett set per anrop (ett per rundavslut)', () => {
    const r = evaluateUnlocks(stats({ merges: 3000 }), base(), [DEFAULT_SET], mulberry32(1));
    expect(r.newSet).toBeDefined();
    expect(THEME_SET_IDS).toContain(r.newSet);
    expect(r.newSet).not.toBe(DEFAULT_SET);
  });

  it('alla fyra nås till slut, aldrig dubblett, aldrig mer än fem', () => {
    for (let seed = 0; seed < 50; seed++) {
      const all = drain(stats({ merges: 10_000, maxLevelEver: 10, doubleKlunks: 3 }), fullPage(), [DEFAULT_SET], seed);
      expect(new Set(all).size).toBe(all.length);
      expect([...all].sort()).toEqual([...THEME_SET_IDS].sort());
    }
  });

  it('determinism: samma seed ger samma ordning, olika seeds varierar', () => {
    const order = (seed: number): string =>
      drain(stats({ merges: 3000 }), base(), [DEFAULT_SET], seed).join(',');
    expect(order(7)).toBe(order(7));
    const seen = new Set<string>();
    for (let s = 0; s < 30; s++) seen.add(order(s));
    expect(seen.size).toBeGreaterThan(3);
  });

  it('stapeln visar bara tidsspåret och döljs när allt är upplåst', () => {
    expect(nextSetProgress(0, 1)).toBe(0);
    expect(nextSetProgress(100, 1)).toBeCloseTo(0.5, 5);
    expect(nextSetProgress(400, 2)).toBeCloseTo(0.5, 5);
    // Skicklighetsspåret har sprungit före: tidsstapeln står still på 0.
    expect(nextSetProgress(100, 3)).toBe(0);
    expect(nextSetProgress(99_999, 4)).toBe(1);
    expect(nextSetProgress(99_999, 5)).toBeNull();
  });
});

describe('sparformat för temaset', () => {
  it('gammal sparfil får grundsetet, fresh[21] och nya stats', () => {
    const d = mergeWithDefaults(
      JSON.parse(JSON.stringify({ bestLevel: 6, stats: { merges: 50 }, collection: { glimtarna: { caught: [true, true] } } })),
    );
    expect(d.unlockedSets).toEqual([DEFAULT_SET]);
    expect(d.activeSet).toBe(DEFAULT_SET);
    expect(d.freshSet).toBeNull();
    expect(d.stats.doubleKlunks).toBe(0);
    expect(d.stats.maxLevelEver).toBe(6);
    expect(d.collection.glimtarna.fresh).toHaveLength(SLOTS_PER_PAGE);
    expect(d.collection.glimtarna.shiny).toHaveLength(LEVEL_COUNT);
  });

  it('okända set, dubbletter och ett aktivt set som inte är upplåst lagas', () => {
    const d = mergeWithDefaults(
      JSON.parse(
        JSON.stringify({
          unlockedSets: ['planeterna', 'okänt', 'planeterna'],
          activeSet: 'gloden',
          freshSet: 'gloden',
        }),
      ),
    );
    expect(d.unlockedSets).toEqual([DEFAULT_SET, 'planeterna']);
    expect(d.activeSet).toBe(DEFAULT_SET);
    expect(d.freshSet).toBeNull();
    expect(d.collection.planeterna.caught[0]).toBe(true);
  });
});
