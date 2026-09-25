import { test, expect, type Page } from '@playwright/test';
import './hook';

/** Släpparen och förmågorna (DESIGN §14.1, §14.5, UI.md §13.5/13.8). */

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

async function tap(page: Page, wx: number, wy: number): Promise<void> {
  const p = await toCanvas(page, wx, wy);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.mouse.up();
}

async function startGame(page: Page): Promise<void> {
  await page.waitForTimeout(1200);
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
}

function seedSave(page: Page): Promise<void> {
  return page.addInitScript(() => {
    if (localStorage.getItem('klunk.save.v1')) return;
    localStorage.setItem('klunk.save.v1', JSON.stringify({ schema: 2, highscore: 500, bestLevel: 4, stats: { runs: 4, merges: 0 } }));
  });
}

/** Byter kompis via hooken och väntar på den nya rundan. */
async function equip(page: Page, id: string, level = 1): Promise<void> {
  await page.evaluate(([i, l]) => window.__game!.equipForTest(i as string, l as number), [id, level]);
  await page.waitForFunction((i) => window.__game?.abilityState.id === i, id, { timeout: 5_000 });
  await page.waitForTimeout(300);
}

test('(a) första musslan: Släpparen håller objektet i nästa runda', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  expect(await page.evaluate(() => window.__game!.buddy)).toBeNull();

  await page.evaluate(() => {
    window.__game!.grantMerges(120);
    window.__game!.forceLoss();
  });
  await page.waitForFunction(() => window.__game!.pendingBoxes === 1, undefined, { timeout: 10_000 });
  await page.reload();
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(1000);
  await tap(page, 92, 450);
  await page.waitForFunction(() => window.__start?.openPhase === 'done', undefined, { timeout: 10_000 });
  const first = await page.evaluate(() => window.__start!.lastBox!.avatarId);
  await tap(page, 180, 330); // stänger öppningen
  await page.waitForFunction(() => window.__start !== undefined && !window.__start.opening);

  await startGame(page);
  await page.waitForTimeout(500);
  const buddy = await page.evaluate(() => window.__game!.buddy);
  expect(buddy?.id).toBe(first);
  expect(buddy?.visible).toBe(true);
  // Greppunkten ligger ovanpå det hängande objektet, inom skärmens övre band.
  expect(buddy!.y).toBeGreaterThanOrEqual(30);
  expect(buddy!.y).toBeLessThanOrEqual(60);
  await page.screenshot({ path: 'tests/e2e/screenshots/avatar-ingame.png' });
  expect(errors).toEqual([]);
});

test('(b) Lykt-Lisa: objekt av samma nivå får lyktring medan man siktar', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  await equip(page, 'lisa');
  const lvl = await page.evaluate(() => window.__game!.hangingLevel);
  expect(lvl).toBeGreaterThanOrEqual(0);
  await page.evaluate((l) => {
    window.__game!.spawn(l, 80, 560);
    window.__game!.spawn(l === 0 ? 1 : 0, 280, 560);
  }, lvl);
  await page.waitForTimeout(600);
  expect(await page.evaluate(() => window.__game!.abilityState.lisa.active)).toBe(false);

  const p = await toCanvas(page, 200, 300);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.waitForTimeout(400);
  const st = await page.evaluate(() => window.__game!.abilityState.lisa);
  expect(st.active).toBe(true);
  expect(st.oilMs).toBeLessThan(6000);
  expect(await page.evaluate(() => window.__game!.lampsVisible)).toBe(1);
  await page.screenshot({ path: 'tests/e2e/screenshots/ability-lisa.png' });
  await page.mouse.up();
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__game!.abilityState.lisa.active)).toBe(false);
  expect(errors).toEqual([]);
});

