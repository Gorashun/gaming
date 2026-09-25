import Phaser from 'phaser';
import { INT, THEME, hexToInt } from '../data/theme';
import { SLOTS_PER_PAGE } from '../data/collection';
import { CATCH_STEPS, META, META_COLORS, META_SOUND, themeSetById } from '../data/themes';
import {
  FX_DOT,
  FX_GLITTER,
  FX_GLITTER_R,
  ballTextureKey,
  scaleForBodyRadius,
} from '../ui/textures';
import { iconTextureKey, setIconKey } from '../ui/icons';
import { cached, save } from '../systems/save';
import { slotIndex } from '../systems/collection';
import { playSound, playTimbre, playTone } from '../systems/audio';
import { vibrate } from '../systems/haptics';
import { Juice } from '../systems/juice';
import { BOX_FX } from '../data/boxes';
import { drawShell } from '../ui/shell';

/** En plats som fylldes i rundan. */
export interface RevealCatch {
  level: number;
  shiny: boolean;
}

/** Det rundavslutet spelar upp (DESIGN §13.4). Räknas fram i Game innan overlayen visas. */
export interface RevealData {
  setId: string;
  catches: RevealCatch[];
  filledBefore: number;
  /** Stapeln mot nästa set (tidsspåret) före och efter rundan. null = allt upplåst. */
  barFrom: number | null;
  barTo: number | null;
  newSet: string | null;
  /** Nya musslor i rundan (DESIGN §14.3). */
  boxes: number;
}

export interface GameOverData {
  score: number;
  bestLevel: number;
  record: boolean;
  highscore: number;
  reveal?: RevealData;
}

