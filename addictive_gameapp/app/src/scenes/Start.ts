import Phaser from 'phaser';
import { INT, THEME, hexToInt } from '../data/theme';
import { META, META_COLORS } from '../data/themes';
import { AVATAR_UI, avatarById } from '../data/avatarsIndex';
import { openBox, type BoxResult } from '../systems/boxes';
import { mulberry32 } from '../systems/rng';
import { ballTextureKey, scaleForBodyRadius, useSet } from '../ui/textures';
import { avatarIconKey } from '../ui/icons';
import { addAvatarImage, gripToCenter, rarityInt } from '../ui/avatarArt';
import { AvatarRig } from '../ui/avatarRig';
import { ShellOpening } from '../ui/shellOpening';
import { Counters } from '../ui/counters';
import { nextSetProgress } from '../systems/unlocks';
import { drawBackground } from '../ui/background';
import { iconTextureKey, type IconKey } from '../ui/icons';
import { cached, save } from '../systems/save';
import { playSound, setCalm, setSoundEnabled, unlockAudio } from '../systems/audio';
import { setHapticsEnabled, vibrate } from '../systems/haptics';
import { clearBackHandler, setBackHandler } from '../systems/back';
import { DEBUG } from '../data/debug';
import { DebugPanel } from '../ui/debugPanel';
import { fitCamera } from '../ui/view';

