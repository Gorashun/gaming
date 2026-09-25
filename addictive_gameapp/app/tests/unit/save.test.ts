import { describe, expect, it } from 'vitest';
import { AVATARS } from '../../src/data/avatarsIndex';
import { SAVE_SCHEMA, cached, load, resetSave, save, setStorageAdapter } from '../../src/systems/save';

const KEY = 'klunk.save.v1';

function memAdapter(init?: unknown): { mem: Map<string, string>; log: string[] } {
  const mem = new Map<string, string>();
  const log: string[] = [];
  if (init !== undefined) mem.set(KEY, JSON.stringify(init));
  setStorageAdapter({
    get: async (k) => mem.get(k) ?? null,
    set: async (k, v) => {
      log.push('set');
      mem.set(k, v);
    },
    remove: async (k) => {
      log.push('remove');
      mem.delete(k);
    },
  });
  return { mem, log };
}

describe('schemaversion (DESIGN §16.5)', () => {
  it('sparfil utan schema raderas helt och ersätts av en ny fil med schema 2', async () => {
    const old = { highscore: 900, stats: { runs: 30, merges: 1500 }, avatars: { owned: [AVATARS[0].id] } };
    const { mem, log } = memAdapter(old);
    const d = await load();
    expect(log).toEqual(['remove', 'set']);
    expect(d.highscore).toBe(0);
    expect(d.stats.merges).toBe(0);
    expect(d.avatars.owned).toEqual([]);
    expect(d.schema).toBe(SAVE_SCHEMA);
    expect(JSON.parse(mem.get(KEY)!).schema).toBe(2);
    // En gång: nästa laddning raderar inget.
    await save({ highscore: 10 });
    log.length = 0;
    expect((await load()).highscore).toBe(10);
    expect(log).toEqual([]);
  });

  it('lägre schema raderas också', async () => {
    const { log } = memAdapter({ schema: 1, highscore: 5 });
    expect((await load()).highscore).toBe(0);
    expect(log[0]).toBe('remove');
  });

  it('schema 2 migreras normalt (nya fält får defaults, inget tappas)', async () => {
    const id = AVATARS[0].id;
    const { log } = memAdapter({ schema: 2, highscore: 700, stats: { merges: 40 }, avatars: { owned: [id], equipped: id } });
    const d = await load();
    expect(log).toEqual([]);
    expect(d.highscore).toBe(700);
    expect(d.stats.merges).toBe(40);
    expect(d.avatars.equipped).toBe(id);
    expect(d.economy.pearls).toBe(0);
    expect(d.economy.pick3Offer).toEqual({});
    expect(d.settings.sound).toBe(true);
  });

  it('nollställning ger ny fil med schema 2', async () => {
    const { mem } = memAdapter({ schema: 2, highscore: 700 });
    await load();
    await resetSave();
    expect(cached().highscore).toBe(0);
    expect(JSON.parse(mem.get(KEY)!).schema).toBe(2);
  });
});
