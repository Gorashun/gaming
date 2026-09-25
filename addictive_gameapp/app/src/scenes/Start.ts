import Phaser from 'phaser';
import { INT, THEME, hexToInt } from '../data/theme';
import { CATCH_STEPS, META, META_COLORS, META_SOUND, themeSetById } from '../data/themes';
import { AVATARS, RARITY } from '../data/avatarsIndex';
import { BOX_FX } from '../data/boxes';
import { openBox, type BoxResult } from '../systems/boxes';
import { mulberry32 } from '../systems/rng';
import { Juice } from '../systems/juice';
import { drawShell } from '../ui/shell';
import { addAvatarBadge, drawPearls } from '../ui/avatarBadge';
import { ballTextureKey, scaleForBodyRadius, useSet } from '../ui/textures';
import { nextSetProgress } from '../systems/unlocks';
import { drawBackground } from '../ui/background';
import { iconTextureKey, type IconKey } from '../ui/icons';
import { cached, save } from '../systems/save';
import { playSound, playTone, setCalm, setSoundEnabled, unlockAudio } from '../systems/audio';
import { setHapticsEnabled, vibrate } from '../systems/haptics';

const L = THEME.layout;
const TOUCH = THEME.touch.minLogical;
/** Minsta mellanrum mellan två träffytor (UI.md §2.3). */
const ICON_GAP = 8;
const SH = META.shelf;
const BS = BOX_FX.shelf;
const OP = BOX_FX.open;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');
/** Senast öppnade musslan (testhook), överlever scenomstart. */
let lastBox: BoxResult | null = null;

interface Toggle {
  img: Phaser.GameObjects.Image;
  on: () => boolean;
  set: (v: boolean) => void;
  keys: [onKey: IconKey, offKey: IconKey];
}

/** Startskärm enligt UI.md §7.1. Ingen text utöver logotypen och highscore-siffran. */
export class Start extends Phaser.Scene {
  private toggles: Toggle[] = [];
  /** Öppningsflödet pågår eller visas (ett tryck stänger det). */
  private opening = false;

  constructor() {
    super('Start');
  }

