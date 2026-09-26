import { test, expect, type Page } from '@playwright/test';
import './hook';

/** Polish-omgången U1, U3–U8 (BACKLOG). */

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

function seedSave(page: Page, extra: Record<string, unknown> = {}): Promise<void> {
  return page.addInitScript((x) => {
    if (localStorage.getItem('klunk.save.v1')) return;
    localStorage.setItem('klunk.save.v1', JSON.stringify({ schema: 2, highscore: 500, bestLevel: 4, stats: { runs: 4, merges: 0 }, ...x }));
  }, extra);
}

const saved = (page: Page): Promise<{ settings: Record<string, boolean>; avatars: { fresh: string[] } }> =>
  page.evaluate(() => JSON.parse(localStorage.getItem('klunk.save.v1')!));

/** Ljusaste pixeln inom ikonens 48 px-ruta på den renderade skärmen. */
async function iconColor(page: Page, wx: number, wy: number): Promise<[number, number, number]> {
  const box = (await page.locator('canvas').boundingBox())!;
  const k = box.width / 360;
  const png = await page.screenshot({ clip: { x: box.x + (wx - 24) * k, y: box.y + (wy - 24) * k, width: 48 * k, height: 48 * k } });
  return page.evaluate(async (b64) => {
    const img = await createImageBitmap(await (await fetch(`data:image/png;base64,${b64}`)).blob());
    const c = new OffscreenCanvas(img.width, img.height);
    const ctx = c.getContext('2d')!;
    ctx.drawImage(img, 0, 0);
    const d = ctx.getImageData(0, 0, img.width, img.height).data;
    let best = -1;
    let out: [number, number, number] = [0, 0, 0];
    for (let i = 0; i < d.length; i += 4) {
      const l = d[i] + d[i + 1] + d[i + 2];
      if (l > best) {
        best = l;
        out = [d[i], d[i + 1], d[i + 2]];
      }
    }
    return out;
  }, png.toString('base64'));
}

test('(a) U1: inställningsarkets på-ikoner är hud-vita, även siktlinjen; av = hudDim', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 320, 36);
  await page.waitForFunction(() => window.__start?.sheetOpen === true);
  await page.waitForTimeout(500);
  // Arkets rader y 404/468/532/596: ljud, haptik, lugnt, siktlinje. Ikonen står vid x 44.
  const sound = await iconColor(page, 44, 404);
  const haptic = await iconColor(page, 44, 468);
  const calmOff = await iconColor(page, 44, 532);
  const aim = await iconColor(page, 44, 596);
  console.log(`[e2e] ikoner: ljud ${sound} haptik ${haptic} lugnt(av) ${calmOff} sikt ${aim}`);
  // hud #EAF2FF: rött > 200. accent #7CF9FF hade rött ≈ 124.
  for (const c of [sound, haptic, aim]) expect(c[0]).toBeGreaterThan(200);
  for (let i = 0; i < 3; i++) expect(Math.abs(aim[i] - sound[i])).toBeLessThanOrEqual(16);
  // Av-läge: hudDim #8FA3C8.
  expect(calmOff[0]).toBeLessThan(170);
  await tap(page, 180, 596);
  await page.waitForTimeout(200);
  const aimOff = await iconColor(page, 44, 596);
  expect(aimOff[0]).toBeLessThan(170);
  expect(aimOff[2]).toBeLessThan(220);
  await tap(page, 180, 596);
  // Lugnt läge på: också hud-vit (beslut efter U1).
  await tap(page, 180, 532);
  await page.waitForTimeout(200);
  const calmOn = await iconColor(page, 44, 532);
  for (let i = 0; i < 3; i++) expect(Math.abs(calmOn[i] - sound[i])).toBeLessThanOrEqual(16);
  await tap(page, 180, 532);
  expect(errors).toEqual([]);
});