test('(c) Regnbågs-Rut: regnbåge i kön (II: första köobjektet, I: drop 3)', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  await equip(page, 'rut', 2);
  expect(await page.evaluate(() => window.__game!.nextKind)).toBe('rainbow');

  await equip(page, 'rut', 1);
  expect(await page.evaluate(() => window.__game!.nextKind)).toBe('level');
  await page.evaluate(() => window.__game!.drop(180));
  await page.waitForTimeout(900);
  expect(await page.evaluate(() => window.__game!.nextKind)).toBe('rainbow');
  expect(errors).toEqual([]);
});

test('(d) Andrums-Vala: farogränsen är 2 500 ms första gången', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  await equip(page, 'vala');
  expect(await page.evaluate(() => window.__game!.abilityState.vala)).toEqual({ usesLeft: 1, breathing: false, graceMs: 1500 });
  await page.evaluate(() => window.__game!.pin(1, 180, 90));
  await page.waitForFunction(() => window.__game!.abilityState.vala.breathing, undefined, { timeout: 5_000 });
  const st = await page.evaluate(() => window.__game!.abilityState.vala);
  expect(st.graceMs).toBe(2500);
  expect(st.usesLeft).toBe(0);
  expect(await page.evaluate(() => window.__game!.over)).toBe(false);
  await page.waitForFunction(() => window.__game!.over, undefined, { timeout: 5_000 });
  expect(errors).toEqual([]);
});

test('(e) Stjärnvalen: skimrande-chansen i samlarboken är ×2 på nivå I', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  expect(await page.evaluate(() => window.__game!.abilityState.shinyMul)).toBe(1);
  await equip(page, 'stjärnvalen');
  expect(await page.evaluate(() => window.__game!.abilityState.shinyMul)).toBe(2);
  await equip(page, 'stjärnvalen', 3);
  expect(await page.evaluate(() => window.__game!.abilityState.shinyMul)).toBe(3);
  expect(errors).toEqual([]);
});

test('Magnet-Maja: två lika som ligger stilla nära varandra dras ihop, en gång per runda (I)', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  await equip(page, 'maja');
  await page.evaluate(() => {
    const g = window.__game!;
    g.spawn(3, 80, 569);
    g.spawn(3, 80 + 2 * 31 + 30, 569);
  });
  await page.waitForFunction(() => window.__game!.abilityState.maja.usesLeft === 0, undefined, { timeout: 8_000 });
  // Paret mergear genom vanlig kontakt (poängen kommer från mergen, inte från förmågan).
  await page.waitForFunction(() => window.__game!.bodyCount === 1, undefined, { timeout: 5_000 });
  expect(errors).toEqual([]);
});

test('alla förmågor går en runda utan fel (kedja, rekord, fara, förlust)', async ({ page }) => {
  test.setTimeout(120_000);
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await startGame(page);
  // Klick sist: förlusten visar polaroiden i rundavslutet.
  const ids = ['muller', 'maestro', 'tick', 'fia', 'vulle', 'disco', 'eko', 'nora', 'lisa', 'siri', 'sixten', 'bubbel', 'ekko', 'kajsa', 'maja', 'rut', 'vala', 'havsdrottningen', 'stjärnvalen', 'common-6', 'uncommon-1', 'klick'];
  for (const id of ids) {
    await equip(page, id, 3);
    await page.evaluate(() => {
      const g = window.__game!;
      // Kedja: 1+1 → 2 → 3 → 4 i en stapel, plus några drop.
      g.spawn(3, 180, 560);
      g.spawn(2, 180, 500);
      g.spawn(1, 180, 450);
      g.spawn(1, 180, 405);
      g.spawn(2, 60, 560);
      g.spawn(2, 60 + 2 * 25 + 20, 560);
      g.drop(100);
    });
    await page.waitForTimeout(900);
    await page.evaluate(() => window.__game!.pin(0, 300, 95));
    await page.waitForTimeout(700);
  }
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForTimeout(1500);
  await page.screenshot({ path: 'tests/e2e/screenshots/ability-polaroid.png' });
  expect(errors).toEqual([]);
});
