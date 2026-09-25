import { describe, expect, it } from 'vitest';
import { zoomFor } from '../../src/systems/zoom';
import { SetLru } from '../../src/systems/setLru';
import { ART } from '../../src/data/art';

describe('zoomFor (Z = min(DPR, maxZoom), DESIGN §17)', () => {
  it('taket är 2 i data', () => {
    expect(ART.maxZoom).toBe(2);
    expect(ART.maxSets).toBe(2);
  });
  it('följer DPR upp till taket', () => {
    expect(zoomFor(1, 2)).toBe(1);
    expect(zoomFor(2, 2)).toBe(2);
    expect(zoomFor(3, 2)).toBe(2);
    expect(zoomFor(2.625, 2)).toBe(2);
    expect(zoomFor(1.5, 2)).toBe(1.5);
  });
  it('aldrig under 1, okänd DPR = 1', () => {
    expect(zoomFor(0.75, 2)).toBe(1);
    expect(zoomFor(undefined, 2)).toBe(1);
    expect(zoomFor(0, 2)).toBe(1);
    expect(zoomFor(NaN, 2)).toBe(1);
  });
  it('steg om 0,25 så att canvasen blir hela pixlar', () => {
    for (const d of [1.1, 1.33, 1.6, 1.99]) {
      const z = zoomFor(d, 2);
      expect(Number.isInteger(360 * z) && Number.isInteger(640 * z)).toBe(true);
      expect(z).toBeLessThanOrEqual(d);
    }
    expect(zoomFor(1.33, 2)).toBe(1.25);
  });
  it('?zoom= kan bara sänka', () => {
    expect(zoomFor(3, 2, '1')).toBe(1);
    expect(zoomFor(3, 2, '1.5')).toBe(1.5);
    expect(zoomFor(1, 2, '2')).toBe(1);
    expect(zoomFor(3, 2, '4')).toBe(2);
    expect(zoomFor(3, 2, 'x')).toBe(2);
    expect(zoomFor(3, 2, '')).toBe(2);
    expect(zoomFor(3, 2, null)).toBe(2);
  });
});

describe('SetLru (högst 2 set i full upplösning)', () => {
  it('frigör äldsta när ett tredje behövs', () => {
    const l = new SetLru(2);
    expect(l.use('a')).toEqual([]);
    expect(l.use('b')).toEqual([]);
    expect(l.use('c')).toEqual(['a']);
    expect(l.sets).toEqual(['b', 'c']);
  });
  it('användning flyttar setet sist (LRU, inte FIFO)', () => {
    const l = new SetLru(2);
    l.use('a');
    l.use('b');
    expect(l.use('a')).toEqual([]);
    expect(l.use('c')).toEqual(['b']);
    expect(l.sets).toEqual(['a', 'c']);
  });
  it('frigör aldrig det aktiva (keep) eller det som används', () => {
    const l = new SetLru(2);
    l.use('a');
    l.use('b');
    expect(l.use('c', ['a'])).toEqual(['b']);
    expect(l.sets).toEqual(['a', 'c']);
    // Aktivt + glow-varianten låsta: ett tredje set går över budgeten hellre än att frigöra dem.
    expect(l.use('d', ['a', 'c'])).toEqual([]);
    expect(l.sets).toEqual(['a', 'c', 'd']);
    expect(l.use('e', ['e'])).toEqual(['a', 'c']);
    expect(l.sets).toEqual(['d', 'e']);
  });
  it('bläddring genom fem set med aktivt låst håller ≤ 2 och det aktiva kvar', () => {
    const l = new SetLru(2);
    const all = ['glimtarna', 'planeterna', 'frostisarna', 'godisarna', 'gloden'];
    l.use('glimtarna', ['glimtarna']);
    for (const s of all) {
      l.use(s, ['glimtarna']);
      expect(l.sets.length).toBeLessThanOrEqual(2);
      expect(l.sets).toContain('glimtarna');
      expect(l.sets).toContain(s);
    }
  });
  it('idempotent: samma set igen frigör inget', () => {
    const l = new SetLru(2);
    l.use('a');
    expect(l.use('a')).toEqual([]);
    expect(l.sets).toEqual(['a']);
  });
});
