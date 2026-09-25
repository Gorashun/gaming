import Phaser from 'phaser';
import { hexToInt } from '../data/theme';
import type { FxCue } from '../data/avatarsIndex';
import { FX_RING, FX_RING_R } from './textures';
import { avatarParticleKey } from './avatarArt';

/**
 * Showcase-effekter (`FxCue`, UI.md §13.3) i öppningen och på bokens scen. Engångsobjekt som
 * städar efter sig; används aldrig i spelets update(). Koordinater i box-enheter × k (px/enhet).
 */

const tints = (t: string | readonly string[]): number[] => (typeof t === 'string' ? [hexToInt(t)] : t.map(hexToInt));

export function playFxCue(scene: Phaser.Scene, cue: FxCue, x: number, y: number, k: number, depth: number, calm = false): void {
  const half = (n: number): number => (calm ? Math.max(1, Math.round(n / 2)) : n);
  switch (cue.kind) {
    case 'burst': {
      const e = scene.add
        .particles(x, y, avatarParticleKey(cue.shape), {
          lifespan: cue.lifeMs,
          speed: { min: cue.speed * 0.5 * k, max: cue.speed * k },
          angle: { min: 0, max: 360 },
          scale: { start: Math.max(0.6, k * 0.6), end: 0 },
          alpha: { start: 1, end: 0 },
          rotate: { start: 0, end: 180 },
          gravityY: (cue.gravityY ?? 0) * k,
          tint: tints(cue.tint),
          emitting: false,
        })
        .setDepth(depth);
      e.explode(half(cue.count));
      scene.time.delayedCall(cue.lifeMs + 100, () => e.destroy());
      return;
    }
    case 'rise':
    case 'fall': {
      const ts = tints(cue.tint);
      const n = half(cue.count);
      for (let i = 0; i < n; i++) {
        const spread = cue.kind === 'fall' ? cue.spreadPx : cue.swayPx * 2;
        const ox = ((i / Math.max(1, n - 1)) - 0.5) * spread * k;
        const dist = (cue.kind === 'rise' ? -cue.risePx : cue.fallPx) * k;
        const img = scene.add
          .image(x + ox, y, avatarParticleKey(cue.shape))
          .setTint(ts[i % ts.length])
          .setScale(Math.max(0.6, k * 0.6))
          .setDepth(depth)
          .setAlpha(0);
        scene.tweens.add({
          targets: img,
          y: y + dist,
          x: img.x + (cue.kind === 'rise' ? (i % 2 ? 1 : -1) * cue.swayPx * k : 0),
          alpha: { from: 1, to: 0 },
          delay: i * cue.staggerMs,
          duration: cue.lifeMs,
          ease: 'Sine.easeOut',
          onComplete: () => img.destroy(),
        });
      }
      return;
    }
    case 'rings': {
      const n = calm ? Math.min(1, cue.count) : cue.count;
      for (let i = 0; i < n; i++) {
        const img = scene.add
          .image(x, y, FX_RING)
          .setTint(hexToInt(cue.color))
          .setScale((cue.fromR * k) / FX_RING_R)
          .setAlpha(0)
          .setDepth(depth);
        scene.tweens.add({
          targets: img,
          scale: (cue.toR * k) / FX_RING_R,
          alpha: { from: 0.85, to: 0 },
          delay: i * cue.staggerMs,
          duration: cue.ms,
          ease: 'Cubic.easeOut',
          onComplete: () => img.destroy(),
        });
      }
      return;
    }
    case 'bolts': {
      const n = half(cue.count);
      for (let i = 0; i < n; i++) {
        const g = scene.add.graphics().setDepth(depth).setAlpha(0);
        const a = -Math.PI / 2 + (i - (n - 1) / 2) * 0.7;
        drawZigzag(g, x, y, a, cue.len * k, 4, hexToInt(cue.color), Math.max(2, k * 1.4));
        scene.tweens.add({
          targets: g,
          alpha: { from: 1, to: 0 },
          delay: i * cue.staggerMs,
          duration: cue.ms,
          ease: 'Quad.easeIn',
          onComplete: () => g.destroy(),
        });
      }
      return;
    }
    case 'arc': {
      const g = scene.add.graphics().setDepth(depth).setAlpha(0);
      const w = cue.width * k;
      cue.colors.forEach((c, i) => {
        g.lineStyle(w, hexToInt(c), 1);
        g.beginPath();
        g.arc(x, y, (cue.r - i * cue.width) * k, Math.PI, Math.PI * 2, false);
        g.strokePath();
      });
      scene.tweens.chain({
        targets: g,
        tweens: [
          { alpha: 1, duration: cue.inMs, ease: 'Sine.easeOut' },
          { alpha: 1, duration: cue.holdMs },
          { alpha: 0, duration: cue.outMs, ease: 'Sine.easeIn' },
        ],
        onComplete: () => g.destroy(),
      });
      return;
    }
    case 'aim': {
      const g = scene.add.graphics().setDepth(depth).setAlpha(0);
      const c = hexToInt(cue.color);
      const len = cue.len * k;
      g.lineStyle(Math.max(2, k), c, 0.8);
      for (let d = 0; d < len; d += 10) g.lineBetween(x, y + d, x, y + Math.min(d + 4, len));
      g.fillStyle(c, 1);
      g.fillCircle(x, y + len, cue.dotR * k);
      scene.tweens.add({ targets: g, alpha: { from: 1, to: 0 }, duration: cue.ms, ease: 'Quad.easeIn', onComplete: () => g.destroy() });
      return;
    }
    case 'orbit': {
      const ts = tints(cue.tint);
      const n = half(cue.count);
      const imgs = Array.from({ length: n }, (_, i) =>
        scene.add.image(x, y, avatarParticleKey(cue.shape)).setTint(ts[i % ts.length]).setScale(Math.max(0.6, k * 0.6)).setDepth(depth),
      );
      scene.tweens.addCounter({
        from: 0,
        to: 1,
        duration: cue.ms,
        onUpdate: (tw) => {
          const t = tw.getValue() ?? 1;
          imgs.forEach((img, i) => {
            const a = (i / n) * Math.PI * 2 + t * cue.turns * Math.PI * 2;
            img.setPosition(x + Math.cos(a) * cue.r * k, y + Math.sin(a) * cue.r * k).setAlpha(1 - t * t);
          });
        },
        onComplete: () => imgs.forEach((i) => i.destroy()),
      });
      return;
    }
  }
}

/** Sicksackblixt från (x, y) i riktning a, som streck (ingen fyllning, ingen blixt över skärmen). */
export function drawZigzag(g: Phaser.GameObjects.Graphics, x: number, y: number, a: number, len: number, zigs: number, color: number, width: number): void {
  const ux = Math.cos(a);
  const uy = Math.sin(a);
  const amp = len * 0.14;
  g.lineStyle(width, color, 1);
  g.beginPath();
  g.moveTo(x, y);
  for (let i = 1; i <= zigs; i++) {
    const t = i / zigs;
    const side = i === zigs ? 0 : i % 2 ? amp : -amp;
    g.lineTo(x + ux * len * t - uy * side, y + uy * len * t + ux * side);
  }
  g.strokePath();
}
