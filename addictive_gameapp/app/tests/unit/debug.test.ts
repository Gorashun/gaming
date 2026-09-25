import { describe, expect, it } from 'vitest';
import { AVATARS } from '../../src/data/avatarsIndex';
import { DEBUG } from '../../src/data/debug';
import {
  exportJson,
  nextGift,
  normalizeDebug,
  percentile,
  pushRun,
  setRestart,
  summarizeRun,
  type RunLog,
  type RunSample,
} from '../../src/systems/debug';
import { defaultAvatars, giveAvatar } from '../../src/systems/avatars';
import { defaultSave, mergeWithDefaults } from '../../src/systems/save';

const D = DEBUG.modes.indexOf('drought');
const F = DEBUG.modes.indexOf('flow');

function sample(over: Partial<RunSample> = {}): RunSample {
  return {
    startedAt: 1,
    durationMs: 60_000,
    drops: 10,
    merges: 7,
    autoDrops: 1,
    latencies: [],
    latencyModes: [],
    modeDrops: [0, 0, 0],
    firstMergeMs: 4200,
    boxesEarned: 0,
    score: 120,
    maxLevel: 4,
    activeSet: 'glimtarna',
    equipped: '',
    pacingMode: 'flow',
    calm: false,
    ended: 'loss',
    ...over,
  };
}

describe('nyckeltal per runda (PLAYTEST §3)', () => {
  it('percentil med närmaste rang', () => {
    const v = [5, 1, 4, 2, 3, 10, 9, 8, 7, 6];
    expect(percentile(v, 50)).toBe(5);
    expect(percentile(v, 90)).toBe(9);
    expect(percentile([42], 90)).toBe(42);
    expect(percentile([], 50)).toBeNull();
    expect(v).toEqual([5, 1, 4, 2, 3, 10, 9, 8, 7, 6]); // indata sorteras inte om
  });

  it('P50/P90 totalt och per läge, andel drop per läge', () => {
    const r = summarizeRun(
      sample({
        latencies: [100, 200, 300, 400, 1000, 2000],
        latencyModes: [F, F, F, F, D, D],
        modeDrops: [0, 1, 2].map((i) => (i === D ? 2 : i === F ? 4 : 0)),
      }),
    );
    expect(r.latency.all).toEqual([300, 2000]);
    expect(r.latency.flow).toEqual([200, 400]);
    expect(r.latency.drought).toEqual([1000, 2000]);
    expect(r.modeShare.flow).toBeCloseTo(4 / 6, 3);
    expect(r.modeShare.drought).toBeCloseTo(2 / 6, 3);
    expect(r.modeShare.kick).toBe(0);
    expect(r).toMatchObject({ drops: 10, merges: 7, autoDrops: 1, firstMergeMs: 4200, restartMs: null, restartReadyMs: null });
    expect(r).not.toHaveProperty('latencies');
  });

  it('runda utan drop: inga latenser, andelar 0', () => {
    const r = summarizeRun(sample({ drops: 0, firstMergeMs: null }));
    expect(r.latency).toEqual({ all: null, flow: null, drought: null });
    expect(r.modeShare).toEqual({ drought: 0, flow: 0, kick: 0 });
  });

  it('omstart skrivs på senaste förlustrundan en gång, aldrig på bakåt-avslut', () => {
    const runs: RunLog[] = [summarizeRun(sample())];
    setRestart(runs, 1800.4, 120.6);
    expect(runs[0]).toMatchObject({ restartMs: 1800, restartReadyMs: 121 });
    setRestart(runs, 5000, 5000);
    expect(runs[0].restartMs).toBe(1800);
    const quit: RunLog[] = [summarizeRun(sample({ ended: 'quit' }))];
    setRestart(quit, 900, 100);
    expect(quit[0].restartMs).toBeNull();
  });
});

describe('ringbuffer debug.runs', () => {
  it('högst 20 rundor, de äldsta kastas', () => {
    const runs: RunLog[] = [];
    for (let i = 0; i < 25; i++) pushRun(runs, summarizeRun(sample({ startedAt: i })));
    expect(runs).toHaveLength(DEBUG.maxRuns);
    expect(runs[0].startedAt).toBe(5);
    expect(runs[19].startedAt).toBe(24);
  });

  it('sparfil: default tom, gamla filer får tom logg, för långa kapas, skräp tvättas', () => {
    expect(defaultSave().debug).toEqual({ runs: [], autoDropOff: false });
    expect(mergeWithDefaults({ highscore: 3 }).debug.runs).toEqual([]);
    const many = Array.from({ length: 30 }, (_, i) => ({ startedAt: i }));
    const n = normalizeDebug({ runs: [...many, null, 7], autoDropOff: 'ja' });
    expect(n.runs).toHaveLength(20);
    expect(n.autoDropOff).toBe(false);
  });

  it('exporten innehåller rundorna', () => {
    const d = defaultSave();
    pushRun(d.debug.runs, summarizeRun(sample({ score: 777 })));
    const j = JSON.parse(exportJson(d));
    expect(j.runs).toHaveLength(1);
    expect(j.runs[0].score).toBe(777);
    expect(j.app).toBe('klunk');
  });
});

describe('Ge kompis', () => {
  it('cyklar sällsynt → episk → legendarisk → mytisk och ger en av varje; Lisa är första episka', () => {
    const s = defaultAvatars();
    let k = 0;
    const got: string[] = [];
    for (let i = 0; i < 4; i++) {
      const g = nextGift(s.owned, k)!;
      k = g.k;
      giveAvatar(s, g.id);
      got.push(g.id);
    }
    const rar = got.map((id) => AVATARS.find((a) => a.id === id)!.rarity);
    expect(rar).toEqual(['rare', 'epic', 'legendary', 'mythic']);
    expect(got[1]).toBe('lisa');
    expect(s.equipped).toBe(got[3]);
    expect(s.level[got[0]]).toBe(1);
    expect(s.fresh).toEqual(got);
  });

  it('hoppar över tomma rariteter, null när allt med förmåga ägs', () => {
    const mythic = AVATARS.filter((a) => a.rarity === 'mythic').map((a) => a.id);
    expect(AVATARS.find((a) => a.id === nextGift(mythic, 3)!.id)!.rarity).toBe('rare');
    const all = AVATARS.filter((a) => DEBUG.giftOrder.includes(a.rarity)).map((a) => a.id);
    expect(nextGift(all, 0)).toBeNull();
  });
});
