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

/** Startar spelet från startskärmen och väntar tills testhooken finns. */
async function startGame(page: Page): Promise<void> {
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();
  const box = (await canvas.boundingBox())!;
  await page.waitForTimeout(1200);
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  // Musen bort från canvasen: ingen input får störa pacing-timern.
  await page.mouse.move(box.x + box.width / 2, box.y + box.height + 40);
}

test('mjuk auto-drop: vickning efter 3 s, objektet faller själv efter 6 s', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);

  // Fast seed: regissören är i Flöde de första 10 dropsen (DIRECTOR.openingFlowDrops).
  await page.evaluate(() => {
    window.__game!.seed(12345);
  });
  await page.waitForTimeout(600);
  await page.evaluate(() => window.__game!.setPacing('flow'));

  // Pacing vilar tills spelaren droppat själv en gång i rundan (DESIGN §11).
  await page.evaluate(() => window.__game!.drop(180));
  await page.waitForTimeout(1000);
  // Tömmer burken så att bodyCount mäter auto-droppet ensamt (och inte en merge).
  await page.evaluate(() => window.__game!.clear());

  const before = await page.evaluate(() => ({
    bodies: window.__game!.bodyCount,
    autoDrops: window.__game!.autoDrops,
    mode: window.__game!.mode,
    phase: window.__game!.pacingPhase,
  }));
  expect(before.autoDrops).toBe(0);
  expect(before.phase).toBe('idle');
  expect(before.bodies).toBe(0);

  // Mellan 3 och 6 s: vickning, men inget släpp än.
  await page.waitForTimeout(4200);
  const mid = await page.evaluate(() => ({
    phase: window.__game!.pacingPhase,
    autoDrops: window.__game!.autoDrops,
  }));
  expect(mid.phase).toBe('nudge');
  expect(mid.autoDrops).toBe(0);
  await page.screenshot({ path: 'tests/e2e/screenshots/pacing-nudge.png' });

  // Efter 6 s: exakt ett auto-drop, och objektet ligger i burken.
  await page.waitForTimeout(2600);
  const after = await page.evaluate(() => ({
    bodies: window.__game!.bodyCount,
    autoDrops: window.__game!.autoDrops,
    latencies: window.__game!.dropLatencies,
    over: window.__game!.over,
  }));
  console.log(`[e2e] autoDrops=${after.autoDrops} latencies=${JSON.stringify(after.latencies)}`);
  expect(after.over).toBe(false);
  expect(after.autoDrops).toBe(1);
  expect(after.bodies).toBe(before.bodies + 1);
  // [0] = spelarens eget drop, [1] = auto-droppet. Rampen (§12) gör drop 1 lite snabbare
  // än 6000 ms: 6000 − 2500/60 ≈ 5958 ms.
  expect(after.latencies.length).toBe(2);
  expect(after.latencies[1]).toBeGreaterThanOrEqual(5900);
  expect(after.latencies[1]).toBeLessThan(6800);

  // Stats sparas.
  const stats = await page.evaluate(
    () => JSON.parse(localStorage.getItem('klunk.save.v1')!).stats as { autoDrops: number },
  );
  expect(stats.autoDrops).toBeGreaterThanOrEqual(0);

  expect(errors, errors.join('\n')).toEqual([]);
});

test('inget auto-drop innan spelaren droppat själv i rundan', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => window.__game!.setPacing('flow'));

  await page.waitForTimeout(7000);
  const idle = await page.evaluate(() => ({
    autoDrops: window.__game!.autoDrops,
    bodies: window.__game!.bodyCount,
    phase: window.__game!.pacingPhase,
  }));
  expect(idle.autoDrops).toBe(0);
  expect(idle.bodies).toBe(0);
  expect(idle.phase).toBe('idle');

  // Efter det egna droppet vaknar pacing: timern räknas från det nya objektet.
  await page.evaluate(() => window.__game!.drop(150));
  await page.waitForTimeout(7200);
  const after = await page.evaluate(() => window.__game!.autoDrops);
  expect(after).toBe(1);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('Lugnt läge stänger av auto-drop helt', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await page.waitForTimeout(800);
  await page.evaluate(() =>
    localStorage.setItem(
      'klunk.save.v1',
      JSON.stringify({
        schema: 2,
        highscore: 0,
        bestLevel: 0,
        settings: { sound: false, haptics: false, calm: true },
        stats: { runs: 3, merges: 0, autoDrops: 0 },
      }),
    ),
  );
  await page.reload();
  await startGame(page);
  await page.evaluate(() => window.__game!.setPacing('flow'));
  await page.evaluate(() => window.__game!.drop(180));
  await page.waitForTimeout(1000);

  const bodies = await page.evaluate(() => window.__game!.bodyCount);
  await page.waitForTimeout(7000);
  const after = await page.evaluate(() => ({
    autoDrops: window.__game!.autoDrops,
    bodies: window.__game!.bodyCount,
    phase: window.__game!.pacingPhase,
  }));
  expect(after.autoDrops).toBe(0);
  expect(after.phase).toBe('idle');
  expect(after.bodies).toBe(bodies);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('fingret nere: auto-droppet väntar tills spelaren släpper', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => window.__game!.setPacing('flow'));
  await page.evaluate(() => window.__game!.drop(180));
  await page.waitForTimeout(1000);

  const box = (await page.locator('canvas').boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(7000);
  const held = await page.evaluate(() => ({
    autoDrops: window.__game!.autoDrops,
    bodies: window.__game!.bodyCount,
    phase: window.__game!.pacingPhase,
  }));
  expect(held.autoDrops, 'auto-drop får inte avfyras medan fingret är nere').toBe(0);
  expect(held.bodies).toBe(1);
  expect(held.phase).toBe('autodrop');

  await page.mouse.up();
  await page.waitForTimeout(400);
  const released = await page.evaluate(() => ({
    autoDrops: window.__game!.autoDrops,
    bodies: window.__game!.bodyCount,
  }));
  expect(released.autoDrops).toBe(0);
  expect(released.bodies).toBe(2);
  expect(errors, errors.join('\n')).toEqual([]);
});

test('pacing off: inget auto-drop på 7 s', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('/?test=1');
  await startGame(page);
  await page.evaluate(() => window.__game!.setPacing('off'));
  await page.evaluate(() => window.__game!.drop(180));
  await page.waitForTimeout(7000);
  const after = await page.evaluate(() => ({
    autoDrops: window.__game!.autoDrops,
    phase: window.__game!.pacingPhase,
  }));
  expect(after.autoDrops).toBe(0);
  expect(after.phase).toBe('idle');
  expect(errors, errors.join('\n')).toEqual([]);
});
