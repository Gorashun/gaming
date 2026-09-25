import Phaser from 'phaser';
import { THEME, hexToInt } from '../data/theme';
import { setPalette, themeSetById, type BackdropOp, type ThemeSet } from '../data/themes';
import { mulberry32 } from '../systems/rng';
import { BG_GLOW } from './textures';

type ScatterOp = Extract<BackdropOp, { op: 'scatter' }>;

function drawScatter(g: Phaser.GameObjects.Graphics, op: ScatterOp, ox: number, oy: number): void {
  const rng = mulberry32(op.seed);
  const c = hexToInt(op.color);
  for (let i = 0; i < op.count; i++) {
    const x = ox + rng.next() * op.w;
    const y = oy + rng.next() * op.h;
    const r = op.rMin + rng.next() * (op.rMax - op.rMin);
    const a = op.alphaMin + rng.next() * (op.alphaMax - op.alphaMin);
    if (op.stroke) {
      g.lineStyle(op.stroke, c, a);
      g.strokeCircle(x, y, r);
    } else {
      g.fillStyle(c, a);
      g.fillCircle(x, y, r);
    }
  }
}

/** Ritar setets bakgrundsprimitiver (UI.md §12.1.4). Rörliga scatter-lager hoppas över om `skipMoving`. */
function drawOps(g: Phaser.GameObjects.Graphics, set: ThemeSet, skipMoving: boolean): void {
  for (const op of set.backdrop.ops) {
    switch (op.op) {
      case 'circle':
      case 'ellipse': {
        const c = hexToInt(op.color);
        const w = op.op === 'circle' ? op.r * 2 : op.w;
        const h = op.op === 'circle' ? op.r * 2 : op.h;
        if (op.stroke) {
          g.lineStyle(op.stroke, c, op.alpha);
          g.strokeEllipse(op.x, op.y, w, h);
        } else {
          g.fillStyle(c, op.alpha);
          g.fillEllipse(op.x, op.y, w, h);
        }
        break;
      }
      case 'poly':
        g.fillStyle(hexToInt(op.color), op.alpha);
        g.fillPoints(op.pts.map(([x, y]) => ({ x, y })), true);
        break;
      case 'line':
        g.lineStyle(op.width, hexToInt(op.color), op.alpha);
        g.lineBetween(op.from[0], op.from[1], op.to[0], op.to[1]);
        break;
      case 'curve': {
        const pts = new Phaser.Curves.QuadraticBezier(
          new Phaser.Math.Vector2(op.from[0], op.from[1]),
          new Phaser.Math.Vector2(op.ctrl[0], op.ctrl[1]),
          new Phaser.Math.Vector2(op.to[0], op.to[1]),
        ).getPoints(32);
        g.lineStyle(op.width, hexToInt(op.color), op.alpha);
        g.strokePoints(pts, false);
        break;
      }
      case 'scatter':
        if (!(skipMoving && op.vy)) drawScatter(g, op, op.x, op.y);
        break;
    }
  }
}

/** Setets stilla bakgrundsdetalj som en textur 360×640, bakad en gång per set. */
function backdropKey(scene: Phaser.Scene, set: ThemeSet, still: boolean): string | null {
  if (set.backdrop.ops.length === 0) return null;
  const key = `bd-${set.id}${still ? '-still' : ''}`;
  if (!scene.textures.exists(key)) {
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    drawOps(g, set, !still);
    g.generateTexture(key, THEME.layout.width, THEME.layout.height);
    g.destroy();
  }
  return key;
}

export interface BackgroundOpts {
  /** Förskjutning i x (bokens sidor ligger bredvid varandra). */
  ox?: number;
  /** Inga rörliga lager (boken, Lugnt läge). */
  still?: boolean;
  /** Utan setets detaljer (låst boksida). */
  plain?: boolean;
  /** Lägg allt i en container (boken). */
  into?: Phaser.GameObjects.Container;
}

/**
 * Bakgrund enligt UI.md §7 + §12.1.4: gradient bg → bgDeep, mjuk radial bakom burken och
 * setets bakgrundsdetalj. Allt ritas en gång; bara scatter-lager med `vy` rör sig (tweens).
 */
export function drawBackground(scene: Phaser.Scene, setId?: string, opts: BackgroundOpts = {}): void {
  const set = themeSetById(setId ?? 'glimtarna');
  const pal = setPalette(set);
  const ox = opts.ox ?? 0;
  const w = THEME.layout.width;
  const h = THEME.layout.height;
  const add = <T extends Phaser.GameObjects.GameObject>(o: T): T => {
    opts.into?.add(o);
    return o;
  };
  if (!opts.into) scene.cameras.main.setBackgroundColor(hexToInt(pal.bg));
  const g = add(scene.add.graphics().setDepth(-10));
  g.fillGradientStyle(hexToInt(pal.bg), hexToInt(pal.bg), hexToInt(pal.bgDeep), hexToInt(pal.bgDeep), 1);
  g.fillRect(ox, 0, w, h);
  if (scene.textures.exists(BG_GLOW)) {
    add(
      scene.add
        .image(ox + 180, 330, BG_GLOW)
        .setDisplaySize(640, 640)
        .setDepth(-9)
        .setAlpha(0.9)
        .setTint(hexToInt(pal.bgGlow)),
    );
  }
  if (opts.plain) return;
  const still = opts.still ?? false;
  const key = backdropKey(scene, set, still);
  if (key) add(scene.add.image(ox, 0, key).setOrigin(0).setDepth(-8));
  if (still) return;

  // Rörliga lager: TileSprite som scrollar och wrappar i y, vaggning ≤0,5 Hz.
  set.backdrop.ops.forEach((op, i) => {
    if (op.op !== 'scatter' || !op.vy) return;
    const lk = `bd-${set.id}-m${i}`;
    if (!scene.textures.exists(lk)) {
      const lg = scene.make.graphics({ x: 0, y: 0 }, false);
      drawScatter(lg, op, 0, 0);
      lg.generateTexture(lk, op.w, op.h);
      lg.destroy();
    }
    const layer = add(scene.add.tileSprite(ox + op.x, op.y, op.w, op.h, lk).setOrigin(0).setDepth(-8));
    scene.tweens.add({
      targets: layer,
      tilePositionY: -Math.sign(op.vy) * op.h,
      duration: (op.h / Math.abs(op.vy)) * 1000,
      repeat: -1,
    });
    if (op.swayPx && op.swayHz) {
      scene.tweens.add({
        targets: layer,
        x: layer.x + op.swayPx,
        duration: 500 / op.swayHz,
        ease: 'Sine.easeInOut',
        yoyo: true,
        repeat: -1,
      });
    }
  });
}
