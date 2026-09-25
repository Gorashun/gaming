import { test, expect, type Page } from '@playwright/test';
import './hook';

/** Debugpanelen för speltest (P5.1a) och bakåtknappen i spel/förlustskärm. */

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

function seedSave(page: Page): Promise<void> {
  return page.addInitScript(() => {
    if (localStorage.getItem('klunk.save.v1')) return;
    localStorage.setItem('klunk.save.v1', JSON.stringify({ schema: 2, highscore: 500, bestLevel: 4, stats: { runs: 4, merges: 0 }, settings: { bookHintSeen: true } }));
  });
}

interface Saved {
  highscore: number;
  stats: { runs: number };
  avatars: { owned: string[]; equipped: string };
  debug: { runs: { ended: string; drops: number; restartMs: number | null; restartReadyMs: number | null }[]; autoDropOff: boolean };
}
const saved = (page: Page): Promise<Saved> => page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!));

async function startGame(page: Page): Promise<void> {
  await tap(page, 180, 330);
  await page.waitForFunction(() => window.__game !== undefined && !window.__game.over, undefined, { timeout: 10_000 });
}

test('bakåt: förlustskärm → start, mitt i rundan → rundan sparas som förlust och start', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await startGame(page);
  await page.evaluate(() => window.__game!.setPacing('off'));
  for (const x of [120, 180, 240]) {
    await page.evaluate((v) => window.__game!.drop(v), x);
    await page.waitForTimeout(250);
  }
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(600);
  // Omstart från förlustskärmen (loggar återstartstiden), sedan bakåt mitt i nästa runda.
  await tap(page, 180, 530);
  await page.waitForFunction(() => window.__game !== undefined && !window.__game.over, undefined, { timeout: 5_000 });
  await page.evaluate(() => window.__game!.drop(180));
  await page.waitForTimeout(300);
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__start !== undefined && window.__game === undefined, undefined, { timeout: 5_000 });
  let s = await saved(page);
  expect(s.debug.runs.map((r) => r.ended)).toEqual(['loss', 'quit']);
  expect(s.debug.runs[0].drops).toBeGreaterThanOrEqual(3);
  expect(s.debug.runs[0].restartMs).toBeGreaterThan(0);
  expect(s.debug.runs[0].restartReadyMs).toBeGreaterThanOrEqual(0);
  expect(s.debug.runs[1].drops).toBe(1);

  // Bakåt på förlustskärmen går till startskärmen.
  await page.waitForTimeout(500);
  await startGame(page);
  await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForFunction(() => window.__reveal !== undefined, undefined, { timeout: 5_000 });
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__start !== undefined && window.__reveal === undefined && window.__game === undefined, undefined, { timeout: 5_000 });
  s = await saved(page);
  expect(s.debug.runs).toHaveLength(3);
  expect(errors).toEqual([]);
});

test('debugpanel: långtryck öppnar, JSON har senaste rundan, knapparna fungerar, Nollställ tömmer', async ({ page, context }) => {
  const errors = collectErrors(page);
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  await seedSave(page);
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await startGame(page);
  await page.evaluate(() => window.__game!.setPacing('off'));
  for (const x of [100, 200]) {
    await page.evaluate((v) => window.__game!.drop(v), x);
    await page.waitForTimeout(250);
  }
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(600);

  // Långtryck 2 s på logotypen öppnar panelen; fingrets pointerup startar inte spelet.
  const logo = await toCanvas(page, 180, 160);
  await page.mouse.move(logo.x, logo.y);
  await page.mouse.down();
  await page.waitForTimeout(2300);
  expect(await page.evaluate(() => window.__start!.debugOpen)).toBe(true);
  await page.mouse.up();
  await page.waitForTimeout(200);
  expect(await page.evaluate(() => window.__game === undefined && window.__start!.debugOpen)).toBe(true);
  await page.screenshot({ path: 'tests/e2e/screenshots/debug-panel.png' });

  // Kopiera JSON.
  await tap(page, 94, 410);
  await page.waitForFunction(() => window.__start!.debugExport !== null, undefined, { timeout: 5_000 });
  const json = JSON.parse((await page.evaluate(() => window.__start!.debugExport))!);
  expect(json.runs).toHaveLength(1);
  expect(json.runs[0]).toMatchObject({ ended: 'quit', drops: 2 });
  expect(json.runs[0].latency.all).toHaveLength(2);

  // Ge kompis: sällsynt först, vald. Auto-drop av sparas.
  await tap(page, 94, 474);
  await tap(page, 266, 474);
  await page.waitForTimeout(200);
  let s = await saved(page);
  expect(s.avatars.owned).toHaveLength(1);
  expect(s.avatars.equipped).toBe(s.avatars.owned[0]);
  expect(s.debug.autoDropOff).toBe(true);

  // Nollställ kräver två tryck.
  await tap(page, 266, 410);
  await page.waitForTimeout(200);
  expect((await saved(page)).debug.runs).toHaveLength(1);
  await tap(page, 266, 410);
  await page.waitForFunction(() => window.__start !== undefined && !window.__start.debugOpen, undefined, { timeout: 5_000 });
  s = await saved(page);
  expect(s.debug.runs).toEqual([]);
  expect(s.highscore).toBe(0);
  expect(s.stats.runs).toBe(0);
  expect(s.avatars.owned).toEqual([]);
  expect(errors).toEqual([]);
});
