import { describe, expect, it } from 'vitest';
import { AVATARS, avatarById } from '../../src/data/avatarsIndex';
import { ABILITY_FX } from '../../src/data/abilities';
import { LEVELS, TOP_PAIR_SCORE } from '../../src/data/levels';
import { SPECIALS, DIRECTOR } from '../../src/data/director';
import { COLLECTION, LEVEL_COUNT } from '../../src/data/collection';
import { PHYSICS } from '../../src/data/physics';
import {
  Abilities,
  abilityParams,
  findMagnetPair,
  neutralOverrides,
  overridesFor,
  type AbilityLevel,
  type MagnetItem,
} from '../../src/systems/abilities';
import { createDirector } from '../../src/systems/director';
import { createDangerTracker } from '../../src/systems/danger';
import { emptyPage, onLevelCreated, type CollectionState } from '../../src/systems/collection';
import { mulberry32, type Rng } from '../../src/systems/rng';

const LEVELS3: AbilityLevel[] = [1, 2, 3];
const KEY = ['I', 'II', 'III'] as const;
const GRACE = PHYSICS.lossGraceMs;

/** Parametern ur avatars.ts (ingen hårdkodning i testet heller). */
function param(id: string, lvl: AbilityLevel, k: string): number | boolean | readonly number[] {
  return avatarById(id)!.ability!.params[KEY[lvl - 1]][k];
}

describe('förmågornas data (DESIGN §14.5)', () => {
  it('sällsynt och uppåt har en förmåga, vanlig/ovanlig ger neutrala overrides', () => {
    for (const a of AVATARS) {
      const has = a.rarity !== 'common' && a.rarity !== 'uncommon';
      expect(a.ability !== undefined).toBe(has);
      if (!has) for (const l of LEVELS3) expect(overridesFor(a.id, l)).toEqual(neutralOverrides());
    }
  });

  it('abilityParams läser rätt nivå ur avatars.ts', () => {
    for (const a of AVATARS.filter((x) => x.ability)) {
      for (const l of LEVELS3) {
        const p = abilityParams(a.id, l)!;
        expect(p.key).toBe(a.ability!.key);
        expect(p.p).toBe(a.ability!.params[KEY[l - 1]]);
      }
    }
  });
});

describe('overrides per förmåga och nivå I/II/III', () => {
  it('Muller: shake × shakeMul vid kedja', () => {
    for (const l of LEVELS3) expect(overridesFor('muller', l).chainShakeMul).toBe(param('muller', l, 'shakeMul'));
    expect(LEVELS3.map((l) => overridesFor('muller', l).chainShakeMul)).toEqual([1.2, 1.3, 1.4]);
  });

  it('Kajsa: near-miss från nivå 6/5/4', () => {
    expect(LEVELS3.map((l) => overridesFor('kajsa', l).nearMissMinLevel)).toEqual([6, 5, 4]);
  });

  it('Stjärnvalen: skimrande × 2/2,5/3, stjärnhimmel och glow', () => {
    expect(LEVELS3.map((l) => overridesFor('stjärnvalen', l).shinyMul)).toEqual([2, 2.5, 3]);
    for (const l of LEVELS3) {
      const o = overridesFor('stjärnvalen', l);
      expect(o.starSky).toBe(true);
      expect(o.glowBonus).toBe(param('stjärnvalen', l, 'glowBonus'));
    }
  });

  it('Siri: två i kön på alla nivåer', () => {
    for (const l of LEVELS3) expect(overridesFor('siri', l).peekSteps).toBe(2);
  });

  it('Bubbel: 10/12/15 drop utan studs', () => {
    expect(LEVELS3.map((l) => overridesFor('bubbel', l).noBounceDrops)).toEqual([10, 12, 15]);
  });

  it('Rut: regnbåge som drop 3/2/2, bomb som drop 12 bara på III', () => {
    expect(overridesFor('rut', 1).seedQueue).toEqual([{ atDrop: 3, type: 'rainbow' }]);
    expect(overridesFor('rut', 2).seedQueue).toEqual([{ atDrop: 2, type: 'rainbow' }]);
    expect(overridesFor('rut', 3).seedQueue).toEqual([
      { atDrop: 2, type: 'rainbow' },
      { atDrop: 12, type: 'bomb' },
    ]);
  });

  it('Havsdrottningen: regnbåge varje runda + 1/1/2 extra specialobjekt, guldburk och stråkar', () => {
    const Q = ABILITY_FX.queen;
    for (const l of LEVELS3) {
      const o = overridesFor('havsdrottningen', l);
      const extra = param('havsdrottningen', l, 'extraSpecials') as number;
      expect(o.seedQueue[0]).toEqual({ atDrop: Q.rainbowAtDrop, type: 'rainbow' });
      expect(o.seedQueue.length - 1).toBe(extra);
      expect(o.seedQueue.slice(1).every((e) => e.type === null)).toBe(true);
      expect(o.goldJar && o.orchestra).toBe(true);
    }
    expect(LEVELS3.map((l) => overridesFor('havsdrottningen', l).seedQueue.length - 1)).toEqual([1, 1, 2]);
  });

  it('känsloförmågor utan spel-overrides ändrar inget i systemen', () => {
    for (const id of ['maestro', 'tick', 'fia', 'vulle', 'disco', 'eko', 'klick', 'nora', 'lisa', 'sixten', 'ekko', 'maja', 'vala']) {
      for (const l of LEVELS3) {
        const o = overridesFor(id, l);
        expect({ ...o, key: '' }).toEqual(neutralOverrides());
      }
    }
  });
});

