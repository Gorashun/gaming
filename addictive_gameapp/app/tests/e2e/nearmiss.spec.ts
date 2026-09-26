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

async function startGame(page: Page): Promise<void> {
  const box = (await page.locator('canvas').boundingBox())!;
  await page.waitForTimeout(1200);
  await page.mouse.move(box.x + box.width / 2, box.y + (box.height * 390) / 640); // SPELA (Start v2)
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
}

test('near-miss pulsar för nivå 8 med litet gap, jackpot ger 1000 p', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);

  // Två nivå-8 (r=74) på golvet med ~10 px gap: 104 → 262 ligger inom burken.
  await page.evaluate(() => {
    window.__game!.spawn(8, 104, 526);
    window.__game!.spawn(8, 262, 526);
  });
  // Väntar på pulsen i stället för en fast tid: suiten kör flera sidor parallellt.
  await page.waitForFunction(() => window.__game!.nearMissCount === 2, undefined, {
    timeout: 20_000,
  });
  await page.screenshot({ path: 'tests/e2e/screenshots/near-miss.png' });

  // Jackpot: två nivå 10 möts ⇒ båda försvinner, 1000 p, guldringar och slow-mo.
  const before = await page.evaluate(() => window.__game!.score);
  await page.evaluate(() => {
    window.__game!.spawn(10, 180, 480);
    window.__game!.spawn(10, 180, 240);
  });
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'tests/e2e/screenshots/jackpot.png' });
  await page.waitForFunction((s0) => window.__game!.score >= s0 + 1000, before, {
    timeout: 20_000,
  });

  const st = await page.evaluate(() => ({
    score: window.__game!.score,
    bodies: window.__game!.bodyCount,
    over: window.__game!.over,
  }));
  const after = st.score;
  console.log(`[e2e] jackpot: ${before} → ${JSON.stringify(st)}`);
  expect(after - before).toBeGreaterThanOrEqual(1000);
  expect(errors, errors.join('\n')).toEqual([]);
});
