import { test, expect, type Page } from '@playwright/test';
import './hook';

function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  return errors;
}

/** Tryck på en punkt i den logiska ytan 360×640. */
async function tap(page: Page, wx: number, wy: number): Promise<void> {
  const box = (await page.locator('canvas').boundingBox())!;
  await page.mouse.move(box.x + (wx * box.width) / 360, box.y + (wy * box.height) / 640);
  await page.mouse.down();
  await page.mouse.up();
}

async function startGame(page: Page): Promise<void> {
  await page.waitForTimeout(1200);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
}

test('kedjan tänds och nivå 3 fångas när den skapas', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => window.__game!.seed(11));
  await page.waitForTimeout(600);
  await page.waitForFunction(() => window.__game !== undefined);
  await page.evaluate(() => window.__game!.setPacing('off'));

  const before = await page.evaluate(() => ({
    lit: window.__game!.chainLit,
    col: window.__game!.collection,
  }));
  expect(before.lit[0]).toBe(true);
  expect(before.lit[3]).toBe(false);
  expect(before.col.glimtarna.caught[0]).toBe(true);
  expect(before.col.glimtarna.caught[3]).toBe(false);

  let drops = 0;
  for (; drops < 120; drops++) {
    if (await page.evaluate(() => window.__game!.chainLit[3])) break;
    await page.evaluate((x) => window.__game!.drop(x), 60 + ((drops * 53) % 240));
    await page.waitForTimeout(220);
    if (await page.evaluate(() => window.__game!.bodyCount >= 14)) {
      await page.evaluate(() => window.__game!.clear());
    }
    expect(await page.evaluate(() => window.__game!.over)).toBe(false);
  }
  await page.waitForTimeout(400);
  const after = await page.evaluate(() => ({
    lit: window.__game!.chainLit,
    col: window.__game!.collection,
  }));
  console.log(`[e2e] nivå 3 efter ${drops} drops, kedja=${after.lit.map(Number).join('')}`);
  expect(after.lit[3]).toBe(true);
  expect(after.col.glimtarna.caught[3]).toBe(true);
  // Fångsten ligger i sparfilen, inte bara i minnet.
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1') ?? '{}'));
  expect(saved.collection.glimtarna.caught[3]).toBe(true);
  expect(saved.stats.createdPerLevel[3]).toBeGreaterThan(0);
  await page.screenshot({ path: 'tests/e2e/screenshots/chain.png' });
  expect(errors, errors.join('\n')).toEqual([]);
});

test('forceShiny(2) + merge ger skimrande nivå 2 med glitter', async ({ page }) => {
  const errors = collectErrors(page);
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
  await page.waitForFunction(() => window.__game!.collection.glimtarna.shiny[2] === true, undefined, {
    timeout: 5_000,
  });
  await page.waitForTimeout(700);
  const state = await page.evaluate(() => ({
    shiny: window.__game!.collection.glimtarna.shiny,
    caught: window.__game!.collection.glimtarna.caught,
    glitter: window.__game!.glitterVisible,
    lit: window.__game!.chainLit,
    fx: window.__game!.fxCounts,
  }));
  // Sex guldstjärnor vid skapandet; nivå 2 var "?" och fick dubbelring + partiklar (U5).
  expect(state.fx.stars).toBe(1);
  expect(state.fx.chainFirst).toBeGreaterThanOrEqual(1);
  expect(state.shiny[2]).toBe(true);
  expect(state.caught[2]).toBe(true);
  expect(state.lit[2]).toBe(true);
  expect(state.glitter).toBe(1);
  await page.screenshot({ path: 'tests/e2e/screenshots/shiny.png' });

  // Skimrande försvinner när objektet mergeas vidare.
  await page.evaluate(() => window.__game!.spawn(2, 176, 470));
  await page.waitForFunction(() => window.__game!.chainLit[3] === true, undefined, { timeout: 5_000 });
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__game!.glitterVisible)).toBe(0);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('hyllan öppnar samlarboken, stäng-ikonen och svep ner stänger', async ({ page }) => {
  const errors = collectErrors(page);
  // Gammal sparfil (utan meta-lager) + en påbörjad sida: defaults-merge ska klara båda.
  await page.addInitScript(() => {
    if (localStorage.getItem('klunk.save.v1')) return;
    const caught = [true, true, true, true, false, false, false, false, false, false, false];
    const shiny = [false, false, true, false, false, false, false, false, false, false, false];
    localStorage.setItem(
      'klunk.save.v1',
      JSON.stringify({
        highscore: 840,
        bestLevel: 4,
        settings: { sound: false, haptics: false, calm: false },
        stats: { runs: 5, merges: 120, autoDrops: 0 },
        collection: { glimtarna: { caught, shiny } },
      }),
    );
  });
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 180, 440);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(500);
  const book = await page.evaluate(() => ({
    page: window.__book!.page,
    pages: window.__book!.pages,
    filled: window.__book!.filled,
  }));
  // Fem sidor (ett per temaset), bara grundsetet upplåst; 4 vanliga + 1 skimrande av 21.
  expect(book).toEqual({ page: 0, pages: 5, filled: 5 });
  expect(await page.evaluate(() => window.__game)).toBeUndefined();
  await page.screenshot({ path: 'tests/e2e/screenshots/book.png' });

  // Svep i sidled: nästa sida (låst).
  const box = (await page.locator('canvas').boundingBox())!;
  const sx = (wx: number): number => box.x + (wx * box.width) / 360;
  const sy = (wy: number): number => box.y + (wy * box.height) / 640;
  await page.mouse.move(sx(300), sy(300));
  await page.mouse.down();
  await page.mouse.move(sx(80), sy(300), { steps: 6 });
  await page.mouse.up();
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__book?.page)).toBe(1);

  // Stäng-ikonen.
  await tap(page, 316, 44);
  await page.waitForFunction(() => window.__book === undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(400);
  expect(await page.evaluate(() => window.__game)).toBeUndefined(); // tillbaka på Start, inte i spel

  // Svep ner stänger också.
  await tap(page, 180, 440);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  await page.mouse.move(sx(180), sy(200));
  await page.mouse.down();
  await page.mouse.move(sx(180), sy(420), { steps: 6 });
  await page.mouse.up();
  await page.waitForFunction(() => window.__book === undefined, undefined, { timeout: 5_000 });

  // Play startar fortfarande spelet.
  await page.waitForTimeout(300);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 5_000 });
  expect(errors, errors.join('\n')).toEqual([]);
});
