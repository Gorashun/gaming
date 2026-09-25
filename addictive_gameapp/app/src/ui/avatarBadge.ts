import type Phaser from 'phaser';
import { THEME, hexToInt } from '../data/theme';
import { RARITY, type AvatarDef } from '../data/avatarsIndex';

/** Platshållare tills ritrecepten (K1/K3) finns: raritetsfärgad cirkel med första bokstaven. */
export function addAvatarBadge(scene: Phaser.Scene, x: number, y: number, r: number, def: AvatarDef): Phaser.GameObjects.Container {
  const g = scene.add.graphics();
  g.fillStyle(hexToInt(RARITY.color[def.rarity]), 1);
  g.fillCircle(0, 0, r);
  const t = scene.add
    .text(0, 0, def.name.charAt(0), {
      fontFamily: THEME.type.family,
      fontSize: `${Math.round(r * 1.1)}px`,
      color: THEME.palette.ink,
      fontStyle: THEME.type.weightHeavy,
    })
    .setOrigin(0.5);
  return scene.add.container(x, y, [g, t]);
}

/** Pärlor på rad, centrerade på x: `filled` fyllda i färgen, resten som tomma ringar upp till `total`. */
export function drawPearls(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  filled: number,
  total: number,
  r: number,
  pitch: number,
  color: number,
): void {
  const x0 = x - ((total - 1) * pitch) / 2;
  for (let i = 0; i < total; i++) {
    if (i < filled) {
      g.fillStyle(color, 1);
      g.fillCircle(x0 + i * pitch, y, r);
    } else {
      g.lineStyle(1, color, 0.6);
      g.strokeCircle(x0 + i * pitch, y, r);
    }
  }
}
