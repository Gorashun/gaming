#!/usr/bin/env node
/**
 * Performance budgets (docs/RELEASE.md): bundle size, cold start, texture memory, bench fps.
 *
 *   node scripts/measure.mjs --dir <built dist> [--port 4191] [--runs 5] [--dpr 1,2] [--throttle 1,4] [--json out.json]
 *
 * Serves the build with `vite preview` on its own port and drives headless Chromium
 * (PLAYWRIGHT_BROWSERS_PATH, e.g. /opt/pw-browsers; never `playwright install`).
 *
 * Definitions
 *  - bundle: every .js in <dir>/assets, raw and gzip (zlib level 9). "startup" = entry + its static
 *    imports (what index.html loads before the game can boot).
 *  - cold start: fresh browser context (empty cache), navigate to `/?test=1`, time from navigation
 *    start to the first animation frame painted after the Start scene installed `window.__start`
 *    (the first frame that accepts a tap). Median of `runs`.
 *  - texture memory: WebGL texImage2D allocations still alive at that frame, w·h·4 bytes each
 *    (+1/3 when mipmaps were generated). Counts baked Canvas2D textures, Text objects and render
 *    targets (texImage2D without pixels: Phaser's pipeline framebuffers), which are reported apart.
 *  - bench fps: `/?bench=1` (~2000 additive particles), 3 s warm-up, frames counted over 5 s,
 *    without CPU throttling only (SwiftShader draws on the CPU, so throttling would double-count).
 *
 * Headless Chromium renders WebGL with SwiftShader (CPU). Absolute fps is therefore pessimistic
 * for fill-rate and optimistic for JS; use the numbers to catch regressions between builds.
 */
import { chromium } from '@playwright/test';
import { preview } from 'vite';
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { gzipSync } from 'node:zlib';

function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : def;
}

const dir = resolve(arg('dir', 'dist'));
const port = Number(arg('port', '4191'));
const runs = Number(arg('runs', '5'));
const dprs = arg('dpr', '1,2').split(',').map(Number);
const throttles = arg('throttle', '1,4').split(',').map(Number);
const jsonOut = arg('json', null);
const skip = new Set((arg('skip', '') || '').split(',').filter(Boolean));
const base = `http://localhost:${port}`;

const median = (a) => {
  const s = [...a].sort((x, y) => x - y);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
const kb = (b) => Math.round(b / 102.4) / 10;
const mb = (b) => Math.round(b / 104857.6) / 10;

// ------------------------------------------------------------------ bundle
function bundle() {
  const html = readFileSync(join(dir, 'index.html'), 'utf8');
  const assets = join(dir, 'assets');
  const files = readdirSync(assets).filter((f) => f.endsWith('.js'));
  const entry = [...html.matchAll(/src="\.?\/?assets\/([^"]+\.js)"/g)].map((m) => m[1]);
  const preload = [...html.matchAll(/href="\.?\/?assets\/([^"]+\.js)"/g)].map((m) => m[1]);
  // Static imports of the entry chunk(s), transitively.
  const startup = new Set([...entry, ...preload]);
  const queue = [...startup];
  while (queue.length) {
    const f = queue.pop();
    const src = readFileSync(join(assets, f), 'utf8');
    for (const m of src.matchAll(/(?:^|[;\n}])\s*import\s*(?:[\w${},*\s]+from\s*)?["']\.\/([^"']+\.js)["']/g)) {
      if (!startup.has(m[1])) {
        startup.add(m[1]);
        queue.push(m[1]);
      }
    }
  }
  const rows = files.map((f) => {
    const buf = readFileSync(join(assets, f));
    return { file: f, raw: buf.length, gzip: gzipSync(buf, { level: 9 }).length, startup: startup.has(f) };
  });
  const sum = (k, pred = () => true) => rows.filter(pred).reduce((s, r) => s + r[k], 0);
  return {
    files: rows.sort((a, b) => b.raw - a.raw),
    totalRaw: sum('raw'),
    totalGzip: sum('gzip'),
    startupRaw: sum('raw', (r) => r.startup),
    startupGzip: sum('gzip', (r) => r.startup),
  };
}

