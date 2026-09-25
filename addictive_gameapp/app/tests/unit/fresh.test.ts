import { describe, expect, it } from 'vitest';
import { AVATARS } from '../../src/data/avatarsIndex';
import { emptyPage, markPageSeen, slotIndex } from '../../src/systems/collection';
import { defaultAvatars, markFriendsSeen, normalizeAvatars } from '../../src/systems/avatars';
import { openBox } from '../../src/systems/boxes';
import { mulberry32 } from '../../src/systems/rng';
import { load, mergeWithDefaults, save, setStorageAdapter } from '../../src/systems/save';

describe('freshSet: nytt set är nytt tills sidan visats i boken (DESIGN §13.4, §13.6)', () => {
  it('bara det visade setets sida nollställer freshSet och sidans platser', () => {
    const d = mergeWithDefaults({ unlockedSets: ['glimtarna', 'gloden'], freshSet: 'gloden' });
    d.collection.glimtarna.fresh[slotIndex(3, false)] = true;
    // Grundsetets sida visas: dess platser nollställs, det nya setet ligger kvar som nytt.
    expect(markPageSeen(d, 'glimtarna')).toBe(true);
    expect(d.collection.glimtarna.fresh.some(Boolean)).toBe(false);
    expect(d.freshSet).toBe('gloden');
    // Det nya setets sida visas: freshSet nollställs.
    expect(markPageSeen(d, 'gloden')).toBe(true);
    expect(d.freshSet).toBeNull();
    // Inget kvar: ingen ändring (ingen onödig skrivning).
    expect(markPageSeen(d, 'gloden')).toBe(false);
  });

  it('freshSet överlever en omladdning (rundavslutet nollställer det inte)', () => {
    const d = mergeWithDefaults(JSON.parse(JSON.stringify({ unlockedSets: ['glimtarna', 'frostisarna'], freshSet: 'frostisarna' })));
    expect(d.freshSet).toBe('frostisarna');
    expect(markPageSeen({ collection: { x: emptyPage() }, freshSet: null }, 'x')).toBe(false);
  });
});

describe('avatars.fresh: nyöppnade kompisar (UI.md §13.4)', () => {
  it('öppnad mussla markeras som ny, en gång per kompis', () => {
    const s = defaultAvatars();
    expect(s.fresh).toEqual([]);
    const a = openBox(s, mulberry32(3))!;
    const b = openBox(s, mulberry32(4))!;
    expect(s.fresh).toEqual([a.avatarId, b.avatarId]);
  });

  it('fliken visad i 2 s tömmer listan; tom lista ger ingen ändring', () => {
    const s = defaultAvatars();
    openBox(s, mulberry32(5));
    expect(markFriendsSeen(s)).toBe(true);
    expect(s.fresh).toEqual([]);
    expect(markFriendsSeen(s)).toBe(false);
  });

  it('sparfil: bara ägda, inga dubbletter; gamla sparfiler får []', () => {
    const id = AVATARS[3].id;
    const n = normalizeAvatars({ owned: [id], fresh: [id, id, AVATARS[4].id, 'okänd', 7] });
    expect(n.fresh).toEqual([id]);
    expect(mergeWithDefaults({ highscore: 1 }).avatars.fresh).toEqual([]);
  });
});

describe('settings.bookHintSeen / friendsHintSeen', () => {
  it('default false, gamla sparfiler får false, true sparas och läses tillbaka', async () => {
    expect(mergeWithDefaults({}).settings.bookHintSeen).toBe(false);
    const old = mergeWithDefaults(JSON.parse(JSON.stringify({ settings: { sound: false, haptics: true, calm: false } })));
    expect(old.settings).toMatchObject({ sound: false, bookHintSeen: false, friendsHintSeen: false });

    const mem = new Map<string, string>();
    setStorageAdapter({
      get: async (k) => mem.get(k) ?? null,
      set: async (k, v) => void mem.set(k, v),
    });
    await save({ settings: { bookHintSeen: true } });
    const back = await load();
    expect(back.settings.bookHintSeen).toBe(true);
    expect(back.settings.friendsHintSeen).toBe(false);
    expect(back.settings.sound).toBe(true);
  });
});