const R = META.reveal;
const CH = META.chain;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');

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

    // Hela ytan är knapp (DESIGN §7), från t = 0 – även mitt i rundavslutet.
    this.input.once('pointerup', () => {
      playSound('ui');
      this.scene.start('Game');
    });
    // Det som hann visas är inte längre "nytt"; resten ligger kvar som fresh till boken.
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => void save());

    if (TEST_HOOK) {
      const self = this;
      const t0 = this.time.now;
      (window as unknown as Record<string, unknown>).__reveal = {
        get landed(): number {
          return self.landed;
        },
        /** Speltid (ms) sedan overlayen skapades. */
        get elapsed(): number {
          return self.time.now - t0;
        },
      };
      this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
        delete (window as unknown as Record<string, unknown>).__reveal;
      });
    }
    this.landed = 0;
    if (data.reveal) this.playReveal(data.reveal);
  }

  /** Antal fångster som landat i boken (testhook). */
  private landed = 0;

  /**
   * Rundavslut "nytt!" (UI.md §12.5) ovanpå förlustskärmen: bok-ikon, nyfångade flyger in,
   * mätaren x/21, stapeln mot nästa set och ev. nytt set. Max 2,5 s. Ingen text utöver siffror.
   */
  private playReveal(rv: RevealData): void {
    const n = rv.catches.length;
    if (n === 0 && rv.barFrom === null && !rv.newSet && rv.boxes === 0) return;
    const page = cached().collection[rv.setId];
    const fast = rv.newSet !== null;
    const fly = fast ? { ...R.flyers, ...R.flyersFast } : R.flyers;
    const m = Math.min(n, R.flyers.max);
    const depth = 23;

    const strip = this.add.container(0, 0).setDepth(depth);
    const book = this.add.image(R.book.x, R.book.y, iconTextureKey('book')).setDisplaySize(R.book.size, R.book.size);
    const bookScale = book.scale;
    book.setScale(0);
    let filled = rv.filledBefore;
    const meter = this.add
      .text(R.meter.x, R.meter.y, `${filled}/${SLOTS_PER_PAGE}`, {
        fontFamily: THEME.type.family,
        fontSize: `${R.meter.px}px`,
        color: THEME.palette.hud,
        fontStyle: THEME.type.weightHeavy,
      })
      .setOrigin(0, 0.5)
      .setAlpha(0);
    strip.add([book, meter]);

    const B = R.bar;
    const bar = this.add.graphics().setAlpha(0);
    const drawBar = (v: number): void => {
      bar.clear();
      bar.fillStyle(hexToInt(META_COLORS.barTrack), 1);
      bar.fillRoundedRect(B.x0, B.y - B.h / 2, B.x1 - B.x0, B.h, B.h / 2);
      const w = (B.x1 - B.x0) * v;
      if (w <= 0) return;
      bar.fillStyle(hexToInt(META_COLORS.barFill), 1);
      bar.fillRoundedRect(B.x0, B.y - B.h / 2, Math.max(w, B.h), B.h, B.h / 2);
    };
    if (rv.barFrom !== null) {
      drawBar(rv.barFrom);
      const q = this.add.image(B.iconX, B.y, iconTextureKey('qmark')).setDisplaySize(B.iconSize, B.iconSize);
      strip.add([bar, q.setAlpha(0)]);
    }

    // t = 200: stripen in med gamla värden.
    this.time.delayedCall(R.startMs, () => {
      this.tweens.add({ targets: book, scale: bookScale, duration: R.book.inMs, ease: 'Back.easeOut' });
      this.tweens.add({ targets: strip.list.slice(1), alpha: 1, duration: R.book.inMs });
    });

    // Flygarna, en i taget från sin kedjeplats in i boken.
    for (let i = 0; i < m; i++) {
      const rest = i === m - 1 ? rv.catches.slice(i) : [rv.catches[i]];
      this.time.delayedCall(R.flyStartMs + i * fly.staggerMs, () =>
        this.flyer(rv, rest, fly.flightMs, depth + 1, () => {
          filled += rest.length;
          this.landed += rest.length;
          meter.setText(`${filled}/${SLOTS_PER_PAGE}`);
          for (const c of rest) if (page) page.fresh[slotIndex(c.level, c.shiny)] = false;
          this.tweens.add({ targets: book, scale: bookScale * R.bookPunch.peak, duration: R.bookPunch.ms / 2, yoyo: true, ease: 'Back.easeOut' });
          this.tweens.add({ targets: meter, scale: 1.25, duration: R.bookPunch.ms / 2, yoyo: true, ease: 'Back.easeOut' });
          const shiny = rest.some((c) => c.shiny);
          playTone(shiny ? META_SOUND.shinyCatch : META_SOUND.catch, CATCH_STEPS[i]);
          vibrate(10);
          if (shiny) this.sparks(R.book.x, R.book.y, depth + 1);
        }),
      );
    }

    // Stapeln fylls från gammalt till nytt värde.
    const barAt = m > 0 ? R.flyStartMs + (m - 1) * fly.staggerMs + fly.flightMs + 80 : R.flyStartMs;
    const barMs = fast ? R.barFillFastMs : R.barFillMs;
    if (rv.barFrom !== null && rv.barTo !== null && rv.barTo !== rv.barFrom) {
      const from = rv.barFrom;
      const to = rv.barTo;
      this.time.delayedCall(barAt, () =>
        this.tweens.addCounter({
          from,
          to,
          duration: barMs,
          ease: 'Quad.easeOut',
          onUpdate: (tw) => drawBar(tw.getValue() ?? to),
        }),
      );
    }

    if (rv.newSet) {
      const id = rv.newSet;
      this.time.delayedCall(barAt + barMs, () => {
        this.tweens.add({ targets: strip, alpha: 0, duration: R.newSet.stripFadeMs });
        this.revealSet(id, depth + 2);
      });
    }

    // Sist: musslan poppar upp och flyger till hyllan (≤400 ms, omstart går alltid).
    if (rv.boxes > 0) {
      const at = barAt + barMs + (rv.newSet ? R.newSet.ringMs : 0);
      this.time.delayedCall(at, () => this.flyShell(depth + 3));
    }
  }

  private flyShell(depth: number): void {
    const F = BOX_FX.fly;
    const g = drawShell(this.add.graphics(), F.size).setPosition(F.x, F.y).setDepth(depth).setScale(0);
    playTone(META_SOUND.catch, CATCH_STEPS[CATCH_STEPS.length - 1]);
    this.tweens.chain({
      targets: g,
      tweens: [
        { scale: 1, duration: F.popMs, ease: 'Back.easeOut' },
        { x: F.toX, y: F.toY, scale: 0.5, alpha: 0, duration: F.flyMs, ease: 'Cubic.easeIn' },
      ],
    });
  }

  /** En Glimt lyfter från sin kedjeplats och flyger i en båge in i boken. */
  private flyer(rv: RevealData, carries: RevealCatch[], ms: number, depth: number, onArrive: () => void): void {
    const c = carries[0];
    const r0 = CH.r0 + CH.rStep * c.level;
    const x0 = CH.x0 + CH.pitch * c.level;
    const y0 = CH.y;
    const cx = (x0 + R.book.x) / 2;
    const img = this.add.image(x0, y0, ballTextureKey(c.level, rv.setId)).setDepth(depth);
    const glitter = carries.some((k) => k.shiny) ? this.add.image(x0, y0, FX_GLITTER).setDepth(depth) : null;
    const F = R.flyers;
    this.tweens.addCounter({
      from: 0,
      to: 1,
      duration: ms,
      ease: 'Sine.easeInOut',
      onUpdate: (tw) => {
        const t = tw.getValue() ?? 1;
        const u = 1 - t;
        const x = u * u * x0 + 2 * u * t * cx + t * t * R.book.x;
        const y = u * u * y0 + 2 * u * t * F.ctrlY + t * t * R.book.y;
        const rad = t < 0.5 ? r0 + (F.midR - r0) * t * 2 : F.midR + (F.endR - F.midR) * (t - 0.5) * 2;
        img.setPosition(x, y).setScale(scaleForBodyRadius(c.level, rad));
        glitter?.setPosition(x, y).setScale((rad * META.shiny.ringRadius) / FX_GLITTER_R).setRotation(t * 4);
      },
      onComplete: () => {
        img.destroy();
        glitter?.destroy();
        onArrive();
      },
    });
  }

  /** Fyra guldgnistor när en skimrande landar. */
  private sparks(x: number, y: number, depth: number): void {
    for (let k = 0; k < 4; k++) {
      const a = (k / 4) * Math.PI * 2 + Math.PI / 4;
      const s = this.add.image(x, y, FX_DOT).setTint(INT.gold).setDepth(depth).setBlendMode('ADD');
      this.tweens.add({
        targets: s,
        x: x + Math.cos(a) * 30,
        y: y + Math.sin(a) * 30,
        alpha: 0,
        scale: 0.3,
        duration: 360,
        ease: 'Cubic.easeOut',
        onComplete: () => s.destroy(),
      });
    }
  }

  /** Nytt set: setikonen med guldringar, jackpot-juice utan shake/zoom/hit-stop och fanfar. */
  private revealSet(id: string, depth: number): void {
    const N = R.newSet;
    const set = themeSetById(id);
    const settings = cached().settings;
    const icon = this.add.image(N.x, N.y, setIconKey(id)).setDisplaySize(N.size, N.size).setDepth(depth);
    const s = icon.scale;
    icon.setScale(0);
    this.tweens.add({ targets: icon, scale: s, duration: N.inMs, ease: 'Back.easeOut', easeParams: [2] });
    const juice = new Juice(this, N.x, N.y, settings, set.particle);
    juice.trigger('jackpot', N.intensity, N.x, N.y, {
      overlay: true,
      color: hexToInt(set.signature),
      ring: {
        count: settings.calm ? 1 : N.rings,
        fromR: N.ringFromR,
        maxR: N.ringMaxR,
        durationMs: N.ringMs,
        stepMs: N.ringStepMs,
        color: THEME.palette.gold,
        alpha: 0.85,
      },
    });
    playTone(META_SOUND.newSet);
    // "Hör den nya världen": setets egen klang på 392 och 587 Hz.
    playTimbre(set.sound, 0, META_SOUND.newSetPreviewAtMs);
    playTimbre(set.sound, 7, META_SOUND.newSetPreviewAtMs + 120);
    const d = cached();
    if (d.freshSet === id) d.freshSet = null;
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
