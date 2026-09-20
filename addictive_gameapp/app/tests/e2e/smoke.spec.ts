import { test, expect } from '@playwright/test';

declare global {
  interface Window {
    __game?: { bodyCount: number; score: number; over: boolean; combo: number; drop(x: number): void; forceLoss(): void };
  }
}

test('startar, tappar ett objekt och får en body i burken', async ({ page }) => {
  await page.goto('/?test=1');
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();
  const box = (await canvas.boundingBox())!;

  // Tryck på ▶ (mitten av startskärmen).
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.up();

  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });

  // Sikta och släpp med pointer-events.
  const dropX = box.x + box.width * 0.4;
  const dropY = box.y + box.height * 0.5;
  await page.mouse.move(dropX, dropY);
  await page.mouse.down();
  await page.mouse.move(dropX + 20, dropY, { steps: 5 });
  await page.mouse.up();

  await page.waitForTimeout(1500);

  const state = await page.evaluate(() => ({
    bodyCount: window.__game!.bodyCount,
    score: window.__game!.score,
  }));
  expect(state.bodyCount).toBeGreaterThanOrEqual(1);

  await page.screenshot({ path: 'tests/e2e/screenshots/game.png' });
});

test('benchmark-scenen mäter fps', async ({ page }) => {
  const logs: string[] = [];
  page.on('console', (m) => logs.push(m.text()));
  await page.goto('/?bench=1');
  await page.waitForFunction(() => (window as any).__fps > 0, undefined, { timeout: 20_000 });
  await page.waitForTimeout(5000);
  const fps = await page.evaluate(() => (window as any).__fps as number);
  console.log(`[e2e] bench avg fps = ${fps.toFixed(1)}`);
  await page.screenshot({ path: 'tests/e2e/screenshots/bench.png' });
  expect(fps).toBeGreaterThan(0);
  expect(logs.some((l) => l.startsWith('[bench]'))).toBe(true);
});
