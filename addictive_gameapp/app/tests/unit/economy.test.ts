import { describe, expect, it } from 'vitest';
import { AVATARS, RARITY, type Rarity } from '../../src/data/avatarsIndex';
import { ECONOMY, type ShellType } from '../../src/data/economy';
import { mulberry32 } from '../../src/systems/rng';
import { defaultAvatars, type AvatarState } from '../../src/systems/avatars';
import {
  buyPick,
  buyShell,
  canBuy,
  canUpgrade,
  claimFreeShells,
  defaultEconomy,
  earnForRun,
  freeShellsDue,
  offerPick3,
  shellAvailable,
  upgrade,
  upgradeCost,
  type EconomyState,
  type RunSummary,
} from '../../src/systems/economy';
import { mergeWithDefaults } from '../../src/systems/save';

const idx = (r: Rarity): number => RARITY.order.indexOf(r);
const ids = (pred: (r: Rarity) => boolean): string[] => AVATARS.filter((a) => pred(a.rarity)).map((a) => a.id);

interface W {
  economy: EconomyState;
  avatars: AvatarState;
  stats: { merges: number };
}
function wallet(pearls = 0, sand = 0, owned: string[] = []): W {
  const avatars = defaultAvatars();
  for (const id of owned) {
    avatars.owned.push(id);
    avatars.level[id] = 1;
  }
  return { economy: { ...defaultEconomy(), pearls, sand }, avatars, stats: { merges: 0 } };
}

const quiet: RunSummary = {
  merges: 0,
  shinies: 0,
  chains3: 0,
  level10s: 0,
  maxLevelEver: 0,
  doubleKlunks: 0,
  anyShiny: false,
  fullPages: [],
};

describe('intjäning per runda (DESIGN §16.1)', () => {
  it('1 pärla per merge och alla sand-källor', () => {
    const w = wallet();
    const e = earnForRun({ ...quiet, merges: 60, shinies: 2, chains3: 2, level10s: 1 }, w);
    expect(e).toEqual({ pearls: 60, sand: 2 + 2 + 2, milestones: [] });
    expect(w.economy).toMatchObject({ pearls: 60, sand: 6 });
  });

  it('kedjor ≥3 ger högst 3 sand per runda', () => {
    const w = wallet();
    expect(earnForRun({ ...quiet, chains3: 9 }, w).sand).toBe(3);
  });

  it('engångsmilstolpar +3 (nivå 7–10, skimrande, dubbel-Klunk), full sida +10, bara en gång', () => {
    const w = wallet();
    const flags = { maxLevelEver: 10, doubleKlunks: 1, anyShiny: true, fullPages: ['glimtarna'] };
    const first = earnForRun({ ...quiet, ...flags }, w);
    expect(first.sand).toBe(6 * 3 + 10);
    expect(first.milestones.sort()).toEqual(['doubleKlunk', 'level10', 'level7', 'level8', 'level9', 'page:glimtarna', 'shiny']);
    const again = earnForRun({ ...quiet, ...flags, merges: 5 }, w);
    expect(again).toEqual({ pearls: 5, sand: 0, milestones: [] });
    // Ny full sida i ett annat set ger +10 igen.
    expect(earnForRun({ ...quiet, ...flags, fullPages: ['glimtarna', 'planeterna'] }, w).sand).toBe(10);
  });

  it('flera utbetalningar i samma runda betalar bara skillnaden', () => {
    const w = wallet();
    const paid = { pearls: 0, sand: 0 };
    earnForRun({ ...quiet, merges: 20, chains3: 2 }, w, paid);
    const e = earnForRun({ ...quiet, merges: 50, chains3: 5, shinies: 1 }, w, paid);
    expect(e).toEqual({ pearls: 30, sand: 2, milestones: [] });
    expect(w.economy).toMatchObject({ pearls: 50, sand: 4 });
  });
});

