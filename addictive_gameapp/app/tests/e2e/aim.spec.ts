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

/** Logisk yta 360×640 FIT:as in i canvasen: räknar om logiska koordinater till skärm. */
async function mapper(page: Page): Promise<(x: number, y: number) => { x: number; y: number }> {
  const box = (await page.locator('canvas').boundingBox())!;
  const scale = box.width / 360;
  const offsetY = (box.height - 640 * scale) / 2;
  return (x: number, y: number) => ({ x: box.x + x * scale, y: box.y + offsetY + y * scale });
}

async function startGame(page: Page): Promise<void> {
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();
  await page.waitForTimeout(1200);
  const to = await mapper(page);
  const play = to(180, 330);
  await page.mouse.move(play.x, play.y);
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  await page.waitForTimeout(400);
}

test('siktlinjen syns bara medan fingret är nere (läge aiming)', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);
  const to = await mapper(page);

  expect(await page.evaluate(() => window.__game!.aimLineMode)).toBe('aiming');
  expect(await page.evaluate(() => window.__game!.aimLineVisible)).toBe(false);

  const p = to(150, 300);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.waitForTimeout(200);
  expect(await page.evaluate(() => window.__game!.aimLineVisible)).toBe(true);
  await page.screenshot({ path: 'tests/e2e/screenshots/aim-line-on.png' });

  await page.mouse.up();
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__game!.aimLineVisible)).toBe(false);

  expect(errors, errors.join('\n')).toEqual([]);
});

test('siktlinjen syns aldrig i läge off', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);
  const to = await mapper(page);
  await page.evaluate(() => window.__game!.setAimLine('off'));

  const p = to(200, 300);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.waitForTimeout(250);
  expect(await page.evaluate(() => window.__game!.aimLineVisible)).toBe(false);
  await page.mouse.move(p.x - 30, p.y);
  await page.waitForTimeout(150);
  expect(await page.evaluate(() => window.__game!.aimLineVisible)).toBe(false);
  await page.mouse.up();
  await page.waitForTimeout(250);
  expect(await page.evaluate(() => window.__game!.aimLineVisible)).toBe(false);

  expect(errors, errors.join('\n')).toEqual([]);
});

test('fjärde startikonen stänger av siktlinjen och sparas', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await page.waitForTimeout(1500);
  const to = await mapper(page);
  await page.screenshot({ path: 'tests/e2e/screenshots/start-four-icons.png' });

  const icon = to(300, 580);
  await page.mouse.move(icon.x, icon.y);
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForTimeout(200);

  const settings = await page.evaluate(
    () => JSON.parse(localStorage.getItem('klunk.save.v1')!).settings as { aimLine: boolean },
  );
  expect(settings.aimLine).toBe(false);
  // Ett tryck på ikonraden får inte starta spelet.
  expect(await page.evaluate(() => window.__game === undefined)).toBe(true);
  await page.screenshot({ path: 'tests/e2e/screenshots/start-aim-off.png' });

  // Inställningen slår igenom i spelet.
  await startGame(page);
  expect(await page.evaluate(() => window.__game!.aimLineMode)).toBe('off');

  expect(errors, errors.join('\n')).toEqual([]);
});

test('auto-drop-tiden rampar ned med antalet drops i rundan', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);

  expect(await page.evaluate(() => window.__game!.autoDropAtMs)).toBe(6000);

  // 30 drops; burken töms mellan varje så att rundan inte tar slut.
  await page.evaluate(() => {
    for (let i = 0; i < 30; i++) {
      window.__game!.drop(100 + (i % 5) * 40);
      window.__game!.clear();
    }
  });
  await page.waitForTimeout(300);

  const after = await page.evaluate(() => ({
    autoDropAtMs: window.__game!.autoDropAtMs,
    over: window.__game!.over,
    autoDrops: window.__game!.autoDrops,
  }));
  console.log(`[e2e] autoDropAtMs efter 30 drops = ${after.autoDropAtMs}`);
  expect(after.over).toBe(false);
  expect(after.autoDrops).toBe(0);
  expect(after.autoDropAtMs).toBeGreaterThan(4700);
  expect(after.autoDropAtMs).toBeLessThan(4800);

  expect(errors, errors.join('\n')).toEqual([]);
});
