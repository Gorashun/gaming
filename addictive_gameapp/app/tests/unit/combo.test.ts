import { describe, expect, it } from 'vitest';
import { createComboTracker } from '../../src/systems/combo';
import { createDangerTracker } from '../../src/systems/danger';

const cfg = { windowMs: 1200, chainWindowMs: 450, chainMin: 3 };

describe('combo', () => {
  it('räknar upp inom fönstret och nollställs efter', () => {
    const c = createComboTracker(cfg);
    expect(c.merge(0, false).combo).toBe(1);
    expect(c.merge(500, false).combo).toBe(2);
    expect(c.merge(1600, false).combo).toBe(3);
    expect(c.merge(3000, false).combo).toBe(1);
  });

  it('tick nollställer när fönstret gått ut', () => {
    const c = createComboTracker(cfg);
    c.merge(0, false);
    expect(c.tick(1000)).toBe(false);
    expect(c.tick(1300)).toBe(true);
    expect(c.state.combo).toBe(0);
    expect(c.tick(1400)).toBe(false);
  });
});

describe('kedja', () => {
  it('kräver tre merges i rad som orsakas av varandra', () => {
    const c = createComboTracker(cfg);
    expect(c.merge(0, false).chain).toBe(1);
    expect(c.merge(100, true).chain).toBe(2);
    const third = c.merge(200, true);
    expect(third.chain).toBe(3);
    expect(third.chainTriggered).toBe(true);
  });

  it('bryts när mergen inte orsakas av en merge', () => {
    const c = createComboTracker(cfg);
    c.merge(0, false);
    c.merge(100, true);
    expect(c.merge(200, false).chain).toBe(1);
  });

  it('bryts när det tar för lång tid', () => {
    const c = createComboTracker(cfg);
    c.merge(0, false);
    c.merge(100, true);
    expect(c.merge(900, true).chain).toBe(1);
  });
});

describe('fara', () => {
  const dcfg = { maxTriggers: 3, windowMs: 10_000, releaseMs: 400 };

  it('startar och slutar, och triggar bara en gång per farotillfälle', () => {
    const d = createDangerTracker(dcfg);
    expect(d.update(0, true)).toBe('start');
    expect(d.update(100, true)).toBe(null);
    expect(d.update(200, false)).toBe(null);
    expect(d.update(700, false)).toBe('end');
    expect(d.active).toBe(false);
  });

  it('max 3 triggers per 10 s', () => {
    const d = createDangerTracker(dcfg);
    let t = 0;
    for (let i = 0; i < 3; i++) {
      expect(d.update(t, true)).toBe('start');
      t += 100;
      d.update(t, false);
      t += 500;
      d.update(t, false);
      t += 100;
    }
    expect(d.update(t, true)).toBe(null);
    // Efter att fönstret glidit förbi tillåts fler.
    expect(d.update(t + 10_001, true)).toBe('start');
  });
});
