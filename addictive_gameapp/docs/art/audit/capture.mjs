// Art audit capture (art director): 390x844 @2x against a preview build on :4190.
// Build: cd app && npx vite build --outDir /tmp/art-dist && npx vite preview --outDir /tmp/art-dist --port 4190
// Run:   node docs/art/audit/capture.mjs [start game merge chain special jackpot danger gameover book shell upgrade sets firstframe]
import { createRequire } from 'node:module';
import fs from 'node:fs';
const require = createRequire('/home/user/gaming/addictive_gameapp/app/package.json');
const { chromium } = require('@playwright/test');

const BASE_URL = 'http://localhost:4190';
const OUT = process.env.OUT || (await import('node:os')).tmpdir() + '/klunk-art-audit';
fs.mkdirSync(OUT, { recursive: true });
const only = process.argv.slice(2);

const KEY = 'klunk.save.v1';
const BASE = {
  schema: 2,
  highscore: 2480,
  bestLevel: 7,
  stats: { runs: 9, merges: 412 },
  unlockedSets: ['glimtarna', 'gloden'],
  collection: { glimtarna: { caught: [true, true, true, true, true, true, true, true] } },
  economy: { pearls: 1240, sand: 18 },
  avatars: { owned: ['lisa', 'siri', 'maja', 'vala', 'muller'], equipped: 'siri', level: { siri: 2 } },
  highscoreAvatar: 'lisa',
  settings: { bookHintSeen: true, friendsHintSeen: true },
};

const browser = await chromium.launch();

async function newPage(save) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, hasTouch: true });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('  pageerror', e.message));
  if (save !== null) {
    await page.addInitScript(([k, x]) => {
      if (!localStorage.getItem(k)) localStorage.setItem(k, JSON.stringify(x));
    }, [KEY, save ?? BASE]);
  }
  return { ctx, page };
}
async function tap(page, wx, wy) {
  const b = await page.locator('canvas').boundingBox();
  await page.mouse.move(b.x + (wx * b.width) / 360, b.y + (wy * b.height) / 640);
  await page.mouse.down();
  await page.mouse.up();
}
const shot = (page, name) => page.screenshot({ path: `${OUT}/${name}.png` });
async function openStart(page, q = '') {
  await page.goto(`${BASE_URL}/?test=1${q}`);
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 30000 });
  await page.waitForTimeout(1500);
}
async function toGame(page) {
  await tap(page, 180, 390);
  await page.waitForFunction(() => window.__game !== undefined, undefined, { timeout: 30000 });
  await page.waitForTimeout(800);
  await page.evaluate(() => window.__game.setPacing('off'));
}
const G = (page, fn, arg) => page.evaluate(fn, arg);