describe('gratismusslor (DESIGN §16.2)', () => {
  it('vid 120, 400, 1150, 1900 merges från baseline', () => {
    const due = (m: number): number => {
      const w = wallet();
      w.stats.merges = m;
      return freeShellsDue(w);
    };
    expect([0, 119, 120, 399, 400, 1149, 1150, 1899, 1900].map(due)).toEqual([0, 0, 1, 1, 2, 2, 3, 3, 4]);
  });

  it('claim lägger musslor på hyllan en gång', () => {
    const w = wallet();
    w.stats.merges = 400;
    expect(claimFreeShells(w)).toEqual({ shells: 2, sand: 0 });
    expect(w.avatars.pendingBoxes).toBe(2);
    expect(claimFreeShells(w)).toEqual({ shells: 0, sand: 0 });
    expect(w.economy.freeShellsClaimed).toBe(2);
  });

  it('inte retroaktivt: gammal sparfil med 2000 merges ger 0 vid start, första vid +120', () => {
    const d = mergeWithDefaults({ stats: { merges: 2000 } } as never);
    expect(d.economy).toMatchObject({ pearls: 0, sand: 0, mergesBaseline: 2000, freeShellsClaimed: 0 });
    expect(freeShellsDue(d)).toBe(0);
    d.stats.merges = 2119;
    expect(freeShellsDue(d)).toBe(0);
    d.stats.merges = 2120;
    expect(freeShellsDue(d)).toBe(1);
  });

  it('full bok: gratismusslan ger 10 stjärnsand', () => {
    const w = wallet(0, 0, AVATARS.map((a) => a.id));
    w.stats.merges = 400;
    expect(claimFreeShells(w)).toEqual({ shells: 0, sand: 20 });
    expect(w.economy.sand).toBe(20);
    expect(w.avatars.pendingBoxes).toBe(0);
  });

  it('en mussla redan på hyllan räknas: sista figuren ges inte två gånger', () => {
    const w = wallet(0, 0, AVATARS.slice(0, 47).map((a) => a.id));
    w.stats.merges = 400;
    expect(claimFreeShells(w)).toEqual({ shells: 1, sand: 10 });
  });
});

describe('butik (DESIGN §16.2)', () => {
  const rare = ids((r) => r === 'rare')[0];

  it('köp drar rätt pris', () => {
    const w = wallet(1000, 50, [rare]);
    buyShell(w, 'common', mulberry32(1));
    expect(w.economy).toMatchObject({ pearls: 700, sand: 50 });
    buyShell(w, 'silver', mulberry32(2));
    expect(w.economy).toMatchObject({ pearls: 0, sand: 50 });
    buyShell(w, 'gold', mulberry32(3));
    expect(w.economy).toMatchObject({ pearls: 0, sand: 0 });
    expect(w.avatars.owned.length).toBe(4);
  });

  it('"räcker inte" ändrar ingenting', () => {
    for (const [type, p, s] of [['common', 299, 99], ['silver', 699, 99], ['gold', 9999, 49]] as const) {
      const w = wallet(p, s, [rare]);
      const before = JSON.stringify(w);
      expect(canBuy(w, type)).toBe(false);
      expect(buyShell(w, type, mulberry32(1))).toBeNull();
      expect(JSON.stringify(w)).toBe(before);
    }
  });

  it('första musslan i livet är alltid sällsynt, oavsett typ', () => {
    for (const type of ['common', 'silver', 'gold'] as const) {
      for (let seed = 1; seed <= 50; seed++) {
        const w = wallet(1000, 100);
        expect(buyShell(w, type, mulberry32(seed))!.rarity).toBe('rare');
        expect(w.avatars.equipped).toBe(w.avatars.owned[0]);
      }
    }
  });

  it('golv: silver ger aldrig vanlig, guld aldrig vanlig eller ovanlig', () => {
    const rng = mulberry32(99);
    for (let i = 0; i < 2000; i++) {
      const s = buyShell(wallet(700, 0, [rare]), 'silver', rng)!;
      expect(idx(s.rarity)).toBeGreaterThanOrEqual(idx('uncommon'));
      const g = buyShell(wallet(0, 50, [rare]), 'gold', rng)!;
      expect(idx(g.rarity)).toBeGreaterThanOrEqual(idx('rare'));
    }
  });

  it('odds per typ över 20 000 köp ≈ tabellen ±2 procentenheter', () => {
    for (const type of ['common', 'silver', 'gold'] as const) {
      const rng = mulberry32(4242);
      const counts: Partial<Record<Rarity, number>> = {};
      const n = 20_000;
      for (let i = 0; i < n; i++) {
        const r = buyShell(wallet(1000, 100, [rare]), type, rng)!;
        counts[r.rarity] = (counts[r.rarity] ?? 0) + 1;
      }
      const odds = ECONOMY.shells[type].odds;
      const sum = odds.reduce((a, b) => a + b, 0);
      RARITY.order.forEach((r, i) => {
        expect(Math.abs(((counts[r] ?? 0) / n) * 100 - (odds[i] / sum) * 100)).toBeLessThan(2);
      });
    }
  });

  it('48 köp ger alla 48 utan dubbletter, sedan ospelbart', () => {
    for (let seed = 1; seed <= 20; seed++) {
      const w = wallet(300 * 48);
      const rng = mulberry32(seed);
      const got = new Set<string>();
      for (let i = 0; i < 48; i++) {
        const r = buyShell(w, 'common', rng)!;
        expect(got.has(r.avatarId)).toBe(false);
        got.add(r.avatarId);
      }
      expect(got.size).toBe(48);
      expect(w.economy.pearls).toBe(0);
      w.economy.pearls = 1000;
      expect(canBuy(w, 'common')).toBe(false);
      expect(buyShell(w, 'common', rng)).toBeNull();
      expect(w.economy.pearls).toBe(1000);
    }
  });

  it('tomt golv: silver/guld ospelbara när inget finns kvar över golvet', () => {
    const w = wallet(10_000, 1000, ids((r) => idx(r) >= idx('rare')));
    expect(shellAvailable(w.avatars, 'gold')).toBe(false);
    expect(canBuy(w, 'gold')).toBe(false);
    expect(canBuy(w, 'silver')).toBe(true);
    expect(buyShell(w, 'silver', mulberry32(1))!.rarity).toBe('uncommon');
    const all = wallet(10_000, 1000, ids((r) => idx(r) >= idx('uncommon')));
    expect(canBuy(all, 'silver')).toBe(false);
    expect(canBuy(all, 'common')).toBe(true);
  });

  it('oöppnade musslor på hyllan reserverar figurer', () => {
    const w = wallet(1000, 0, AVATARS.slice(0, 46).map((a) => a.id));
    w.avatars.pendingBoxes = 2;
    expect(canBuy(w, 'common')).toBe(false);
  });

  it('deterministisk med seed', () => {
    const run = (seed: number): string[] => {
      const w = wallet(300 * 10);
      const rng = mulberry32(seed);
      return Array.from({ length: 10 }, () => buyShell(w, 'common', rng)!.avatarId);
    };
    expect(run(5)).toEqual(run(5));
    expect(run(5)).not.toEqual(run(6));
  });
});

