import Phaser from 'phaser';
import { INT, THEME, hexToInt } from '../data/theme';
import { avatarById } from '../data/avatarsIndex';
import { ECONOMY_ICON_KEYS, formatAmount } from '../data/economyUi';
import { BUTTON_SOUND, BUTTON_STYLE, START_COLORS, START_FONT, START_ICON_KEYS, START_UI, fillString, type StartCard } from '../data/startUi';
import { openBox, type BoxResult } from '../systems/boxes';
import { mulberry32 } from '../systems/rng';
import { ballTextureKey, BG_GLOW, scaleForBodyRadius, useSet } from '../ui/textures';
import { avatarIconKey, iconTextureKey, setIconKey } from '../ui/icons';
import { addAvatarImage, gripToCenter, rarityInt } from '../ui/avatarArt';
import { AvatarRig } from '../ui/avatarRig';
import { playFxCue } from '../ui/avatarFx';
import { ShellOpening } from '../ui/shellOpening';
import { drawBackground } from '../ui/background';
import { cached, save } from '../systems/save';
import { playSound, playTone, unlockAudio } from '../systems/audio';
import { clearBackHandler, setBackHandler } from '../systems/back';
import { getLocale, str, type Locale } from '../systems/i18n';
import { startView, type StartView } from '../systems/startView';
import { DEBUG } from '../data/debug';
import { DebugPanel } from '../ui/debugPanel';
import { fitCamera } from '../ui/view';
import { bakeLogical, UiButton } from '../ui/button';
import { SettingsSheet } from '../ui/settingsSheet';

const U = START_UI;
const C = START_COLORS;
const FONT = START_FONT.family;
/** SVG-ikonerna rastreras i 128 px (2×). */
const ICON_PX = 128;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');
/** Senast öppnade musslan (testhook), överlever scenomstart. */
let lastBox: BoxResult | null = null;

const text = (px: number, weight: string, color: string): Phaser.Types.GameObjects.Text.TextStyle => ({
  fontFamily: FONT,
  fontSize: `${px}px`,
  fontStyle: weight,
  color,
});

/** Blandar två färger (tal) med andelen t av b. */
function mix(a: number, b: number, t: number): number {
  const ch = (s: number): number => Math.round(((a >> s) & 255) * (1 - t) + ((b >> s) & 255) * t) << s;
  return ch(16) | ch(8) | ch(0);
}

/** Startskärm v2 (UI.md §16, DESIGN §18): piller, hjälte, rekord, SPELA, tre kort, set-stapel. */
export class Start extends Phaser.Scene {
  private buttons: UiButton[] = [];
  /** Knappen som hålls ned just nu. */
  private held: UiButton | null = null;
  private play!: UiButton;
  /** Öppningen pågår eller visas (ett tryck hoppar över/stänger). null = ingen. */
  private opening: ShellOpening | null = null;
  private sheet: SettingsSheet | null = null;
  /** Debugpanelen (långtryck 2 s på logotypen). */
  private debug: DebugPanel | null = null;
  /** Långtryckets timer i realtid (spelklockan går långsammare vid låg fps). */
  private pressTimer: number | null = null;
  private pressAt = { x: 0, y: 0 };
  /** Fingret som öppnade panelen är fortfarande nere: dess pointerup ignoreras. */
  private debugJustOpened = false;
  private heroTap: () => void = () => undefined;
  private view!: StartView;
  /** Den tittande musslans plats (öppningen startar där). */
  private peekAt = { x: 0, y: 0 };
  /** Synliga texter per element (testhook). */
  private labels: Record<string, string> = {};

  constructor() {
    super('Start');
  }

