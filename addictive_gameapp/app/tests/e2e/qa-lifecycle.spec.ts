import { test, expect, type Page } from '@playwright/test';
import {
  BOOK,
  BUDDIES,
  GEAR,
  KEY,
  PLAY,
  SHOP,
  SHOP_SLOTS,
  SHOTS,
  checkInvariants,
  knownBug,
  collectErrors,
  drag,
  expectNoErrors,
  goldish,
  open,
  pixels,
  saved,
  seed,
  startRound,
  tap,
  waitStart,
} from './qa-util';

/** QA-utforskning: omladdning, bakgrund, migrering och bakåtknappen i alla lägen. */

const RETURNING = {
  schema: 2,
  highscore: 40,
  bestLevel: 4,
  stats: { runs: 5, merges: 100, maxLevelEver: 4 },
  economy: { pearls: 400, sand: 5, mergesBaseline: 0, freeShellsClaimed: 0 },
  settings: { bookHintSeen: true, friendsHintSeen: true },
};

async function dropsByHand(page: Page, n: number): Promise<void> {
  let x = 180;
  for (let i = 0; i < n; i++) {
    const to = 70 + ((i * 53) % 220);
    await drag(page, x, to, 300);
    x = to;
    await page.waitForTimeout(620);
  }
}

/** Låtsas att appen läggs i bakgrunden (och tas fram igen). Phaser läser `hidden`, spelet `visibilityState`. */
async function setHidden(page: Page, hidden: boolean): Promise<void> {
  await page.evaluate((h) => {
    if (h) {
      Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'hidden' });
      Object.defineProperty(document, 'hidden', { configurable: true, get: () => true });
    } else {
      delete (document as unknown as Record<string, unknown>).visibilityState;
      delete (document as unknown as Record<string, unknown>).hidden;
    }
    document.dispatchEvent(new Event('visibilitychange'));
  }, hidden);
}

test('(QA) omladdning mitt i rundan: pärlor, merges och rekord tappas inte', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, RETURNING);
  await open(page, '&lang=en');
  await startRound(page);
  await page.evaluate(() => window.__game!.seed(7)); // startar om rundan (runs +1 till)
  await page.waitForTimeout(300);
  const base = await saved(page);
  await dropsByHand(page, 18);
  const score = await page.evaluate(() => window.__game!.score);
  await page.reload();
  await waitStart(page);
  const s = await saved(page);
  const merges = s.stats.merges - RETURNING.stats.merges;
  expect(s.stats.runs).toBe(base.stats.runs);
  expect(merges).toBeGreaterThan(0);
  expect(s.economy.pearls - RETURNING.economy.pearls).toBe(merges);
  expect(s.highscore).toBe(Math.max(RETURNING.highscore, score));
  checkInvariants(s);
  expectNoErrors(errors);
});

test('(QA) omladdning mitt i rundavslutet: allt som visas är redan sparat, inget betalas två gånger', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, { ...RETURNING, stats: { runs: 5, merges: 110, maxLevelEver: 4 } });
  await open(page, '&lang=en');
  await startRound(page);
  await dropsByHand(page, 8);
  await page.evaluate(() => window.__game!.grantMerges(15)); // passerar 120: en gratismussla
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(250);
  const atReveal = await saved(page);
  expect(atReveal.avatars.pendingBoxes).toBe(1);
  await page.reload();
  await waitStart(page);
  const s = await saved(page);
  expect(s.economy).toEqual(atReveal.economy);
  expect(s.stats.merges).toBe(atReveal.stats.merges);
  expect(s.avatars.pendingBoxes).toBe(1);
  expect(await page.evaluate(() => window.__start!.shopBadge)).toBe(true);
  checkInvariants(s);
  expectNoErrors(errors);
});

test('(QA) omladdning mitt i musslans öppning (start och butik): figuren ägs, inget dras om, betalt en gång', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, { ...RETURNING, economy: { ...RETURNING.economy, pearls: 1000 }, avatars: { pendingBoxes: 1 } });
  await open(page, '&lang=en');
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__start?.opening === true, undefined, { timeout: 10_000 });
  await page.waitForTimeout(300);
  const id = await page.evaluate(() => window.__start!.lastBox!.avatarId);
  await page.reload();
  await waitStart(page);
  let s = await saved(page);
  expect(s.avatars.owned).toEqual([id]);
  expect(s.avatars.pendingBoxes).toBe(0);
  expect(s.avatars.equipped).toBe(id); // första musslan väljs automatiskt
  expect(await page.evaluate(() => window.__start!.badges)).toMatchObject({ buddies: true, shop: false });

  // Butiken: två tryck på vanlig mussla, ladda om mitt i ceremonin.
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__book?.tab === 'friends', undefined, { timeout: 10_000 });
  await page.waitForTimeout(500);
  await tap(page, SHOP_SLOTS.common);
  await page.waitForTimeout(400);
  await tap(page, SHOP_SLOTS.common);
  await page.waitForFunction(() => window.__book?.shop.opening === true, undefined, { timeout: 10_000 });
  const bought = await page.evaluate(() => window.__book!.shop.lastBuy!.avatarId);
  await page.reload();
  await waitStart(page);
  s = await saved(page);
  expect(s.economy.pearls).toBe(700);
  expect(s.avatars.owned).toEqual([id, bought]);
  checkInvariants(s);
  expectNoErrors(errors);
});

