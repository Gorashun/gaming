import { describe, expect, it } from 'vitest';
import { LEVELS, MAX_LEVEL, QUEUE_LEVELS, scoreForCreating } from '../../src/data/levels';

describe('levels', () => {
  it('har 11 nivåer 0–10', () => {
    expect(LEVELS).toHaveLength(11);
    expect(MAX_LEVEL).toBe(10);
    LEVELS.forEach((l, i) => expect(l.level).toBe(i));
  });

  it('har strikt stigande radier', () => {
    for (let i = 1; i < LEVELS.length; i++) {
      expect(LEVELS[i].radius).toBeGreaterThan(LEVELS[i - 1].radius);
    }
  });

  it('har triangulära poäng T(n+1) = (n+1)(n+2)/2', () => {
    LEVELS.forEach((l, i) => {
      expect(l.score).toBe(((i + 1) * (i + 2)) / 2);
    });
  });

  it('bara nivå 10 har bonus, och nivå 0–4 får ligga i kön', () => {
    expect(QUEUE_LEVELS).toEqual([0, 1, 2, 3, 4]);
    expect(scoreForCreating(10)).toBe(566);
    expect(scoreForCreating(0)).toBe(1);
  });

  it('två största får plats i burken', () => {
    expect(LEVELS[MAX_LEVEL].radius * 2).toBeLessThan(280);
  });
});
