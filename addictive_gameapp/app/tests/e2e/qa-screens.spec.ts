import { test, expect, type Page } from '@playwright/test';
import {
  BOOK,
  BOOK_CLOSE,
  BUDDIES,
  GEAR,
  PLAY,
  SHEET_CLOSE,
  SHEET_ROWS,
  SHOP,
  SHOTS,
  TAB_FRIENDS,
  TAB_SETS,
  collectErrors,
  drag,
  knownBug,
  tapUntil,
  expectNoErrors,
  open,
  saved,
  seed,
  startRound,
  tap,
  toCanvas,
  waitStart,
} from './qa-util';

/** QA-utforskning: språk, inställningar, set, bokens in- och utgångar och träffytor mot det som syns. */
test.use({ deviceScaleFactor: 2 });

const SETS = ['glimtarna', 'planeterna', 'frostisarna', 'godisarna', 'gloden'];
const RICH = {
  schema: 2,
  highscore: 12480,
  bestLevel: 8,
  stats: { runs: 40, merges: 2400, maxLevelEver: 8 },
  unlockedSets: SETS,
  economy: { pearls: 12345, sand: 88, mergesBaseline: 2400 },
  avatars: { owned: ['lisa', 'siri', 'maja', 'vala', 'muller', 'havsdrottningen'], equipped: 'havsdrottningen', level: { havsdrottningen: 3 } },
  highscoreAvatar: 'lisa',
  settings: { bookHintSeen: true, friendsHintSeen: true },
};

const labels = (page: Page): Promise<Record<string, string>> => page.evaluate(() => window.__start!.labels);

test.describe('enhetens språk är svenska', () => {
  test.use({ locale: 'sv-SE' });

  test('(QA) svensk enhet utan ?lang: allt på engelska (beslut 2026-09-26); ?lang=sv ger svenska', async ({ page }) => {
    const errors = collectErrors(page);
    await seed(page, RICH);
    await open(page);
    expect(await page.evaluate(() => navigator.language)).toBe('sv-SE');
    expect(await labels(page)).toMatchObject({ play: 'PLAY', book: 'Book', buddies: 'Buddies', shop: 'Shop', shopSub: 'Shells' });
    await page.screenshot({ path: `${SHOTS}/screens-device-sv-default.png` });
    await tap(page, BUDDIES);
    await page.waitForFunction(() => window.__book?.stage !== undefined, undefined, { timeout: 10_000 });
    await page.waitForTimeout(600);
    const stage = await page.evaluate(() => window.__book!.stage!);
    expect(stage.name).toBe('The Sea Queen');
    await page.screenshot({ path: `${SHOTS}/screens-device-sv-book.png` });
    await page.keyboard.press('Escape');
    await waitStart(page);
    await open(page, '&lang=sv');
    expect(await labels(page)).toMatchObject({ play: 'SPELA', book: 'Bok', buddies: 'Kompisar', shop: 'Butik', shopSub: 'Musslor' });
    await tap(page, BUDDIES);
    await page.waitForFunction(() => window.__book?.stage !== undefined, undefined, { timeout: 10_000 });
    await page.waitForTimeout(600);
    expect(await page.evaluate(() => window.__book!.stage!.name)).toBe('Havsdrottningen');
    expectNoErrors(errors);
  });
});