// ------------------------------------------------------------------ browser instrumentation
/** Runs in the page before any app code. */
function instrument() {
  const w = window;
  w.__perf = { interactive: null, textures: null, gl: null, frames: [] };
  const live = new Map(); // WebGLTexture -> bytes
  const bound = new Map(); // texture unit -> WebGLTexture
  const mip = new Set();
  const patch = (proto, kind) => {
    if (!proto) return;
    const active = proto.activeTexture;
    const bind = proto.bindTexture;
    const img = proto.texImage2D;
    const del = proto.deleteTexture;
    const gen = proto.generateMipmap;
    proto.activeTexture = function (u) {
      this.__unit = u;
      return active.call(this, u);
    };
    proto.bindTexture = function (t, tex) {
      if (t === this.TEXTURE_2D) bound.set(this.__unit ?? this.TEXTURE0, tex);
      return bind.call(this, t, tex);
    };
    proto.texImage2D = function (...a) {
      const tex = bound.get(this.__unit ?? this.TEXTURE0);
      if (tex && a[1] === 0) {
        let wdt, hgt;
        let rt = false;
        if (a.length >= 8) {
          wdt = a[3];
          hgt = a[4];
          rt = a[8] == null; // no pixels: a render target (framebuffer colour attachment)
        } else {
          const s = a[5];
          wdt = s.videoWidth || s.naturalWidth || s.width || s.displayWidth || 0;
          hgt = s.videoHeight || s.naturalHeight || s.height || s.displayHeight || 0;
        }
        live.set(tex, { bytes: wdt * hgt * 4, rt });
      }
      w.__perf.gl = kind;
      return img.apply(this, a);
    };
    proto.generateMipmap = function (t) {
      const tex = bound.get(this.__unit ?? this.TEXTURE0);
      if (tex) mip.add(tex);
      return gen.call(this, t);
    };
    proto.deleteTexture = function (tex) {
      live.delete(tex);
      mip.delete(tex);
      return del.call(this, tex);
    };
  };
  patch(w.WebGLRenderingContext?.prototype, 'webgl1');
  patch(w.WebGL2RenderingContext?.prototype, 'webgl2');
  const texBytes = () => {
    const r = { bytes: 0, count: live.size, rtBytes: 0, rtCount: 0 };
    for (const [t, v] of live) {
      const b = mip.has(t) ? Math.round((v.bytes * 4) / 3) : v.bytes;
      r.bytes += b;
      if (v.rt) {
        r.rtBytes += b;
        r.rtCount++;
      }
    }
    return r;
  };
  w.__texBytes = texBytes;
  const poll = () => {
    if (w.__start && w.__perf.interactive === null) {
      // The frame after the hook appeared is the first one that shows Start and accepts input.
      requestAnimationFrame(() => {
        w.__perf.interactive = performance.now();
        w.__perf.textures = texBytes();
      });
      return;
    }
    requestAnimationFrame(poll);
  };
  requestAnimationFrame(poll);
}

async function newPage(browser, dpr, throttle) {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: dpr,
    hasTouch: true,
    isMobile: true,
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  await page.addInitScript(instrument);
  if (throttle > 1) {
    const cdp = await context.newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: throttle });
  }
  return { context, page, errors };
}

async function coldStart(browser, dpr, throttle) {
  const { context, page, errors } = await newPage(browser, dpr, throttle);
  await page.goto(`${base}/?test=1`);
  await page.waitForFunction(() => window.__perf.interactive !== null, undefined, { timeout: 60_000 });
  const r = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0];
    const fcp = performance.getEntriesByName('first-contentful-paint')[0];
    const heap = performance.memory ? performance.memory.usedJSHeapSize : null;
    const c = document.querySelector('canvas');
    return {
      interactive: window.__perf.interactive,
      domContentLoaded: nav ? nav.domContentLoadedEventEnd : null,
      fcp: fcp ? fcp.startTime : null,
      textures: window.__perf.textures,
      gl: window.__perf.gl,
      heap,
      canvas: c ? `${c.width}x${c.height}` : null,
    };
  });
  await context.close();
  return { ...r, errors };
}