describe('räknare per runda', () => {
  it('Lisa: oljan (seconds) räcker N s siktning och fylls på vid ny runda', () => {
    for (const l of LEVELS3) {
      const a = new Abilities('lisa', l, GRACE);
      const sec = param('lisa', l, 'seconds') as number;
      expect(a.lisaOilMs).toBe(sec * 1000);
      expect(a.tickAim(100, false)).toBe(false);
      expect(a.lisaOilMs).toBe(sec * 1000);
      let n = 0;
      while (a.tickAim(100, true)) n++;
      expect(n).toBe(sec * 10);
      expect(a.lisaActive).toBe(false);
      a.resetRound();
      expect(a.lisaOilMs).toBe(sec * 1000);
      expect(a.tickAim(16, true)).toBe(true);
    }
  });

  it('Maja: 1/1/2 drag per runda, aldrig under fara, nollställs vid ny runda', () => {
    for (const l of LEVELS3) {
      const a = new Abilities('maja', l, GRACE);
      const uses = param('maja', l, 'uses') as number;
      expect(a.tryMagnet(true)).toBe(false);
      for (let i = 0; i < uses; i++) expect(a.tryMagnet(false)).toBe(true);
      expect(a.tryMagnet(false)).toBe(false);
      a.resetRound();
      expect(a.magnetLeft).toBe(uses);
    }
  });

  it('Vala: farogränsen blir graceMs första gången, räcker 1/2/2 gånger, nollställs vid ny runda', () => {
    for (const l of LEVELS3) {
      const a = new Abilities('vala', l, GRACE);
      const uses = param('vala', l, 'uses') as number;
      const grace = param('vala', l, 'graceMs') as number;
      for (let k = 0; k < uses; k++) {
        expect(a.lossGrace(GRACE - 1)).toBe(GRACE);
        expect(a.lossGrace(GRACE)).toBe(grace);
        expect(a.breathing).toBe(true);
        expect(a.lossGrace(grace - 1)).toBe(grace);
        expect(a.lossGrace(0)).toBe(GRACE);
      }
      expect(a.lossGrace(GRACE)).toBe(GRACE);
      a.resetRound();
      expect(a.breathLeft).toBe(uses);
      expect(a.lossGrace(GRACE)).toBe(grace);
    }
    expect(LEVELS3.map((l) => new Abilities('vala', l, GRACE).lossGrace(GRACE))).toEqual([2500, 2500, 2800]);
  });

  it('Bubbel: N drop utan studs, sedan normalt; nollställs vid ny runda', () => {
    const a = new Abilities('bubbel', 1, GRACE);
    let n = 0;
    while (a.takeNoBounce()) n++;
    expect(n).toBe(10);
    a.resetRound();
    expect(a.noBounceLeft).toBe(10);
  });

  it('andra kompisar påverkar inte farogränsen', () => {
    expect(new Abilities('lisa', 3, GRACE).lossGrace(5000)).toBe(GRACE);
    expect(new Abilities('', 1, GRACE).lossGrace(5000)).toBe(GRACE);
  });
});

