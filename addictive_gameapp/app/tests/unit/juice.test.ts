import { describe, expect, it } from 'vitest';
import { EVENTS, FEEL, JUICE, mergeIntensity } from '../../src/data/juice';
import { THEME } from '../../src/data/theme';

const rgb = (hex: string): [number, number, number] => [
  parseInt(hex.slice(1, 3), 16),
  parseInt(hex.slice(3, 5), 16),
  parseInt(hex.slice(5, 7), 16),
];

describe('flash-guard (WCAG 2.3.1)', () => {
  it('ingen loopande puls går snabbare än 3 Hz', () => {
    for (const [name, halfCycleMs] of Object.entries(JUICE.pulseHalfCycleMs)) {
      const hz = 500 / halfCycleMs;
      expect(hz, `${name} pulsar ${hz.toFixed(2)} Hz`).toBeLessThanOrEqual(
        THEME.a11y.maxFlashesPerSec,
      );
    }
  });

  it('ingen mättad röd i pulsfärgerna', () => {
    for (const hex of JUICE.pulseColors) {
      const [r, g, b] = rgb(hex);
      const saturatedRed = r > 180 && g < 90 && b < 90;
      expect(saturatedRed, `${hex} är mättad röd`).toBe(false);
    }
  });

  it('inga vitblixtar: ingen pulsfärg är ren vit', () => {
    for (const hex of JUICE.pulseColors) {
      const [r, g, b] = rgb(hex);
      expect(r === 255 && g === 255 && b === 255, `${hex} är ren vit`).toBe(false);
    }
  });

  it('farolinjen är bärnsten, inte röd', () => {
    const [r, g, b] = rgb(THEME.palette.danger);
    expect(g).toBeGreaterThan(120);
    expect(r).toBeGreaterThan(g);
    expect(b).toBeLessThan(g);
  });
});

describe('juice-konfig', () => {
  it('håller taken från DESIGN §6', () => {
    expect(JUICE.particles.max).toBeLessThanOrEqual(40);
    expect(JUICE.shake.maxPx).toBeLessThanOrEqual(8);
    expect(JUICE.shake.durationMs).toBeLessThanOrEqual(300);
    expect(JUICE.hitStop.maxFrames * JUICE.hitStop.frameMs).toBeLessThanOrEqual(
      JUICE.hitStop.maxMs + 1,
    );
    expect(JUICE.hitStop.maxMs).toBeLessThanOrEqual(100);
    expect(JUICE.zoom.peak).toBeCloseTo(1.06, 5);
  });

  it('lugnt läge halverar intensiteten och släcker shake och zoom', () => {
    expect(JUICE.calm.intensityScale).toBe(0.5);
    expect(JUICE.calm.shake).toBe(false);
    expect(JUICE.calm.zoom).toBe(false);
  });

  it('kamerazoom bara för chain och special', () => {
    const zooming = Object.entries(EVENTS)
      .filter(([, ch]) => ch.zoom)
      .map(([k]) => k);
    expect(zooming.sort()).toEqual(['chain', 'special']);
  });

  it('partikelantalet följer 6 + 24·i med tak 40', () => {
    const count = (i: number): number =>
      Math.min(JUICE.particles.max, Math.round(JUICE.particles.base + JUICE.particles.perIntensity * i));
    expect(count(0)).toBe(6);
    expect(count(0.5)).toBe(18);
    expect(count(1)).toBe(30);
    expect(count(2)).toBe(40);
  });
});

describe('belöningstrappan', () => {
  it('vanlig merge ligger på 0,25–0,45', () => {
    expect(mergeIntensity(0, 1)).toBeCloseTo(0.32, 2);
    expect(mergeIntensity(10, 1)).toBeCloseTo(0.52, 2);
    expect(mergeIntensity(0, 0)).toBeCloseTo(0.25, 2);
    expect(mergeIntensity(10, 0)).toBeCloseTo(0.45, 2);
  });

  it('combo höjer intensiteten men aldrig över 1', () => {
    expect(mergeIntensity(5, 4)).toBeGreaterThan(mergeIntensity(5, 1));
    expect(mergeIntensity(10, 12)).toBeLessThanOrEqual(1);
  });

  it('combo-fönstret är 1,2 s och kedjan kräver 3', () => {
    expect(FEEL.combo.windowMs).toBe(1200);
    expect(FEEL.chain.minLength).toBe(3);
    expect(FEEL.danger.marginPx).toBe(40);
    expect(FEEL.danger.maxTriggers).toBe(3);
    expect(FEEL.danger.windowMs).toBe(10_000);
    expect(FEEL.danger.timeScale).toBe(0.6);
  });
});