const L = THEME.layout;
const TOUCH = THEME.touch.minLogical;
/** Minsta mellanrum mellan två träffytor (UI.md §2.3). */
const ICON_GAP = 8;
const SH = AVATAR_UI.shelf;
const BS = SH.box;
/** Stängd mussla: SVG-ikonen rastreras i 128 px (2×). */
const ICON_PX = 128;
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
  /** Öppningen pågår eller visas (ett tryck hoppar över/stänger). null = ingen. */
  private opening: ShellOpening | null = null;
  /** Debugpanelen (långtryck 2 s på logotypen). */
  private debug: DebugPanel | null = null;
  /** Långtryckets timer i realtid (spelklockan går långsammare vid låg fps). */
  private pressTimer: number | null = null;
  private pressAt = { x: 0, y: 0 };
  /** Fingret som öppnade panelen är fortfarande nere: dess pointerup ignoreras. */
  private debugJustOpened = false;

  constructor() {
    super('Start');
  }

  create(): void {
    fitCamera(this);
    // Bästa objektet visas i aktivt sets skinn (UI.md §12.4).
    useSet(this, cached().activeSet);
    drawBackground(this);
    this.toggles = [];
    this.opening = null;
    this.debug = null;
    this.pressTimer = null;
    this.debugJustOpened = false;
    // Resursräknare i överkanten, y 30 (UI.md §14.2, DESIGN §16.5).
    new Counters(this, cached().economy.pearls, cached().economy.sand);
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
          return self.opening !== null;
        },
        /** 'play' före 1 200 ms (tryck hoppar över), 'done' efter (tryck stänger). */
        get openPhase(): string {
          return self.opening?.phase ?? 'play';
        },
        get debugOpen(): boolean {
          return self.debug !== null;
        },
        /** JSON från debugpanelens "Kopiera JSON" (null innan knappen tryckts). */
        get debugExport(): string | null {
          return self.debug?.lastExport ?? null;
        },
      };
      this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
        delete (window as unknown as Record<string, unknown>).__start;
      });
    }

    // Bakåtknappen stänger öppningen (annars standardbeteendet).
    const onBack = (): boolean => {
      if (this.debug) {
        this.scene.restart();
        return true;
      }
      if (!this.opening) return false;
      this.opening.tap();
      this.opening?.tap();
      return true;
    };
    setBackHandler(onBack);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => clearBackHandler(onBack));

    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      unlockAudio();
      const r = DEBUG.logoHit;
      if (this.opening || this.debug) return;
      if (p.worldX < r.x || p.worldX > r.x + r.w || p.worldY < r.y || p.worldY > r.y + r.h) return;
      this.pressAt = { x: p.worldX, y: p.worldY };
      this.cancelPress();
      this.pressTimer = window.setTimeout(() => {
        this.pressTimer = null;
        if (!this.sys.isActive()) return;
        this.debugJustOpened = true;
        // Stäng = starta om startskärmen, så att nollställning och ny kompis syns direkt.
        this.debug = new DebugPanel(this, () => this.scene.restart());
      }, DEBUG.longPressMs);
    });
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.cancelPress());
    this.input.on('pointermove', (p: Phaser.Input.Pointer) => {
      if (this.pressTimer !== null && Math.hypot(p.worldX - this.pressAt.x, p.worldY - this.pressAt.y) > DEBUG.moveCancelPx) {
        this.cancelPress();
      }
    });
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => {
      if (this.debug) {
        if (this.debugJustOpened) this.debugJustOpened = false;
        else this.debug.tap(p.worldX, p.worldY);
        return;
      }
      this.cancelPress();
      // Öppningen visas: ett tryck hoppar över, nästa stänger. Nästa mussla kräver ett nytt tryck.
      if (this.opening) {
        this.opening.tap();
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
      const inRect = (r: { x: number; y: number; w: number; h: number }): boolean =>
        p.worldX >= r.x && p.worldX <= r.x + r.w && p.worldY >= r.y && p.worldY <= r.y + r.h;
      const av = cached().avatars;
      if (inRect(BS.hit) && av.pendingBoxes > 0) {
        this.openNext();
        return;
      }
      // Vald kompis på hyllan: tryck öppnar boken på Kompisar.
      if (inRect(BS.hit) && av.equipped) {
        playSound('ui');
        this.scene.start('Book', { tab: 'friends' });
        return;
      }
      // Resten av hyllan är träffyta för boken.
      if (inRect(SH.bookHit)) {
        playSound('ui');
        this.scene.start('Book');
        return;
      }
      playSound('ui');
      this.scene.start('Game');
    });
  }

  private cancelPress(): void {
    if (this.pressTimer !== null) window.clearTimeout(this.pressTimer);
    this.pressTimer = null;
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
    const ln = SH.line;
    g.lineStyle(3, INT.jarEdge, 1);
    g.lineBetween(ln.x0, ln.y, ln.x1, ln.y);
    g.lineBetween(ln.x0 + 12, ln.y, ln.x0 + 12, ln.y + 12);
    g.lineBetween(ln.x1 - 12, ln.y, ln.x1 - 12, ln.y + 12);

    this.add
      .image(SH.best.x, SH.best.y, ballTextureKey(data.bestLevel))
      .setScale(scaleForBodyRadius(data.bestLevel, SH.best.r));

    // Bok-ikonen på hyllan. Nytt i boken: guldprick + andning 0,5 Hz.
    const book = this.add
      .image(SH.book.x, SH.book.y, iconTextureKey('book'))
      .setDisplaySize(SH.book.size, SH.book.size);
    const fresh =
      data.freshSet !== null ||
      data.avatars.fresh.length > 0 ||
      Object.values(data.collection).some((p) => p.fresh.some(Boolean));
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

    if (data.avatars.pendingBoxes > 0) this.drawShells();
    else if (data.avatars.equipped) this.drawShelfBuddy(data.avatars.equipped);

    // Stapel mot nästa set (bara tidsspåret). Döljs när alla set är upplåsta.
    const v = nextSetProgress(data.stats.merges, data.unlockedSets.length);
    if (v !== null) {
      const b = META.shelf.bar;
      const bar = this.add.graphics();
      bar.fillStyle(hexToInt(META_COLORS.barTrack), 1);
      bar.fillRoundedRect(b.x0, b.y - b.h / 2, b.x1 - b.x0, b.h, b.h / 2);
      if (v > 0) {
        bar.fillStyle(hexToInt(META_COLORS.barFill), 1);
        bar.fillRoundedRect(b.x0, b.y - b.h / 2, Math.max(b.h, (b.x1 - b.x0) * v), b.h, b.h / 2);
      }
      this.add.image(b.iconX, b.y, iconTextureKey('qmark')).setDisplaySize(b.iconSize, b.iconSize);
    }

    // Rekordets kompis till vänster om kronan (rekord från före v1.2 visas utan figur).
    const rec = avatarById(data.highscoreAvatar);
    if (rec) {
      const R = SH.recordAvatar;
      const rg = this.add.graphics();
      rg.fillStyle(rarityInt(rec.rarity), 0.15);
      rg.fillCircle(R.x, R.y, R.ringR);
      rg.lineStyle(R.ringW, rarityInt(rec.rarity), 1);
      rg.strokeCircle(R.x, R.y, R.ringR);
      addAvatarImage(this, R.x, R.y + gripToCenter(R.displayPx), rec.id, R.displayPx);
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

  /** Vald kompis sitter på hyllan (greppet på hyllinjen) och andas i sin idle-loop. */
  private drawShelfBuddy(id: string): void {
    const def = avatarById(id);
    if (!def) return;
    const B = SH.buddy;
    const img = addAvatarImage(this, B.x, B.gripY, id, B.displayPx);
    const rig = new AvatarRig(this, def, B.displayPx, cached().settings.calm);
    rig.resumeLoop();
    this.events.on(Phaser.Scenes.Events.UPDATE, () => rig.apply(img, B.x, B.gripY));
  }

  // ---------------------------------------------------------------- musslor

  /** Oöppnade musslor på hyllan (UI.md §13.3): hög om upp till 3, ingen siffra, främsta andas 0,5 Hz. */
  private drawShells(): void {
    const n = Math.min(cached().avatars.pendingBoxes, BS.maxShown);
    const k = BS.size / ICON_PX;
    for (let i = n - 1; i >= 0; i--) {
      const img = this.add
        .image(BS.x + i * BS.dx, BS.y + i * BS.dy, avatarIconKey('shell'))
        .setScale(k * (i === 0 ? 1 : BS.backScale))
        .setAlpha(i === 0 ? 1 : BS.backAlpha);
      if (i > 0) continue;
      this.tweens.add({
        targets: img,
        scale: k * SH.boxPulse.scale,
        duration: SH.boxPulse.halfCycleMs,
        ease: SH.boxPulse.ease,
        yoyo: true,
        repeat: -1,
      });
    }
  }

  /** Öppnar en mussla: sparas direkt, sedan 1,2 s fast visning. */
  private openNext(): void {
    const av = cached().avatars;
    const res = openBox(av, mulberry32((Date.now() ^ Math.imul(av.boxesOpened + 1, 0x9e3779b1)) >>> 0));
    if (!res) av.pendingBoxes = 0;
    lastBox = res;
    void save();
    if (!res) {
      this.scene.restart();
      return;
    }
    this.opening = new ShellOpening(this, res, {
      from: { x: BS.x, y: BS.y, px: BS.size },
      closeTo: { x: SH.book.x, y: SH.book.y },
      onClosed: () => this.scene.restart(),
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
