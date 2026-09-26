import { test, expect, type Page } from '@playwright/test';
import './hook';
import { DIRECTOR } from '../../src/data/director';

/** Fasta seeds: första Kick på drop 25 (DESIGN §4, 25–60), ett per specialobjekt. */
const CASES = [
  { seed: 7, expect: 'bomb', shot: 'special-preview.png' },
  { seed: 35, expect: 'rainbow', shot: 'special-preview-rainbow.png' },
];
const MAX_DROPS = 80;

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

for (const c of CASES) {
  test(`kicken ger ${c.expect} i förhandsvisningen som aktiveras`, async ({ page }) => {
    const errors = collectErrors(page);
    await page.goto('/?test=1');
    await startGame(page);

    // Deterministisk körning: fast seed startar om rundan.
    await page.evaluate((seed) => window.__game!.seed(seed), c.seed);
    await page.waitForTimeout(600);
    await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
    expect(await page.evaluate(() => window.__game!.mode)).toBe('flow'); // första 10 = Flöde

    let kind = 'level';
    let drops = 0;
    for (; drops < MAX_DROPS; drops++) {
      kind = await page.evaluate(() => window.__game!.nextKind);
      if (kind !== 'level') break;
      await page.evaluate((x) => window.__game!.drop(x), 60 + ((drops * 53) % 240));
      await page.waitForTimeout(200);
      // Vänta på nästa hängande objekt (cooldown i speltid) så att burken inte fylls när speltiden går långsamt.
      await page.waitForFunction(() => window.__game!.hangingX !== -1 || window.__game!.over, undefined, { timeout: 10_000 });
      // Burken töms när den blir full: testet mäter regissören, inte överlevnad.
      if (await page.evaluate(() => window.__game!.bodyCount >= 12)) {
        await page.evaluate(() => window.__game!.clear());
      }
      if (await page.evaluate(() => window.__game!.over)) break;
    }

    const stats = await page.evaluate(() => ({
      mode: window.__game!.mode,
      dropsSinceKick: window.__game!.dropsSinceKick,
      over: window.__game!.over,
      score: window.__game!.score,
      bodies: window.__game!.bodyCount,
    }));
    console.log(`[e2e] kick efter ${drops} drops, kind=${kind}, ${JSON.stringify(stats)}`);

    expect(stats.over, 'rundan tog slut innan kicken hann komma').toBe(false);
    expect(kind).toBe(c.expect);
    // Kicken kommer aldrig under de 10 första dropsen och alltid inom intervallet.
    // (Exakt kickavstånd testas utan rendering i tests/unit/director.test.ts.)
    expect(drops).toBeGreaterThan(10);
    expect(drops).toBeLessThanOrEqual(DIRECTOR.kickEvery.max);
    expect(stats.mode).toBe('kick');

    // Specialobjektet ligger i förhandsvisningen (annan form, accent2-ram, puls).
    // Ingen extra väntan: nästa spawnHanging flyttar ner det till drop-läget.
    await page.screenshot({ path: `tests/e2e/screenshots/${c.shot}` });

    // Droppa det som hänger så specialobjektet flyttas ner till drop-läget.
    await page.evaluate(() => window.__game!.drop(180));
    await page.waitForTimeout(700);
    expect(await page.evaluate(() => window.__game!.nextKind)).toBe('level');

    const before = await page.evaluate(() => ({
      score: window.__game!.score,
      bodies: window.__game!.bodyCount,
      activated: window.__game!.specialsActivated,
    }));

    // Släpp specialobjektet mitt i högen.
    await page.evaluate(() => window.__game!.drop(180));
    const peak = await page.evaluate(() => window.__game!.bodyCount);
    // Aktiveras vid första kontakt, senast av nödaktiveringen 3 s efter landning.
    await page.waitForFunction((n) => window.__game!.specialsActivated > n, before.activated, {
      timeout: 20_000,
    });
    await page.waitForTimeout(300);

    const after = await page.evaluate(() => ({
      score: window.__game!.score,
      bodies: window.__game!.bodyCount,
      activated: window.__game!.specialsActivated,
    }));
    console.log(`[e2e] ${kind}: ${JSON.stringify(before)} → ${JSON.stringify(after)} peak=${peak}`);

    expect(after.activated).toBeGreaterThan(before.activated);
    expect(after.bodies < peak || after.score > before.score).toBe(true);
    expect(errors, errors.join('\n')).toEqual([]);
  });
}
