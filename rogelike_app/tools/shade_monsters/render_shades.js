#!/usr/bin/env node
// Render the interim "shade" monsters: game-icons.net silhouettes (CC BY 3.0)
// turned into dark, solid charcoal/slag creatures lit by the torch.
//
// Input : tools/shade_monsters/shades.json (what to render, style knobs)
//         assets/incoming/game-icons-shades/svg/<author>__<name>.svg
//         (downloaded by tools/shade_monsters/fetch_shades.py)
// Output: assets/incoming/game-icons-shades/<ID>.png, transparent, square
//         (size from shades.json). tools/normalize_art.py takes it from there.
//
// Everything runs inside headless Chromium (Playwright): the SVG is rasterised
// on a canvas, the grain is an SVG feTurbulence, the inner bevel is an SVG
// feMorphology erode + feGaussianBlur, and the layers are combined with plain
// pixel math. No randomness outside feTurbulence's fixed seed, so the same
// shades.json gives the same PNGs (bit-exact on the same Chromium build).
//
// Usage (from rogelike_app/):
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers \
//   NODE_PATH=/opt/node22/lib/node_modules node tools/shade_monsters/render_shades.js
//   ... render_shades.js --only RUST_RAT          one figure
//   ... render_shades.js --debug-grid             draw a 64-unit icon grid (for eye placement)
//   ... render_shades.js --out DIR                write somewhere else

'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..', '..');
const SPEC = path.join(__dirname, 'shades.json');

function parseArgs(argv) {
  const args = { only: '', out: '', debugGrid: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--only') args.only = argv[++i];
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--debug-grid') args.debugGrid = true;
    else throw new Error(`unknown argument ${a}`);
  }
  return args;
}

// Strip the black 512x512 background square every game-icons SVG carries and
// force the figure white, so its alpha is the silhouette.
function figureSvg(raw) {
  let svg = raw.replace(/<path d="M0 0h512v512H0z"\s*\/>/, '');
  svg = svg.replace(/fill="#[0-9a-fA-F]{3,6}"/g, 'fill="#fff"');
  if (!/viewBox="0 0 512 512"/.test(svg)) throw new Error('unexpected viewBox (expected 0 0 512 512)');
  return svg;
}

