import { test, expect, type Page } from '@playwright/test';
import './hook';

const KEY = 'klunk.save.v1';

function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  return errors;
}

async function tap(page: Page, wx: number, wy: number): Promise<void> {
  const box = (await page.locator('canvas').boundingBox())!;
  await page.mouse.move(box.x + (wx * box.width) / 360, box.y + (wy * box.height) / 640);
  await page.mouse.down();
  await page.mouse.up();
}

async function startGame(page: Page): Promise<void> {
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(600);
  await tap(page, 180, 390);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
}

/** Från spelet till startskärmen utan omladdning (bakåt), så att shopMode ligger kvar. */
async function toStart(page: Page): Promise<void> {
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(400);
}

async function openFriends(page: Page): Promise<void> {
  await tap(page, 180, 506); // Kompisar-kortet
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  await page.evaluate(() => window.__book!.selectTab('friends'));
  await page.waitForTimeout(300);
}

function seedSave(page: Page, extra: Record<string, unknown> = {}): Promise<void> {
  return page.addInitScript(
    ([key, x]) => {
      if (localStorage.getItem(key)) return;
      localStorage.setItem(
        key,
        JSON.stringify({
          schema: 2,
          highscore: 500,
          bestLevel: 4,
          stats: { runs: 4, merges: 0 },
          settings: { bookHintSeen: true, friendsHintSeen: true },
          ...x,
        }),
      );
    },
    [KEY, extra] as const,
  );
}

const saved = (page: Page): Promise<{ schema: number; highscore: number; economy: { pearls: number; sand: number }; avatars: { owned: string[]; level: Record<string, number> } }> =>
  page.evaluate((k) => JSON.parse(localStorage.getItem(k)!), KEY);

test('(a) gammal sparfil utan schema raderas: ny start med schema 2', async ({ page }) => {
  const errors = collectErrors(page);
  await page.addInitScript((key) => {
    if (sessionStorage.getItem('seeded')) return;
    sessionStorage.setItem('seeded', '1');
    localStorage.setItem(key, JSON.stringify({ highscore: 900, bestLevel: 8, stats: { runs: 30, merges: 1500 }, avatars: { owned: ['lisa'], equipped: 'lisa' } }));
  }, KEY);
  await page.goto('/?test=1');
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });
  let d = await saved(page);
  expect(d.schema).toBe(2);
  expect(d.highscore).toBe(0);
  expect(d.avatars.owned).toEqual([]);
  // En gång: det som sparas därefter ligger kvar efter omladdning.
  await startGame(page);
  await page.evaluate(() => window.__game!.grantPearls(5));
  await page.reload();
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });
  d = await saved(page);
  expect(d.schema).toBe(2);
  expect(d.economy.pearls).toBe(5);
  expect(errors).toEqual([]);
});

test('(b–d) butik: köp i två tryck, silver räcker inte, uppgradering till II', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page, { avatars: { owned: ['common-1'], equipped: 'common-1' } });
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => window.__game!.grantPearls(300));
  await toStart(page);
  await openFriends(page);

  // (b) vanlig köpbar, silver/guld räcker inte.
  let shop = await page.evaluate(() => window.__book!.shop);
  expect(shop.slots.map((s) => s.state)).toEqual(['ok', 'poor', 'poor']);
  expect(shop.slots[0].price).toEqual({ pearls: 300 });
  await tap(page, 46, 116);
  shop = await page.evaluate(() => window.__book!.shop);
  expect(shop.awake).toBe('common');
  expect(shop.lastBuy).toBeNull();
  await page.waitForTimeout(350);
  await page.screenshot({ path: 'tests/e2e/screenshots/shop-awake.png' });
  await tap(page, 46, 116);
  shop = await page.evaluate(() => window.__book!.shop);
  const bought = shop.lastBuy!;
  expect(bought).not.toBeNull();
  expect(shop.pearls).toBe(0);
  let d = await saved(page);
  expect(d.avatars.owned).toContain(bought.avatarId);
  expect(d.economy.pearls).toBe(0);
  await page.waitForFunction(() => window.__book!.shop.openPhase === 'done', undefined, { timeout: 10_000 });
  await page.screenshot({ path: 'tests/e2e/screenshots/shop-open.png' });
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__book !== undefined && !window.__book.shop.opening && window.__book.tab === 'friends', undefined, { timeout: 5_000 });
  await page.waitForTimeout(500);

  // (c) silver räcker inte: grå, inget vaknar.
  shop = await page.evaluate(() => window.__book!.shop);
  expect(shop.slots.map((s) => s.state)).toEqual(['poor', 'poor', 'poor']);
  await tap(page, 160, 116);
  expect(await page.evaluate(() => window.__book!.shop.awake)).toBeNull();
  await page.waitForTimeout(400);
  await page.screenshot({ path: 'tests/e2e/screenshots/shop.png' });

  // (d) välj kompis: text och stapel syns, uppgradering räcker inte.
  const cell = await page.evaluate(() => window.__book!.cellOf('common-1'));
  await tap(page, cell!.x, cell!.y);
  let stage = await page.evaluate(() => window.__book!.stage)!;
  expect(stage!.id).toBe('common-1');
  expect(stage!.desc.length).toBeGreaterThan(5);
  expect(stage!.level).toBe(1);
  expect(stage!.button).toBe('poor');
  expect(stage!.cost).toEqual({ pearls: 80, sand: 0 });

  await tap(page, 320, 44);
  await startGame(page);
  await page.evaluate(() => window.__game!.grantPearls(80));
  await toStart(page);
  await openFriends(page);
  stage = await page.evaluate(() => window.__book!.stage);
  expect(stage!.button).toBe('ok');
  await tap(page, 224, 314);
  expect((await page.evaluate(() => window.__book!.stage))!.button).toBe('awake');
  await page.waitForTimeout(350);
  await tap(page, 224, 314);
  stage = await page.evaluate(() => window.__book!.stage);
  expect(stage!.level).toBe(2);
  expect(stage!.rombs).toBe(1);
  expect(stage!.cost).toEqual({ pearls: 200, sand: 4 });
  await page.waitForTimeout(700);
  await page.screenshot({ path: 'tests/e2e/screenshots/upgrade.png' });
  d = await saved(page);
  expect(d.avatars.level['common-1']).toBe(2);
  expect(d.economy.pearls).toBe(0);
  expect(errors).toEqual([]);
});

