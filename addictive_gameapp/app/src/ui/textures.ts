import Phaser from 'phaser';
import { LEVELS } from '../data/levels';
import { INT, LEVEL_COLORS, LEVEL_COLORS2 } from '../data/theme';

export function ballTextureKey(level: number): string {
  return `ball-${level}`;
}

/** Genererar en textur per nivå en gång. Inga Graphics-anrop per frame. */
export function ensureBallTextures(scene: Phaser.Scene): void {
  for (const def of LEVELS) {
    const key = ballTextureKey(def.level);
    if (scene.textures.exists(key)) continue;
    const r = def.radius;
    const edgeW = Math.max(2, r * 0.12);
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(LEVEL_COLORS[def.level], 1);
    g.fillCircle(r, r, r);
    g.lineStyle(edgeW, LEVEL_COLORS2[def.level], 1);
    g.strokeCircle(r, r, r - edgeW / 2);
    const ex = r * 0.34;
    const ey = r * 0.12;
    const er = Math.max(2, r * 0.2);
    g.fillStyle(INT.hud, 1);
    g.fillCircle(r - ex, r - ey, er);
    g.fillCircle(r + ex, r - ey, er);
    g.fillStyle(INT.ink, 1);
    g.fillCircle(r - ex, r - ey + er * 0.15, er * 0.5);
    g.fillCircle(r + ex, r - ey + er * 0.15, er * 0.5);
    g.generateTexture(key, r * 2, r * 2);
    g.destroy();
  }
}
