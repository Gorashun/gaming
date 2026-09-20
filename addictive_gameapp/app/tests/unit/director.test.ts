import { describe, expect, it } from 'vitest';
import { createDirector, type DirectorPick } from '../../src/systems/director';
import { mulberry32 } from '../../src/systems/rng';
import { DIRECTOR } from '../../src/data/director';
import { QUEUE_LEVELS } from '../../src/data/levels';

const NONE: ReadonlySet<number> = new Set();

function run(seed: number, drops: number, mergeable: ReadonlySet<number> = NONE) {
  const d = createDirector(mulberry32(seed));
  const picks: DirectorPick[] = [];
  const modes: string[] = [];
  for (let i = 0; i < drops; i++) {
    picks.push(d.next({ mergeableLevels: mergeable }));
    modes.push(d.mode);
  }
  return { picks, modes, director: d };
}

describe('regissören (DESIGN §4)', () => {
  it('ger en deterministisk sekvens för en fast seed', () => {
    const a = run(12345, 200).picks;
    const b = run(12345, 200).picks;
    expect(b).toEqual(a);
    // Annan seed ger en annan sekvens.
    expect(run(999, 200).picks).not.toEqual(a);
  });

  it('lägger bara köbara nivåer (0–4) i kön', () => {
    for (const p of run(7, 300).picks) {
      if (p.kind === 'level') expect(QUEUE_LEVELS).toContain(p.level);
      else expect(DIRECTOR.specials).toContain(p.type);
    }
  });

  it('har Flöde de första 10 dropsen', () => {
    for (let seed = 1; seed <= 20; seed++) {
      const { picks, modes } = run(seed, DIRECTOR.openingFlowDrops);
      expect(modes.every((m) => m === 'flow')).toBe(true);
      expect(picks.every((p) => p.kind === 'level')).toBe(true);
    }
  });

  it('kickar med 25–60 drops mellan varje specialobjekt', () => {
    for (let seed = 1; seed <= 30; seed++) {
      const picks = run(seed, 1000).picks;
      let last = 0;
      let kicks = 0;
      for (let i = 0; i < picks.length; i++) {
        if (picks[i].kind !== 'special') continue;
        const gap = i + 1 - last;
        expect(gap).toBeGreaterThanOrEqual(DIRECTOR.kickEvery.min);
        expect(gap).toBeLessThanOrEqual(DIRECTOR.kickEvery.max);
        last = i + 1;
        kicks++;
      }
      expect(kicks).toBeGreaterThan(10);
    }
  });

  it('växlar Torka → Flöde → Torka och håller sig inom varaktigheterna', () => {
    const { modes } = run(42, 2000);
    let runLen = 0;
    let seen = 0;
    for (let i = 1; i < modes.length; i++) {
      if (modes[i] === modes[i - 1] && modes[i] !== 'kick') {
        runLen++;
        continue;
      }
      // Ett avslutat läge (hoppa över det första, som kan vara avhugget).
      const cfg = modes[i - 1] === 'drought' ? DIRECTOR.drought : DIRECTOR.flow;
      if (modes[i - 1] !== 'kick' && seen > 2 && modes[i] !== 'kick') {
        expect(runLen + 1).toBeGreaterThanOrEqual(cfg.min);
        expect(runLen + 1).toBeLessThanOrEqual(cfg.max);
      }
      seen++;
      runLen = 0;
    }
    expect(new Set(modes)).toEqual(new Set(['flow', 'drought', 'kick']));
  });

  it('undviker mergebara nivåer i Torka och föredrar dem i Flöde', () => {
    const mergeable = new Set([0, 1]);
    const d = createDirector(mulberry32(2024));
    let droughtHits = 0;
    let droughtN = 0;
    let flowHits = 0;
    let flowN = 0;
    for (let i = 0; i < 4000; i++) {
      const p = d.next({ mergeableLevels: mergeable });
      if (p.kind !== 'level') continue;
      const hit = mergeable.has(p.level) ? 1 : 0;
      if (d.mode === 'drought') {
        droughtHits += hit;
        droughtN++;
      } else {
        flowHits += hit;
        flowN++;
      }
    }
    // Torka: 0,7 undviker helt, annars likformigt (2/5) ⇒ ~0,12.
    expect(droughtHits / droughtN).toBeLessThan(0.3);
    // Flöde: 0,6 väljer mergebar, annars likformigt ⇒ ~0,76.
    expect(flowHits / flowN).toBeGreaterThan(0.6);
    expect(droughtN).toBeGreaterThan(200);
    expect(flowN).toBeGreaterThan(200);
  });

  it('faller tillbaka på likformigt när inga nivåer är mergebara', () => {
    const d = createDirector(mulberry32(5));
    const seen = new Set<number>();
    for (let i = 0; i < 400; i++) {
      const p = d.next({ mergeableLevels: NONE });
      if (p.kind === 'level') seen.add(p.level);
    }
    expect([...seen].sort()).toEqual([...QUEUE_LEVELS]);
  });

  it('reset() startar om med Flöde och nollställd kickräknare', () => {
    const d = createDirector(mulberry32(3));
    for (let i = 0; i < 40; i++) d.next({ mergeableLevels: NONE });
    d.reset();
    expect(d.dropsSinceKick).toBe(0);
    d.next({ mergeableLevels: NONE });
    expect(d.mode).toBe('flow');
  });
});
