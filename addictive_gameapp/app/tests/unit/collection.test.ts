import { describe, expect, it } from 'vitest';
import { COLLECTION, DEFAULT_SET, LEVEL_COUNT } from '../../src/data/collection';
import {
  emptyPage,
  filledSlots,
  onLevelCreated,
  pityThreshold,
  slotIndex,
  type CollectionState,
} from '../../src/systems/collection';
import { mergeWithDefaults } from '../../src/systems/save';
import { mulberry32, type Rng } from '../../src/systems/rng';

function state(run = 1, everShiny = true): CollectionState {
  return {
    page: emptyPage(),
    createdPerLevel: new Array<number>(LEVEL_COUNT).fill(0),
    shinyPity: new Array<number>(LEVEL_COUNT).fill(0),
    run,
    everShiny,
  };
}

/** RNG som aldrig träffar: isolerar garantierna. */
const never: Rng = { next: () => 0.999999, int: (a) => a, pick: (xs) => xs[0] };

describe('sannolikhetstabellen (DESIGN §13.2)', () => {
  it('nivå 0–4: 1/60, 5–6: 1/30, 7–8: 1/12, 9–10: 1/5', () => {
    const p = COLLECTION.shinyP;
    expect(p).toHaveLength(LEVEL_COUNT);
    for (const l of [0, 1, 2, 3, 4]) expect(p[l]).toBeCloseTo(1 / 60, 10);
    for (const l of [5, 6]) expect(p[l]).toBeCloseTo(1 / 30, 10);
    for (const l of [7, 8]) expect(p[l]).toBeCloseTo(1 / 12, 10);
    for (const l of [9, 10]) expect(p[l]).toBeCloseTo(1 / 5, 10);
    expect(COLLECTION.pityFactor).toBe(3);
    expect(COLLECTION.firstShinyByRun).toBe(3);
    expect(COLLECTION.firstShinyMinLevel).toBe(2);
  });
});

describe('pity', () => {
  it.each([1, 4, 5, 7, 9, 10])('nivå %i: skimrande exakt vid den 3/p:e skapade i rad', (level) => {
    const n = pityThreshold(level, COLLECTION);
    expect(n).toBe(Math.round(3 / COLLECTION.shinyP[level]));
    const s = state();
    for (let i = 1; i < n; i++) {
      expect(onLevelCreated(level, s, never, COLLECTION).shiny).toBe(false);
    }
    expect(s.shinyPity[level]).toBe(n - 1);
    const hit = onLevelCreated(level, s, never, COLLECTION);
    expect(hit.shiny).toBe(true);
    expect(hit.newShiny).toBe(true);
    expect(s.shinyPity[level]).toBe(0);
    // Räknaren börjar om: nästa är inte garanterad.
    expect(onLevelCreated(level, s, never, COLLECTION).shiny).toBe(false);
  });

  it('räknaren är per nivå', () => {
    const s = state();
    for (let i = 0; i < 10; i++) onLevelCreated(9, s, never, COLLECTION);
    expect(s.shinyPity[9]).toBe(10);
    expect(s.shinyPity[8]).toBe(0);
  });
});

describe('första skimrande', () => {
  it('garanteras i runda 3 på första nivå ≥2, inte tidigare', () => {
    for (const run of [1, 2]) {
      const s = state(run, false);
      for (let l = 1; l <= 10; l++) expect(onLevelCreated(l, s, never, COLLECTION).shiny).toBe(false);
    }
    const s = state(3, false);
    expect(onLevelCreated(1, s, never, COLLECTION).shiny).toBe(false);
    const r = onLevelCreated(2, s, never, COLLECTION);
    expect(r.shiny).toBe(true);
    expect(s.everShiny).toBe(true);
    // Bara den första är gratis.
    expect(onLevelCreated(2, s, never, COLLECTION).shiny).toBe(false);
  });

  it('gäller inte om spelaren redan haft ett skimrande', () => {
    const s = state(3, true);
    expect(onLevelCreated(2, s, never, COLLECTION).shiny).toBe(false);
  });
});

