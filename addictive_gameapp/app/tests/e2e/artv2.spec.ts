import { test, expect, type Page } from '@playwright/test';
import './hook';

/** Art v2 och hi-DPI (DESIGN §17, UI.md §15): DPR 2 ⇒ Z = 2, canvas 720×1280, logiska koordinater oförändrade. */
test.use({ deviceScaleFactor: 2 });

function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  return errors;
}

/** Logiska koordinater (360×640) → CSS-pixlar på canvasen. */
async function toCss(page: Page, wx: number, wy: number): Promise<[number, number]> {
  const box = (await page.locator('canvas').boundingBox())!;
  return [box.x + (wx * box.width) / 360, box.y + (wy * box.height) / 640];
}

async function tap(page: Page, wx: number, wy: number): Promise<void> {
  const [x, y] = await toCss(page, wx, wy);
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.up();
}

const ALL_SETS = ['glimtarna', 'planeterna', 'frostisarna', 'godisarna', 'gloden'];

function seedSave(page: Page, extra: Record<string, unknown> = {}): Promise<void> {
  return page.addInitScript((x) => {
    if (localStorage.getItem('klunk.save.v1')) return;
    localStorage.setItem(
      'klunk.save.v1',
      JSON.stringify({ schema: 2, highscore: 500, bestLevel: 4, stats: { runs: 4, merges: 20 }, ...x }),
    );
  }, extra);
}

test('(a–c, e) DPR 2: canvas 720×1280, ▶ startar, drop vid x=100 hamnar vid logisk x≈100', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });

  // (a) Canvasens pixelbuffert är 360·2 × 640·2, oberoende av CSS-storleken.
  const size = await page.evaluate(() => {
    const c = document.querySelector('canvas')!;
    const r = c.getBoundingClientRect();
    return { w: c.width, h: c.height, cssW: r.width, cssH: r.height, left: r.left, top: r.top };
  });
  expect([size.w, size.h]).toEqual([720, 1280]);
  // Scale.FIT centrerar fortfarande i 390×844.
  expect(size.cssW).toBeCloseTo(390, 0);
  expect(size.top).toBeCloseTo((844 - size.cssH) / 2, 0);

  // (b) Ett tryck på ▶ startar spelet.
  await page.waitForTimeout(1200);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  await page.evaluate(() => window.__game!.setPacing('off'));
  await page.waitForTimeout(300);

  // (c) Pointer → logisk x: objektet hänger där fingret är, åt båda hållen från mitten.
  for (const wx of [100, 250]) {
    const [x, y] = await toCss(page, wx, 300);
    await page.mouse.move(x, y);
    await page.mouse.down();
    const hx = await page.evaluate(() => window.__game!.hangingX);
    expect(Math.abs(hx - wx)).toBeLessThanOrEqual(1.5);
    await page.mouse.up();
    await page.waitForTimeout(700);
  }
  expect(await page.evaluate(() => window.__game!.bodyCount)).toBeGreaterThanOrEqual(2);

  // (e) Spelskärm i DPR 2 med objekt av många nivåer.
  await page.evaluate(() => {
    const g = window.__game!;
    g.clear();
    const lv = [10, 7, 5, 8, 3, 6, 2, 4, 1, 0, 2, 3];
    const xs = [110, 262, 60, 250, 48, 170, 300, 105, 200, 150, 240, 300];
    const ys = [520, 530, 420, 400, 330, 400, 330, 330, 320, 300, 300, 260];
    lv.forEach((l, i) => g.spawn(l, xs[i], ys[i]));
  });
  await page.waitForTimeout(1800);
  await page.screenshot({ path: 'tests/e2e/screenshots/artv2-game.png' });
  expect(await page.evaluate(() => window.__game!.ballSets)).toEqual(['glimtarna']);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(d, e) budget: ≤ 2 set i full upplösning efter alla 5 bokens sidor och tre setbyten', async ({ page }) => {
  const errors = collectErrors(page);
  const logs: string[] = [];
  page.on('console', (m) => logs.push(m.text()));
  const caught = [true, true, true, true, true, true, false, false, false, false, false];
  await seedSave(page, {
    unlockedSets: ALL_SETS,
    activeSet: 'glimtarna',
    collection: Object.fromEntries(ALL_SETS.map((id) => [id, { caught, shiny: [false, true, true] }])),
  });
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 238, 444); // bok-ikonen på hyllan
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  for (let i = 0; i < ALL_SETS.length; i++) {
    await page.evaluate((k) => window.__book!.selectPage(k), i);
    await page.waitForTimeout(350);
    expect((await page.evaluate(() => window.__book!.ballSets)).length).toBeLessThanOrEqual(2);
  }
  await page.evaluate(() => window.__book!.selectPage(0));
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'tests/e2e/screenshots/artv2-book.png' });
  expect(await page.evaluate(() => window.__book!.ballSets)).toEqual(['glimtarna']);

  // Tre rundor i tre andra set: äldsta frigörs, aldrig det aktiva.
  await tap(page, 320, 44);
  await page.waitForFunction(() => window.__book === undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(300);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  for (const id of ['planeterna', 'frostisarna', 'gloden']) {
    await page.evaluate((s) => window.__game!.setActiveSet(s), id);
    await page.evaluate(() => window.__game!.seed(3));
    await page.waitForTimeout(500);
    await page.waitForFunction((s) => window.__game?.activeSet === s, id);
    const sets = await page.evaluate(() => window.__game!.ballSets);
    expect(sets.length).toBeLessThanOrEqual(2);
    expect(sets).toContain(id);
    expect(await page.evaluate(() => window.__game!.textureKey)).toMatch(new RegExp(`^ball-${id}-\\d+$`));
  }
  const inMemory = logs.filter((l) => l.startsWith('[art] bakade set'));
  console.log(`[e2e] ${inMemory.join(' | ')}`);
  expect(inMemory.length).toBeGreaterThanOrEqual(4);
  for (const l of inMemory) expect(l.split('i minnet: ')[1].split(',').length).toBeLessThanOrEqual(2);
  expect(logs.some((l) => l.startsWith('[art] frigjorde set'))).toBe(true);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('(e) öppningen av en mussla i DPR 2', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page, { stats: { runs: 4, merges: 0 } });
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 20_000 });
  await page.evaluate(() => {
    window.__game!.grantMerges(120);
    window.__game!.forceLoss();
  });
  await page.waitForFunction(() => window.__game!.pendingBoxes === 1, undefined, { timeout: 20_000 });
  await page.waitForTimeout(2500);
  await page.reload();
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 20_000 });
  await page.waitForTimeout(1200);
  await tap(page, 92, 450);
  await page.waitForFunction(() => window.__start?.openPhase === 'done', undefined, { timeout: 20_000 });
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'tests/e2e/screenshots/artv2-open.png' });
  expect(errors, errors.join('\n')).toEqual([]);
});
