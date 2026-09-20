import { describe, expect, it } from 'vitest';
import { findNearMiss, type NearMissItem } from '../../src/systems/nearmiss';
import { FEEL } from '../../src/data/juice';

const CFG = FEEL.nearMiss;
const out: number[] = [];

function item(level: number, x: number, y: number, r: number): NearMissItem {
  return { level, x, y, r };
}

describe('near-miss (DESIGN §5)', () => {
  it('flaggar två objekt av nivå ≥8 med gap under 20 px', () => {
    const items = [item(8, 100, 300, 74), item(8, 100 + 74 + 74 + 10, 300, 74)];
    findNearMiss(items, items.length, CFG, out);
    expect(out.sort()).toEqual([0, 1]);
  });

  it('ger aldrig falsk positiv när objekten nuddar', () => {
    const touching = [item(9, 100, 300, 85), item(9, 100 + 170, 300, 85)];
    findNearMiss(touching, touching.length, CFG, out);
    expect(out).toEqual([]);

    const overlapping = [item(9, 100, 300, 85), item(9, 100 + 168, 300, 85)];
    findNearMiss(overlapping, overlapping.length, CFG, out);
    expect(out).toEqual([]);
  });

  it('ignorerar för stora gap och för låga nivåer', () => {
    const far = [item(8, 100, 300, 74), item(8, 100 + 148 + 40, 300, 74)];
    findNearMiss(far, far.length, CFG, out);
    expect(out).toEqual([]);

    const low = [item(7, 100, 300, 64), item(7, 100 + 128 + 10, 300, 64)];
    findNearMiss(low, low.length, CFG, out);
    expect(out).toEqual([]);
  });

  it('ignorerar specialobjekt (level < 0) och respekterar count', () => {
    const items = [item(-1, 100, 300, 25), item(8, 100 + 25 + 74 + 8, 300, 74)];
    findNearMiss(items, items.length, CFG, out);
    expect(out).toEqual([]);

    const three = [
      item(8, 100, 300, 74),
      item(8, 100 + 148 + 10, 300, 74),
      item(8, 100, 300 + 148 + 10, 74),
    ];
    findNearMiss(three, 1, CFG, out);
    expect(out).toEqual([]);
    findNearMiss(three, 3, CFG, out);
    expect(new Set(out)).toEqual(new Set([0, 1, 2]));
  });

  it('återanvänder out-arrayen utan att allokera ny', () => {
    const items = [item(8, 100, 300, 74), item(8, 100 + 158, 300, 74)];
    const target: number[] = [];
    findNearMiss(items, items.length, CFG, target);
    const ref = target;
    findNearMiss(items, items.length, CFG, target);
    expect(target).toBe(ref);
    expect(target.length).toBe(2);
  });
});