test('(QA) EN och SV: start, ark, bok (set + kompisar + butik), öppning: skärmdumpar för textgranskning', async ({ page }) => {
  test.setTimeout(120_000);
  const errors = collectErrors(page);
  await seed(page, { ...RICH, avatars: { ...RICH.avatars, pendingBoxes: 1 } });
  for (const lang of ['en', 'sv']) {
    await open(page, `&lang=${lang}`);
    await page.screenshot({ path: `${SHOTS}/screens-${lang}-start.png` });
    await tap(page, GEAR);
    await page.waitForFunction(() => window.__start?.sheetOpen === true);
    await page.waitForTimeout(500);
    await page.screenshot({ path: `${SHOTS}/screens-${lang}-sheet.png` });
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => window.__start?.sheetOpen === false);
    await tap(page, BOOK);
    await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${SHOTS}/screens-${lang}-book-sets.png` });
    await tapUntil(page, TAB_FRIENDS, () => window.__book!.tab === 'friends');
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${SHOTS}/screens-${lang}-book-friends.png` });
    // Kompisen med längst namn/text i ägda: gå igenom alla ägda och ta en bild per kompis.
    for (const id of ['vala', 'muller', 'maja']) {
      await page.evaluate((x) => window.__book!.equip(x), id);
      await page.waitForTimeout(400);
      await page.screenshot({ path: `${SHOTS}/screens-${lang}-stage-${id}.png` });
      const st = await page.evaluate(() => window.__book!.stage!);
      expect(st.desc.length, `${id} ${lang}`).toBeLessThanOrEqual(60);
    }
    await page.keyboard.press('Escape');
    await waitStart(page);
  }
  expectNoErrors(errors);
});

test('(QA) bokens alla ingångar och utgångar: kort ×3, X, svep ned, Escape, flikbyte', async ({ page }) => {
  test.setTimeout(120_000);
  const errors = collectErrors(page);
  await seed(page, RICH);
  await open(page, '&lang=en');
  const entries: [readonly [number, number], string, number | null][] = [
    [BOOK, 'sets', null],
    [BUDDIES, 'friends', null],
    [SHOP, 'friends', 0],
  ];
  for (const [card, tab, scroll] of entries) {
    for (const exit of ['x', 'escape', 'swipe']) {
      await tap(page, card);
      await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
      await page.waitForTimeout(500);
      expect(await page.evaluate(() => window.__book!.tab)).toBe(tab);
      if (scroll !== null) expect(await page.evaluate(() => window.__book!.scroll)).toBe(scroll);
      if (exit === 'x') await tapUntil(page, BOOK_CLOSE, () => window.__book === undefined);
      else if (exit === 'escape') await page.keyboard.press('Escape');
      else {
        // Svep ned stänger bara på Set-fliken (Kompisar scrollar); byt flik först.
        if (tab === 'friends') {
          await tapUntil(page, TAB_SETS, () => window.__book!.tab === 'sets');
          await page.waitForTimeout(400);
        }
        const a = await toCanvas(page, 180, 220);
        const b = await toCanvas(page, 180, 420);
        await page.mouse.move(a.x, a.y);
        await page.mouse.down();
        await page.mouse.move(b.x, b.y, { steps: 6 });
        await page.mouse.up();
      }
      const ok = await page
        .waitForFunction(() => window.__start !== undefined && window.__book === undefined, undefined, { timeout: 10_000 })
        .then(() => true, () => false);
      if (!ok) await page.screenshot({ path: `${SHOTS}/screens-book-exit-stuck-${tab}-${exit}.png` });
      expect(ok, `${tab} via ${exit}: boken stängdes inte`).toBe(true);
      await waitStart(page);
    }
  }
  expectNoErrors(errors);
});

test('(QA) set: alla fem väljs i boken och används i nästa runda (texturer)', async ({ page }) => {
  test.setTimeout(300_000);
  const errors = collectErrors(page);
  await seed(page, RICH);
  await open(page, '&lang=en');
  for (let i = 0; i < SETS.length; i++) {
    await tap(page, BOOK);
    await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
    await page.evaluate((k) => window.__book!.selectPage(k), i);
    await page.waitForTimeout(500);
    await page.keyboard.press('Escape');
    await waitStart(page);
    expect((await saved(page)).activeSet ?? 'glimtarna').toBe(SETS[i]);
    await page.screenshot({ path: `${SHOTS}/screens-set-start-${SETS[i]}.png` });
    await startRound(page);
    expect(await page.evaluate(() => window.__game!.activeSet)).toBe(SETS[i]);
    expect(await page.evaluate(() => window.__game!.textureKey)).toContain(SETS[i]);
    for (let d = 0; d < 3; d++) {
      await drag(page, 180, 80 + d * 80, 300, 3);
      await page.waitForTimeout(650);
    }
    await page.screenshot({ path: `${SHOTS}/screens-set-game-${SETS[i]}.png` });
    await page.keyboard.press('Escape');
    await waitStart(page);
  }
  expectNoErrors(errors);
});

