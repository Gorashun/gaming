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

/** Sparfil med en påbörjad runda (ingen onboarding) och valfria set. */
function seedSave(page: Page, extra: Record<string, unknown> = {}): Promise<void> {
  return page.addInitScript((x) => {
    if (localStorage.getItem('klunk.save.v1')) return;
    localStorage.setItem(
      'klunk.save.v1',
      JSON.stringify({ highscore: 500, bestLevel: 4, stats: { runs: 4, merges: 20 }, ...x }),
    );
  }, extra);
}

test('rundavslut: 200 merges låser upp ett nytt set, tryck mitt i sekvensen startar om <500 ms', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => {
    const g = window.__game!;
    g.setPacing('off');
    g.clear();
    // Två fångster i rundan så att flygarna syns.
    g.spawn(2, 180, 575);
    g.spawn(2, 184, 520);
  });
  await page.waitForFunction(() => window.__game!.collection.glimtarna.caught[3] === true, undefined, { timeout: 15_000 });
  await page.evaluate(() => {
    window.__game!.grantMerges(200);
    window.__game!.forceLoss();
  });
  await page.waitForFunction(() => window.__game!.unlockedSets.length === 2, undefined, { timeout: 10_000 });
  const s = await page.evaluate(() => ({ u: window.__game!.unlockedSets, f: window.__game!.freshSet }));
  expect(s.u[0]).toBe('glimtarna');
  expect(s.f).toBe(s.u[1]);
  // Hela sekvensen (≤2,5 s speltid). freshSet ligger kvar tills setets sida visats i boken (U3).
  await page.waitForFunction(() => (window.__reveal?.landed ?? 0) >= 1, undefined, { timeout: 20_000 });
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'tests/e2e/screenshots/reveal-newset.png' });
  expect(await page.evaluate(() => window.__game!.freshSet)).toBe(s.u[1]);
  const fresh = await page.evaluate(() => window.__game!.collection.glimtarna.fresh);
  expect(fresh[3]).toBe(false);

  // Ny runda, förlust igen utan nytt set; tryck mitt i sekvensen.
  await tap(page, 180, 530);
  await page.waitForFunction(() => window.__game !== undefined && !window.__game.over, undefined, { timeout: 5_000 });
  await page.evaluate(() => {
    const g = window.__game!;
    g.setPacing('off');
    g.clear();
    g.spawn(3, 180, 575);
    g.spawn(3, 184, 510);
  });
  await page.waitForFunction(() => window.__game!.collection.glimtarna.caught[4] === true, undefined, { timeout: 15_000 });
  await page.evaluate(() => window.__game!.forceLoss());
  // Tryck inifrån sidan när overlayen kört 300 ms speltid (stripen är inne, flygaren landar
  // först vid 840 ms). Mät från pointerup till att en ny runda finns, utan Playwrights rundresor.
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 5_000 });
  const res = await page.evaluate(
    () =>
      new Promise<{ ms: number; landed: number }>((resolve) => {
        const old = window.__game;
        const canvas = document.querySelector('canvas')!;
        const r = canvas.getBoundingClientRect();
        const at = { clientX: r.left + r.width / 2, clientY: r.top + (300 * r.height) / 640, bubbles: true };
        let t0 = 0;
        let landed = -1;
        const poll = (): void => {
          const rv = window.__reveal;
          if (t0 === 0 && rv && rv.elapsed >= 300) {
            landed = rv.landed;
            canvas.dispatchEvent(new MouseEvent('mousedown', at));
            t0 = performance.now();
            canvas.dispatchEvent(new MouseEvent('mouseup', at));
          }
          const g = window.__game;
          if (t0 > 0 && g && g !== old && !g.over) resolve({ ms: performance.now() - t0, landed });
          else requestAnimationFrame(poll);
        };
        poll();
      }),
  );
  expect(res.landed).toBe(0);
  const ms = res.ms;
  console.log(`[e2e] omstart mitt i rundavslutet: ${ms.toFixed(0)} ms`);
  expect(ms).toBeLessThan(500);
  // Flygaren hann inte landa: platsen ligger kvar som "nytt sedan sist" till boken.
  const after = await page.evaluate(() => window.__game!.collection.glimtarna.fresh);
  expect(after[4]).toBe(true);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('boken: låst sida är låst, upplåst sida kan väljas som aktiv och sparas', async ({ page }) => {
  const errors = collectErrors(page);
  const caught = [true, true, true, true, true, false, false, false, false, false, false];
  const fresh = new Array(21).fill(false);
  fresh[4] = true;
  await seedSave(page, {
    unlockedSets: ['glimtarna', 'frostisarna'],
    activeSet: 'glimtarna',
    freshSet: 'frostisarna',
    collection: {
      glimtarna: { caught, shiny: [false, false, true], fresh },
      frostisarna: { caught: [true, true, true] },
    },
  });
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'tests/e2e/screenshots/start-shelf.png' });
  await tap(page, 238, 444); // bok-ikonen på hyllan
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  // Boken öppnas på det nya setet.
  expect(await page.evaluate(() => window.__book!.page)).toBe(2);
  expect(await page.evaluate(() => window.__book!.locked)).toEqual([false, true, false, true, true]);
  await page.waitForTimeout(600);

  // Låst sida: tryck ändrar inget.
  await page.evaluate(() => window.__book!.selectPage(1));
  await page.waitForTimeout(400);
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!).activeSet)).toBe('glimtarna');
  expect(await page.evaluate(() => window.__book!.filled)).toBe(0);
  await page.screenshot({ path: 'tests/e2e/screenshots/book-locked.png' });

  // Upplåst sida: riktigt tryck väljer setet.
  await page.evaluate(() => window.__book!.selectPage(2));
  await page.evaluate(() => window.__book!.selectPage(0));
  await page.waitForTimeout(400);
  const box = (await page.locator('canvas').boundingBox())!;
  const sx = (wx: number): number => box.x + (wx * box.width) / 360;
  const sy = (wy: number): number => box.y + (wy * box.height) / 640;
  await page.mouse.move(sx(300), sy(300));
  await page.mouse.down();
  await page.mouse.move(sx(40), sy(300), { steps: 6 });
  await page.mouse.up();
  await page.waitForTimeout(400);
  expect(await page.evaluate(() => window.__book!.page)).toBe(1);
  await page.evaluate(() => window.__book!.selectPage(2));
  await page.waitForTimeout(400);
  await tap(page, 180, 250);
  await page.waitForTimeout(600);
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!));
  expect(saved.activeSet).toBe('frostisarna');
  // Sidan har synts i 2 s: freshSet nollställt.
  await page.waitForFunction(() => JSON.parse(localStorage.getItem('klunk.save.v1')!).freshSet === null, undefined, {
    timeout: 20_000,
  });
  await page.screenshot({ path: 'tests/e2e/screenshots/book-sets.png' });

  // Glimtarnas sida: nivå 4 var ny och nollställs när sidan setts i 2 s.
  await page.evaluate(() => window.__book!.selectPage(0));
  await page.waitForFunction(
    () => JSON.parse(localStorage.getItem('klunk.save.v1')!).collection.glimtarna.fresh[4] === false,
    undefined,
    { timeout: 20_000 },
  );
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!).activeSet)).toBe('glimtarna');

  // Stäng och spela: rundan använder det aktiva setet.
  await tap(page, 320, 44);
  await page.waitForFunction(() => window.__book === undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(300);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 5_000 });
  expect(await page.evaluate(() => window.__game!.activeSet)).toBe('glimtarna');
  expect(errors, errors.join('\n')).toEqual([]);
});

