import Phaser from 'phaser';
import { INT, THEME } from '../data/theme';
import { BG_GLOW } from './textures';

/** Bakgrund enligt UI.md §7: gradient bg → bgDeep + mjuk radial bakom burken. */
export function drawBackground(scene: Phaser.Scene): void {
  const w = THEME.layout.width;
  const h = THEME.layout.height;
  scene.cameras.main.setBackgroundColor(INT.bg);
  const g = scene.add.graphics().setDepth(-10);
  g.fillGradientStyle(INT.bg, INT.bg, INT.bgDeep, INT.bgDeep, 1);
  g.fillRect(0, 0, w, h);
  if (scene.textures.exists(BG_GLOW)) {
    scene.add.image(180, 330, BG_GLOW).setDisplaySize(640, 640).setDepth(-9).setAlpha(0.9);
  }
}
