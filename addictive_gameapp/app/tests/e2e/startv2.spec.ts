import { test, expect, type Page } from '@playwright/test';
import './hook';

/** Start v2 (UI.md §16, DESIGN §18): knappar, inställningsark, badge, etiketter, skärmdumpar. */

// Logiska mått (360×640): SPELA, korten (Bok, Kompisar, Butik), kugghjulet, arkets stäng och rader.
const PLAY = [180, 390] as const;
const BOOK = [66.5, 506] as const;
const BUDDIES = [180, 506] as const;
const SHOP = [293.5, 506] as const;
const GEAR = [320, 36] as const;
const CLOSE = [320, 342] as const;
const ROWS = [404, 468, 532, 596] as const;

function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  return errors;
}

async function toCanvas(page: Page, wx: number, wy: number): Promise<{ x: number; y: number }> {
  const box = (await page.locator('canvas').boundingBox())!;
  return { x: box.x + (wx * box.width) / 360, y: box.y + (wy * box.height) / 640 };
}

async function tap(page: Page, [wx, wy]: readonly [number, number]): Promise<void> {
  const p = await toCanvas(page, wx, wy);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.mouse.up();
}

/** Rekord 2 480, två set, 8 / 21 i boken, Siri vald (Lisa satte rekordet), 5 kompisar. */
const BASE = {
  schema: 2,
  highscore: 2480,
  bestLevel: 5,
  stats: { runs: 9, merges: 412 },
  unlockedSets: ['glimtarna', 'gloden'],
  collection: { glimtarna: { caught: [true, true, true, true, true, true, true, true] } },
  economy: { pearls: 1240, sand: 18 },
  avatars: { owned: ['lisa', 'siri', 'maja', 'vala', 'muller'], equipped: 'siri' },
  highscoreAvatar: 'lisa',
  settings: { bookHintSeen: true, friendsHintSeen: true },
};

function seed(page: Page, extra: Record<string, unknown> = {}): Promise<void> {
  return page.addInitScript((x) => {
    if (localStorage.getItem('klunk.save.v1')) return;
    localStorage.setItem('klunk.save.v1', JSON.stringify(x));
  }, { ...BASE, ...extra });
}

async function open(page: Page, query = ''): Promise<void> {
  await page.goto(`/?test=1${query}`);
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 20_000 });
  await page.waitForTimeout(1200);
}

const saved = (page: Page): Promise<{ settings: Record<string, boolean>; avatars: { pendingBoxes: number } }> =>
  page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!));