describe('förmågor ger aldrig poäng direkt', () => {
  it('ingen förmåga (alla 48 × 3 nivåer, alla metoder) ändrar poängtabellen', () => {
    const before = JSON.stringify({ LEVELS, TOP_PAIR_SCORE, bomb: SPECIALS.bomb.scoreMultiplier });
    for (const a of AVATARS) {
      for (const l of LEVELS3) {
        const ab = new Abilities(a.id, l, GRACE);
        ab.tickAim(1000, true);
        ab.takeNoBounce();
        ab.tryMagnet(false);
        ab.lossGrace(GRACE);
        ab.resetRound();
        // Overrides har inga poängfält.
        expect(Object.keys(ab.o).some((k) => /score|point|poäng/i.test(k))).toBe(false);
      }
    }
    expect(JSON.stringify({ LEVELS, TOP_PAIR_SCORE, bomb: SPECIALS.bomb.scoreMultiplier })).toBe(before);
  });
});

describe('overrides i systemen', () => {
  it('regissören: setSeedQueue lägger specialobjekt på rätt drop utan att röra Kick-räknaren', () => {
    const d = createDirector(mulberry32(5));
    d.setSeedQueue([
      { atDrop: 2, type: 'rainbow' },
      { atDrop: 4, type: null },
    ]);
    const s = { mergeableLevels: new Set<number>() };
    expect(d.next(s).kind).toBe('level');
    const before = d.dropsSinceKick;
    expect(d.next(s)).toEqual({ kind: 'special', type: 'rainbow' });
    expect(d.dropsSinceKick).toBe(before);
    d.next(s);
    const p = d.next(s);
    expect(p.kind).toBe('special');
    if (p.kind === 'special') expect(DIRECTOR.specials).toContain(p.type);
  });

  it('fara: graceMs är PHYSICS.lossGraceMs som standard och återställs vid reset', () => {
    const t = createDangerTracker();
    expect(t.graceMs).toBe(GRACE);
    t.graceMs = 2500;
    t.reset();
    expect(t.graceMs).toBe(GRACE);
  });

  it('samlarboken: shinyMul multiplicerar chansen, garantin oförändrad', () => {
    const level = 3;
    const p = COLLECTION.shinyP[level];
    const at = (v: number): Rng => ({ next: () => v, int: (a) => a, pick: (xs) => xs[0] });
    const st = (mul?: number): CollectionState => ({
      page: emptyPage(),
      createdPerLevel: new Array<number>(LEVEL_COUNT).fill(0),
      shinyPity: new Array<number>(LEVEL_COUNT).fill(0),
      run: 1,
      everShiny: true,
      shinyMul: mul,
    });
    expect(onLevelCreated(level, st(), at(p * 1.5), COLLECTION).shiny).toBe(false);
    expect(onLevelCreated(level, st(2), at(p * 1.5), COLLECTION).shiny).toBe(true);
    expect(onLevelCreated(level, st(2), at(p * 2.01), COLLECTION).shiny).toBe(false);
  });

  it('Maja: par av samma nivå, stilla, gap < range; aldrig nivå 10, rörliga eller för långt isär', () => {
    const M = ABILITY_FX.maja;
    const it = (level: number, x: number, speed = 0): MagnetItem => ({ level, x, y: 500, r: LEVELS[level].radius, speed });
    const out = [0, 0];
    const r3 = LEVELS[3].radius;
    expect(findMagnetPair([it(3, 100), it(2, 150), it(3, 100 + 2 * r3 + 30)], 3, 40, M.maxLevel, M.stillSpeed, out)).toBe(true);
    expect(out).toEqual([0, 2]);
    expect(findMagnetPair([it(3, 100), it(3, 100 + 2 * r3 + 40)], 2, 40, M.maxLevel, M.stillSpeed, out)).toBe(false);
    expect(findMagnetPair([it(3, 100), it(3, 100 + 2 * r3 + 10, 5)], 2, 40, M.maxLevel, M.stillSpeed, out)).toBe(false);
    const r10 = LEVELS[10].radius;
    expect(findMagnetPair([it(10, 100), it(10, 100 + 2 * r10 + 10)], 2, 40, M.maxLevel, M.stillSpeed, out)).toBe(false);
    // Nuddar redan: ingen magnet (merge sker ändå).
    expect(findMagnetPair([it(3, 100), it(3, 100 + 2 * r3)], 2, 40, M.maxLevel, M.stillSpeed, out)).toBe(false);
  });
});
