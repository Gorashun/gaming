import { describe, expect, it } from 'vitest';
import { resolveMerges } from '../../src/systems/merge';

describe('resolveMerges', () => {
  it('mergear två bodies med samma nivå', () => {
    expect(resolveMerges([{ a: 1, b: 2, levelA: 3, levelB: 3 }])).toEqual([
      { a: 1, b: 2, level: 3 },
    ]);
  });

  it('mergear inte olika nivåer', () => {
    expect(resolveMerges([{ a: 1, b: 2, levelA: 3, levelB: 4 }])).toEqual([]);
  });

  it('låter aldrig en body ingå i två par samma frame', () => {
    const out = resolveMerges([
      { a: 1, b: 2, levelA: 0, levelB: 0 },
      { a: 2, b: 3, levelA: 0, levelB: 0 },
      { a: 3, b: 4, levelA: 0, levelB: 0 },
    ]);
    expect(out).toEqual([
      { a: 1, b: 2, level: 0 },
      { a: 3, b: 4, level: 0 },
    ]);
  });

  it('ignorerar en body mot sig själv', () => {
    expect(resolveMerges([{ a: 7, b: 7, levelA: 2, levelB: 2 }])).toEqual([]);
  });

  it('hanterar tom lista', () => {
    expect(resolveMerges([])).toEqual([]);
  });
});