test('(e) rundavslutet räknar upp pärlor och sand', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => {
    const g = window.__game!;
    g.setPacing('off');
    g.clear();
    g.forceShiny(2);
    g.spawn(1, 180, 575);
    g.spawn(1, 184, 520);
  });
  await page.waitForFunction(() => window.__game!.collection.glimtarna.shiny[2] === true, undefined, { timeout: 5_000 });
  await page.evaluate(() => window.__game!.spawn(2, 176, 470));
  await page.waitForFunction(() => window.__game!.chainLit[3] === true, undefined, { timeout: 5_000 });
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal?.tally.done === true, undefined, { timeout: 10_000 });
  const tally = await page.evaluate(() => ({ ...window.__reveal!.tally, elapsed: window.__reveal!.elapsed }));
  // 2 merges ⇒ 2 pärlor. Skimrande: 1 sand + 3 för första skimrande.
  expect(tally).toMatchObject({ pearls: 2, sand: 4, rows: 2 });
  expect(tally.elapsed).toBeLessThan(2500 + 400);
  await page.screenshot({ path: 'tests/e2e/screenshots/reveal-economy.png' });
  expect(errors).toEqual([]);
});

test('(f) pick3: tre kandidater, samma efter stäng, val ger ägd', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page, { avatars: { owned: ['common-1'], equipped: 'common-1' } });
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => {
    window.__game!.grantPearls(300);
    window.__game!.setShopMode('pick3');
  });
  await toStart(page);
  await openFriends(page);
  await tap(page, 46, 116);
  await page.waitForTimeout(500);
  const offer = (await page.evaluate(() => window.__book!.shop.offer))!;
  expect(offer.length).toBe(3);
  expect(new Set(offer).size).toBe(3);
  await page.screenshot({ path: 'tests/e2e/screenshots/pick3.png' });
  // Stäng och öppna: samma tre (sparade).
  await tap(page, 320, 44);
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__book!.shop.offer)).toBeNull();
  await tap(page, 46, 116);
  await page.waitForTimeout(400);
  expect(await page.evaluate(() => window.__book!.shop.offer)).toEqual(offer);
  // Välj mittenkortet, sedan köpknappen.
  await tap(page, 180, 258);
  expect(await page.evaluate(() => window.__book!.shop.picked)).toBe(offer[1]);
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'tests/e2e/screenshots/pick3-picked.png' });
  await tap(page, 180, 448);
  await page.waitForFunction(() => window.__book!.shop.opening, undefined, { timeout: 5_000 });
  const d = await saved(page);
  expect(d.avatars.owned).toContain(offer[1]);
  expect(d.economy.pearls).toBe(0);
  expect((d.economy as unknown as { pick3Offer: Record<string, unknown> }).pick3Offer.common).toBeUndefined();
  expect(errors).toEqual([]);
});
