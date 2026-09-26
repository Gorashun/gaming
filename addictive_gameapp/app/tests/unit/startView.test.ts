import { describe, expect, it } from 'vitest';
import { startView, type StartSource } from '../../src/systems/startView';
import { nextSetCount } from '../../src/systems/unlocks';
import { emptyPage } from '../../src/systems/collection';

function src(over: Partial<StartSource> = {}, av: Partial<StartSource['avatars']> = {}): StartSource {
  return {
    activeSet: 'glimtarna',
    freshSet: null,
    unlockedSets: ['glimtarna'],
    collection: { glimtarna: emptyPage() },
    stats: { runs: 0, merges: 0 },
    ...over,
    avatars: { owned: [], fresh: [], pendingBoxes: 0, ...av },
  };
}

describe('startView (UI.md §16.6)', () => {
  it('Butik-badge bara när en gratismussla väntar', () => {
    expect(startView(src()).shop).toEqual({ pending: 0, badge: false });
    expect(startView(src({}, { pendingBoxes: 2 })).shop).toEqual({ pending: 2, badge: true });
  });

  it('kortens räknare: fångade i aktivt set / 21, ägda kompisar / 48', () => {
    const page = emptyPage();
    page.caught[0] = page.caught[1] = page.caught[2] = true;
    page.shiny[2] = true;
    const v = startView(src({ collection: { glimtarna: page } }, { owned: ['lisa', 'siri'] }));
    expect(v.book).toMatchObject({ n: 4, m: 21 });
    expect(v.buddies).toMatchObject({ n: 2, m: 48 });
  });

  it('Bok-badge vid nytt set eller ny plats, Kompisar-badge vid ny kompis', () => {
    expect(startView(src()).book.badge).toBe(false);
    expect(startView(src({ freshSet: 'gloden' })).book.badge).toBe(true);
    const page = emptyPage();
    page.fresh[3] = true;
    expect(startView(src({ collection: { glimtarna: page } })).book.badge).toBe(true);
    expect(startView(src()).buddies.badge).toBe(false);
    expect(startView(src({}, { owned: ['lisa'], fresh: ['lisa'] })).buddies.badge).toBe(true);
  });

  it('ny spelare = inga rundor', () => {
    expect(startView(src()).newPlayer).toBe(true);
    expect(startView(src({ stats: { runs: 1, merges: 5 } })).newPlayer).toBe(false);
  });

  it('set-stapeln: 0 / 200 för ny spelare, 412 / 600 med två set, null när allt är upplåst', () => {
    expect(startView(src()).setBar).toEqual({ n: 0, m: 200, v: 0 });
    const two = startView(src({ unlockedSets: ['glimtarna', 'gloden'], stats: { runs: 9, merges: 412 } })).setBar!;
    expect([two.n, two.m]).toEqual([412, 600]);
    expect(two.v).toBeCloseTo((412 - 200) / 400);
    expect(nextSetCount(9999, 5)).toBeNull();
    expect(nextSetCount(700, 2)).toEqual({ n: 600, m: 600 });
  });
});