  create(): void {
    fitCamera(this);
    const d = cached();
    // Bästa objektet visas i aktivt sets skinn (UI.md §12.4).
    useSet(this, d.activeSet);
    drawBackground(this);
    this.buttons = [];
    this.held = null;
    this.opening = null;
    this.sheet = null;
    this.debug = null;
    this.pressTimer = null;
    this.debugJustOpened = false;
    this.labels = {};
    this.heroTap = () => undefined;
    this.view = startView(d);
    const loc = getLocale();

    this.drawTopbar();
    this.drawLogo();
    this.drawHero();
    this.drawRecord();
    this.drawPlay(loc);
    this.drawCards(loc);
    this.drawSetBar(loc);

    if (TEST_HOOK) this.installTestHook();

    // Bakåt: arket, sedan öppningen, sedan debugpanelen (annars standardbeteendet).
    const onBack = (): boolean => {
      if (this.sheet) {
        this.sheet.hide();
        return true;
      }
      if (this.opening) {
        this.opening.tap();
        this.opening?.tap();
        return true;
      }
      if (this.debug) {
        this.scene.restart();
        return true;
      }
      return false;
    };
    setBackHandler(onBack);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      clearBackHandler(onBack);
      this.cancelPress();
    });
    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => this.onDown(p.worldX, p.worldY));
    this.input.on('pointermove', (p: Phaser.Input.Pointer) => this.onMove(p.worldX, p.worldY));
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => this.onUp(p.worldX, p.worldY));
    this.input.on('pointerupoutside', () => {
      this.held?.release(false);
      this.held = null;
    });
  }

  private installTestHook(): void {
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
      get sheetOpen(): boolean {
        return self.sheet !== null;
      },
      /** Butik-kortet har badge (prick + guldkant + tittande mussla). */
      get shopBadge(): boolean {
        return self.view.shop.badge;
      },
      get badges(): Record<StartCard, boolean> {
        const v = self.view;
        return { book: v.book.badge, buddies: v.buddies.badge, shop: v.shop.badge };
      },
      get labels(): Record<string, string> {
        return { ...self.labels };
      },
    };
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      delete (window as unknown as Record<string, unknown>).__start;
    });
  }

  // ---------------------------------------------------------------- input (en väg, modala lager först)

  private onDown(x: number, y: number): void {
    unlockAudio();
    if (this.opening || this.debug) return;
    if (this.sheet) {
      this.sheet.down(x, y);
      return;
    }
    const r = DEBUG.logoHit;
    if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
      this.pressAt = { x, y };
      this.cancelPress();
      this.pressTimer = window.setTimeout(() => {
        this.pressTimer = null;
        if (!this.sys.isActive() || this.sheet || this.opening) return;
        this.debugJustOpened = true;
        // Stäng = starta om startskärmen, så att nollställning och ny kompis syns direkt.
        this.debug = new DebugPanel(this, () => this.scene.restart());
      }, DEBUG.longPressMs);
      return;
    }
    const b = this.buttons.find((k) => k.contains(x, y));
    if (b) {
      this.held = b;
      b.press();
      return;
    }
    const H = U.hero.hit;
    if (x >= H.x && x <= H.x + H.w && y >= H.y && y <= H.y + H.h) this.heroTap();
  }

  private onMove(x: number, y: number): void {
    if (this.pressTimer !== null && Math.hypot(x - this.pressAt.x, y - this.pressAt.y) > DEBUG.moveCancelPx) this.cancelPress();
    this.sheet?.move(x, y);
    // Glider fingret ut ur träffytan släpps knappen tyst.
    if (this.held && !this.held.contains(x, y)) {
      this.held.release(false);
      this.held = null;
    }
  }

  private onUp(x: number, y: number): void {
    if (this.debug) {
      if (this.debugJustOpened) this.debugJustOpened = false;
      else this.debug.tap(x, y);
      return;
    }
    this.cancelPress();
    // Öppningen visas: ett tryck hoppar över, nästa stänger. Nästa mussla kräver ett nytt tryck.
    if (this.opening) {
      this.opening.tap();
      return;
    }
    if (this.sheet) {
      this.sheet.up(x, y);
      return;
    }
    const b = this.held;
    this.held = null;
    b?.release(b.contains(x, y));
  }

  private cancelPress(): void {
    if (this.pressTimer !== null) window.clearTimeout(this.pressTimer);
    this.pressTimer = null;
  }

  // ---------------------------------------------------------------- toppbar

  private drawTopbar(): void {
    const T = U.topbar;
    const P = T.pill;
    const eco = cached().economy;
    const g = this.add.graphics();
    const pill = (x: number, iconKey: string, iconPx: number, n: number): number => {
      const icon = this.add.image(0, T.y, iconKey).setScale(iconPx / ICON_PX);
      const t = this.add.text(0, T.y, formatAmount(n), text(P.textPx, P.textWeight, C.hud)).setOrigin(0, 0.5);
      const w = Math.max(P.minW, P.padL + iconPx + P.gap + t.width + P.padR);
      g.fillStyle(hexToInt(C.pillFill), 1);
      g.fillRoundedRect(x, T.y - P.h / 2, w, P.h, P.r);
      g.lineStyle(P.edgeW, hexToInt(C.pillEdge), 1);
      g.strokeRoundedRect(x + P.edgeW / 2, T.y - P.h / 2 + P.edgeW / 2, w - P.edgeW, P.h - P.edgeW, P.r - P.edgeW / 2);
      // Innehållet centreras i pillret (minsta bredd).
      const inner = iconPx + P.gap + t.width;
      const x0 = x + P.padL + (w - P.padL - P.padR - inner) / 2;
      icon.x = x0 + iconPx / 2;
      t.x = x0 + iconPx + P.gap;
      return x + w;
    };
    const right = pill(T.pearls.x, ECONOMY_ICON_KEYS.pearlCoin, T.pearls.iconPx, eco.pearls);
    pill(Math.max(T.sand.minX, right + T.sand.gapAfterPearls), ECONOMY_ICON_KEYS.sand, T.sand.iconPx, eco.sand);

    const G = T.gear;
    const gear = new UiButton(this, 'round', G.x, G.y, G.d, G.d, G.hit, G.hit, () => this.openSheet());
    gear.body.add(this.add.image(0, 0, START_ICON_KEYS.gear).setScale(G.iconPx / ICON_PX));
    this.buttons.push(gear);
  }

  private openSheet(): void {
    if (this.sheet) return;
    this.sheet = new SettingsSheet(this, getLocale(), () => {
      this.sheet = null;
    });
  }

  // ---------------------------------------------------------------- logotyp

  private drawLogo(): void {
    const L = U.logo;
    const style = text(L.px, L.weight, THEME.palette.hud);
    const make = (s: string): Phaser.GameObjects.Text =>
      this.add
        .text(0, L.baseline, s, style)
        .setOrigin(0, 1)
        .setLetterSpacing(L.letterSpacing)
        .setShadow(L.shadow.dx, L.shadow.dy, L.shadow.color, 0, false, true);
    const kl = make('KL');
    const nk = make('NK');
    // Textrutans underkant ligger `descent` under baslinjen.
    const descent = kl.getTextMetrics().descent;
    kl.y += descent;
    nk.y += descent;
    const measure = make('U');
    const wU = measure.width - L.letterSpacing;
    measure.destroy();
    const total = kl.width + wU + L.letterSpacing + nk.width;
    let x = 180 - total / 2;
    kl.x = x;
    x += kl.width;
    this.drawJarGlyph(x, L.baseline, wU);
    nk.x = x + wU + L.letterSpacing;
  }

  /** U:et i logotypen ÄR burken: öppen upptill, rimlinje ovanför, en glimt i sig. */
  private drawJarGlyph(x: number, baseline: number, w: number): void {
    const L = U.logo;
    // Fredokas versalhöjd ≈ 0,69 em; rundningen går 1 px under baslinjen som i typsnittet.
    const sw = L.jarStroke;
    const bot = baseline + 1 - sw / 2;
    const top = baseline - L.px * 0.69;
    const r = w / 2 - sw / 2;
    const g = this.add.graphics();
    const glyph = (dy: number, color: number): void => {
      g.lineStyle(sw, color, 1);
      g.beginPath();
      g.moveTo(x + sw / 2, top + dy);
      g.lineTo(x + sw / 2, bot - r + dy);
      g.arc(x + w / 2, bot - r + dy, r, Math.PI, 0, true);
      g.lineTo(x + w - sw / 2, top + dy);
      g.strokePath();
    };
    glyph(L.shadow.dy, hexToInt(L.shadow.color));
    glyph(0, INT.hud);
    g.lineStyle(5, INT.jarEdge, 1);
    g.lineBetween(x - 3, top - 8, x + w + 3, top - 8);
    this.add.image(x + w / 2, bot - r - 1, ballTextureKey(2)).setScale(scaleForBodyRadius(2, r - sw / 2 - 3));
  }

  // ---------------------------------------------------------------- hjälte

  private drawHero(): void {
    const d = cached();
    const H = U.hero;
    const def = d.avatars.equipped ? avatarById(d.avatars.equipped) : undefined;
    const calm = d.settings.calm;

    const halo = this.add.image(H.cx, H.halo.cy, BG_GLOW).setScale((H.halo.r * 2) / 256).setAlpha(H.halo.alpha);
    halo.setTint(def ? mix(INT.accent, rarityInt(def.rarity), H.halo.rarityMix) : INT.accent);

    // Scenen: bakad ellips med tjocklek, gradient, kant, reflex och skugga.
    const S = H.stage;
    const pad = 12;
    const sw = S.rx * 2 + pad * 2;
    const sh = S.ry * 2 + S.depth + pad * 2;
    const key = bakeLogical(this, 'st-stage', sw, sh, (ctx, dpr) => {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const cx = sw / 2;
      const cy = pad + S.ry;
      ctx.save();
      ctx.filter = 'blur(5px)';
      ctx.fillStyle = `rgba(0,0,0,${S.shadowAlpha})`;
      ctx.beginPath();
      ctx.ellipse(cx, cy + S.depth + 4, S.rx, S.ry, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
      // Tjockleken: botten-ellips + sidor.
      ctx.fillStyle = C.stageBottom;
      ctx.beginPath();
      ctx.ellipse(cx, cy + S.depth, S.rx, S.ry, 0, 0, Math.PI);
      ctx.lineTo(cx - S.rx, cy);
      ctx.ellipse(cx, cy, S.rx, S.ry, 0, Math.PI, 0, true);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = C.stageEdge;
      ctx.lineWidth = S.edgeW;
      ctx.globalAlpha = 0.5;
      ctx.stroke();
      ctx.globalAlpha = 1;
      const grad = ctx.createLinearGradient(0, cy - S.ry, 0, cy + S.ry);
      grad.addColorStop(0, C.stageTop);
      grad.addColorStop(1, C.stageBottom);
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.ellipse(cx, cy, S.rx, S.ry, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = C.stageEdge;
      ctx.stroke();
      // Reflexbåge i främre kanten.
      ctx.strokeStyle = 'rgba(255,255,255,0.22)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.ellipse(cx, cy, S.rx - 8, S.ry - 4, 0, Math.PI * 0.2, Math.PI * 0.8);
      ctx.stroke();
    });
    this.add.image(H.cx, S.cy + S.depth / 2, key);

    const B = H.ball;
    const lvl = d.bestLevel;
    if (!def) {
      // Utan kompis: objektet r 30 står på scenen och guppar (0,36 Hz). Tryck: mergePunch + pling.
      const r = 30;
      const base = scaleForBodyRadius(lvl, r);
      const cy = S.cy - r + 6;
      const ball = this.add.image(H.cx, cy, ballTextureKey(lvl)).setScale(base);
      this.tweens.add({ targets: ball, y: cy + (calm ? U.calm.bobDy : H.bob.dy), duration: H.bob.halfCycleMs, ease: H.bob.ease, yoyo: true, repeat: -1 });
      const P = THEME.anim.mergePunch;
      this.heroTap = () => {
        if (this.tweens.isTweening(ball) && ball.scale !== base) return;
        this.tweens.add({ targets: ball, scale: base * 1.1, duration: P.durationMs / 2, ease: 'Quad.easeOut', yoyo: true, onComplete: () => void ball.setScale(base) });
        playSound('merge', { combo: 1 });
      };
      return;
    }
    this.add.image(H.cx, B.cy, ballTextureKey(lvl)).setScale(scaleForBodyRadius(lvl, B.r));
    const px = H.buddy.displayPx;
    const gripY = B.cy - B.r + H.buddy.gripBelowTop;
    const img = addAvatarImage(this, H.cx, gripY, def.id, px);
    const rig = new AvatarRig(this, def, px, calm);
    rig.resumeLoop();
    this.events.on(Phaser.Scenes.Events.UPDATE, () => rig.apply(img, H.cx, gripY));
    // Tryck = kompisens showcase en gång (leksak). Tryck under pågående showcase ignoreras.
    let showing = false;
    this.heroTap = () => {
      if (showing) return;
      showing = true;
      const sc = def.showcase;
      playTone(sc.sound);
      rig.play(sc.anim, 3, 1, () => {
        showing = false;
        rig.resumeLoop();
      });
      this.time.delayedCall(sc.fxAtMs, () => playFxCue(this, sc.fx, H.cx, gripY - gripToCenter(px), px / 56, 7, calm));
    };
  }

  // ---------------------------------------------------------------- rekord

  private drawRecord(): void {
    const d = cached();
    const R = U.record;
    const num = this.add.text(0, R.y, formatAmount(d.highscore), text(R.textPx, R.textWeight, C.gold)).setOrigin(0, 0.5);
    const rec = d.highscoreAvatar && d.highscoreAvatar !== d.avatars.equipped ? avatarById(d.highscoreAvatar) : undefined;
    const A = R.avatar;
    const avW = rec ? A.ringR * 2 + R.gap : 0;
    const w = R.padX * 2 + avW + R.crownPx + R.gap + num.width;
    const x0 = 180 - w / 2;
    const g = this.add.graphics();
    g.fillStyle(INT.gold, 0.1);
    g.fillRoundedRect(x0, R.y - R.h / 2, w, R.h, R.r);
    g.lineStyle(R.edgeW, INT.gold, 0.45);
    g.strokeRoundedRect(x0 + R.edgeW / 2, R.y - R.h / 2 + R.edgeW / 2, w - R.edgeW, R.h - R.edgeW, R.r - R.edgeW / 2);
    let x = x0 + R.padX;
    if (rec) {
      const cx = x + A.ringR;
      g.fillStyle(rarityInt(rec.rarity), 0.15);
      g.fillCircle(cx, R.y, A.ringR);
      g.lineStyle(A.ringW, rarityInt(rec.rarity), 1);
      g.strokeCircle(cx, R.y, A.ringR);
      addAvatarImage(this, cx, R.y + gripToCenter(A.displayPx), rec.id, A.displayPx);
      x += avW;
    }
    this.add.image(x + R.crownPx / 2, R.y, iconTextureKey('crown')).setScale(R.crownPx / ICON_PX);
    num.x = x + R.crownPx + R.gap;
  }

  // ---------------------------------------------------------------- SPELA

  private drawPlay(loc: Locale): void {
    const P = U.play;
    const style = BUTTON_STYLE.primary;
    const b = new UiButton(this, 'primary', P.cx, P.cy, P.w, P.h, P.w + P.slop * 2, P.h + P.slop * 2, () => this.scene.start('Game'));
    const label = str('play', loc).toUpperCase();
    const L = style.label;
    const t = this.add.text(0, 0, label, text(L.px, L.weight, style.looks.normal.ink)).setOrigin(0, 0.5).setLetterSpacing(L.letterSpacing);
    const tw = t.width - L.letterSpacing;
    const x0 = -(P.iconPx + P.gap + tw) / 2;
    const glyph = this.add.image(x0 + P.iconPx / 2, 0, START_ICON_KEYS.playGlyph).setScale(P.iconPx / ICON_PX);
    t.x = x0 + P.iconPx + P.gap;
    t.y = 1;
    b.body.add([glyph, t]);
    this.labels.play = label;
    const scale = cached().settings.calm ? U.calm.playPulseScale : P.pulse.scale;
    b.pulse = this.tweens.add({ targets: b.root, scale, duration: P.pulse.halfCycleMs, ease: P.pulse.ease, yoyo: true, repeat: -1 });
    this.buttons.push(b);
    this.play = b;
    if (this.view.newPlayer) this.drawHand();
  }

  /** Ny spelare: handen trycker på SPELA var 2,2 s och knappen gör sitt tryckläge i takt (panel E). */
  private drawHand(): void {
    const P = U.play;
    const H = P.hint;
    const k = H.handPx / ICON_PX;
    const hand = this.add.image(P.cx + H.dx, P.cy + H.dy, iconTextureKey('hand')).setScale(k).setOrigin(0.5, 0.2).setDepth(5);
    const press = (): void => {
      this.handPress(true);
      this.tweens.add({ targets: hand, scale: k * 0.9, duration: 80, ease: 'Quad.easeOut', yoyo: true, hold: H.pressMs - 80 });
      this.time.delayedCall(H.pressMs, () => this.handPress(false));
    };
    this.time.addEvent({ delay: H.loopMs, loop: true, startAt: H.loopMs - H.pressAtMs, callback: press });
  }

  private handPress(on: boolean): void {
    if (this.held === this.play) return;
    this.play.showPressed(on);
  }

  // ---------------------------------------------------------------- kort

  private drawCards(loc: Locale): void {
    const K = U.cards;
    const v = this.view;
    const cy = K.top + K.h / 2;
    const sub = (n: number, m: number): string => fillString(str('count', loc), formatAmount(n), formatAmount(m));
    const cards: Record<StartCard, { icon: string; label: string; sub: string; subColor: string; badge: boolean; go: () => void }> = {
      book: { icon: iconTextureKey('book'), label: str('book', loc), sub: sub(v.book.n, v.book.m), subColor: K.subColor, badge: v.book.badge, go: () => this.scene.start('Book', { tab: 'sets' }) },
      buddies: { icon: START_ICON_KEYS.buddies, label: str('buddies', loc), sub: sub(v.buddies.n, v.buddies.m), subColor: K.subColor, badge: v.buddies.badge, go: () => this.scene.start('Book', { tab: 'friends' }) },
      shop: {
        icon: START_ICON_KEYS.shop,
        label: str('shop', loc),
        sub: v.shop.badge ? str('free', loc) : str('shells', loc),
        subColor: v.shop.badge ? K.shop.subFreeColor : K.subColor,
        badge: v.shop.badge,
        go: () => (cached().avatars.pendingBoxes > 0 ? this.openNext() : this.scene.start('Book', { tab: 'friends', focus: 'shop' })),
      },
    };
    const lab = BUTTON_STYLE.card.label;
    K.order.forEach((id, i) => {
      const c = cards[id];
      const cx = K.cx[i];
      const b = new UiButton(this, 'card', cx, cy, K.w, K.h, K.w + K.slop * 2, K.h + K.slop * 2, c.go, c.badge ? 'badge' : 'normal');
      const top = -K.h / 2;
      const icon = this.add.image(0, top + K.iconY, c.icon).setScale(K.iconPx / ICON_PX);
      const label = this.add.text(0, top + K.labelY, c.label, text(lab.px, lab.weight, K.labelColor)).setOrigin(0.5).setLetterSpacing(lab.letterSpacing);
      const subT = this.add.text(0, top + K.subY, c.sub, text(K.subPx, K.subWeight, c.subColor)).setOrigin(0.5);
      b.body.add([icon, label, subT]);
      this.labels[id] = c.label;
      this.labels[`${id}Sub`] = c.sub;
      this.buttons.push(b);
      if (!c.badge) return;
      b.addBadge(K.w, K.h);
      if (id === 'shop') {
        this.drawPeek(b, cx);
        return;
      }
      // Nytt i boken / nya kompisar: ikonen andas 1,00 ↔ 1,08 (0,5 Hz).
      const B = K.freshBreath;
      this.tweens.add({ targets: icon, scale: icon.scale * B.scale, duration: B.halfCycleMs, ease: B.ease, yoyo: true, repeat: -1 });
    });
  }

  /**
   * Väntande gratismussla: en mussla tittar upp över Butik-kortets övre vänstra hörn och studsar
   * var 2:a sekund (0,5 Hz). Två eller fler: en andra skymtar bakom. Ingen siffra.
   */
  private drawPeek(b: UiButton, cx: number): void {
    const K = U.cards;
    const P = K.shop.peek;
    const x = -K.w / 2 + P.x;
    const y = -K.h / 2 + P.y;
    this.peekAt = { x: cx + x, y: K.top + P.y };
    const k = P.px / ICON_PX;
    const key = avatarIconKey('shell');
    if (this.view.shop.pending >= 2) {
      const bk = P.back;
      b.body.add(this.add.image(x + bk.dx, y + bk.dy, key).setScale(k * bk.scale).setAlpha(bk.alpha).setAngle(P.rotDeg));
    }
    const shell = this.add.image(x, y, key).setScale(k).setAngle(P.rotDeg);
    b.body.add(shell);
    const dy = cached().settings.calm ? U.calm.peekDy : P.dy;
    let first = true;
    this.tweens.chain({
      targets: shell,
      loop: -1,
      tweens: [
        { y: y + dy, duration: P.upMs, ease: 'Quad.easeOut' },
        {
          y,
          duration: P.downMs,
          ease: 'Bounce.easeOut',
          onComplete: () => {
            if (!first) return;
            first = false;
            playTone(BUTTON_SOUND.shellPeek);
          },
        },
        { scaleX: k * P.squash[0], scaleY: k * P.squash[1], duration: 90, ease: 'Quad.easeOut', yoyo: true },
        { scaleX: k, duration: P.restMs - 180 },
      ],
    });
  }

  /** Öppnar en mussla på startskärmen: sparas direkt, sedan 1,2 s fast visning. */
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
    const K = U.cards;
    this.opening = new ShellOpening(this, res, {
      from: { x: this.peekAt.x, y: this.peekAt.y, px: K.shop.peek.px },
      closeTo: { x: K.cx[1], y: K.top + K.iconY },
      onClosed: () => this.scene.restart(),
    });
  }

  // ---------------------------------------------------------------- set-stapel

  private drawSetBar(loc: Locale): void {
    const v = this.view.setBar;
    if (!v) return;
    const S = U.setBar;
    const B = S.bar;
    this.add.image(S.from.x, S.y, setIconKey(cached().activeSet)).setScale(S.from.px / ICON_PX);
    const g = this.add.graphics();
    const w = B.x1 - B.x0;
    g.fillStyle(hexToInt(C.barTrack), 1);
    g.fillRoundedRect(B.x0, S.y - B.h / 2, w, B.h, B.r);
    if (v.v > 0) {
      const fw = Math.max(B.h, w * v.v);
      g.fillStyle(hexToInt(C.barFill[2]), 1);
      g.fillRoundedRect(B.x0, S.y - B.h / 2, fw, B.h, B.r);
      g.fillStyle(hexToInt(C.barFill[1]), 1);
      g.fillRoundedRect(B.x0, S.y - B.h / 2, fw, B.h - 3, B.r);
      g.fillStyle(hexToInt(C.barFill[0]), 0.8);
      g.fillRoundedRect(B.x0 + 4, S.y - B.h / 2 + 2, Math.max(0, fw - 8), 3, 1.5);
    }
    // Nästa set: streckad cirkel med en okänd Glimt och ett hänglås.
    const T = S.to;
    const r = T.d / 2;
    const [on, off] = T.dash;
    const step = (on + off) / r;
    const len = on / r;
    g.lineStyle(T.edgeW, INT.hudDim, 1);
    for (let a = 0; a < Math.PI * 2 - 1e-3; a += step) {
      g.beginPath();
      g.arc(T.x, S.y, r, a, a + len);
      g.strokePath();
    }
    this.add.image(T.x, S.y, START_ICON_KEYS.nextSet).setScale(T.iconPx / ICON_PX);
    this.add.image(T.x + T.lock.dx, S.y + T.lock.dy, START_ICON_KEYS.lock).setScale(T.lock.px / ICON_PX);
    const label = fillString(str('nextSet', loc), formatAmount(v.n), formatAmount(v.m));
    this.add.text((B.x0 + B.x1) / 2, S.text.y, label, text(S.text.px, S.text.weight, S.text.color)).setOrigin(0.5);
    this.labels.setBar = label;
  }
}