async function benchFps(browser, dpr, throttle) {
  const { context, page, errors } = await newPage(browser, dpr, throttle);
  await page.goto(`${base}/?bench=1`);
  await page.waitForFunction(() => window.__fps > 0, undefined, { timeout: 60_000 });
  await page.waitForTimeout(3000);
  const fps = await page.evaluate(
    () =>
      new Promise((res) => {
        let n = 0;
        const t0 = performance.now();
        const worst = [];
        let last = t0;
        const tick = (t) => {
          n++;
          worst.push(t - last);
          last = t;
          if (t - t0 < 5000) requestAnimationFrame(tick);
          else {
            worst.sort((a, b) => b - a);
            res({ fps: (n / (t - t0)) * 1000, p95FrameMs: worst[Math.floor(worst.length * 0.05)] });
          }
        };
        requestAnimationFrame(tick);
      }),
  );
  await context.close();
  return { ...fps, errors };
}

// ------------------------------------------------------------------ main
const out = { dir, date: new Date().toISOString(), bundle: bundle(), cold: [], bench: [] };
const b = out.bundle;
console.log(`\nBundle (${dir})`);
for (const f of b.files) console.log(`  ${f.startup ? '*' : ' '} ${f.file.padEnd(34)} ${String(kb(f.raw)).padStart(8)} kB  gzip ${String(kb(f.gzip)).padStart(7)} kB`);
console.log(`  total ${kb(b.totalRaw)} kB, gzip ${kb(b.totalGzip)} kB; startup (*) gzip ${kb(b.startupGzip)} kB`);

const server = await preview({ configFile: false, root: process.cwd(), base: './', logLevel: 'silent', build: { outDir: dir }, preview: { port, strictPort: true } });
const browser = await chromium.launch();
try {
  for (const throttle of throttles) {
    for (const dpr of dprs) {
      if (!skip.has('cold')) {
        await coldStart(browser, dpr, throttle); // warm the OS file cache / JIT of the browser once
        const rs = [];
        for (let i = 0; i < runs; i++) rs.push(await coldStart(browser, dpr, throttle));
        const row = {
          dpr,
          throttle,
          interactiveMs: Math.round(median(rs.map((r) => r.interactive))),
          minMs: Math.round(Math.min(...rs.map((r) => r.interactive))),
          maxMs: Math.round(Math.max(...rs.map((r) => r.interactive))),
          fcpMs: Math.round(median(rs.map((r) => r.fcp ?? 0))),
          textureMB: mb(rs[0].textures.bytes),
          textureCount: rs[0].textures.count,
          renderTargetMB: mb(rs[0].textures.rtBytes),
          renderTargetCount: rs[0].textures.rtCount,
          heapMB: rs[0].heap ? mb(rs[0].heap) : null,
          gl: rs[0].gl,
          canvas: rs[0].canvas,
          errors: [...new Set(rs.flatMap((r) => r.errors))],
        };
        out.cold.push(row);
        console.log(
          `cold  dpr ${dpr} cpu×${throttle}: interactive ${row.interactiveMs} ms (min ${row.minMs}, max ${row.maxMs}), FCP ${row.fcpMs} ms, textures ${row.textureMB} MB in ${row.textureCount} (render targets ${row.renderTargetMB} MB in ${row.renderTargetCount}), heap ${row.heapMB} MB, ${row.gl} ${row.canvas}${row.errors.length ? `, ERRORS: ${row.errors.join(' | ')}` : ''}`,
        );
      }
      if (!skip.has('bench') && throttle === 1) {
        const r = await benchFps(browser, dpr, throttle);
        const row = { dpr, throttle, fps: Math.round(r.fps * 10) / 10, p95FrameMs: Math.round(r.p95FrameMs * 10) / 10, errors: r.errors };
        out.bench.push(row);
        console.log(`bench dpr ${dpr} cpu×${throttle}: ${row.fps} fps, p95 frame ${row.p95FrameMs} ms${r.errors.length ? `, ERRORS: ${r.errors.join(' | ')}` : ''}`);
      }
    }
  }
} finally {
  await browser.close();
  await new Promise((r) => server.httpServer.close(r));
}
if (jsonOut) writeFileSync(jsonOut, JSON.stringify(out, null, 2));
