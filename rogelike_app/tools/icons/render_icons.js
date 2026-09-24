#!/usr/bin/env node
// Render game-icons SVGs to 256x256 RGBA PNGs with a chalk/paper finish.
//
// Reads tools/art_build.json. Every entry with "source": "game-icons" has
//   "svg":    "<author>/<name>.svg"   (fetched by tools/icons/fetch_icons.py)
//   "src":    "render/<file>.png"     (where this script writes, relative to
//                                      assets/incoming/game-icons/)
// and optionally
//   "rotate": degrees clockwise (arrows share one SVG), "flip": "h" | "v",
//   "pad":    margin as a fraction of the canvas (default 0.07).
//
// The PNG is WHITE ink on transparent. Colour is applied in Godot with
// modulate and the semantic tokens in src/game/ui/tokens.gd, never here, so
// one file serves every theme (high contrast, colour-blind palettes).
//
// The finish is an SVG filter, not a hand edit, so every icon gets the same
// hand: a slightly rough chalk edge, an inner shade on the lower-right rim
// (the one light source sits upper left in the UI), a faint paper grain in
// the fill and a soft dark outline so the ink survives on lit stone. The
// shading lives in the RGB channels (white -> grey) so a tint multiplies it.
//
// Usage (from rogelike_app/):
//   NODE_PATH=/opt/node22/lib/node_modules node tools/icons/render_icons.js
//   ... render_icons.js --only ui.slot.fire
//   ... render_icons.js --svg lorc/anvil.svg --out /tmp/preview   (ad hoc)
//   ... render_icons.js --flat          (no chalk filter, for comparison)
//
// Needs Playwright with Chromium (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers).

'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const SIZE = 256;
const ROOT = process.cwd();
const INCOMING = path.join(ROOT, 'assets/incoming/game-icons');
const BUILD_SPEC = path.join(ROOT, 'tools/art_build.json');

function parseArgs(argv) {
  const args = { only: '', svg: [], out: '', flat: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--only') args.only = argv[++i];
    else if (a === '--svg') args.svg.push(...argv[++i].split(','));
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--flat') args.flat = true;
    else throw new Error(`unknown argument ${a}`);
  }
  return args;
}

function jobs(args) {
  if (args.svg.length > 0) {
    const outDir = args.out || path.join(INCOMING, 'render/adhoc');
    return args.svg.map((svg) => ({
      id: svg,
      svg,
      target: path.join(outDir, svg.replace('/', '__').replace(/\.svg$/, '.png')),
      rotate: 0, flip: '', pad: 0.07,
    }));
  }
  const spec = JSON.parse(fs.readFileSync(BUILD_SPEC, 'utf8'));
  return spec.entries
    .filter((e) => e.source === 'game-icons')
    .filter((e) => !args.only || e.id === args.only)
    .map((e) => ({
      id: e.id,
      svg: e.svg,
      target: path.join(INCOMING, e.src),
      rotate: Number(e.rotate || 0),
      flip: String(e.flip || ''),
      pad: e.pad === undefined ? 0.07 : Number(e.pad),
    }));
}

// Chalk finish. Units are the icon's own 512 user space.
const CHALK_FILTER = `
<filter id="chalk" x="-8%" y="-8%" width="116%" height="116%" color-interpolation-filters="sRGB">
  <!-- 1. Rough edge: displace the ink a few units with fine noise. -->
  <feTurbulence type="fractalNoise" baseFrequency="0.55" numOctaves="2" seed="11" result="edgeNoise"/>
  <feDisplacementMap in="SourceGraphic" in2="edgeNoise" scale="7" xChannelSelector="R" yChannelSelector="G" result="ink"/>

  <!-- 2. Inner shade on the lower-right rim: ink minus itself shifted up-left. -->
  <feGaussianBlur in="ink" stdDeviation="7" result="inkBlur"/>
  <feOffset in="inkBlur" dx="-9" dy="-11" result="inkShift"/>
  <feComposite in="ink" in2="inkShift" operator="out" result="rimMask"/>
  <feGaussianBlur in="rimMask" stdDeviation="3" result="rimSoft"/>
  <feColorMatrix in="rimSoft" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.55 0" result="rimShade"/>

  <!-- 3. Paper grain: low-contrast speckle inside the ink (0.84..1.0). -->
  <feTurbulence type="fractalNoise" baseFrequency="1.9" numOctaves="1" seed="3" result="grainNoise"/>
  <feColorMatrix in="grainNoise" type="matrix"
    values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0.55 0 0 0 -0.12" result="grainAlpha"/>
  <feComposite in="grainAlpha" in2="ink" operator="in" result="grain"/>

  <!-- 4. Lit ink = white ink, darkened by rim shade and grain. -->
  <feComposite in="rimShade" in2="ink" operator="atop" result="shaded"/>
  <feComposite in="grain" in2="shaded" operator="atop" result="lit"/>

  <!-- 5. Soft dark outline under everything, for lit backgrounds. -->
  <feMorphology in="ink" operator="dilate" radius="9" result="fat"/>
  <feGaussianBlur in="fat" stdDeviation="3" result="fatSoft"/>
  <feColorMatrix in="fatSoft" type="matrix" values="0 0 0 0 0.03  0 0 0 0 0.035  0 0 0 0 0.04  0 0 0 0.62 0" result="outline"/>

  <feMerge>
    <feMergeNode in="outline"/>
    <feMergeNode in="lit"/>
  </feMerge>
</filter>`;

function pageFor(job, svgText, flat) {
  // The fetched file is a bare <svg> with one or more white paths. Pull out
  // the inner markup and place it in a transformed group.
  const inner = svgText.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
  const scale = 1 - 2 * job.pad;
  const sx = job.flip === 'h' ? -scale : scale;
  const sy = job.flip === 'v' ? -scale : scale;
  const transform = `translate(256 256) rotate(${job.rotate}) scale(${sx} ${sy}) translate(-256 -256)`;
  const filter = flat ? '' : 'filter="url(#chalk)"';
  return `<!doctype html><html><head><style>
    html,body{margin:0;padding:0;background:transparent;}
    svg{display:block;}
  </style></head><body>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="${SIZE}" height="${SIZE}">
    <defs>${CHALK_FILTER}</defs>
    <g ${filter}><g transform="${transform}" fill="#fff">${inner}</g></g>
  </svg></body></html>`;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const list = jobs(args);
  if (list.length === 0) {
    console.error('nothing to render (no game-icons entries matched)');
    process.exit(1);
  }
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 1 });
  let failed = 0;
  for (const job of list) {
    const source = path.join(INCOMING, job.svg);
    if (!fs.existsSync(source)) {
      console.error(`MISSING ${job.svg} (run tools/icons/fetch_icons.py first)`);
      failed++;
      continue;
    }
    await page.setContent(pageFor(job, fs.readFileSync(source, 'utf8'), args.flat));
    fs.mkdirSync(path.dirname(job.target), { recursive: true });
    await page.screenshot({
      path: job.target, omitBackground: true, clip: { x: 0, y: 0, width: SIZE, height: SIZE },
    });
    console.log(`${job.id.padEnd(24)} ${job.svg.padEnd(40)} -> ${path.relative(ROOT, job.target)}`);
  }
  await browser.close();
  if (failed > 0) process.exit(1);
}

main().catch((err) => { console.error(err); process.exit(1); });