const scenes = {
  async start() {
    const { ctx, page } = await newPage();
    await openStart(page);
    await shot(page, '01-start');
    await tap(page, 320, 36);
    await page.waitForTimeout(600);
    await shot(page, '02-settings');
    await ctx.close();
    const n = await newPage(null);
    await openStart(n.page);
    await n.page.waitForTimeout(600);
    await shot(n.page, '01b-start-new-player');
    await n.ctx.close();
  },
  async game() {
    const { ctx, page } = await newPage();
    await openStart(page);
    await toGame(page);
    await G(page, () => { const g = window.__game; [90, 200, 270].forEach((x) => g.drop(x)); });
    await page.waitForTimeout(1600);
    await shot(page, '03-game-early');
    await G(page, () => {
      const g = window.__game; g.clear();
      const lv = [6, 4, 5, 3, 2, 3, 1, 2, 0];
      const xs = [90, 220, 290, 60, 150, 200, 260, 120, 300];
      const ys = [540, 560, 500, 440, 450, 470, 420, 400, 420];
      lv.forEach((l, i) => g.spawn(l, xs[i], ys[i]));
    });
    await page.waitForTimeout(1800);
    await shot(page, '04-game-mid');
    await G(page, () => {
      const g = window.__game; g.clear();
      const lv = [9, 7, 8, 6, 5, 4, 6, 3, 2, 5, 1, 3, 2, 0, 4, 1];
      const xs = [100, 260, 250, 90, 180, 50, 290, 150, 210, 300, 120, 60, 180, 240, 110, 300];
      const ys = [520, 530, 380, 360, 330, 280, 260, 250, 260, 200, 210, 200, 190, 200, 160, 160];
      lv.forEach((l, i) => g.spawn(l, xs[i], ys[i]));
    });
    await page.waitForTimeout(2200);
    await shot(page, '05-game-crowded');
    await ctx.close();
  },
  async merge() {
    const { ctx, page } = await newPage();
    await openStart(page);
    await toGame(page);
    await G(page, () => { const g = window.__game; g.clear(); g.spawn(3, 150, 560); g.spawn(2, 240, 570); g.spawn(4, 300, 555); });
    await page.waitForTimeout(1200);
    await G(page, () => { const g = window.__game; g.spawn(5, 170, 480); g.spawn(5, 200, 400); });
    for (const t of [120, 120, 150]) { await page.waitForTimeout(t); await shot(page, `06-merge-${t}-${Date.now() % 1000}`); }
    await ctx.close();
  },
  async chain() {
    const { ctx, page } = await newPage();
    await openStart(page);
    await toGame(page);
    await G(page, () => { const g = window.__game; g.clear(); g.spawn(6, 75, 545); g.spawn(6, 285, 545); g.spawn(6, 75, 435); g.spawn(6, 285, 435); g.spawn(3, 180, 565); g.spawn(2, 180, 505); });
    await page.waitForTimeout(1500);
    await G(page, () => { const g = window.__game; g.spawn(1, 178, 420); g.spawn(1, 182, 370); });
    for (let i = 0; i < 10; i++) { await page.waitForTimeout(120); await shot(page, `07-chain-${i}`); }
    console.log('  combo', await G(page, () => window.__game.combo));
    await ctx.close();
  },
  async special() {
    const which = process.env.KIND ? [[35, process.env.KIND]] : [[7, 'bomb'], [35, 'rainbow']];
    for (const [seed, kind] of which) {
      const { ctx, page } = await newPage(process.env.KIND ? null : undefined);
      await openStart(page);
      await toGame(page);
      await G(page, (s) => window.__game.seed(s), seed);
      await page.waitForTimeout(1200);
      await page.waitForFunction(() => window.__game !== undefined);
      await G(page, () => window.__game.setPacing('off'));
      let k = 'level';
      for (let d = 0; d < 80; d++) {
        k = await G(page, () => window.__game.nextKind);
        if (k !== 'level') break;
        await G(page, (x) => window.__game.drop(x), 60 + ((d * 53) % 240));
        await page.waitForTimeout(150);
        if (await G(page, () => window.__game.bodyCount >= 12)) await G(page, () => window.__game.clear());
      }
      console.log('  special', kind, k);
      // Build a crowd to hit.
      await G(page, () => { const g = window.__game; g.clear(); [[4, 120, 560], [4, 200, 560], [3, 280, 560], [2, 160, 500], [2, 230, 500], [5, 60, 540], [1, 300, 500]].forEach(([l, x, y]) => g.spawn(l, x, y)); });
      await page.waitForTimeout(1400);
      await shot(page, `08-${kind}-preview`);
      await G(page, () => window.__game.drop(320));
      await page.waitForTimeout(800);
      await shot(page, `08-${kind}-hanging`);
      await G(page, () => window.__game.drop(180));
      for (let i = 0; i < 10; i++) { await page.waitForTimeout(110); await shot(page, `08-${kind}-fx-${i}`); }
      await ctx.close();
    }
  },
  async jackpot() {
    const { ctx, page } = await newPage();
    await openStart(page);
    await toGame(page);
    await G(page, () => { const g = window.__game; g.clear(); g.spawn(3, 60, 560); g.spawn(4, 300, 550); g.spawn(9, 180, 500); });
    await page.waitForTimeout(1200);
    await G(page, () => window.__game.spawn(9, 190, 300));
    for (let i = 0; i < 10; i++) { await page.waitForTimeout(130); await shot(page, `10-jackpot-${i}`); }
    await ctx.close();
  },
  async danger() {
    const { ctx, page } = await newPage();
    await openStart(page);
    await toGame(page);
    await G(page, () => {
      const g = window.__game; g.clear();
      const lv = [8, 7, 6, 5, 7, 4, 3];
      const xs = [100, 260, 90, 200, 280, 160, 60];
      const ys = [520, 520, 390, 420, 380, 300, 290];
      lv.forEach((l, i) => g.spawn(l, xs[i], ys[i]));
      g.pin(5, 200, 128);
    });
    for (let i = 0; i < 6; i++) { await page.waitForTimeout(350); await shot(page, `11-danger-${i}`); }
    await ctx.close();
  },
  async gameover() {
    const { ctx, page } = await newPage({ ...BASE, highscore: 300, unlockedSets: ['glimtarna', 'gloden'] });
    await openStart(page);
    await toGame(page);
    await G(page, () => { const g = window.__game; g.clear(); g.forceShiny(2); g.spawn(1, 180, 575); g.spawn(1, 184, 520); });
    await page.waitForTimeout(1500);
    await G(page, () => { const g = window.__game; g.spawn(2, 176, 470); g.spawn(6, 60, 540); g.spawn(6, 70, 440); });
    await page.waitForTimeout(1500);
    await G(page, () => { window.__game.grantMerges(400); window.__game.forceLoss(); });
    const t0 = Date.now();
    for (const at of [150, 450, 800, 1200, 1700, 2300, 3000]) {
      await page.waitForTimeout(Math.max(0, at - (Date.now() - t0)));
      await shot(page, `12-gameover-${at}`);
    }
    await ctx.close();
  },
  async book() {
    const { ctx, page } = await newPage();
    await openStart(page);
    await tap(page, 66.5, 506);
    await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 30000 });
    await page.waitForTimeout(1200);
    await shot(page, '14-book-sets');
    const locked = await G(page, () => ({ locked: window.__book.locked, pages: window.__book.pages }));
    console.log('  book', JSON.stringify(locked));
    await G(page, () => window.__book.selectPage(2));
    await page.waitForTimeout(900);
    await shot(page, '15-book-locked');
    await G(page, () => window.__book.selectTab('friends'));
    await page.waitForTimeout(900);
    await shot(page, '16-buddies-shop');
    await G(page, () => { const c = window.__book.cellOf('siri'); return c; });
    await page.waitForTimeout(700);
    await shot(page, '16b-buddies-grid');
    await ctx.close();
  },
  async shell() {
    const { ctx, page } = await newPage({ ...BASE, avatars: { ...BASE.avatars, pendingBoxes: 1 } });
    await openStart(page);
    await shot(page, '17-start-shell-waiting');
    await tap(page, 293.5, 506);
    const t0 = Date.now();
    for (const at of [120, 300, 450, 650, 900, 1400]) {
      await page.waitForTimeout(Math.max(0, at - (Date.now() - t0)));
      await shot(page, `18-shell-${at}`);
    }
    await ctx.close();
  },
  async upgrade() {
    const { ctx, page } = await newPage({ ...BASE, economy: { pearls: 5000, sand: 200 }, avatars: { ...BASE.avatars, equipped: 'lisa' } });
    await openStart(page);
    await tap(page, 180, 506);
    await page.waitForFunction(() => window.__book !== undefined, undefined, { timeout: 30000 });
    await G(page, () => window.__book.selectTab('friends'));
    await page.waitForTimeout(900);
    const st = await G(page, () => window.__book.stage);
    console.log('  stage', JSON.stringify(st));
    await shot(page, '19-upgrade-before');
    await tap(page, 224, 314);
    await page.waitForTimeout(350);
    await shot(page, '19-upgrade-awake');
    await tap(page, 224, 314);
    for (const at of [100, 350, 800]) { await page.waitForTimeout(at === 100 ? 100 : 250); await shot(page, `19-upgrade-${at}`); }
    console.log('  stage after', JSON.stringify(await G(page, () => window.__book.stage)));
    await ctx.close();
  },
  async sets() {
    const all = ['glimtarna', 'planeterna', 'frostisarna', 'godisarna', 'gloden'];
    for (const s of all) {
      const { ctx, page } = await newPage({ ...BASE, unlockedSets: all, activeSet: s });
      await openStart(page);
      await toGame(page);
      await G(page, () => {
        const g = window.__game; g.clear();
        const lv = [8, 6, 5, 4, 3, 2, 1, 0, 7];
        const xs = [110, 260, 60, 200, 290, 150, 230, 100, 250];
        const ys = [520, 540, 440, 450, 440, 400, 380, 380, 300];
        lv.forEach((l, i) => g.spawn(l, xs[i], ys[i]));
      });
      await page.waitForTimeout(1800);
      await shot(page, `20-set-${s}`);
      await ctx.close();
    }
  },
  async firstframe() {
    const { ctx, page } = await newPage();
    const t0 = Date.now();
    page.goto(`${BASE_URL}/?test=1`);
    for (const at of [150, 400, 800]) {
      await page.waitForTimeout(Math.max(0, at - (Date.now() - t0)));
      await shot(page, `00-firstframe-${at}`);
    }
    await ctx.close();
  },
};

for (const [name, fn] of Object.entries(scenes)) {
  if (only.length && !only.includes(name)) continue;
  const t = Date.now();
  try { await fn(); console.log('ok', name, Date.now() - t, 'ms'); } catch (e) { console.log('FAIL', name, e.message.split('\n')[0]); }
}
await browser.close();
