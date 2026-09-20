import Phaser from 'phaser';
import { INT, THEME } from '../data/theme';
import { ballTextureKey, scaleForBodyRadius } from '../ui/textures';
import { drawBackground } from '../ui/background';
import { iconTextureKey, type IconKey } from '../ui/icons';
import { cached, save } from '../systems/save';
import { playSound, setCalm, setSoundEnabled, unlockAudio } from '../systems/audio';
import { setHapticsEnabled, vibrate } from '../systems/haptics';

const L = THEME.layout;
const TOUCH = THEME.touch.minLogical;
/** Minsta mellanrum mellan två träffytor (UI.md §2.3). */
const ICON_GAP = 8;

interface Toggle {
  img: Phaser.GameObjects.Image;
  on: () => boolean;
  set: (v: boolean) => void;
  keys: [onKey: IconKey, offKey: IconKey];
}

/** Startskärm enligt UI.md §7.1. Ingen text utöver logotypen och highscore-siffran. */
export class Start extends Phaser.Scene {
  private toggles: Toggle[] = [];

  constructor() {
    super('Start');
  }

  create(): void {
    drawBackground(this);
    this.toggles = [];
    this.drawLogo();
    this.drawPlay();
    this.drawShelf();
    this.drawIcons();

    this.input.on('pointerdown', () => unlockAudio());
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => {
      const hit = this.toggles.find(
        (t) => Math.abs(p.worldX - t.img.x) <= TOUCH / 2 && Math.abs(p.worldY - t.img.y) <= TOUCH / 2,
      );
      if (hit) {
        const next = !hit.on();
        hit.set(next);
        hit.img.setTexture(iconTextureKey(next ? hit.keys[0] : hit.keys[1]));
        playSound('ui');
        vibrate(10);
        return;
      }
      if (p.worldY > 540) return; // ikonraden: ingen oavsiktlig start
      playSound('ui');
      this.scene.start('Game');
    });
  }

  // ---------------------------------------------------------------- logotyp

  private drawLogo(): void {
    const baseline = 190;
    const style = {
      fontFamily: THEME.type.family,
      fontSize: `${THEME.type.logo}px`,
      color: THEME.palette.hud,
      fontStyle: THEME.type.weightHeavy,
    };
    const sp = THEME.type.letterSpacingLogo;
    const measure = (s: string): number => {
      const t = this.make.text({ text: s, style }, false);
      const w = t.width + sp * (s.length - 1);
      t.destroy();
      return w;
    };
    const wKL = measure('KL');
    const wU = measure('U');
    const wNK = measure('NK');
    const total = wKL + sp + wU + sp + wNK;
    let x = (L.width - total) / 2;

    this.add.text(x, baseline, 'KL', style).setOrigin(0, 1).setLetterSpacing(sp);
    x += wKL + sp;
    this.drawJarGlyph(x, baseline, wU);
    x += wU + sp;
    this.add.text(x, baseline, 'NK', style).setOrigin(0, 1).setLetterSpacing(sp);
  }

  /** U:et i logotypen ÄR burken: öppen upptill, rimlinje ovanför, en glimt i sig. */
  private drawJarGlyph(x: number, baseline: number, w: number): void {
    const top = baseline - 48;
    const bot = baseline - 4;
    const r = Math.min(w / 2, (bot - top) / 2);
    const g = this.add.graphics();
    g.lineStyle(9, INT.hud, 1);
    g.lineBetween(x + 4, top, x + 4, bot - r);
    g.lineBetween(x + w - 4, top, x + w - 4, bot - r);
    g.beginPath();
    g.arc(x + w / 2, bot - r, w / 2 - 4, 0, Math.PI, false);
    g.strokePath();
    g.lineStyle(5, INT.jarEdge, 1);
    g.lineBetween(x - 2, top - 8, x + w + 2, top - 8);
    this.add
      .image(x + w / 2, bot - r - 2, ballTextureKey(2))
      .setScale(scaleForBodyRadius(2, w / 2 - 12));
  }

  // ---------------------------------------------------------------- play

  private drawPlay(): void {
    const cx = 180;
    const cy = 330;
    const g = this.add.graphics();
    g.fillStyle(INT.accent, 0.12);
    g.fillCircle(cx, cy, 56);
    g.lineStyle(4, INT.accent, 1);
    g.strokeCircle(cx, cy, 56);
    const icon = this.add.image(cx + 4, cy, iconTextureKey('play')).setDisplaySize(64, 64);
    this.tweens.add({
      targets: icon,
      scale: icon.scale * 1.06,
      duration: THEME.anim.recordPulse.durationMs,
      ease: THEME.anim.recordPulse.ease,
      yoyo: true,
      repeat: -1,
    });
  }

  // ---------------------------------------------------------------- hylla

  private drawShelf(): void {
    const data = cached();
    const g = this.add.graphics();
    g.lineStyle(3, INT.jarEdge, 1);
    g.lineBetween(80, 470, 280, 470);
    g.lineBetween(92, 470, 92, 482);
    g.lineBetween(268, 470, 268, 482);

    this.add
      .image(180, 436, ballTextureKey(data.bestLevel))
      .setScale(scaleForBodyRadius(data.bestLevel, 34));

    this.add.image(140, 498, iconTextureKey('crown')).setDisplaySize(26, 26);
    this.add
      .text(172, 498, `${data.highscore}`, {
        fontFamily: THEME.type.family,
        fontSize: '28px',
        color: THEME.palette.gold,
        fontStyle: THEME.type.weightHeavy,
      })
      .setOrigin(0, 0.5);
  }

  // ---------------------------------------------------------------- ikoner

  private drawIcons(): void {
    const s = cached().settings;
    // Fyra 72 px-mål centrerade: 4·72 + 3·8 mellanrum = 312 px, marginal 24 px i kanterna.
    const step = TOUCH + ICON_GAP;
    const x0 = L.width / 2 - (step * 3) / 2;
    const y = 580;
    this.addToggle(x0, y, ['soundOn', 'soundOff'], () => s.sound, (v) => {
      s.sound = v;
      setSoundEnabled(v);
      if (v) unlockAudio();
      void save({ settings: { ...s, sound: v } });
    });
    this.addToggle(x0 + step, y, ['hapticOn', 'hapticOff'], () => s.haptics, (v) => {
      s.haptics = v;
      setHapticsEnabled(v);
      void save({ settings: { ...s, haptics: v } });
    });
    this.addToggle(x0 + step * 2, y, ['calmOn', 'calmOff'], () => s.calm, (v) => {
      s.calm = v;
      setCalm(v);
      void save({ settings: { ...s, calm: v } });
    });
    this.addToggle(x0 + step * 3, y, ['aimOn', 'aimOff'], () => s.aimLine, (v) => {
      s.aimLine = v;
      void save({ settings: { ...s, aimLine: v } });
    });
  }

  private addToggle(
    x: number,
    y: number,
    keys: [IconKey, IconKey],
    on: () => boolean,
    set: (v: boolean) => void,
  ): void {
    const img = this.add
      .image(x, y, iconTextureKey(on() ? keys[0] : keys[1]))
      .setDisplaySize(48, 48);
    this.toggles.push({ img, on, set, keys });
  }
}
