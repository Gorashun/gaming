#!/usr/bin/env node
/**
 * CI smoke check on a built dist (docs/RELEASE.md): boots the game, starts a round, drops one object.
 * Fails on a page error, a console error, or no body in the jar. ~10 s; not a substitute for `npm run e2e`.
 *
 *   node scripts/smoke.mjs [--dir dist] [--port 4192] [--channel chrome]
 *
 * `--channel chrome` uses the runner's installed Google Chrome (no browser download in CI).
 * Without it, Playwright's Chromium from PLAYWRIGHT_BROWSERS_PATH is used.
 */
import { chromium } from '@playwright/test';
import { preview } from 'vite';
import { resolve } from 'node:path';

function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : def;
}
const dir = resolve(arg('dir', 'dist'));
const port = Number(arg('port', '4192'));
const channel = arg('channel', undefined);

const server = await preview({ configFile: false, root: process.cwd(), base: './', logLevel: 'silent', build: { outDir: dir }, preview: { port, strictPort: true } });
// SwiftShader keeps WebGL available on GPU-less runners (newer Chrome no longer falls back silently).
const browser = await chromium.launch({ ...(channel ? { channel } : {}), args: ['--enable-unsafe-swiftshader'] });
const errors = [];
let ok = false;
try {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true });
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => m.type() === 'error' && errors.push(`console: ${m.text()}`));
  page.on('response', (r) => r.status() >= 400 && errors.push(`http ${r.status()}: ${r.url()}`));
  const t0 = Date.now();
  await page.goto(`http://localhost:${port}/?test=1`);
  await page.waitForFunction(() => window.__start !== undefined, undefined, { timeout: 30_000 });
  const startMs = Date.now() - t0;

  // Tap PLAY (Start v2: logical (180, 390) in the 360×640 world).
  const box = await page.locator('canvas').boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + (box.height * 390) / 640);
  await page.mouse.down();
  await page.mouse.up();
  await page.waitForFunction(() => window.__game !== undefined && !window.__game.over, undefined, { timeout: 15_000 });
  await page.evaluate(() => window.__game.drop(180));
  await page.waitForTimeout(1500);
  const bodies = await page.evaluate(() => window.__game.bodyCount);
  ok = bodies >= 1 && errors.length === 0;
  console.log(`smoke: start ${startMs} ms, bodies ${bodies}, errors ${errors.length}`);
} catch (e) {
  errors.push(String(e));
} finally {
  await browser.close();
  await new Promise((r) => server.httpServer.close(r));
}
for (const e of errors) console.error(`smoke: ${e}`);
if (!ok) {
  console.error('smoke: FAILED');
  process.exit(1);
}
console.log('smoke: OK');
