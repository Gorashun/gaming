import Phaser from 'phaser';
import { INT, THEME } from '../data/theme';
import { ballTextureKey, scaleForBodyRadius } from '../ui/textures';
import { iconTextureKey } from '../ui/icons';
import { cached } from '../systems/save';
import { playSound } from '../systems/audio';

export interface GameOverData {
  score: number;
  bestLevel: number;
  record: boolean;
  highscore: number;
}

const L = THEME.layout;

/** Förlustskärm enligt UI.md §7.3. Hela ytan är en knapp. */
export class GameOver extends Phaser.Scene {
  constructor() {
    super('GameOver');
  }

  create(data: GameOverData): void {
    const score = data.score ?? 0;
    const highscore = data.highscore ?? cached().highscore;
    const bestLevel = data.bestLevel ?? 0;

    const scrim = this.add
      .rectangle(L.width / 2, L.height / 2, L.width, L.height, INT.scrim, 0.82)
      .setDepth(20)
      .setAlpha(0);
    this.tweens.add({
      targets: scrim,
      alpha: 1,
      duration: THEME.anim.overlayIn.durationMs,
      ease: THEME.anim.overlayIn.ease,
    });

    this.add
      .text(180, 190, `${score}`, {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.scoreBig}px`,
        color: THEME.palette.hud,
        fontStyle: THEME.type.weightHeavy,
      })
      .setOrigin(0.5)
      .setDepth(21);

    this.add.image(132, 278, iconTextureKey('crown')).setDisplaySize(24, 24).setDepth(21);
    this.add
      .text(164, 278, `${highscore}`, {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.sub}px`,
        color: THEME.palette.gold,
        fontStyle: THEME.type.weightHeavy,
      })
      .setOrigin(0, 0.5)
      .setDepth(21);

    if (data.record) this.drawGoldRing();

    this.add
      .image(180, 400, ballTextureKey(bestLevel))
      .setScale(scaleForBodyRadius(bestLevel, 56))
      .setDepth(21);

    const ring = this.add.graphics().setDepth(21);
    ring.lineStyle(3, INT.accent, 0.45);
    ring.strokeCircle(180, 530, 44);
    const replay = this.add
      .image(180, 530, iconTextureKey('replay'))
      .setDisplaySize(64, 64)
      .setDepth(22);
    this.tweens.add({
      targets: replay,
      scale: replay.scale * THEME.anim.recordPulse.scale,
      duration: THEME.anim.recordPulse.durationMs,
      ease: THEME.anim.recordPulse.ease,
      yoyo: true,
      repeat: -1,
    });

    // Hela ytan är knapp (DESIGN §7).
    this.input.once('pointerup', () => {
      playSound('ui');
      this.scene.start('Game');
    });
  }

  /** Streckad guldring, endast vid nytt rekord. */
  private drawGoldRing(): void {
    const g = this.add.graphics().setDepth(21);
    g.lineStyle(4, INT.gold, 0.8);
    const r = 110;
    const seg = 10 / r;
    const gap = 8 / r;
    for (let a = 0; a < Math.PI * 2; a += seg + gap) {
      g.beginPath();
      g.arc(180, 220, r, a, a + seg, false);
      g.strokePath();
    }
  }
}