test('(QA) arket: alla fyra rader, lugnt läge och siktlinje av slår igenom i spelet', async ({ page }) => {
  const errors = collectErrors(page);
  await seed(page, RICH);
  await open(page, '&lang=en');
  await tap(page, GEAR);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.waitForTimeout(400);
  // Lugnt läge (rad 3) och siktlinje (rad 4) av, ljud/vibration kvar.
  await tap(page, [180, SHEET_ROWS[2]]);
  await tap(page, [180, SHEET_ROWS[3]]);
  await page.waitForTimeout(300);
  await page.screenshot({ path: `${SHOTS}/screens-sheet-calm-aimoff.png` });
  await tap(page, SHEET_CLOSE);
  await page.waitForFunction(() => window.__start?.sheetOpen === false);
  expect((await saved(page)).settings).toMatchObject({ sound: true, haptics: true, calm: true, aimLine: false });
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${SHOTS}/screens-start-calm.png` });
  await startRound(page);
  expect(await page.evaluate(() => window.__game!.aimLineMode)).toBe('off');
  // Siktar med fingret nere: ingen siktlinje.
  const p = await toCanvas(page, 120, 300);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.mouse.move(p.x + 60, p.y, { steps: 4 });
  await page.waitForTimeout(200);
  expect(await page.evaluate(() => window.__game!.aimLineVisible)).toBe(false);
  await page.mouse.up();
  // Lugnt läge: ingen auto-drop efter första egna drop.
  await page.waitForTimeout(7000);
  expect(await page.evaluate(() => window.__game!.autoDrops)).toBe(0);
  await page.screenshot({ path: `${SHOTS}/screens-game-calm.png` });
  expectNoErrors(errors);
});

test.describe('?zoom=1 i DPR 2', () => {
  test('(QA) ?zoom=1: canvas 360×640, pekaren träffar rätt, start och bok ritas', async ({ page }) => {
    const errors = collectErrors(page);
    await seed(page, RICH);
    await open(page, '&lang=en&zoom=1');
    expect(await page.evaluate(() => [document.querySelector('canvas')!.width, document.querySelector('canvas')!.height])).toEqual([360, 640]);
    await page.screenshot({ path: `${SHOTS}/screens-zoom1-start.png` });
    await startRound(page);
    await drag(page, 180, 100);
    await page.waitForTimeout(200);
    await page.waitForFunction(() => window.__game!.hangingX !== -1, undefined, { timeout: 10_000 });
    await page.waitForTimeout(1500);
    await page.screenshot({ path: `${SHOTS}/screens-zoom1-game.png` });
    await page.keyboard.press('Escape');
    await waitStart(page);
    await tap(page, BUDDIES);
    await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
    await page.waitForTimeout(600);
    await page.screenshot({ path: `${SHOTS}/screens-zoom1-book.png` });
    expectNoErrors(errors);
  });
});

test('(QA) träffytor: varje knapp på sin synliga mitt och kanter, men inte utanför träffytan', async ({ page }) => {
  test.setTimeout(180_000);
  const errors = collectErrors(page);
  await seed(page, RICH);
  await open(page, '&lang=en');
  type Btn = { name: string; cx: number; cy: number; w: number; h: number; hitW: number; hitH: number; opened: string };
  const buttons: Btn[] = [
    { name: 'play', cx: 180, cy: 390, w: 268, h: 88, hitW: 284, hitH: 104, opened: 'game' },
    { name: 'book', cx: 66.5, cy: 506, w: 101, h: 104, hitW: 109, hitH: 112, opened: 'book' },
    { name: 'buddies', cx: 180, cy: 506, w: 101, h: 104, hitW: 109, hitH: 112, opened: 'book' },
    { name: 'shop', cx: 293.5, cy: 506, w: 101, h: 104, hitW: 109, hitH: 112, opened: 'book' },
    { name: 'gear', cx: 320, cy: 36, w: 48, h: 48, hitW: 64, hitH: 64, opened: 'sheet' },
  ];
  const state = (): Promise<string> =>
    page.evaluate(() => (window.__game ? 'game' : window.__book ? 'book' : window.__start?.sheetOpen ? 'sheet' : 'start'));
  const back = async (): Promise<void> => {
    await page.keyboard.press('Escape');
    await waitStart(page);
    await page.waitForFunction(() => window.__start?.sheetOpen === false);
  };
  const miss: string[] = [];
  for (const b of buttons) {
    const e = 3;
    const inside: [string, number, number][] = [
      ['centre', b.cx, b.cy],
      ['left', b.cx - b.w / 2 + e, b.cy],
      ['right', b.cx + b.w / 2 - e, b.cy],
      ['top', b.cx, b.cy - b.h / 2 + e],
      ['bottom', b.cx, b.cy + b.h / 2 - e],
    ];
    for (const [where, x, y] of inside) {
      await tap(page, [x, y]);
      await page.waitForTimeout(250);
      const s = await state();
      if (s !== b.opened) {
        // Scenbyte kan ta en stund: vänta lite till innan det räknas som miss.
        await page.waitForTimeout(1200);
      }
      const s2 = await state();
      if (s2 !== b.opened) miss.push(`${b.name} ${where} (${x}, ${y}) → ${s2}`);
      if (s2 !== 'start') await back();
    }
    // Utanför träffytan (3 px utanför till vänster/höger): ingenting händer.
    for (const [where, x, y] of [
      ['outside-left', b.cx - b.hitW / 2 - 3, b.cy],
      ['outside-right', b.cx + b.hitW / 2 + 3, b.cy],
    ] as [string, number, number][]) {
      if (x < 2 || x > 358) continue;
      await tap(page, [x, y]);
      await page.waitForTimeout(700);
      const s = await state();
      if (s === b.opened) miss.push(`${b.name} ${where} (${x}, ${y}) triggered`);
      if (s !== 'start') await back();
    }
  }
  expect(miss, miss.join('\n')).toEqual([]);
  // Arkets rader: vänster- och högerkant av raden växlar, stäng-X på sin mitt och kant.
  await tap(page, GEAR);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.waitForTimeout(400);
  const before = (await saved(page)).settings;
  await tap(page, [19, SHEET_ROWS[0]]);
  await page.waitForTimeout(200);
  await tap(page, [341, SHEET_ROWS[0]]);
  await page.waitForTimeout(200);
  await tap(page, [180, SHEET_ROWS[1] - 29]);
  await page.waitForTimeout(200);
  const after = (await saved(page)).settings;
  expect(after.sound).toBe(before.sound);
  expect(after.haptics).toBe(!before.haptics);
  await tap(page, [SHEET_CLOSE[0] + 22, SHEET_CLOSE[1]]);
  await page.waitForFunction(() => window.__start?.sheetOpen === false, undefined, { timeout: 5_000 });
  await tap(page, PLAY);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  expectNoErrors(errors);
});

test('(QA) tryck i boken fungerar även när en frame tar 400 ms (långsam telefon)', async ({ page }) => {
  knownBug('BUG-010', 'Book.onUp mäter trycket i frame-tid; en frame över 350 ms gör trycket till ett drag');
  const errors = collectErrors(page);
  await seed(page, { schema: 2, settings: { bookHintSeen: true, friendsHintSeen: true } });
  await open(page, '&lang=en');
  await tap(page, BOOK);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(500);
  // Simulerar en långsam enhet: varje frame tar minst 400 ms.
  await page.evaluate(() => {
    const block = (): void => {
      const t = performance.now();
      while (performance.now() - t < 400) {
        /* upptagen */
      }
      requestAnimationFrame(block);
    };
    requestAnimationFrame(block);
  });
  await page.waitForTimeout(800);
  await tap(page, TAB_FRIENDS);
  await page.waitForTimeout(1500);
  expect(await page.evaluate(() => window.__book!.tab)).toBe('friends');
  expectNoErrors(errors);
});