describe('fångst', () => {
  it('ny sida har nivå 0 vanlig ifylld, 1/21', () => {
    const p = emptyPage();
    expect(p.caught[0]).toBe(true);
    expect(p.shiny.every((v) => !v)).toBe(true);
    expect(filledSlots(p)).toBe(1);
  });

  it('fångst och ny skimrande markeras som nytt sedan sist (fresh)', () => {
    const s = state();
    s.shinyPity[4] = pityThreshold(4, COLLECTION) - 1;
    onLevelCreated(3, s, never, COLLECTION);
    onLevelCreated(4, s, never, COLLECTION);
    expect(s.page.fresh).toHaveLength(21);
    expect(s.page.fresh[3]).toBe(true);
    expect(s.page.fresh[4]).toBe(true);
    expect(s.page.fresh[slotIndex(4, true)]).toBe(true);
    expect(slotIndex(4, true)).toBe(14);
    expect(s.page.fresh.filter(Boolean)).toHaveLength(3);
  });

  it('första skapandet fångar, andra gör det inte', () => {
    const s = state();
    expect(onLevelCreated(3, s, never, COLLECTION).caught).toBe(true);
    expect(onLevelCreated(3, s, never, COLLECTION).caught).toBe(false);
    expect(s.createdPerLevel[3]).toBe(2);
    expect(s.page.caught[3]).toBe(true);
  });

  it('nivå 0 blir aldrig skimrande (skapas bara genom drop)', () => {
    const always: Rng = { next: () => 0, int: (a) => a, pick: (xs) => xs[0] };
    const s = state(5, false);
    s.shinyPity[0] = 10_000;
    for (let i = 0; i < 1000; i++) expect(onLevelCreated(0, s, always, COLLECTION).shiny).toBe(false);
    expect(s.page.shiny[0]).toBe(false);
  });
});

describe('determinism och statistik', () => {
  it('samma seed ger samma utfall', () => {
    const run = (seed: number): boolean[] => {
      const rng = mulberry32(seed);
      const s = state();
      const out: boolean[] = [];
      for (let i = 0; i < 2000; i++) out.push(onLevelCreated(1 + (i % 10), s, rng, COLLECTION).shiny);
      return out;
    };
    expect(run(42)).toEqual(run(42));
    expect(run(42)).not.toEqual(run(43));
  });

  it('10 000 skapade nivå 9 ⇒ andel skimrande ≈ 1/5 ± 0,03', () => {
    const rng = mulberry32(2026);
    const s = state();
    let hits = 0;
    const N = 10_000;
    for (let i = 0; i < N; i++) if (onLevelCreated(9, s, rng, COLLECTION).shiny) hits++;
    expect(Math.abs(hits / N - 0.2)).toBeLessThanOrEqual(0.03);
  });
});

describe('sparformat', () => {
  it('gammal sparfil utan meta-lager får defaults och behåller allt gammalt', () => {
    const old = {
      highscore: 1234,
      bestLevel: 7,
      settings: { sound: false, haptics: true, calm: false },
      stats: { runs: 9, merges: 400, autoDrops: 3 },
    };
    const d = mergeWithDefaults(JSON.parse(JSON.stringify(old)));
    expect(d.highscore).toBe(1234);
    expect(d.bestLevel).toBe(7);
    expect(d.settings.sound).toBe(false);
    expect(d.settings.aimLine).toBe(true);
    expect(d.stats.runs).toBe(9);
    expect(d.stats.merges).toBe(400);
    expect(d.stats.createdPerLevel).toEqual(new Array(LEVEL_COUNT).fill(0));
    expect(d.stats.shinyPity).toEqual(new Array(LEVEL_COUNT).fill(0));
    expect(d.activeSet).toBe(DEFAULT_SET);
    expect(d.collection[DEFAULT_SET].caught[0]).toBe(true);
    expect(filledSlots(d.collection[DEFAULT_SET])).toBe(1);
  });

  it('sparad samling överlever och trasiga fält lagas', () => {
    const caught = new Array(LEVEL_COUNT).fill(false);
    caught[4] = true;
    const d = mergeWithDefaults(
      JSON.parse(
        JSON.stringify({
          collection: { glimtarna: { caught, shiny: [false, true] }, annat: { caught: 'x' } },
          stats: { createdPerLevel: [0, 5, 2], shinyPity: [0, 1] },
        }),
      ),
    );
    expect(d.collection.glimtarna.caught[4]).toBe(true);
    expect(d.collection.glimtarna.caught[0]).toBe(true);
    expect(d.collection.glimtarna.shiny[1]).toBe(true);
    expect(d.collection.glimtarna.shiny).toHaveLength(LEVEL_COUNT);
    expect(d.collection.annat.caught[0]).toBe(true);
    expect(d.stats.createdPerLevel.slice(0, 3)).toEqual([0, 5, 2]);
    expect(d.stats.createdPerLevel).toHaveLength(LEVEL_COUNT);
  });

  it('två defaults delar aldrig arrayer', () => {
    const a = mergeWithDefaults({});
    const b = mergeWithDefaults({});
    a.collection[DEFAULT_SET].caught[5] = true;
    a.stats.createdPerLevel[5] = 1;
    expect(b.collection[DEFAULT_SET].caught[5]).toBe(false);
    expect(b.stats.createdPerLevel[5]).toBe(0);
  });
});