test('(a) SPELA startar spelet; tomma ytor och hjälten gör det inte', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page);
  await open(page);
  // Hjälten (leksak), rekordchippet och bakgrunden startar inte en runda.
  await tap(page, [180, 230]);
  await tap(page, [180, 312]);
  await tap(page, [30, 300]);
  await page.waitForTimeout(400);
  expect(await page.evaluate(() => window.__game === undefined)).toBe(true);
  await tap(page, PLAY);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(a) Bok → Set även med nya kompisar; Kompisar → Kompisar', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, { avatars: { ...BASE.avatars, fresh: ['maja'] } });
  await open(page);
  await tap(page, BOOK);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
  expect(await page.evaluate(() => window.__book!.tab)).toBe('sets');
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__book === undefined && window.__start !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(300);
  await tap(page, BUDDIES);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
  expect(await page.evaluate(() => window.__book!.tab)).toBe('friends');
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(a) Butik utan mussla → Kompisar med butikshyllan överst (scroll 0)', async ({ page }) => {
  const errors = collectErrors(page);
  // Vald kompis långt ned i rutnätet: Kompisar-kortet scrollar dit, Butik gör det inte.
  await seed(page, { avatars: { ...BASE.avatars, equipped: 'vala' } });
  await open(page);
  expect(await page.evaluate(() => window.__start!.shopBadge)).toBe(false);
  await tap(page, BUDDIES);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
  expect(await page.evaluate(() => window.__book!.scroll)).toBeGreaterThan(0);
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__book === undefined && window.__start !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(300);
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
  expect(await page.evaluate(() => window.__book!.tab)).toBe('friends');
  expect(await page.evaluate(() => window.__book!.scroll)).toBe(0);
  expect(await page.evaluate(() => window.__book!.shop.slots.length)).toBe(3);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(a, c) Butik med väntande mussla: badge, öppning på startskärmen, sedan ingen badge', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, { avatars: { ...BASE.avatars, pendingBoxes: 2 } });
  await open(page, '&lang=sv');
  expect(await page.evaluate(() => window.__start!.shopBadge)).toBe(true);
  expect(await page.evaluate(() => window.__start!.labels.shopSub)).toBe('Gratis!');
  await page.screenshot({ path: 'tests/e2e/screenshots/start-v2-badge.png' });
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__start?.opening === true, undefined, { timeout: 10_000 });
  expect(await page.evaluate(() => window.__book === undefined)).toBe(true);
  expect((await saved(page)).avatars.pendingBoxes).toBe(1);
  await page.waitForFunction(() => window.__start?.openPhase === 'done', undefined, { timeout: 10_000 });
  await tap(page, PLAY); // stänger öppningen, startar inte spelet
  await page.waitForFunction(() => window.__start !== undefined && !window.__start.opening, undefined, { timeout: 10_000 });
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__game === undefined)).toBe(true);
  // En kvar: badgen finns kvar; öppna den också, sedan ingen badge.
  expect(await page.evaluate(() => window.__start!.shopBadge)).toBe(true);
  await tap(page, SHOP);
  await page.waitForFunction(() => window.__start?.openPhase === 'done', undefined, { timeout: 10_000 });
  await tap(page, PLAY);
  await page.waitForFunction(() => window.__start !== undefined && !window.__start.opening, undefined, { timeout: 10_000 });
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__start!.shopBadge)).toBe(false);
  expect(await page.evaluate(() => window.__start!.labels.shopSub)).toBe('Musslor');
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(c) ingen badge för "har råd": många pärlor utan väntande mussla', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, { economy: { pearls: 5000, sand: 50 } });
  await open(page);
  expect(await page.evaluate(() => window.__start!.badges)).toEqual({ book: false, buddies: false, shop: false });
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(b) inställningsarket: switchar sparas, stängs med X, Escape, scrim och svep', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page);
  await open(page);
  await tap(page, GEAR);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'tests/e2e/screenshots/start-v2-settings.png' });
  for (const y of ROWS) {
    await tap(page, [180, y]);
    await page.waitForTimeout(150);
  }
  expect((await saved(page)).settings).toMatchObject({ sound: false, haptics: false, calm: true, aimLine: false });
  // X stänger.
  await tap(page, CLOSE);
  await page.waitForFunction(() => window.__start?.sheetOpen === false, undefined, { timeout: 5_000 });
  // Escape (bakåtknappens fallback) stänger, och stänger inte appen/scenen.
  await tap(page, GEAR);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__start?.sheetOpen === false, undefined, { timeout: 5_000 });
  // Tryck på scrimmen ovanför arket stänger.
  await tap(page, GEAR);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.waitForTimeout(300);
  await tap(page, [180, 200]);
  await page.waitForFunction(() => window.__start?.sheetOpen === false, undefined, { timeout: 5_000 });
  // Svep nedåt på arket stänger utan att växla någon rad.
  await tap(page, GEAR);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.waitForTimeout(300);
  const a = await toCanvas(page, 180, 420);
  const b = await toCanvas(page, 180, 560);
  await page.mouse.move(a.x, a.y);
  await page.mouse.down();
  await page.mouse.move(b.x, b.y, { steps: 5 });
  await page.mouse.up();
  await page.waitForFunction(() => window.__start?.sheetOpen === false, undefined, { timeout: 5_000 });
  expect((await saved(page)).settings).toMatchObject({ sound: false, haptics: false, calm: true, aimLine: false });
  // Inställningarna överlever omladdning; arket visar dem.
  await page.reload();
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 20_000 });
  expect((await saved(page)).settings).toMatchObject({ sound: false, haptics: false, calm: true, aimLine: false });
  expect(await page.evaluate(() => window.__game === undefined)).toBe(true);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(d, e) etiketter på engelska och svenska, skärmdumpar 390×844', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page);
  await open(page, '&lang=en');
  expect(await page.evaluate(() => window.__start!.labels)).toEqual({
    play: 'PLAY',
    book: 'Book',
    bookSub: '8 / 21',
    buddies: 'Buddies',
    buddiesSub: '5 / 48',
    shop: 'Shop',
    shopSub: 'Shells',
    setBar: '412 / 600 to next set',
  });
  await page.screenshot({ path: 'tests/e2e/screenshots/start-v2.png' });
  await open(page, '&lang=sv');
  expect(await page.evaluate(() => window.__start!.labels)).toEqual({
    play: 'SPELA',
    book: 'Bok',
    bookSub: '8 / 21',
    buddies: 'Kompisar',
    buddiesSub: '5 / 48',
    shop: 'Butik',
    shopSub: 'Musslor',
    setBar: '412 / 600 till nästa set',
  });
  await page.screenshot({ path: 'tests/e2e/screenshots/start-v2-sv.png' });
  expect(errors, errors.join('\n')).toEqual([]);
});

test.describe('DPR 2', () => {
  test.use({ deviceScaleFactor: 2 });

  test('(e) skärmdump i DPR 2, SPELA fungerar', async ({ page }) => {
    const errors = collectErrors(page);
    await seed(page);
    await open(page, '&lang=en');
    expect(await page.evaluate(() => document.querySelector('canvas')!.width)).toBe(720);
    await page.screenshot({ path: 'tests/e2e/screenshots/start-v2-dpr2.png' });
    await tap(page, PLAY);
    await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 20_000 });
    expect(errors, errors.join('\n')).toEqual([]);
  });
});