// ---------------------------------------------------------------------------
// Everything below renderInPage() runs in the browser.
// ---------------------------------------------------------------------------
async function renderInPage(job) {
  const { svg, size, ss, style, shade, debugGrid } = job;
  const W = size * ss;            // supersampled canvas
  const H = W;
  const margin = Math.round(W * (shade.margin ?? style.margin));
  const iconPx = W - 2 * margin;  // the 512-unit icon box on the canvas
  const u = iconPx / 512;         // canvas px per icon unit
  const px = ss;                  // canvas px per output px

  const loadImage = (src) => new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('image load failed'));
    img.src = src;
  });
  const svgUrl = (text) => 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(text)));
  const canvas = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };

  // 1. Rasterise the figure.
  const figImg = await loadImage(svgUrl(svg.replace('<svg ', `<svg width="512" height="512" `)));
  const c0 = canvas(W, H);
  const g0 = c0.getContext('2d');
  const flip = shade.flip ? -1 : 1;
  g0.save();
  if (shade.flip) { g0.translate(W, 0); g0.scale(-1, 1); }
  g0.drawImage(figImg, margin, margin, iconPx, iconPx);
  // erase: circles in icon units to cut away (stray bits that do not belong to the creature).
  g0.globalCompositeOperation = 'destination-out';
  for (const e of shade.erase || []) {
    g0.beginPath(); g0.arc(margin + e.x * u, margin + e.y * u, e.r * u, 0, Math.PI * 2); g0.fill();
  }
  g0.restore();
  const A = new Float32Array(W * H);
  { const d = g0.getImageData(0, 0, W, H).data; for (let i = 0; i < W * H; i++) A[i] = d[i * 4 + 3] / 255; }

  // 2. Body = figure with its enclosed holes filled (flood fill from outside).
  // Chamfer distance (3-4 metric / 3) from every pixel to the nearest seed pixel.
  const chamfer = (isSeed) => {
    const d = new Float32Array(W * H);
    for (let i = 0; i < W * H; i++) d[i] = isSeed(i) ? 0 : 1e9;
    const D1 = 1, D2 = Math.SQRT2;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = y * W + x; if (d[i] === 0) continue;
      let v = d[i];
      if (x > 0) v = Math.min(v, d[i - 1] + D1);
      if (y > 0) { v = Math.min(v, d[i - W] + D1); if (x > 0) v = Math.min(v, d[i - W - 1] + D2); if (x < W - 1) v = Math.min(v, d[i - W + 1] + D2); }
      d[i] = v;
    }
    for (let y = H - 1; y >= 0; y--) for (let x = W - 1; x >= 0; x--) {
      const i = y * W + x; if (d[i] === 0) continue;
      let v = d[i];
      if (x < W - 1) v = Math.min(v, d[i + 1] + D1);
      if (y < H - 1) { v = Math.min(v, d[i + W] + D1); if (x < W - 1) v = Math.min(v, d[i + W + 1] + D2); if (x > 0) v = Math.min(v, d[i + W - 1] + D2); }
      d[i] = v;
    }
    return d;
  };
  // seal (icon units): gaps narrower than 2 x seal in the outline count as
  // closed, so an open ring (the tick's back) still fills as one body.
  const sealR = (shade.seal ?? 0) * u;
  const toFigure = sealR > 0 ? chamfer((i) => A[i] >= 0.5) : null;
  const passable = (i) => A[i] < 0.5 && (!toFigure || toFigure[i] > sealR);
  const outside = new Uint8Array(W * H);
  const stack = [];
  const push = (i) => { if (!outside[i] && passable(i)) { outside[i] = 1; stack.push(i); } };
  for (let x = 0; x < W; x++) { push(x); push((H - 1) * W + x); }
  for (let y = 0; y < H; y++) { push(y * W); push(y * W + W - 1); }
  while (stack.length) {
    const i = stack.pop(); const x = i % W; const y = (i / W) | 0;
    if (x > 0) push(i - 1); if (x < W - 1) push(i + 1);
    if (y > 0) push(i - W); if (y < H - 1) push(i + W);
  }
  if (sealR > 0) {
    // Grow the sealed outside back to the real outline (closing, not dilation).
    const toOutside = chamfer((i) => outside[i] === 1);
    for (let i = 0; i < W * H; i++) if (A[i] < 0.5 && toOutside[i] <= sealR + 1.5) outside[i] = 1;
  }
  // Holes wide enough to hold a disc of radius hole_keep_r (icon units) are
  // real gaps (between legs, inside a tail loop) and stay see-through; thinner
  // enclosed holes are the icon's drawing lines and become part of the body.
  const keepR = (shade.hole_keep_r ?? style.hole_keep_r) * u;
  {
    // Distance from each hole pixel to the nearest non-hole pixel.
    const dist = chamfer((i) => !(!outside[i] && A[i] < 0.5));
    // Flood each hole component; if any pixel is deeper than keepR, open it.
    const seen = new Uint8Array(W * H);
    for (let s = 0; s < W * H; s++) {
      if (seen[s] || dist[s] === 0) continue;
      const comp = [s]; seen[s] = 1; let deep = false;
      for (let n = 0; n < comp.length; n++) {
        const i = comp[n]; if (dist[i] > keepR) deep = true;
        const x = i % W;
        const nb = [x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, i - W, i + W];
        for (const j of nb) if (j >= 0 && j < W * H && !seen[j] && dist[j] > 0) { seen[j] = 1; comp.push(j); }
      }
      if (deep) for (const i of comp) outside[i] = 1;
    }
  }
  const B = new Float32Array(W * H);  // body alpha
  const L = new Float32Array(W * H);  // interior lines (the icon's holes)
  const linesMode = shade.lines ?? 'incise';
  for (let i = 0; i < W * H; i++) {
    B[i] = (!outside[i] && A[i] < 0.5) ? 1 : A[i];
    L[i] = linesMode === 'fill' ? 0 : Math.max(0, B[i] - A[i]);
  }
  // Depth inside a line (px): thin cuts are cut deep, a wide filled hole (the
  // tick's shell) only darkens a little and keeps its texture and light.
  const lineDepth = chamfer((i) => L[i] < 0.5);

  // Figure bounding box (for the vertical rim gradient and the boss glow).
  let minY = H, maxY = 0, minX = W, maxX = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (B[y * W + x] > 0.03) { if (y < minY) minY = y; if (y > maxY) maxY = y; if (x < minX) minX = x; if (x > maxX) maxX = x; }
  }

  // Helpers: mask -> PNG data URL, SVG filter pass -> Float32 channel.
  const maskUrl = (M) => {
    const c = canvas(W, H); const g = c.getContext('2d');
    const img = g.createImageData(W, H);
    for (let i = 0; i < W * H; i++) { const o = i * 4; img.data[o] = 255; img.data[o + 1] = 255; img.data[o + 2] = 255; img.data[o + 3] = Math.round(M[i] * 255); }
    g.putImageData(img, 0, 0);
    return c.toDataURL('image/png');
  };
  const filterPass = async (body, filterXml, channel) => {
    const doc = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
      <defs><filter id="f" x="0" y="0" width="${W}" height="${H}" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">${filterXml}</filter></defs>
      ${body}</svg>`;
    const img = await loadImage(svgUrl(doc));
    const c = canvas(W, H); const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, W, H).data;
    const out = new Float32Array(W * H);
    const ch = channel === 'a' ? 3 : 0;
    for (let i = 0; i < W * H; i++) out[i] = d[i * 4 + ch] / 255;
    return out;
  };
  const bodyUrl = maskUrl(B);
  const bodyImage = `<image href="${bodyUrl}" x="0" y="0" width="${W}" height="${H}" filter="url(#f)"/>`;
  const blurA = (sigma) => filterPass(bodyImage, `<feGaussianBlur in="SourceAlpha" stdDeviation="${sigma}"/>`, 'a');

  // 3. Height field: big soft form + an inner bevel (erode + blur) + mottle.
  const bigForm = await blurA(style.form_blur * px);
  const bevel = await filterPass(bodyImage,
    `<feMorphology in="SourceAlpha" operator="erode" radius="${style.bevel_erode * px}"/>
     <feGaussianBlur stdDeviation="${style.bevel_blur * px}"/>`, 'a');
  const grain = await filterPass(`<rect width="${W}" height="${H}" filter="url(#f)"/>`,
    `<feTurbulence type="fractalNoise" baseFrequency="${style.grain_freq / px}" numOctaves="3" seed="${shade.seed ?? 7}"/>
     <feColorMatrix type="matrix" values="0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0 0 0 0 1"/>`, 'r');
  const mottle = await filterPass(`<rect width="${W}" height="${H}" filter="url(#f)"/>`,
    `<feTurbulence type="fractalNoise" baseFrequency="${style.mottle_freq / px}" numOctaves="4" seed="${(shade.seed ?? 7) + 31}"/>
     <feColorMatrix type="matrix" values="0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0 0 0 0 1"/>`, 'r');
  const Lurl = maskUrl(L);
  const lineImage = `<image href="${Lurl}" x="0" y="0" width="${W}" height="${H}" filter="url(#f)"/>`;
  const lineGlowNear = await filterPass(lineImage, `<feGaussianBlur in="SourceAlpha" stdDeviation="${2.5 * px}"/>`, 'a');
  const lineGlowFar = await filterPass(lineImage, `<feGaussianBlur in="SourceAlpha" stdDeviation="${9 * px}"/>`, 'a');
  // Rim mask: opaque here, transparent a step toward the torch = the lit edge.
  // The wide rim is the same edge blurred and kept inside the body.
  const lf0 = style.light_from; const ln0 = Math.hypot(lf0[0], lf0[1]);
  const rimTight = new Float32Array(W * H);
  {
    const dx = lf0[0] / ln0 * style.rim_px * px, dy = lf0[1] / ln0 * style.rim_px * px;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = y * W + x; if (B[i] <= 0) continue;
      const xs = Math.round(x + dx), ys = Math.round(y + dy);
      const t = (xs < 0 || ys < 0 || xs >= W || ys >= H) ? 0 : B[ys * W + xs];
      rimTight[i] = B[i] * (1 - t);
    }
  }
  const rimWide = await filterPass(`<image href="${maskUrl(rimTight)}" x="0" y="0" width="${W}" height="${H}" filter="url(#f)"/>`,
    `<feGaussianBlur in="SourceAlpha" stdDeviation="${style.rim_broad_blur * px}"/>`, 'a');

  // Eyes: ellipses in icon units, drawn as their own mask + halo.
  const E = new Float32Array(W * H);
  let eyeHalo = new Float32Array(W * H);
  const eyes = shade.eyes || [];
  if (eyes.length) {
    const c = canvas(W, H); const g = c.getContext('2d');
    g.fillStyle = '#fff';
    for (const e of eyes) {
      const ex = shade.flip ? 512 - e.x : e.x;
      g.save();
      g.translate(margin + ex * u, margin + e.y * u);
      g.rotate(((e.rot || 0) * flip) * Math.PI / 180);
      g.beginPath(); g.ellipse(0, 0, e.rx * u, e.ry * u, 0, 0, Math.PI * 2); g.fill();
      g.restore();
    }
    const d = g.getImageData(0, 0, W, H).data;
    for (let i = 0; i < W * H; i++) E[i] = d[i * 4 + 3] / 255;
    eyeHalo = await filterPass(`<image href="${c.toDataURL('image/png')}" x="0" y="0" width="${W}" height="${H}" filter="url(#f)"/>`,
      `<feGaussianBlur in="SourceAlpha" stdDeviation="${style.eye_halo * px}"/>`, 'a');
  }

  // 4. Shade.
  const hex = (h) => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255];
  const C = {};
  for (const k of Object.keys(style.colors)) C[k] = hex(style.colors[k]);
  const lf = style.light_from;                      // screen vector toward the torch (y down)
  const ln = Math.hypot(lf[0], lf[1]);
  const lx = lf[0] / ln, ly = lf[1] / ln;
  const el = style.light_elevation * Math.PI / 180;
  const Lw = [Math.cos(el) * lx, Math.cos(el) * ly, Math.sin(el)];
  const Lc = [-Math.cos(el) * lx * 0.9, Math.cos(el) * 0.3, Math.sin(el)]; // cool soot fill from the other side
  const sample = (M, x, y) => {
    const xi = Math.round(x), yi = Math.round(y);
    if (xi < 0 || yi < 0 || xi >= W || yi >= H) return 0;
    return M[yi * W + xi];
  };
  const H0 = new Float32Array(W * H);
  for (let i = 0; i < W * H; i++) {
    H0[i] = style.form_weight * bigForm[i] + (1 - style.form_weight) * bevel[i] + style.mottle_relief * (mottle[i] - 0.5);
  }
  const glow = shade.inner_glow;
  const gcx = glow ? margin + (shade.flip ? 512 - glow.x : glow.x) * u : 0;
  const gcy = glow ? margin + glow.y * u : 0;
  const gr = glow ? glow.r * u : 1;
  const out = new Uint8ClampedArray(W * H * 4);
  const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
  const k = style.surface_scale;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      const b = B[i];
      const e = E[i];
      const alpha = Math.max(b, e);
      if (alpha <= 0.002) continue;
      // Normal from the height field.
      const hx = (x > 0 && x < W - 1) ? H0[i + 1] - H0[i - 1] : 0;
      const hy = (y > 0 && y < H - 1) ? H0[i + W] - H0[i - W] : 0;
      let nx = -hx * k, ny = -hy * k, nz = 1;
      const nl = Math.hypot(nx, ny, nz); nx /= nl; ny /= nl; nz /= nl;
      const dw = nx * Lw[0] + ny * Lw[1] + nz * Lw[2];
      const dc = nx * Lc[0] + ny * Lc[1] + nz * Lc[2];
      const warm = Math.max(0, (dw - Lw[2]) / (1 - Lw[2]));
      const cool = Math.max(0, (dc - Lc[2]) / (1 - Lc[2]));
      const gr0 = grain[i] - 0.5;
      const mo = mottle[i] - 0.5;
      // Base: charcoal, mottled towards slag brown, grainy.
      let col = mix(C.body, C.body_slag, Math.min(1, Math.max(0, 0.5 + mo * 2.2)));
      const tex = 1 + style.grain * gr0 * 2;
      col = [col[0] * tex, col[1] * tex, col[2] * tex];
      col = [col[0] + C.lit[0] * Math.pow(warm, 1.3) * style.key, col[1] + C.lit[1] * Math.pow(warm, 1.3) * style.key, col[2] + C.lit[2] * Math.pow(warm, 1.3) * style.key];
      col = [col[0] + C.fill[0] * cool * style.fill, col[1] + C.fill[1] * cool * style.fill, col[2] + C.fill[2] * cool * style.fill];
      // Rim: opaque here, transparent a step toward the torch = the lit edge.
      const tight = rimTight[i];
      const wide = b * Math.min(1, rimWide[i] * 2.5);
      const t = Math.min(1, Math.max(0, (y - minY) / Math.max(1, maxY - minY)));
      const rimCol = t < 0.35 ? mix(C.rim_hot, C.rim, t / 0.35) : mix(C.rim, C.rim_rust, (t - 0.35) / 0.65);
      const rimAmt = (tight * style.rim_tight + wide * style.rim_wide) * (0.75 + 0.5 * (grain[i]));
      col = [col[0] + rimCol[0] * rimAmt, col[1] + rimCol[1] * rimAmt, col[2] + rimCol[2] * rimAmt];
      // Cool counter-rim on the far side so the shape reads on a dark wall.
      const cd = style.rim_px * px;
      const counter = b * (1 - sample(B, x - lx * cd, y - ly * cd * 0.3));
      col = [col[0] + C.counter[0] * counter * style.counter, col[1] + C.counter[1] * counter * style.counter, col[2] + C.counter[2] * counter * style.counter];
      // Interior lines.
      const l = L[i];
      if (linesMode === 'incise') {
        const lip = b * (1 - l) * sample(L, x + lx * 2 * px, y + ly * 2 * px);
        const wide = Math.min(1, Math.max(0, (lineDepth[i] / u - 5) / 6));
        col = mix(col, C.incise, l * (0.92 - 0.55 * wide));
        col = [col[0] + rimCol[0] * lip * style.lip, col[1] + rimCol[1] * lip * style.lip, col[2] + rimCol[2] * lip * style.lip];
      } else if (linesMode === 'ember') {
        // Molten, not a lamp: the heat is broken up by the mottle and grain.
        const heat = Math.min(1, lineGlowNear[i] * 1.1) * (0.45 + 0.9 * Math.max(0, mo + 0.35)) * (0.85 + 0.3 * grain[i]);
        const ember = heat < 0.5 ? mix(C.ember_deep, C.ember, heat * 2) : mix(C.ember, C.ember_hot, (heat - 0.5) * 2);
        col = mix(col, ember, l);
        const halo = lineGlowFar[i] * (1 - l) * style.ember_halo;
        col = [col[0] + C.ember[0] * halo, col[1] + C.ember[1] * halo, col[2] + C.ember[2] * halo];
      }
      // Boss: a slow inner glow, broken up by the mottle so it reads as heat in slag.
      if (glow) {
        const r2 = ((x - gcx) ** 2 + (y - gcy) ** 2) / (gr * gr);
        const gi = Math.exp(-r2 * 2.2) * glow.strength * Math.max(0, bigForm[i] * 1.3 - 0.2) * (0.55 + 1.2 * Math.max(0, mo + 0.15));
        col = [col[0] + C.ember[0] * gi, col[1] + C.ember[1] * gi * 0.8, col[2] + C.ember[2] * gi * 0.6];
      }
      // Eyes on top: hot core, ember halo inside the body.
      if (eyes.length) {
        const halo = eyeHalo[i] * b * style.eye_glow;
        col = [col[0] + C.ember[0] * halo, col[1] + C.ember[1] * halo, col[2] + C.ember[2] * halo];
        const coreT = Math.min(1, e);
        col = mix(col, mix(C.ember, C.eye, Math.min(1, eyeHalo[i] * 1.6)), coreT);
      }
      const o = i * 4;
      out[o] = col[0] * 255; out[o + 1] = col[1] * 255; out[o + 2] = col[2] * 255; out[o + 3] = alpha * 255;
    }
  }
  if (debugGrid) {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const ix = (x - margin) / u, iy = (y - margin) / u;
      if (Math.abs(ix % 64) < 0.8 / u * px || Math.abs(iy % 64) < 0.8 / u * px) {
        const o = (y * W + x) * 4; out[o] = 60; out[o + 1] = 160; out[o + 2] = 255; out[o + 3] = 255;
      }
    }
  }
  const big = canvas(W, H);
  big.getContext('2d').putImageData(new ImageData(out, W, H), 0, 0);
  // Downsample in halving steps (box-like, keeps the grain crisp but not aliased).
  let src = big;
  while (src.width > size) {
    const next = canvas(Math.max(size, src.width / 2), Math.max(size, src.height / 2));
    const g = next.getContext('2d');
    g.imageSmoothingEnabled = true;
    g.imageSmoothingQuality = 'high';
    g.drawImage(src, 0, 0, next.width, next.height);
    src = next;
  }
  return src.toDataURL('image/png');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const spec = JSON.parse(fs.readFileSync(SPEC, 'utf8'));
  const svgDir = path.join(ROOT, spec.svg_dir);
  const outDir = args.out ? path.resolve(args.out) : path.join(ROOT, spec.out_dir);
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.setContent('<html><body></body></html>');
    for (const shade of spec.shades) {
      if (args.only && shade.id !== args.only) continue;
      const file = path.join(svgDir, shade.icon.replace('/', '__') + '.svg');
      if (!fs.existsSync(file)) throw new Error(`${shade.id}: ${file} missing, run tools/shade_monsters/fetch_shades.py first`);
      const svg = figureSvg(fs.readFileSync(file, 'utf8'));
      const job = { svg, size: shade.size, ss: spec.style.supersample, style: spec.style, shade, debugGrid: args.debugGrid };
      const url = await page.evaluate(renderInPage, job);
      const png = Buffer.from(url.split(',')[1], 'base64');
      const target = path.join(outDir, `${shade.id}.png`);
      fs.writeFileSync(target, png);
      console.log(`${shade.id.padEnd(14)} ${shade.icon.padEnd(24)} ${shade.size}x${shade.size} -> ${path.relative(ROOT, target)}`);
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
