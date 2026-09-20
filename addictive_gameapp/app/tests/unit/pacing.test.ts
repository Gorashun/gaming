import { describe, expect, it } from 'vitest';
import { PACING } from '../../src/data/pacing';
import { createPacer, evaluatePacing, type PacerInput, type PacingInput } from '../../src/systems/pacing';
import { THEME } from '../../src/data/theme';

/** Grundfall: allt tillåter pacing. Tiden räknas från t=1000. */
const base = (over: Partial<PacingInput> = {}): PacingInput => ({
  mode: 'flow',
  nowMs: 1000,
  readySinceMs: 1000,
  directorMode: 'flow',
  isSpecial: false,
  isDanger: false,
  isTimeStopped: false,
  calm: false,
  hasDroppedThisRun: true,
  ...over,
});

const at = (ms: number, over: Partial<PacingInput> = {}) =>
  evaluatePacing(base({ nowMs: 1000 + ms, ...over }));

describe('pacing: villkor (DESIGN §11)', () => {
  it('inaktiv tills 3 s gått även när allt är tillåtet', () => {
    expect(at(0).phase).toBe('idle');
    expect(at(2999).phase).toBe('idle');
  });

  const blocked: [string, Partial<PacingInput>][] = [
    ['mode off', { mode: 'off' }],
    ['regissören i Torka', { directorMode: 'drought' }],
    ['regissören i Kick', { directorMode: 'kick' }],
    ['specialobjekt', { isSpecial: true }],
    ['fara', { isDanger: true }],
    ['slow-mo/hit-stop', { isTimeStopped: true }],
    ['Lugnt läge', { calm: true }],
    ['spelaren har inte droppat själv än i rundan', { hasDroppedThisRun: false }],
    ['inget släppbart objekt', { readySinceMs: null }],
  ];

  for (const [name, over] of blocked) {
    it(`ger alltid idle: ${name}`, () => {
      for (const ms of [0, 3000, 6000, 60_000]) {
        const out = at(ms, over);
        expect(out.phase, `${name} vid ${ms} ms`).toBe('idle');
        expect(out.wobbleAngleDeg).toBe(0);
      }
    });
  }
});

describe('pacing: fasgränser', () => {
  it('nudge från och med 3000 ms, autodrop från och med 6000 ms', () => {
    expect(at(PACING.nudgeAtMs - 1).phase).toBe('idle');
    expect(at(PACING.nudgeAtMs).phase).toBe('nudge');
    expect(at(PACING.autoDropAtMs - 1).phase).toBe('nudge');
    expect(at(PACING.autoDropAtMs).phase).toBe('autodrop');
    expect(at(PACING.autoDropAtMs + 5000).phase).toBe('autodrop');
  });

  it('nollställs vid drop: readySinceMs null ⇒ idle och ingen vickning', () => {
    const wobbling = at(4000);
    expect(wobbling.phase).toBe('nudge');
    expect(Math.abs(wobbling.wobbleAngleDeg)).toBeGreaterThan(0);
    const afterDrop = at(4000, { readySinceMs: null });
    expect(afterDrop.phase).toBe('idle');
    expect(afterDrop.wobbleAngleDeg).toBe(0);
  });

  it('timern räknar från att objektet blev släppbart, inte från nowMs', () => {
    const out = evaluatePacing(base({ readySinceMs: 50_000, nowMs: 56_000 }));
    expect(out.phase).toBe('autodrop');
  });
});

describe('pacing: vickningen', () => {
  it('startar på 0 och håller sig inom ±wobbleDeg', () => {
    expect(at(PACING.nudgeAtMs).wobbleAngleDeg).toBeCloseTo(0, 10);
    let max = 0;
    for (let ms = PACING.nudgeAtMs; ms <= PACING.autoDropAtMs; ms += 5) {
      const a = at(ms).wobbleAngleDeg;
      expect(Math.abs(a)).toBeLessThanOrEqual(PACING.wobbleDeg + 1e-9);
      max = Math.max(max, Math.abs(a));
    }
    expect(max).toBeCloseTo(PACING.wobbleDeg, 2);
  });

  it('svänger med wobbleHz: perioden är 1/0,8 s', () => {
    const periodMs = 1000 / PACING.wobbleHz;
    expect(periodMs).toBe(1250);
    const t0 = PACING.nudgeAtMs + 137;
    expect(at(t0 + periodMs).wobbleAngleDeg).toBeCloseTo(at(t0).wobbleAngleDeg, 6);
    // Toppen ligger en kvartsperiod in, nollgenomgång en halv period in.
    expect(at(PACING.nudgeAtMs + periodMs / 4).wobbleAngleDeg).toBeCloseTo(PACING.wobbleDeg, 6);
    expect(at(PACING.nudgeAtMs + periodMs / 2).wobbleAngleDeg).toBeCloseTo(0, 6);
    expect(at(PACING.nudgeAtMs + (periodMs * 3) / 4).wobbleAngleDeg).toBeCloseTo(
      -PACING.wobbleDeg,
      6,
    );
  });

  it('är en rörelse, inte en blink: långt under flash-gränsen', () => {
    expect(PACING.wobbleHz).toBeLessThanOrEqual(THEME.a11y.maxFlashesPerSec);
  });

  it('återanvänder out-objektet (inga allokeringar i update)', () => {
    const out = { phase: 'idle' as const, wobbleAngleDeg: 0 };
    const r1 = evaluatePacing(base({ nowMs: 4500 }), out);
    const r2 = evaluatePacing(base({ nowMs: 1000 }), out);
    expect(r1).toBe(out);
    expect(r2).toBe(out);
    expect(out.phase).toBe('idle');
  });
});

