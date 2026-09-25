import { describe, expect, it } from 'vitest';
import { AVATARS, RARITY, UPGRADE, type Rarity } from '../../src/data/avatarsIndex';
import { BOXES } from '../../src/data/boxes';
import { mulberry32 } from '../../src/systems/rng';
import {
  boxThreshold,
  boxesEarnedFor,
  currentOdds,
  grantBoxes,
  openBox,
  pearlCounts,
  type SkillFlags,
} from '../../src/systems/boxes';
import { addXp, defaultAvatars, equip, levelFor, normalizeAvatars } from '../../src/systems/avatars';
import { mergeWithDefaults } from '../../src/systems/save';

const noSkill: SkillFlags = { maxLevelEver: 0, doubleKlunks: 0, anyShiny: false };
const countBy = (r: Rarity): number => AVATARS.filter((a) => a.rarity === r).length;

describe('avatardata (DESIGN §14.2)', () => {
  it('48 unika, antal per raritet 16/12/9/6/3/2, odds summerar till 100', () => {
    expect(AVATARS.length).toBe(48);
    expect(new Set(AVATARS.map((a) => a.id)).size).toBe(48);
    expect(RARITY.order.map(countBy)).toEqual([16, 12, 9, 6, 3, 2]);
    expect(RARITY.order.reduce((s, r) => s + RARITY.odds[r], 0)).toBe(100);
    expect(UPGRADE).toEqual({ xpII: 150, xpIII: 450 });
  });
});

describe('intjäning (DESIGN §14.3)', () => {
  it('kurvan 50·k^1,3: 50, 123, 209 …', () => {
    expect([1, 2, 3, 4].map((k) => boxThreshold(k))).toEqual([50, 123, 209, 303]);
    expect(boxesEarnedFor(0)).toBe(0);
    expect(boxesEarnedFor(49)).toBe(0);
    expect(boxesEarnedFor(50)).toBe(1);
    expect(boxesEarnedFor(122)).toBe(1);
    expect(boxesEarnedFor(123)).toBe(2);
    expect(boxesEarnedFor(209)).toBe(3);
    expect(boxesEarnedFor(209, BOXES, noSkill)).toBe(3);
  });

  it('skicklighetsmusslor: nivå 7–10, dubbel-Klunk, skimrande ger en var', () => {
    expect(boxesEarnedFor(0, BOXES, { ...noSkill, maxLevelEver: 7 })).toBe(1);
    expect(boxesEarnedFor(0, BOXES, { ...noSkill, maxLevelEver: 10 })).toBe(4);
    expect(boxesEarnedFor(0, BOXES, { maxLevelEver: 10, doubleKlunks: 5, anyShiny: true })).toBe(6);
  });

  it('skicklighetsmusslor ges exakt en gång', () => {
    const s = defaultAvatars();
    const flags: SkillFlags = { maxLevelEver: 8, doubleKlunks: 1, anyShiny: true };
    expect(grantBoxes(s, boxesEarnedFor(10, BOXES, flags))).toBe(4);
    expect(grantBoxes(s, boxesEarnedFor(20, BOXES, flags))).toBe(0);
    expect(grantBoxes(s, boxesEarnedFor(20, BOXES, { ...flags, maxLevelEver: 9 }))).toBe(1);
    expect(grantBoxes(s, boxesEarnedFor(50, BOXES, { ...flags, maxLevelEver: 9 }))).toBe(1);
    expect(s).toMatchObject({ boxesEarned: 6, pendingBoxes: 6 });
  });

  it('oöppnade kapas till figurer som finns kvar', () => {
    const s = defaultAvatars();
    expect(grantBoxes(s, 100)).toBe(48);
    expect(s.pendingBoxes).toBe(48);
    expect(s.boxesEarned).toBe(100);
  });
});

