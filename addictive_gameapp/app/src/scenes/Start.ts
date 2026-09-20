import Phaser from 'phaser';
import { WORLD } from '../data/physics';
import { INT, THEME } from '../data/theme';
import { cached } from '../systems/save';

/** Tillfällig startskärm: bara en stor ▶-cirkel. Full startskärm byggs i fas 3 (P3.4). */
export class Start extends Phaser.Scene {
  constructor() {
    super('Start');
  }

  create(): void {
    this.cameras.main.setBackgroundColor(INT.bg);
    const cx = WORLD.width / 2;
    const cy = WORLD.height / 2;

    this.add
      .text(cx, cy - 180, 'KLUNK', {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.logo}px`,
        color: THEME.palette.hud,
      })
      .setOrigin(0.5);

    const g = this.add.graphics();
    g.fillStyle(INT.accent, 1);
    g.fillCircle(cx, cy, 70);
    g.fillStyle(INT.bg, 1);
    g.fillTriangle(cx - 22, cy - 34, cx - 22, cy + 34, cx + 36, cy);

    this.add
      .text(cx, cy + 160, `${cached().highscore}`, {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.sub}px`,
        color: THEME.palette.gold,
      })
      .setOrigin(0.5);

    // Starta på pointerup så att samma gest inte läcker in som en drop i Game.
    this.input.on('pointerup', () => this.scene.start('Game'));
  }
}