test('en runda i annat set byter texturer och kör setets merge-klang', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page, { unlockedSets: ['glimtarna', 'gloden', 'planeterna'] });
  await page.goto('/?test=1');
  await startGame(page);
  expect(await page.evaluate(() => window.__game!.textureKey)).toMatch(/^ball-glimtarna-\d+$/);

  for (const id of ['planeterna', 'gloden']) {
    expect(await page.evaluate((s) => window.__game!.setActiveSet(s), id)).toBe(true);
    // Bytet gäller först från nästa runda.
    expect(await page.evaluate(() => window.__game!.textureKey)).not.toContain(id);
    await page.evaluate(() => window.__game!.seed(5));
    await page.waitForTimeout(500);
    await page.waitForFunction(() => window.__game !== undefined);
    expect(await page.evaluate(() => window.__game!.textureKey)).toMatch(new RegExp(`^ball-${id}-\\d+$`));
    const before = await page.evaluate(() => window.__game!.timbrePlays);
    await page.evaluate(() => {
      const g = window.__game!;
      g.setPacing('off');
      g.clear();
      g.spawn(4, 180, 575);
      g.spawn(4, 184, 500);
      g.spawn(1, 100, 575);
      g.spawn(1, 104, 530);
    });
    // Två merges ⇒ minst två klanger i setets klangfärg.
    await page.waitForFunction((b) => window.__game!.timbrePlays >= b + 2, before, { timeout: 15_000 });
    await page.screenshot({ path: `tests/e2e/screenshots/set-${id}.png` });
  }
  expect(errors, errors.join('\n')).toEqual([]);
});
