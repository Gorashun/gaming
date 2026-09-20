import Phaser from 'phaser';
import { WORLD } from '../data/physics';
import { INT, THEME } from '../data/theme';
import { ballTextureKey } from '../ui/textures';
import { cached } from '../systems/save';

export interface GameOverData {
  score: number;
  bestLevel: number;
  record: boolean;
  highscore: number;
}

export class GameOver extends Phaser.Scene {
  constructor() {
    super('GameOver');
  }

  create(data: GameOverData): void {
    const cx = WORLD.width / 2;
    const cy = WORLD.height / 2;
    this.add.rectangle(cx, cy, WORLD.width, WORLD.height, INT.scrim, 0.82).setDepth(20);

    this.add
      .text(cx, cy - 110, `${data.score ?? 0}`, {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.scoreBig}px`,
        color: THEME.palette.hud,
      })
      .setOrigin(0.5)
      .setDepth(21);

    this.add
      .text(cx, cy - 50, `★ ${data.highscore ?? cached().highscore}`, {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.sub}px`,
        color: THEME.palette.gold,
      })
      .setOrigin(0.5)
      .setDepth(21);

    this.add
      .image(cx, cy + 40, ballTextureKey(data.bestLevel ?? 0))
      .setDisplaySize(72, 72)
      .setDepth(21);

    const replay = this.add
      .text(cx, cy + 140, '▶', { fontFamily: THEME.type.family, fontSize: '56px', color: THEME.palette.accent })
      .setOrigin(0.5)
      .setDepth(21);
    this.tweens.add({ targets: replay, scale: 1.12, duration: 700, yoyo: true, repeat: -1 });

    // Hela ytan är knapp.
    this.input.once('pointerdown', () => this.scene.start('Game'));
  }
}
