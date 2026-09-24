#!/usr/bin/env node
// Render the interim "shade" monsters: game-icons.net silhouettes (CC BY 3.0)
// turned into dark, solid charcoal/slag creatures lit by the torch.
//
// Input : tools/shade_monsters/shades.json (what to render, style knobs)
//         assets/incoming/game-icons-shades/svg/<author>__<name>.svg
//         (downloaded by tools/shade_monsters/fetch_shades.py)
// Output: assets/incoming/game-icons-shades/<ID>.png           albedo, transparent
//         assets/incoming/game-icons-shades/<ID>_emissive.png  glow only (eyes,
//         ember cracks, inner heat) on opaque black, same canvas. The game adds
//         it after the torch light (battler.gdshader), so eyes glow in the dark.
// tools/normalize_art.py crops and scales both identically.
//
// A shade is one icon, or a composite of "layers" (back to front, the last is
// the front, e.g. the boss: two bat wings + a torso behind a skull).
//
// Everything runs inside headless Chromium (Playwright): the SVGs are
// rasterised on a canvas, the grain is an SVG feTurbulence, the inner bevel is
// an SVG feMorphology erode + feGaussianBlur, and the layers are combined with
// plain pixel math. No randomness outside feTurbulence's fixed seed, so the
// same shades.json gives the same PNGs (bit-exact on the same Chromium build).
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
// Everything in renderInPage() runs in the browser.
// ---------------------------------------------------------------------------
async function renderInPage(job) {
  const { size, ss, style, shade, debugGrid } = job;
  const outW = Array.isArray(size) ? size[0] : size;
  const outH = Array.isArray(size) ? size[1] : size;
  const W = outW * ss;            // supersampled canvas
  const H = outH * ss;
  const px = ss;                  // canvas px per output px
  const N = W * H;

  const loadImage = (src) => new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('image load failed'));
    img.src = src;
  });
  const svgUrl = (text) => 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(text)));
  const canvas = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };

  // Chamfer distance from every pixel to the nearest seed pixel.
  const chamfer = (isSeed) => {
    const d = new Float32Array(N);
    for (let i = 0; i < N; i++) d[i] = isSeed(i) ? 0 : 1e9;
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

  // One icon on the canvas -> {A: figure alpha, B: body (holes filled), L: lines, u, box}.
  // box = [x, y, w, h] of the 512-unit icon square in canvas px.
  const layerMasks = async (layer) => {
    const [bx, by, bw, bh] = layer.box;
    const u = bw / 512;
    const img = await loadImage(svgUrl(layer.svg.replace('<svg ', `<svg width="512" height="512" `)));
    const c0 = canvas(W, H);
    const g0 = c0.getContext('2d');
    g0.save();
    if (layer.flip) { g0.translate(bx * 2 + bw, 0); g0.scale(-1, 1); }
    g0.drawImage(img, bx, by, bw, bh);
    g0.restore();
    // erase: circles in icon units to cut away (stray bits that are not the creature).
    g0.globalCompositeOperation = 'destination-out';
    for (const e of layer.erase || []) {
      const ex = layer.flip ? 512 - e.x : e.x;
      g0.beginPath(); g0.arc(bx + ex * u, by + e.y * u, e.r * u, 0, Math.PI * 2); g0.fill();
    }
    const A = new Float32Array(N);
    { const d = g0.getImageData(0, 0, W, H).data; for (let i = 0; i < N; i++) A[i] = d[i * 4 + 3] / 255; }

    // seal (icon units): outline gaps narrower than 2 x seal count as closed.
    const sealR = (layer.seal ?? 0) * u;
    const toFigure = sealR > 0 ? chamfer((i) => A[i] >= 0.5) : null;
    const passable = (i) => A[i] < 0.5 && (!toFigure || toFigure[i] > sealR);
    const outside = new Uint8Array(N);
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
      const toOutside = chamfer((i) => outside[i] === 1);
      for (let i = 0; i < N; i++) if (A[i] < 0.5 && toOutside[i] <= sealR + 1.5) outside[i] = 1;
    }
    // Holes that hold a disc of radius hole_keep_r (icon units) are real gaps
    // and stay see-through; thinner enclosed holes are drawing lines.
    const keepR = (layer.hole_keep_r ?? style.hole_keep_r) * u;
    {
      const dist = chamfer((i) => !(!outside[i] && A[i] < 0.5));
      const seen = new Uint8Array(N);
      for (let s = 0; s < N; s++) {
        if (seen[s] || dist[s] === 0) continue;
        const comp = [s]; seen[s] = 1; let deep = false;
        for (let n = 0; n < comp.length; n++) {
          const i = comp[n]; if (dist[i] > keepR) deep = true;
          const x = i % W;
          const nb = [x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, i - W, i + W];
          for (const j of nb) if (j >= 0 && j < N && !seen[j] && dist[j] > 0) { seen[j] = 1; comp.push(j); }
        }
        if (deep) for (const i of comp) outside[i] = 1;
      }
    }
    const B = new Float32Array(N);
    const L = new Float32Array(N);
    for (let i = 0; i < N; i++) {
      B[i] = (!outside[i] && A[i] < 0.5) ? 1 : A[i];
      L[i] = (layer.lines === 'fill') ? 0 : Math.max(0, B[i] - A[i]);
    }
    return { A, B, L, u, box: layer.box, flip: !!layer.flip };
  };

  // Layers: a composite, or the single icon filling the square canvas.
  let layers;
  if (shade.layers) {
    layers = shade.layers.map((l) => ({ ...l, box: l.box.map((v) => v * px), lines: l.lines ?? shade.lines ?? 'incise' }));
  } else {
    const margin = Math.round(W * (shade.margin ?? style.margin));
    layers = [{ svg: shade.svg, box: [margin, margin, W - 2 * margin, H - 2 * margin], flip: shade.flip,
      erase: shade.erase, seal: shade.seal, hole_keep_r: shade.hole_keep_r, lines: shade.lines ?? 'incise', tone: 1, main: true }];
  }
  for (const l of layers) l.svg = l.svg || job.svgs[l.icon];
  const main = layers.find((l) => l.main) || layers[layers.length - 1];

  // Composite back to front. B = union, T = tone of the front-most layer,
  // Linc / Lemb = incised / ember lines of the front-most layer, rimT = each
  // layer's own lit edge where that layer is in front (so a skull keeps its
  // rim where it overlaps the wings), contact = shadow a front layer casts on
  // the layers behind it.
  const B = new Float32Array(N), T = new Float32Array(N), Linc = new Float32Array(N), Lemb = new Float32Array(N);
  const rimT = new Float32Array(N), contact = new Float32Array(N);
  const lf0 = style.light_from; const ln0 = Math.hypot(lf0[0], lf0[1]);
  const rdx = lf0[0] / ln0 * style.rim_px * px, rdy = lf0[1] / ln0 * style.rim_px * px;
  let mainMasks = null;
  const masks = [];
  for (const layer of layers) {
    const m = await layerMasks(layer);
    masks.push(m);
    if (layer === main) mainMasks = m;
  }
  const maskUrl = (M) => {
    const c = canvas(W, H); const g = c.getContext('2d');
    const img = g.createImageData(W, H);
    for (let i = 0; i < N; i++) { const o = i * 4; img.data[o] = 255; img.data[o + 1] = 255; img.data[o + 2] = 255; img.data[o + 3] = Math.round(M[i] * 255); }
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
    const out = new Float32Array(N);
    const ch = channel === 'a' ? 3 : 0;
    for (let i = 0; i < N; i++) out[i] = d[i * 4 + ch] / 255;
    return out;
  };
  const imageOf = (M) => `<image href="${maskUrl(M)}" x="0" y="0" width="${W}" height="${H}" filter="url(#f)"/>`;
  for (let k = 0; k < layers.length; k++) {
    const layer = layers[k]; const m = masks[k];
    const tone = layer.tone ?? 1;
    if (k > 0) {
      // Contact shadow on what is behind: this layer's alpha, blurred and pushed away from the torch.
      const sh = await filterPass(imageOf(m.B),
        `<feGaussianBlur in="SourceAlpha" stdDeviation="${style.contact_blur * px}"/><feOffset dx="${-rdx * 2}" dy="${-rdy * 2}"/>`, 'a');
      for (let i = 0; i < N; i++) if (B[i] > 0) contact[i] = Math.max(contact[i] * (1 - m.B[i]), sh[i] * (1 - m.B[i]));
    }
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = y * W + x; const b = m.B[i]; if (b <= 0) continue;
      const xs = Math.round(x + rdx), ys = Math.round(y + rdy);
      const t = (xs < 0 || ys < 0 || xs >= W || ys >= H) ? 0 : m.B[ys * W + xs];
      const own = b * (1 - t) * (layer.rim ?? 1);
      rimT[i] = own + rimT[i] * (1 - b);
      T[i] = tone * b + T[i] * (1 - b);
      const l = m.L[i];
      Linc[i] = (layer.lines === 'incise' ? l : 0) + Linc[i] * (1 - b);
      Lemb[i] = (layer.lines === 'ember' ? l : 0) + Lemb[i] * (1 - b);
      B[i] = b + B[i] * (1 - b);
    }
  }
  for (let i = 0; i < N; i++) if (B[i] > 0) T[i] = Math.min(1, T[i] / B[i]);

  // Figure bounding box (for the vertical rim gradient).
  let minY = H, maxY = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (B[y * W + x] > 0.03) { if (y < minY) minY = y; if (y > maxY) maxY = y; }
  }
  const lineDepth = chamfer((i) => Linc[i] < 0.5);

  // Height field: big soft form + an inner bevel (erode + blur) + mottle.
  const bodyImage = imageOf(B);
  const bigForm = await filterPass(bodyImage, `<feGaussianBlur in="SourceAlpha" stdDeviation="${style.form_blur * px}"/>`, 'a');
  const bevel = await filterPass(bodyImage,
    `<feMorphology in="SourceAlpha" operator="erode" radius="${style.bevel_erode * px}"/>
     <feGaussianBlur stdDeviation="${style.bevel_blur * px}"/>`, 'a');
  const grain = await filterPass(`<rect width="${W}" height="${H}" filter="url(#f)"/>`,
    `<feTurbulence type="fractalNoise" baseFrequency="${style.grain_freq / px}" numOctaves="3" seed="${shade.seed ?? 7}"/>
     <feColorMatrix type="matrix" values="0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0 0 0 0 1"/>`, 'r');
  const mottle = await filterPass(`<rect width="${W}" height="${H}" filter="url(#f)"/>`,
    `<feTurbulence type="fractalNoise" baseFrequency="${style.mottle_freq / px}" numOctaves="4" seed="${(shade.seed ?? 7) + 31}"/>
     <feColorMatrix type="matrix" values="0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0 0 0 0 1"/>`, 'r');
  const lineImage = imageOf(Lemb);
  const lineGlowNear = await filterPass(lineImage, `<feGaussianBlur in="SourceAlpha" stdDeviation="${2.5 * px}"/>`, 'a');
  const lineGlowFar = await filterPass(lineImage, `<feGaussianBlur in="SourceAlpha" stdDeviation="${9 * px}"/>`, 'a');
  const rimWide = await filterPass(imageOf(rimT), `<feGaussianBlur in="SourceAlpha" stdDeviation="${style.rim_broad_blur * px}"/>`, 'a');
  const incImage = imageOf(Linc);

  // Eyes: ellipses in the main layer's icon units, own mask + halo.
  const mu = mainMasks.u; const [mbx, mby] = mainMasks.box;
  const toCanvas = (ix, iy) => [mbx + (mainMasks.flip ? 512 - ix : ix) * mu, mby + iy * mu];
  const E = new Float32Array(N);
  let eyeHalo = new Float32Array(N);
  const eyes = shade.eyes || [];
  if (eyes.length) {
    const c = canvas(W, H); const g = c.getContext('2d');
    g.fillStyle = '#fff';
    for (const e of eyes) {
      const [cx, cy] = toCanvas(e.x, e.y);
      g.save();
      g.translate(cx, cy);
      g.rotate(((e.rot || 0) * (mainMasks.flip ? -1 : 1)) * Math.PI / 180);
      g.beginPath(); g.ellipse(0, 0, e.rx * mu, e.ry * mu, 0, 0, Math.PI * 2); g.fill();
      g.restore();
    }
    const d = g.getImageData(0, 0, W, H).data;
    for (let i = 0; i < N; i++) E[i] = d[i * 4 + 3] / 255;
    eyeHalo = await filterPass(`<image href="${c.toDataURL('image/png')}" x="0" y="0" width="${W}" height="${H}" filter="url(#f)"/>`,
      `<feGaussianBlur in="SourceAlpha" stdDeviation="${style.eye_halo * px}"/>`, 'a');
  }

  // Shade.
  const hex = (h) => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255];
  const C = {};
  for (const k of Object.keys(style.colors)) C[k] = hex(style.colors[k]);
  const lx = lf0[0] / ln0, ly = lf0[1] / ln0;
  const el = style.light_elevation * Math.PI / 180;
  const Lw = [Math.cos(el) * lx, Math.cos(el) * ly, Math.sin(el)];
  const Lc = [-Math.cos(el) * lx * 0.9, Math.cos(el) * 0.3, Math.sin(el)]; // cool soot fill from the other side
  const sample = (M, x, y) => {
    const xi = Math.round(x), yi = Math.round(y);
    if (xi < 0 || yi < 0 || xi >= W || yi >= H) return 0;
    return M[yi * W + xi];
  };
  const H0 = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    H0[i] = style.form_weight * bigForm[i] + (1 - style.form_weight) * bevel[i] + style.mottle_relief * (mottle[i] - 0.5);
  }
  const glow = shade.inner_glow;
  const [gcx, gcy] = glow ? toCanvas(glow.x, glow.y) : [0, 0];
  const gr = glow ? glow.r * mu : 1;
  const out = new Uint8ClampedArray(N * 4);
  const emi = new Uint8ClampedArray(N * 4);
  const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
  const add = (a, b, k) => [a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k];
  const k = style.surface_scale;
  const cd = style.rim_px * px;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      const o = i * 4;
      emi[o + 3] = 255;
      const b = B[i];
      const e = E[i];
      const alpha = Math.max(b, e);
      if (alpha <= 0.002) continue;
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
      const tone = T[i] || 1;
      // Base: charcoal, mottled towards slag brown, grainy; back layers darker (tone).
      let col = mix(C.body, C.body_slag, Math.min(1, Math.max(0, 0.5 + mo * 2.2)));
      const tex = (1 + style.grain * gr0 * 2) * tone;
      col = [col[0] * tex, col[1] * tex, col[2] * tex];
      col = add(col, C.lit, Math.pow(warm, 1.3) * style.key * tone);
      col = add(col, C.fill, cool * style.fill * tone);
      col = mix(col, [0, 0, 0], Math.min(0.85, contact[i] * style.contact));
      // Rim: each layer's own lit edge, plus a wide soft band inside it.
      const tight = rimT[i];
      const wide = b * Math.min(1, rimWide[i] * 2.5);
      const t = Math.min(1, Math.max(0, (y - minY) / Math.max(1, maxY - minY)));
      const rimCol = t < 0.35 ? mix(C.rim_hot, C.rim, t / 0.35) : mix(C.rim, C.rim_rust, (t - 0.35) / 0.65);
      const rimAmt = (tight * style.rim_tight + wide * style.rim_wide) * (0.75 + 0.5 * (grain[i])) * (0.5 + 0.5 * tone);
      col = add(col, rimCol, rimAmt);
      // Cool counter-rim on the far side so the shape reads on a dark wall.
      const counter = b * (1 - sample(B, x - lx * cd, y - ly * cd * 0.3));
      col = add(col, C.counter, counter * style.counter);
      // Incised lines: thin cuts are dark with a warm lip, wide filled holes only darken.
      const li = Linc[i];
      if (li > 0 || sample(Linc, x + lx * 2 * px, y + ly * 2 * px) > 0) {
        const lip = b * (1 - li) * sample(Linc, x + lx * 2 * px, y + ly * 2 * px);
        const wideHole = Math.min(1, Math.max(0, (lineDepth[i] / mu - 5) / 6));
        col = mix(col, C.incise, li * (0.92 - 0.55 * wideHole));
        col = add(col, rimCol, lip * style.lip);
      }
      // Glow (also written to the emissive layer): ember lines, inner heat, eyes.
      let glowCol = [0, 0, 0];
      const le = Lemb[i];
      if (le > 0 || lineGlowFar[i] > 0) {
        // Molten, not a lamp: the heat is broken up by the mottle and grain.
        const heat = Math.min(1, lineGlowNear[i] * 1.1) * (0.45 + 0.9 * Math.max(0, mo + 0.35)) * (0.85 + 0.3 * grain[i]);
        const ember = heat < 0.5 ? mix(C.ember_deep, C.ember, heat * 2) : mix(C.ember, C.ember_hot, (heat - 0.5) * 2);
        col = mix(col, ember, le);
        glowCol = add(glowCol, ember, le * style.emissive_lines);
        const halo = lineGlowFar[i] * (1 - le) * style.ember_halo;
        col = add(col, C.ember, halo);
        glowCol = add(glowCol, C.ember, halo * 0.5);
      }
      if (glow) {
        const r2 = ((x - gcx) ** 2 + (y - gcy) ** 2) / (gr * gr);
        const gi = Math.exp(-r2 * 2.2) * glow.strength * Math.max(0, bigForm[i] * 1.3 - 0.2) * (0.55 + 1.2 * Math.max(0, mo + 0.15));
        const heatCol = [C.ember[0], C.ember[1] * 0.8, C.ember[2] * 0.6];
        col = add(col, heatCol, gi);
        glowCol = add(glowCol, heatCol, gi * 0.5);
      }
      if (eyes.length) {
        const halo = eyeHalo[i] * b * style.eye_glow;
        col = add(col, C.ember, halo);
        const core = mix(C.ember, C.eye, Math.min(1, eyeHalo[i] * 1.6));
        col = mix(col, core, Math.min(1, e));
        glowCol = add(glowCol, C.ember, halo * 0.8);
        glowCol = mix(glowCol, core, Math.min(1, e));
      }
      out[o] = col[0] * 255; out[o + 1] = col[1] * 255; out[o + 2] = col[2] * 255; out[o + 3] = alpha * 255;
      emi[o] = glowCol[0] * alpha * 255; emi[o + 1] = glowCol[1] * alpha * 255; emi[o + 2] = glowCol[2] * alpha * 255;
    }
  }
  if (debugGrid) {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const ix = (x - mbx) / mu, iy = (y - mby) / mu;
      if (Math.abs(ix % 64) < 0.8 / mu * px || Math.abs(iy % 64) < 0.8 / mu * px) {
        const o = (y * W + x) * 4; out[o] = 60; out[o + 1] = 160; out[o + 2] = 255; out[o + 3] = 255;
      }
    }
  }
  // Downsample in halving steps (box-like, keeps the grain crisp but not aliased).
  const shrink = (data) => {
    let src = canvas(W, H);
    src.getContext('2d').putImageData(new ImageData(data, W, H), 0, 0);
    while (src.width > outW) {
      const next = canvas(Math.max(outW, src.width / 2), Math.max(outH, src.height / 2));
      const g = next.getContext('2d');
      g.imageSmoothingEnabled = true;
      g.imageSmoothingQuality = 'high';
      g.drawImage(src, 0, 0, next.width, next.height);
      src = next;
    }
    return src.toDataURL('image/png');
  };
  return { albedo: shrink(out), emissive: shrink(emi) };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const spec = JSON.parse(fs.readFileSync(SPEC, 'utf8'));
  const svgDir = path.join(ROOT, spec.svg_dir);
  const outDir = args.out ? path.resolve(args.out) : path.join(ROOT, spec.out_dir);
  fs.mkdirSync(outDir, { recursive: true });
  const loadSvg = (icon, id) => {
    const file = path.join(svgDir, icon.replace('/', '__') + '.svg');
    if (!fs.existsSync(file)) throw new Error(`${id}: ${file} missing, run tools/shade_monsters/fetch_shades.py first`);
    return figureSvg(fs.readFileSync(file, 'utf8'));
  };
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.setContent('<html><body></body></html>');
    for (const shade of spec.shades) {
      if (args.only && shade.id !== args.only) continue;
      const svgs = {};
      const icons = shade.layers ? shade.layers.map((l) => l.icon) : [shade.icon];
      for (const icon of icons) svgs[icon] = loadSvg(icon, shade.id);
      const job = { size: shade.size, ss: spec.style.supersample, style: spec.style,
        shade: { ...shade, svg: shade.layers ? undefined : svgs[shade.icon] }, svgs, debugGrid: args.debugGrid };
      const result = await page.evaluate(renderInPage, job);
      for (const [suffix, url] of [['', result.albedo], ['_emissive', result.emissive]]) {
        const target = path.join(outDir, `${shade.id}${suffix}.png`);
        fs.writeFileSync(target, Buffer.from(url.split(',')[1], 'base64'));
      }
      const dims = Array.isArray(shade.size) ? shade.size.join('x') : `${shade.size}x${shade.size}`;
      console.log(`${shade.id.padEnd(14)} ${icons.join(' + ').padEnd(24)} ${dims} -> ${path.relative(ROOT, path.join(outDir, shade.id))}{,_emissive}.png`);
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
