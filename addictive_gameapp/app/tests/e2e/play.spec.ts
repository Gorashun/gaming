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

test('30 drops ger poäng, inga JS-fel, skärmbilder av start/spel/förlust', async ({ page }) => {
  const errors = collectErrors(page);

  await page.goto('/?test=1');
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();
  const box = (await canvas.boundingBox())!;

  // Startskärmen hinner rita logotyp, hjälte och knappar.
  await page.waitForTimeout(1500);
  await page.screenshot({ path: 'tests/e2e/screenshots/start.png' });

  // Tryck på ▶.
  await page.mouse.move(box.x + box.width / 2, box.y + (box.height * 390) / 640); // SPELA (Start v2)
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });

  // Onboarding-handen ska visas innan första droppet.
  await page.waitForTimeout(900);
  await page.screenshot({ path: 'tests/e2e/screenshots/onboarding.png' });

  // ~30 drops med varierande x för att tvinga fram merges.
  for (let i = 0; i < 30; i++) {
    const x = 60 + ((i * 53) % 240);
    await page.evaluate((px) => window.__game!.drop(px), x);
    await page.waitForTimeout(260);
    if (i === 9) {
      await page.waitForTimeout(500);
      await page.screenshot({ path: 'tests/e2e/screenshots/game.png' });
    }
    if (await page.evaluate(() => window.__game!.over)) break;
  }
  await page.waitForTimeout(800);

  const state = await page.evaluate(() => ({
    score: window.__game!.score,
    bodyCount: window.__game!.bodyCount,
    over: window.__game!.over,
  }));
  console.log(`[e2e] score=${state.score} bodies=${state.bodyCount} over=${state.over}`);
  expect(state.score).toBeGreaterThan(0);

  if (!state.over) await page.evaluate(() => window.__game!.forceLoss());
  await page.waitForTimeout(900);
  await page.screenshot({ path: 'tests/e2e/screenshots/gameover.png' });

  expect(errors, errors.join('\n')).toEqual([]);
});

test('inställningsikonerna går att stänga av och sparas', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  const box = (await page.locator('canvas').boundingBox())!;
  await page.waitForTimeout(1500);

  // Logisk yta 360×640 FIT:as in i canvasen.
  const scale = box.width / 360;
  const offsetY = (box.height - 640 * scale) / 2;
  const toWorld = (x: number, y: number) => ({
    x: box.x + x * scale,
    y: box.y + offsetY + y * scale,
  });

  const click = async (x: number, y: number): Promise<void> => {
    const p = toWorld(x, y);
    await page.mouse.move(p.x, p.y);
    await page.mouse.down();
    await page.mouse.up();
  };
  // Kugghjulet öppnar inställningsarket; varje rad (y 404/468/532/596) växlar sin inställning.
  await click(320, 36);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.waitForTimeout(400);
  for (const y of [404, 468, 532, 596]) {
    await click(180, y);
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(200);
  await page.screenshot({ path: 'tests/e2e/screenshots/sheet-all-off.png' });

  const settings = await page.evaluate(
    () => JSON.parse(localStorage.getItem('klunk.save.v1')!).settings,
  );
  expect(settings).toMatchObject({ sound: false, haptics: false, calm: true, aimLine: false });
  // Spelet ska inte ha startat av ett tryck i arket.
  expect(await page.evaluate(() => window.__game === undefined)).toBe(true);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('highscore överlever omladdning och rekordjakten triggar', async ({ page }) => {
  const errors = collectErrors(page);

  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await page.evaluate(() =>
    localStorage.setItem(
      'klunk.save.v1',
      JSON.stringify({
        schema: 2,
        highscore: 30,
        bestLevel: 5,
        settings: { sound: true, haptics: true, calm: false },
        stats: { runs: 3, merges: 40 },
      }),
    ),
  );
  await page.reload();
  await page.waitForTimeout(1500);
  await page.screenshot({ path: 'tests/e2e/screenshots/start-highscore.png' });

  const canvas = page.locator('canvas');
  const box = (await canvas.boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + (box.height * 390) / 640); // SPELA (Start v2)
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });

  // Spela tills poängen passerar det låga rekordet (record + newRecord).
  // Som en spelare: nästa drop först när nästa objekt hänger (dropp-cooldown i speltid), annars
  // staplas objekten över farolinjen när speltiden går långsamt under CPU-last.
  for (let i = 0; i < 40; i++) {
    await page.waitForFunction(() => window.__game!.hangingX !== -1 || window.__game!.over, undefined, { timeout: 10_000 });
    if (await page.evaluate(() => window.__game!.over || window.__game!.score > 36)) break;
    await page.evaluate((px) => window.__game!.drop(px), 70 + ((i * 47) % 220));
    await page.waitForTimeout(260);
  }
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'tests/e2e/screenshots/record.png' });

  const score = await page.evaluate(() => window.__game!.score);
  expect(score).toBeGreaterThan(30);
  expect(errors, errors.join('\n')).toEqual([]);
});