describe('pick3 (reservläge)', () => {
  it('ger 3 unika, ej ägda, över golvet, och köpet ger den valda', () => {
    const owned = ids((r) => r === 'rare').slice(0, 3);
    for (let seed = 1; seed <= 100; seed++) {
      for (const type of ['common', 'silver', 'gold'] as ShellType[]) {
        const w = wallet(1000, 100, owned);
        const offer = offerPick3(w, type, mulberry32(seed));
        expect(offer.length).toBe(3);
        expect(new Set(offer.map((a) => a.id)).size).toBe(3);
        for (const a of offer) {
          expect(owned).not.toContain(a.id);
          expect(idx(a.rarity)).toBeGreaterThanOrEqual(idx(ECONOMY.shells[type].floor));
        }
        const before = { ...w.economy };
        const r = buyPick(w, type, offer[1].id)!;
        expect(r.avatarId).toBe(offer[1].id);
        expect(w.avatars.owned).toContain(offer[1].id);
        const p = ECONOMY.shells[type].price;
        expect(w.economy.pearls).toBe(before.pearls - (p.pearls ?? 0));
        expect(w.economy.sand).toBe(before.sand - (p.sand ?? 0));
      }
    }
  });

  it('första i livet: bara sällsynta erbjuds; ägd eller under golvet går inte att köpa', () => {
    const w = wallet(1000, 100);
    expect(offerPick3(w, 'common', mulberry32(1)).every((a) => a.rarity === 'rare')).toBe(true);
    const w2 = wallet(1000, 100, [ids((r) => r === 'rare')[0]]);
    expect(buyPick(w2, 'common', w2.avatars.owned[0])).toBeNull();
    expect(buyPick(w2, 'gold', ids((r) => r === 'common')[0])).toBeNull();
    expect(w2.economy).toMatchObject({ pearls: 1000, sand: 100 });
  });
});