describe('öppning (DESIGN §14.3)', () => {
  it('deterministisk med seed', () => {
    const run = (seed: number): string[] => {
      const s = defaultAvatars();
      const rng = mulberry32(seed);
      return Array.from({ length: 10 }, () => openBox(s, rng)!.avatarId);
    };
    expect(run(7)).toEqual(run(7));
    expect(run(7)).not.toEqual(run(8));
  });

  it('första alltid sällsynt, och den väljs automatiskt', () => {
    for (let seed = 1; seed <= 200; seed++) {
      const s = defaultAvatars();
      const r = openBox(s, mulberry32(seed))!;
      expect(r.rarity).toBe('rare');
      expect(s.equipped).toBe(r.avatarId);
    }
  });

  it('48 öppningar ger alla 48 utan dubblett, sedan null', () => {
    for (let seed = 1; seed <= 50; seed++) {
      const s = defaultAvatars();
      s.pendingBoxes = 48;
      const rng = mulberry32(seed);
      const got = new Set<string>();
      for (let i = 0; i < 48; i++) {
        const r = openBox(s, rng)!;
        expect(got.has(r.avatarId)).toBe(false);
        got.add(r.avatarId);
      }
      expect(got.size).toBe(48);
      expect(s.owned.length).toBe(48);
      expect(s.pendingBoxes).toBe(0);
      expect(openBox(s, rng)).toBeNull();
    }
  });

  it('fördelning över 20 000 första-10-öppningar ≈ odds ±2 procentenheter', () => {
    const counts: Record<string, number> = {};
    let n = 0;
    const rng = mulberry32(12345);
    for (let p = 0; p < 20_000; p++) {
      const s = defaultAvatars();
      openBox(s, rng); // första är tvingad sällsynt
      for (let i = 1; i < 10; i++) {
        const r = openBox(s, rng)!;
        counts[r.rarity] = (counts[r.rarity] ?? 0) + 1;
        n++;
      }
    }
    for (const r of RARITY.order) expect(Math.abs(((counts[r] ?? 0) / n) * 100 - RARITY.odds[r])).toBeLessThan(2);
  });

  it('omnormering när en raritet är tom', () => {
    const s = defaultAvatars();
    s.owned = AVATARS.filter((a) => a.rarity === 'common').map((a) => a.id);
    const o = currentOdds(s.owned);
    expect(o.common).toBe(0);
    expect(o.uncommon).toBeCloseTo(28 / 56);
    expect(o.mythic).toBeCloseTo(1 / 56);
    const rng = mulberry32(3);
    let uncommon = 0;
    for (let i = 0; i < 20_000; i++) {
      const t = { ...defaultAvatars(), owned: s.owned.slice() };
      const r = openBox(t, rng)!;
      expect(r.rarity).not.toBe('common');
      if (r.rarity === 'uncommon') uncommon++;
    }
    expect(Math.abs(uncommon / 20_000 - 0.5)).toBeLessThan(0.02);
  });

  it('odds-burken: 25 pärlor i proportion, tom när allt ägs', () => {
    const c = pearlCounts(currentOdds([]), 25);
    expect(RARITY.order.reduce((s, r) => s + c[r], 0)).toBe(25);
    expect(c).toEqual({ common: 11, uncommon: 7, rare: 4, epic: 2, legendary: 1, mythic: 0 });
    const all = pearlCounts(currentOdds(AVATARS.map((a) => a.id)), 25);
    expect(RARITY.order.every((r) => all[r] === 0)).toBe(true);
  });
});

describe('XP och nivåer (DESIGN §14.4)', () => {
  it('levelFor: 150 och 450 kumulativt', () => {
    expect([0, 149, 150, 449, 450, 9999].map((x) => levelFor(x))).toEqual([1, 1, 2, 2, 3, 3]);
  });

  it('addXp ökar bara ägda, equip bara ägda', () => {
    const s = defaultAvatars();
    openBox(s, mulberry32(1));
    const id = s.owned[0];
    expect(addXp(s, id, 100)).toBe(1);
    expect(addXp(s, id, 60)).toBe(2);
    expect(s.xp[id]).toBe(160);
    expect(addXp(s, id, 290)).toBe(3);
    expect(addXp(s, 'finns-inte', 500)).toBe(0);
    expect(equip(s, 'finns-inte')).toBe(false);
    openBox(s, mulberry32(2));
    expect(equip(s, s.owned[1])).toBe(true);
    expect(s.equipped).toBe(s.owned[1]);
  });

  it('sparning: gamla sparfiler får avatars-default, korrupta värden tvättas', () => {
    const d = mergeWithDefaults({ highscore: 10 });
    expect(d.avatars).toEqual(defaultAvatars());
    expect(d.highscoreAvatar).toBe('');
    const id = AVATARS[20].id;
    const n = normalizeAvatars({ owned: [id, id, 'okänd', 3], xp: { [id]: 200 }, equipped: 'okänd', pendingBoxes: 99, boxesEarned: -1 });
    expect(n.owned).toEqual([id]);
    expect(n.level[id]).toBe(2);
    expect(n.equipped).toBe(id);
    expect(n.pendingBoxes).toBe(47);
    expect(n.boxesEarned).toBe(0);
  });
});