test('(b) U7: boken öppnar på Kompisar när en ny kompis finns, pulsen slutar efter 2 s', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page, { settings: { bookHintSeen: true }, avatars: { owned: ['lisa', 'siri'], equipped: 'siri', fresh: ['lisa'] } });
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 180, 506); // Kompisar-kortet
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  expect(await page.evaluate(() => window.__book!.tab)).toBe('friends');
  expect(await page.evaluate(() => window.__book!.pulsingFriends)).toBe(1);
  expect(await page.evaluate(() => window.__book!.scrollHint)).toBe(true);
  await page.waitForTimeout(1000);
  // Fortfarande nytt efter 1 s.
  expect(await page.evaluate(() => window.__book!.pulsingFriends)).toBe(1);
  expect((await saved(page)).avatars.fresh).toEqual(['lisa']);
  await page.screenshot({ path: 'tests/e2e/screenshots/book-friends-fresh.png' });
  await page.waitForFunction(() => window.__book!.pulsingFriends === 0, undefined, { timeout: 15_000 });
  expect((await saved(page)).avatars.fresh).toEqual([]);

  // Tryck på en siluett: inga fel (bara cellen skakar).
  const cell = await page.evaluate(() => window.__book!.cellOf('maja'));
  await tap(page, cell!.x, cell!.y);
  // Scroll tonar bort scroll-ledtråden och sparas.
  const a = await toCanvas(page, 180, 520);
  const b = await toCanvas(page, 180, 360);
  await page.mouse.move(a.x, a.y);
  await page.mouse.down();
  await page.mouse.move(b.x, b.y, { steps: 6 });
  await page.mouse.up();
  await page.waitForTimeout(400);
  expect(await page.evaluate(() => window.__book!.scrollHint)).toBe(false);
  expect((await saved(page)).settings.friendsHintSeen).toBe(true);

  // Inget nytt längre: boken öppnar på Set.
  await tap(page, 320, 44);
  await page.waitForFunction(() => window.__book === undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(300);
  await tap(page, 66.5, 506);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  expect(await page.evaluate(() => window.__book!.tab)).toBe('sets');
  expect(errors).toEqual([]);
});

test('(c) U4: svep-ledtråden visas första gången boken öppnas, inte andra', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 66.5, 506);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  // Skärmdumpen fångas ~0,5 s efter anropet i headless: då är handen mitt i svepet.
  await page.screenshot({ path: 'tests/e2e/screenshots/book-hint.png' });
  expect(await page.evaluate(() => window.__book!.hintShown)).toBe(true);
  expect((await saved(page)).settings.bookHintSeen).toBe(true);
  await page.waitForFunction(() => window.__book!.hintActive === false, undefined, { timeout: 5_000 });
  expect(await page.evaluate(() => window.__book!.page)).toBe(0);

  await tap(page, 320, 44);
  await page.waitForFunction(() => window.__book === undefined, undefined, { timeout: 5_000 });
  await page.reload();
  await page.waitForTimeout(1200);
  await tap(page, 66.5, 506);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  await page.waitForTimeout(700);
  expect(await page.evaluate(() => window.__book!.hintShown)).toBe(false);
  expect(await page.evaluate(() => window.__book!.hintActive)).toBe(false);
  expect(errors).toEqual([]);
});

test('(d) U4: Escape (bakåtknappens fallback) stänger boken', async ({ page }) => {
  const errors = collectErrors(page);
  await seedSave(page, { settings: { bookHintSeen: true } });
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 66.5, 506);
  await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 5_000 });
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__book === undefined && window.__start !== undefined, undefined, { timeout: 5_000 });
  // Escape på startskärmen utan öppning gör ingenting.
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);
  expect(await page.evaluate(() => window.__start !== undefined)).toBe(true);
  expect(errors).toEqual([]);
});

test('(e) U6: Lisas oljemätare syns vid Släpparen och försvinner när oljan är slut', async ({ page }) => {
  test.setTimeout(90_000);
  const errors = collectErrors(page);
  await seedSave(page);
  await page.goto('/?test=1');
  await page.waitForTimeout(1200);
  await tap(page, 180, 390);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 10_000 });
  await page.evaluate(() => window.__game!.equipForTest('lisa'));
  await page.waitForFunction(() => window.__game?.abilityState.id === 'lisa', undefined, { timeout: 5_000 });
  await page.waitForTimeout(300);
  await page.evaluate(() => window.__game!.setPacing('off'));
  expect(await page.evaluate(() => window.__game!.lanternMeterVisible)).toBe(true);

  const p = await toCanvas(page, 200, 300);
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.waitForFunction(() => window.__game!.abilityState.lisa.oilMs < 3000, undefined, { timeout: 15_000 });
  expect(await page.evaluate(() => window.__game!.lanternMeterVisible)).toBe(true);
  await page.screenshot({ path: 'tests/e2e/screenshots/lantern-meter.png' });
  await page.waitForFunction(() => window.__game!.abilityState.lisa.oilMs === 0, undefined, { timeout: 15_000 });
  await page.waitForTimeout(400);
  expect(await page.evaluate(() => window.__game!.lanternMeterVisible)).toBe(false);
  await page.mouse.up();
  expect(errors).toEqual([]);
});