describe('pacing: konfig', () => {
  it('följer DESIGN §11', () => {
    expect(PACING.mode).toBe('flow');
    expect(PACING.nudgeAtMs).toBe(3000);
    expect(PACING.autoDropAtMs).toBe(6000);
    expect(PACING.wobbleDeg).toBe(4);
    expect(PACING.wobbleHz).toBe(0.8);
    expect(PACING.nudgeAtMs).toBeLessThan(PACING.autoDropAtMs);
  });
});

describe('pacing: timern (createPacer)', () => {
  const cond = (over: Partial<PacerInput> = {}): PacerInput => ({
    mode: 'flow',
    nowMs: 0,
    directorMode: 'flow',
    isSpecial: false,
    isDanger: false,
    isTimeStopped: false,
    calm: false,
    hasDroppedThisRun: true,
    ...over,
  });

  it('räknar från ready() och nollställs av drop()', () => {
    const pacer = createPacer();
    expect(pacer.update(cond({ nowMs: 10_000 })).phase).toBe('idle');
    pacer.ready(10_000);
    pacer.update(cond({ nowMs: 10_000 }));
    expect(pacer.readySinceMs).toBe(10_000);
    expect(pacer.update(cond({ nowMs: 13_000 })).phase).toBe('nudge');
    expect(pacer.update(cond({ nowMs: 16_000 })).phase).toBe('autodrop');
    pacer.drop();
    expect(pacer.readySinceMs).toBeNull();
    expect(pacer.result.phase).toBe('idle');
    expect(pacer.update(cond({ nowMs: 30_000 })).phase).toBe('idle');
  });

  it('nollställer timern när faran släpper: inget auto-drop i samma andetag', () => {
    const pacer = createPacer();
    pacer.ready(0);
    // Objektet hänger i 20 s, hela tiden under fara.
    for (let t = 0; t <= 20_000; t += 500) {
      expect(pacer.update(cond({ nowMs: t, isDanger: true })).phase).toBe('idle');
    }
    // Faran släpper: timern börjar om från noll.
    expect(pacer.update(cond({ nowMs: 20_000 })).phase).toBe('idle');
    expect(pacer.readySinceMs).toBe(20_000);
    expect(pacer.update(cond({ nowMs: 22_999 })).phase).toBe('idle');
    expect(pacer.update(cond({ nowMs: 23_000 })).phase).toBe('nudge');
    expect(pacer.update(cond({ nowMs: 26_000 })).phase).toBe('autodrop');
  });

  const transitions: [string, Partial<PacerInput>][] = [
    ['hit-stop/slow-mo', { isTimeStopped: true }],
    ['specialobjekt', { isSpecial: true }],
    ['Torka', { directorMode: 'drought' }],
    ['Lugnt läge', { calm: true }],
    ['pacing off', { mode: 'off' }],
    ['första manuella droppet', { hasDroppedThisRun: false }],
  ];

  for (const [name, blocking] of transitions) {
    it(`nollställer timern vid övergången blockerad → fri: ${name}`, () => {
      const pacer = createPacer();
      pacer.ready(0);
      expect(pacer.update(cond({ nowMs: 9000, ...blocking })).phase).toBe('idle');
      expect(pacer.update(cond({ nowMs: 9000 })).phase).toBe('idle');
      expect(pacer.readySinceMs).toBe(9000);
      expect(pacer.update(cond({ nowMs: 15_000 })).phase).toBe('autodrop');
    });
  }

  it('rör inte timern när inget objekt hänger', () => {
    const pacer = createPacer();
    pacer.update(cond({ nowMs: 1000, isDanger: true }));
    pacer.update(cond({ nowMs: 2000 }));
    expect(pacer.readySinceMs).toBeNull();
  });

  it('reset() nollställer inför ny runda', () => {
    const pacer = createPacer();
    pacer.ready(1000);
    // Första fria framen nollställer timern (pacern startar i blockerat läge).
    pacer.update(cond({ nowMs: 1000 }));
    pacer.update(cond({ nowMs: 8000 }));
    expect(pacer.result.phase).toBe('autodrop');
    pacer.reset();
    expect(pacer.readySinceMs).toBeNull();
    expect(pacer.result.phase).toBe('idle');
  });
});