describe('uppgradering (DESIGN §16.3)', () => {
  it('kostnader per raritet', () => {
    const table: Record<Rarity, [number, number, number]> = {
      common: [80, 200, 4],
      uncommon: [100, 250, 6],
      rare: [150, 400, 10],
      epic: [200, 550, 15],
      legendary: [250, 700, 20],
      mythic: [300, 800, 24],
    };
    for (const r of RARITY.order) {
      const [ii, iii, sand] = table[r];
      expect(upgradeCost(r, 1)).toEqual({ pearls: ii, sand: 0 });
      expect(upgradeCost(r, 2)).toEqual({ pearls: iii, sand });
      expect(upgradeCost(r, 3)).toBeNull();
    }
  });

  it('drar pris och höjer nivå; nivå III kräver sand; III är slut', () => {
    const id = ids((r) => r === 'epic')[0];
    const w = wallet(10_000, 0, [id]);
    expect(upgrade(w, id)).toBe(true);
    expect(w.avatars.level[id]).toBe(2);
    expect(w.economy.pearls).toBe(10_000 - 200);
    const before = JSON.stringify(w);
    expect(canUpgrade(w, id)).toBe(false);
    expect(upgrade(w, id)).toBe(false);
    expect(JSON.stringify(w)).toBe(before);
    w.economy.sand = 15;
    expect(upgrade(w, id)).toBe(true);
    expect(w.avatars.level[id]).toBe(3);
    expect(w.economy).toMatchObject({ pearls: 10_000 - 200 - 550, sand: 0 });
    expect(canUpgrade(w, id)).toBe(false);
    expect(upgrade(w, id)).toBe(false);
  });

  it('bara ägda, och "räcker inte" ändrar ingenting', () => {
    const id = ids((r) => r === 'common')[0];
    expect(upgrade(wallet(10_000, 100), id)).toBe(false);
    const w = wallet(79, 0, [id]);
    expect(upgrade(w, id)).toBe(false);
    expect(w.economy.pearls).toBe(79);
    expect(w.avatars.level[id]).toBe(1);
  });
});

describe('migrering (DESIGN §16.2–16.3)', () => {
  it('gammal sparfil: xp bort, nivåer kvar, oöppnade kvar, baseline satt, nådda milstolpar räknas som utbetalda', () => {
    const [a, b] = [ids((r) => r === 'rare')[0], ids((r) => r === 'epic')[0]];
    const old = {
      highscore: 900,
      stats: { runs: 30, merges: 1500, maxLevelEver: 8, doubleKlunks: 0 },
      avatars: {
        owned: [a, b],
        level: { [a]: 3, [b]: 2 },
        xp: { [a]: 500, [b]: 160 },
        equipped: b,
        boxesEarned: 9,
        boxesOpened: 2,
        pendingBoxes: 3,
      },
    };
    const d = mergeWithDefaults(old as never);
    expect(d.avatars).not.toHaveProperty('xp');
    expect(d.avatars.level).toEqual({ [a]: 3, [b]: 2 });
    expect(d.avatars).toMatchObject({ owned: [a, b], equipped: b, pendingBoxes: 3 });
    expect(d.economy).toEqual({ pearls: 0, sand: 0, mergesBaseline: 1500, freeShellsClaimed: 0, milestones: ['level7', 'level8'] });
    // Ingen retroaktiv utbetalning: redan nådda milstolpar ger inget, nästa ger.
    const e = earnForRun({ ...quiet, maxLevelEver: 9 }, d);
    expect(e.milestones).toEqual(['level9']);
    expect(e.sand).toBe(3);
  });

  it('gammal xp utan sparad nivå ger nivån XP motsvarade', () => {
    const a = ids((r) => r === 'rare')[0];
    const d = mergeWithDefaults({ avatars: { owned: [a], xp: { [a]: 450 } } } as never);
    expect(d.avatars.level[a]).toBe(3);
  });

  it('ny sparfil och sparfil med economy behålls', () => {
    expect(mergeWithDefaults({}).economy).toEqual(defaultEconomy(0));
    const e = { pearls: 12, sand: 3, mergesBaseline: 7, freeShellsClaimed: 1, milestones: ['shiny', 'shiny', 4] };
    const d = mergeWithDefaults({ economy: e, stats: { merges: 9000 } } as never);
    expect(d.economy).toEqual({ pearls: 12, sand: 3, mergesBaseline: 7, freeShellsClaimed: 1, milestones: ['shiny'] });
  });
});