test('(QA) bakgrund mitt i rundan: bankat en gång, spelet går vidare, rekordringen syns ändå', async ({ page }) => {
  knownBug('BUG-002', 'submitRun vid visibilitychange skriver rekordet, så förlustskärmen tror att det inte är nytt');
  const errors = collectErrors(page);
  await seed(page, { ...RETURNING, highscore: 3 });
  await open(page, '&lang=en');
  await startRound(page);
  await dropsByHand(page, 4);
  // Deterministiskt: tom burk, en merge (nivå 2 + 2 → 3 = 10 p), inga fler rörelser efter bakgrunden.
  await page.evaluate(() => {
    window.__game!.setPacing('off');
    window.__game!.clear();
    window.__game!.spawn(2, 180, 575);
    window.__game!.spawn(2, 184, 520);
  });
  await page.waitForTimeout(1500);
  const scoreA = await page.evaluate(() => window.__game!.score);
  expect(scoreA).toBeGreaterThan(3);
  await setHidden(page, true);
  await page.waitForTimeout(300);
  const mid = await saved(page);
  await setHidden(page, false);
  await page.waitForTimeout(500);
  // Bankat direkt vid bakgrund: pärlor = merges hittills.
  expect(mid.economy.pearls - RETURNING.economy.pearls).toBe(mid.stats.merges - RETURNING.stats.merges);
  expect(await page.evaluate(() => window.__game!.over)).toBe(false);
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(900);
  const s = await saved(page);
  expect(s.economy.pearls - RETURNING.economy.pearls).toBe(s.stats.merges - RETURNING.stats.merges);
  checkInvariants(s);
  await page.screenshot({ path: `${SHOTS}/lifecycle-record-after-hide.png` });
  // Rundan slog rekordet 3: förlustskärmens guldring (r 110 runt (180, 220)) ska synas.
  const ring = await pixels(page, [[180, 110], [180, 330], [70, 220], [290, 220], [102, 142], [258, 298]]);
  expect(ring.filter(goldish).length, JSON.stringify(ring)).toBeGreaterThanOrEqual(2);
  expectNoErrors(errors);
});

test('(QA) bakgrund i rundavslut, bok och start: inga fel, ingenting ändras', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, RETURNING);
  await open(page, '&lang=en');
  for (const where of ['start', 'book']) {
    if (where === 'book') {
      await tap(page, BOOK);
      await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
    }
    const a = await saved(page);
    await setHidden(page, true);
    await page.waitForTimeout(200);
    await setHidden(page, false);
    await page.waitForTimeout(300);
    expect((await saved(page)).economy).toEqual(a.economy);
  }
  await page.keyboard.press('Escape');
  await waitStart(page);
  await startRound(page);
  await dropsByHand(page, 4);
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 10_000 });
  const a = await saved(page);
  await setHidden(page, true);
  await page.waitForTimeout(200);
  await setHidden(page, false);
  await page.waitForTimeout(300);
  expect((await saved(page)).economy).toEqual(a.economy);
  await tap(page, [180, 560]);
  await page.waitForFunction(() => window.__game !== undefined && !window.__game.over, undefined, { timeout: 10_000 });
  expectNoErrors(errors);
});

