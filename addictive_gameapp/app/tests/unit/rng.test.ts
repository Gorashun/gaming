import { describe, expect, it } from 'vitest';
import { mulberry32 } from '../../src/systems/rng';

describe('mulberry32', () => {
  it('ger samma sekvens för samma seed', () => {
    const a = mulberry32(12345);
    const b = mulberry32(12345);
    for (let i = 0; i < 100; i++) expect(a.next()).toBe(b.next());
  });

  it('ger olika sekvens för olika seed', () => {
    expect(mulberry32(1).next()).not.toBe(mulberry32(2).next());
  });

  it('ligger i [0,1)', () => {
    const r = mulberry32(99);
    for (let i = 0; i < 1000; i++) {
      const v = r.next();
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThan(1);
    }
  });

  it('int() täcker hela intervallet inklusive ändarna', () => {
    const r = mulberry32(7);
    const seen = new Set<number>();
    for (let i = 0; i < 2000; i++) {
      const v = r.int(0, 4);
      expect(Number.isInteger(v)).toBe(true);
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThanOrEqual(4);
      seen.add(v);
    }
    expect(seen.size).toBe(5);
  });
});
