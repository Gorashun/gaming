import type Phaser from 'phaser';
import { hexToInt } from '../data/theme';
import { BOX_FX } from '../data/boxes';

/**
 * Platshållarmussla (solfjäder med räfflor och gångjärn) runt (0, 0) i `g`. Ersätts av UI.md §13.
 * Anropas vid skapande, aldrig per frame.
 */
export function drawShell(g: Phaser.GameObjects.Graphics, size: number): Phaser.GameObjects.Graphics {
  const r = size / 2;
  const hy = r * 0.55;
  const ribs = 7;
  const a0 = Math.PI + 0.45;
  const a1 = Math.PI * 2 - 0.45;
  const pts: { x: number; y: number }[] = [{ x: 0, y: hy }];
  for (let i = 0; i <= ribs * 2; i++) {
    const a = a0 + ((a1 - a0) * i) / (ribs * 2);
    const rr = (i % 2 === 0 ? 0.93 : 1) * r * 1.25;
    pts.push({ x: Math.cos(a) * rr, y: hy + Math.sin(a) * rr });
  }
  const fill = hexToInt(BOX_FX.shellColor);
  const edge = hexToInt(BOX_FX.shellEdge);
  g.fillStyle(fill, 1);
  g.fillPoints(pts, true);
  g.lineStyle(Math.max(1.5, r * 0.08), edge, 1);
  g.strokePoints(pts, true);
  for (let i = 1; i < ribs * 2; i += 2) g.lineBetween(0, hy, pts[i + 1].x * 0.85, hy + (pts[i + 1].y - hy) * 0.85);
  // Gångjärnet: två små öron.
  g.fillStyle(fill, 1);
  g.fillTriangle(-r * 0.42, hy + r * 0.1, 0, hy - r * 0.12, 0, hy + r * 0.26);
  g.fillTriangle(r * 0.42, hy + r * 0.1, 0, hy - r * 0.12, 0, hy + r * 0.26);
  g.strokeTriangle(-r * 0.42, hy + r * 0.1, 0, hy - r * 0.12, 0, hy + r * 0.26);
  g.strokeTriangle(r * 0.42, hy + r * 0.1, 0, hy - r * 0.12, 0, hy + r * 0.26);
  return g;
}