test('(QA) migrering: schema 1 raderas; schema 2 med delvisa fält laddar och går att spela', async ({ page }) => {
  const errors = collectErrors(page);
  // Schema 1 med mycket framsteg: raderas helt (DESIGN §16.5).
  await page.addInitScript((k) => {
    if (sessionStorage.getItem('qa-step')) return;
    sessionStorage.setItem('qa-step', '1');
    localStorage.setItem(
      k,
      JSON.stringify({
        schema: 1,
        highscore: 9999,
        bestLevel: 9,
        stats: { runs: 80, merges: 5000 },
        avatars: { owned: ['lisa', 'siri'], equipped: 'lisa', xp: { lisa: 500 } },
        unlockedSets: ['glimtarna', 'gloden'],
      }),
    );
  }, KEY);
  await open(page, '&lang=en');
  let s = await saved(page);
  expect(s.schema).toBe(2);
  expect(s.highscore).toBe(0);
  expect(s.avatars.owned).toEqual([]);
  expect(s.unlockedSets).toEqual(['glimtarna']);
  expect(await page.evaluate(() => window.__start!.labels)).toMatchObject({ bookSub: '1 / 21', buddiesSub: '0 / 48', setBar: '0 / 200 to next set' });

  // Schema 2, testversion 7-fil med bara vissa fält.
  const partials: Record<string, unknown>[] = [
    { schema: 2, highscore: 500 },
    { schema: 2, economy: { pearls: 50 }, stats: { runs: 3 } },
    { schema: 2, avatars: { owned: ['lisa', 'lisa', 'nobody'], equipped: 'nobody', level: { lisa: 7 } } },
    { schema: 2, settings: { sound: false }, activeSet: 'gloden', unlockedSets: ['glimtarna'] },
    { schema: 2, collection: { glimtarna: { caught: [true, true] } }, freshSet: 'planeterna' },
  ];
  for (const p of partials) {
    await page.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)), [KEY, p] as const);
    await page.reload();
    await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 20_000 });
    await page.waitForTimeout(500);
    const labels = await page.evaluate(() => window.__start!.labels);
    for (const v of Object.values(labels)) expect(v, JSON.stringify(p)).not.toMatch(/NaN|undefined|null/);
    await startRound(page);
    await dropsByHand(page, 2);
    await page.evaluate(() => window.__game!.forceLoss());
    await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 10_000 });
    await page.keyboard.press('Escape');
    await waitStart(page);
    s = await saved(page);
    checkInvariants(s);
    expect(s.schema).toBe(2);
  }
  expect(s.activeSet).toBe('glimtarna');
  expectNoErrors(errors);
});

test('(QA) schema 2 med trasiga typer (sträng/negativt): inga NaN på skärmen eller i sparfilen', async ({ page }) => {
  knownBug('BUG-003', 'bestLevel utanför 0–10 kraschar Start (svart skärm); highscore/stats normaliseras inte');
  const errors = collectErrors(page);
  await seed(page, { schema: 2, highscore: 'abc', bestLevel: -3, stats: { runs: 'x', merges: -50 } });
  await open(page, '&lang=en');
  await page.screenshot({ path: `${SHOTS}/lifecycle-corrupt-types.png` });
  await startRound(page);
  await dropsByHand(page, 3);
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 10_000 });
  await page.keyboard.press('Escape');
  await waitStart(page);
  const s = await saved(page);
  expect(typeof s.highscore).toBe('number');
  expect(Number.isFinite(s.highscore)).toBe(true);
  expect(s.stats.merges).toBeGreaterThanOrEqual(0);
  expect(Number.isFinite(s.stats.runs)).toBe(true);
  expectNoErrors(errors);
});

test('(QA) bakåt (Escape) överallt, även dubbeltryck', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, { ...RETURNING, avatars: { owned: ['lisa', 'siri'], equipped: 'lisa', pendingBoxes: 1 } });
  await open(page, '&lang=en');
  const esc2 = async (): Promise<void> => {
    await page.keyboard.press('Escape');
    await page.keyboard.press('Escape');
  };
  // Start utan lager: ingenting händer.
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__start !== undefined)).toBe(true);
  // Arket.
  await tap(page, GEAR);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await esc2();
  await page.waitForFunction(() => window.__start?.sheetOpen === false, undefined, { timeout: 5_000 });
  expect(await page.evaluate(() => window.__start !== undefined)).toBe(true);
  // Öppningen på startskärmen.
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__start?.opening === true, undefined, { timeout: 10_000 });
  await page.keyboard.press('Escape');
  // Bakåt hoppar över och stänger (stängningsanimationen, sedan startar scenen om).
  await page.waitForFunction(() => window.__start?.opening === false, undefined, { timeout: 10_000 });
  await waitStart(page);
  // Boken: Set, Kompisar, Butik.
  for (const entry of [BOOK, BUDDIES, SHOP]) {
    await tap(page, entry);
    await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
    await page.waitForTimeout(400);
    await esc2();
    await waitStart(page);
  }
  // Vaken mussla i butiken: bakåt stänger boken (inget köp).
  const pearls = (await saved(page)).economy.pearls;
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(400);
  await tap(page, SHOP_SLOTS.common);
  await page.waitForTimeout(350);
  await page.keyboard.press('Escape');
  await waitStart(page);
  expect((await saved(page)).economy.pearls).toBe(pearls);
  // Mitt i rundan: rundan avslutas som förlust och sparas.
  await startRound(page);
  await dropsByHand(page, 3);
  await esc2();
  await waitStart(page);
  const s = await saved(page);
  expect(s.debug.runs[s.debug.runs.length - 1].ended).toBe('quit');
  // Förlustskärmen.
  await startRound(page);
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 10_000 });
  await esc2();
  await waitStart(page);
  await page.waitForTimeout(500);
  expect(await page.evaluate(() => window.__game === undefined)).toBe(true);
  await tap(page, PLAY);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  checkInvariants(await saved(page));
  expectNoErrors(errors);
});