  create(): void {
    // Bästa objektet visas i aktivt sets skinn (UI.md §12.4).
    useSet(this, cached().activeSet);
    drawBackground(this);
    this.toggles = [];
    this.opening = false;
    this.drawLogo();
    this.drawPlay();
    this.drawShelf();
    this.drawIcons();

    if (TEST_HOOK) {
      const self = this;
      (window as unknown as Record<string, unknown>).__start = {
        get lastBox(): BoxResult | null {
          return lastBox;
        },
        get opening(): boolean {
          return self.opening;
        },
      };
      this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
        delete (window as unknown as Record<string, unknown>).__start;
      });
    }

    this.input.on('pointerdown', () => unlockAudio());
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => {
      // Öppningen visas: ett tryck hoppar över/stänger. Nästa mussla kräver ett nytt tryck.
      if (this.opening) {
        this.scene.restart();
        return;
      }
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
      if (
        cached().avatars.pendingBoxes > 0 &&
        Math.abs(p.worldX - BS.x) <= BS.hit / 2 &&
        Math.abs(p.worldY - BS.y) <= BS.hit / 2
      ) {
        this.openNext();
        return;
      }
      // Hela hyllan är träffyta för boken.
      if (
        p.worldX >= SH.hit.x &&
        p.worldX <= SH.hit.x + SH.hit.w &&
        p.worldY >= SH.hit.y &&
        p.worldY <= SH.hit.y + SH.hit.h
      ) {
        playSound('ui');
        this.scene.start('Book');
        return;
      }
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
      .image(SH.best.x, SH.best.y, ballTextureKey(data.bestLevel))
      .setScale(scaleForBodyRadius(data.bestLevel, SH.best.r));

    // Bok-ikonen på hyllan. Nytt i boken: guldprick + andning 0,5 Hz.
    const book = this.add
      .image(SH.book.x, SH.book.y, iconTextureKey('book'))
      .setDisplaySize(SH.book.size, SH.book.size);
    const fresh = data.freshSet !== null || Object.values(data.collection).some((p) => p.fresh.some(Boolean));
    if (fresh) {
      this.add.circle(SH.badge.x, SH.badge.y, SH.badge.r, INT.gold);
      this.tweens.add({
        targets: book,
        scale: book.scale * 1.08,
        duration: META.book.freshPulse.halfCycleMs,
        ease: 'Sine.easeInOut',
        yoyo: true,
        repeat: -1,
      });
    }

    this.drawShells();

    // Stapel mot nästa set (bara tidsspåret). Döljs när alla set är upplåsta.
    const v = nextSetProgress(data.stats.merges, data.unlockedSets.length);
    if (v !== null) {
      const b = SH.bar;
      const bar = this.add.graphics();
      bar.fillStyle(hexToInt(META_COLORS.barTrack), 1);
      bar.fillRoundedRect(b.x0, b.y - b.h / 2, b.x1 - b.x0, b.h, b.h / 2);
      if (v > 0) {
        bar.fillStyle(hexToInt(META_COLORS.barFill), 1);
        bar.fillRoundedRect(b.x0, b.y - b.h / 2, Math.max(b.h, (b.x1 - b.x0) * v), b.h, b.h / 2);
      }
      this.add.image(b.iconX, b.y, iconTextureKey('qmark')).setDisplaySize(b.iconSize, b.iconSize);
    }

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

  // ---------------------------------------------------------------- musslor

  /** Oöppnade musslor på hyllan, utan siffra. Främsta andas 0,5 Hz. */
  private drawShells(): void {
    const n = Math.min(cached().avatars.pendingBoxes, BS.maxShown);
    if (n <= 0) return;
    const c = this.add.container(BS.x, BS.y);
    for (let i = n - 1; i >= 0; i--) {
      c.add(drawShell(this.add.graphics(), BS.size).setPosition(i * BS.dx, i * BS.dy));
    }
    this.tweens.add({
      targets: c,
      scale: BOX_FX.pulse.scale,
      duration: BOX_FX.pulse.halfCycleMs,
      ease: 'Sine.easeInOut',
      yoyo: true,
      repeat: -1,
    });
  }

  /** Öppnar en mussla: sparas direkt, sedan 1,2 s fast visning. */
  private openNext(): void {
    const av = cached().avatars;
    const res = openBox(av, mulberry32((Date.now() ^ Math.imul(av.boxesOpened + 1, 0x9e3779b1)) >>> 0));
    if (!res) av.pendingBoxes = 0;
    lastBox = res;
    void save();
    if (res) this.playOpening(res);
    else this.scene.restart();
  }

  private playOpening(res: BoxResult): void {
    this.opening = true;
    const def = AVATARS.find((a) => a.id === res.avatarId)!;
    const color = RARITY.color[res.rarity];
    const depth = 25;
    const scrim = this.add
      .rectangle(L.width / 2, L.height / 2, L.width, L.height, INT.scrim, OP.scrimAlpha)
      .setDepth(depth)
      .setAlpha(0);
    this.tweens.add({ targets: scrim, alpha: 1, duration: OP.shellMs });

    // 0–200 ms: musslan lyfter från hyllan till mitten och öppnas.
    const shell = drawShell(this.add.graphics(), BS.size).setPosition(BS.x, BS.y).setDepth(depth + 1);
    this.tweens.chain({
      targets: shell,
      tweens: [
        { x: OP.x, y: OP.y, scale: OP.shellScale, duration: OP.shellMs, ease: 'Cubic.easeOut' },
        { scale: OP.shellScale * 1.4, alpha: 0, duration: OP.shellMs, ease: 'Quad.easeIn' },
      ],
    });

    // 200 ms: figuren, raritetsfärgen och pärlorna direkt. Ingen rullning.
    this.time.delayedCall(OP.shellMs, () => {
      const ring = this.add.graphics().setDepth(depth + 2);
      ring.lineStyle(4, hexToInt(color), 1);
      ring.strokeCircle(OP.x, OP.y, OP.avatarR + 8);
      const badge = addAvatarBadge(this, OP.x, OP.y, OP.avatarR, def).setDepth(depth + 2).setScale(0);
      this.tweens.add({ targets: badge, scale: 1, duration: OP.popMs, ease: 'Back.easeOut' });
      const pearls = this.add.graphics().setDepth(depth + 2).setAlpha(0);
      const k = RARITY.pearls[res.rarity];
      drawPearls(pearls, OP.x, OP.pearlsY, k, k, OP.pearlR, OP.pearlPitch, hexToInt(color));
      this.tweens.add({ targets: pearls, alpha: 1, duration: OP.popMs });

      const settings = cached().settings;
      const juice = new Juice(this, OP.x, OP.y, { ...settings }, themeSetById(cached().activeSet).particle);
      juice.trigger('jackpot', OP.intensity[res.rarity], OP.x, OP.y, {
        overlay: true,
        color: hexToInt(color),
        ring: { ...OP.ring, count: settings.calm ? 1 : OP.ring.count, color },
      });
      playTone(META_SOUND.shinyCatch, CATCH_STEPS[Math.min(RARITY.order.indexOf(res.rarity), CATCH_STEPS.length - 1)]);
      vibrate(10);
    });
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
