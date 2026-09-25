import Phaser from 'phaser';
import { INT, THEME } from '../data/theme';
import { AVATARS, RARITY, oddsPearls, type AvatarDef, type AvatarTone, type Rarity } from '../data/avatarsIndex';
import { ECONOMY, type Price, type ShellType } from '../data/economy';
import { ECONOMY_COLORS, ECONOMY_ICON_KEYS, ECONOMY_SOUND, ECONOMY_UI, formatAmount } from '../data/economyUi';
import { shellOdds, type BoxResult } from '../systems/boxes';
import { buyPick, buyShell, canBuy, pick3Offer, shellAvailable, shopMode } from '../systems/economy';
import { mulberry32 } from '../systems/rng';
import { cached, save } from '../systems/save';
import { playTone } from '../systems/audio';
import { vibrate } from '../systems/haptics';
import { getLocale, t } from '../systems/i18n';
import { avatarIconKey, ECO_EXTRA_KEYS, iconTextureKey } from './icons';
import { addAvatarImage, drawPearl, drawPearlRow, gripToCenter, rarityInt, strokeRarityRoundRect } from './avatarArt';
import { ShellOpening } from './shellOpening';
import type { Counters, Resource } from './counters';

const SH = ECONOMY_UI.shop;
const WK = ECONOMY_UI.wake;
const P3 = ECONOMY_UI.pick3;
const ICON_PX = 128;
const FONT = THEME.type.family;
const HUD = THEME.palette.hud;
const HUD_DIM = THEME.palette.hudDim;
const ACCENT = THEME.palette.accent;

export type SlotState = 'ok' | 'poor' | 'empty';

interface Slot {
  type: ShellType;
  cx: number;
  state: SlotState;
  shell: Phaser.GameObjects.Image;
  price: Phaser.GameObjects.Container | null;
}

interface Pick3 {
  type: ShellType;
  offer: AvatarDef[];
  picked: number;
  c: Phaser.GameObjects.Container;
  cards: Phaser.GameObjects.Container[];
  info: Phaser.GameObjects.Text;
  buy: Phaser.GameObjects.Container;
}

/** Priset som [resurs, belopp]-par (pärlor först). */
export function priceParts(p: Price): [Resource, number][] {
  const out: [Resource, number][] = [];
  if (p.pearls) out.push(['pearls', p.pearls]);
  if (p.sand) out.push(['sand', p.sand]);
  return out;
}

function have(r: Resource): number {
  return cached().economy[r];
}

/** Fyllnadsring runt en prisikon: hur nära man är (have/pris från kl. 12). */
export function progressRing(g: Phaser.GameObjects.Graphics, x: number, y: number, frac: number): void {
  const R = SH.progressRing;
  g.lineStyle(R.w, INT.hudDim, R.trackAlpha);
  g.strokeCircle(x, y, R.r);
  if (frac <= 0) return;
  const a0 = Phaser.Math.DegToRad(R.startDeg);
  g.lineStyle(R.w, INT.hud, 1);
  g.beginPath();
  g.arc(x, y, R.r, a0, a0 + Math.PI * 2 * Math.min(1, frac), false);
  g.strokePath();
}

/**
 * Butikshyllan i fliken Kompisar (UI.md §14.3–14.4, §14.8): tre musslor med pris och mini-oddsburk,
 * köp i två tryck, sedan öppningsceremonin. I läget pick3 visar ett tryck tre kandidater.
 */
export class FriendsShop {
  private slots: Slot[] = [];
  private awake: ShellType | null = null;
  private wakeAt = 0;
  private sleepTimer: Phaser.Time.TimerEvent | null = null;
  private breath: Phaser.Tweens.Tween | null = null;
  private buying = false;
  private opening: ShellOpening | null = null;
  private pick: Pick3 | null = null;
  /** Senaste köpet (testhook). */
  lastBuy: BoxResult | null = null;

  constructor(
    private readonly scene: Phaser.Scene,
    private readonly into: Phaser.GameObjects.Container,
    private readonly counters: Counters,
    /** Ceremonin stängd: boken byggs om (rutnätet visar den nya kompisen). */
    private readonly onDone: () => void,
  ) {
    this.build();
  }

  /** Overlay, köp eller ceremoni pågår: resten av boken tar inte emot tryck. */
  get blocking(): boolean {
    return this.buying || this.opening !== null || this.pick !== null;
  }

  snapshot(): unknown {
    return {
      mode: shopMode(),
      pearls: have('pearls'),
      sand: have('sand'),
      full: cached().avatars.owned.length >= AVATARS.length,
      slots: this.slots.map((s) => ({ type: s.type, price: ECONOMY.shells[s.type].price, state: s.state })),
      awake: this.awake,
      offer: this.pick ? this.pick.offer.map((a) => a.id) : null,
      picked: this.pick && this.pick.picked >= 0 ? this.pick.offer[this.pick.picked].id : null,
      opening: this.opening !== null,
      openPhase: this.opening?.phase ?? null,
      lastBuy: this.lastBuy,
    };
  }

  // ---------------------------------------------------------------- bygg

  private build(): void {
    const s = this.scene;
    const g = s.add.graphics();
    this.into.add(g);
    const ln = SH.shelf;
    g.lineStyle(ln.w, INT.jarEdge, 1);
    g.lineBetween(ln.x0, ln.y, ln.x1, ln.y);
    for (const x of ln.consoleX) g.lineBetween(x, ln.y, x, ln.y + ln.consoleH);
    const av = cached().avatars;
    if (av.owned.length >= AVATARS.length) {
      // Full bok: gul bok med tre stilla gnistor i stället för musslorna.
      const F = SH.fullBook;
      this.into.add(s.add.image(F.x, F.y, ECO_EXTRA_KEYS.bookGold).setScale(F.px / ICON_PX));
      for (const [dx, dy, px] of F.sparks) this.into.add(s.add.image(F.x + dx, F.y + dy, iconTextureKey('sparkle')).setDisplaySize(px, px));
      return;
    }
    SH.order.forEach((type, i) => {
      const cx = SH.slotX[i];
      const state = this.stateOf(type);
      const shell = s.add
        .image(cx + SH.shell.dx, SH.shell.y, ECONOMY_ICON_KEYS.shell(type, state))
        .setScale(SH.shell.px / ICON_PX)
        .setAlpha(state === 'poor' ? SH.poorAlpha : 1);
      this.into.add(shell);
      this.drawJar(g, type, cx + SH.jar.dx, state === 'empty');
      const slot: Slot = { type, cx, state, shell, price: null };
      this.slots.push(slot);
      this.drawPrice(slot, false);
    });
  }

  private stateOf(type: ShellType): SlotState {
    const d = cached();
    if (!shellAvailable(d.avatars, type)) return 'empty';
    return canBuy(d, type) ? 'ok' : 'poor';
  }

  /** Mini-oddsburk: 25 pärlor efter musslans vikter, vanlig längst ner, mytisk överst. */
  private drawJar(g: Phaser.GameObjects.Graphics, type: ShellType, x: number, empty: boolean): void {
    const J = SH.jar;
    const left = x - J.w / 2;
    const top = J.y - J.h / 2;
    g.fillStyle(INT.jarGlass, 0.55);
    g.fillRoundedRect(left, top, J.w, J.h, 7);
    g.lineStyle(J.edgeW, INT.jarEdge, 1);
    g.strokeRoundedRect(left, top, J.w, J.h, 7);
    g.fillStyle(INT.jarEdge, 1);
    g.fillRoundedRect(left - 2, top - J.lidH, J.w + 4, J.lidH, 2);
    const bottomY = J.y + J.h / 2 - J.bottomPad;
    if (empty) {
      this.into.add(this.scene.add.image(x, bottomY - 8, avatarIconKey('shellOpen')).setScale(24 / ICON_PX).setTint(INT.hudDim));
      return;
    }
    const owned = cached().avatars.owned;
    const remaining = {} as Record<Rarity, number>;
    for (const r of RARITY.order) remaining[r] = AVATARS.filter((a) => a.rarity === r && !owned.includes(a.id)).length;
    // Första musslan i livet är alltid sällsynt: burken visar det ärligt.
    const weights = ECONOMY.firstShellRare && owned.length === 0
      ? ({ common: 0, uncommon: 0, rare: 1, epic: 0, legendary: 0, mythic: 0 } as Record<Rarity, number>)
      : shellOdds(type);
    const counts = oddsPearls(remaining, J.rows.reduce((a, b) => a + b, 0), weights);
    const seq: Rarity[] = [];
    for (const r of RARITY.order) for (let i = 0; i < counts[r]; i++) seq.push(r);
    let k = 0;
    J.rows.forEach((n, row) => {
      for (let i = 0; i < n && k < seq.length; i++, k++) drawPearl(g, x + (i - (n - 1) / 2) * J.pitchX, bottomY - row * J.pitchY, J.pearlR, seq[k]);
    });
  }

  /** Pris: resursikon + siffra centrerat på cx. Räcker inte: hudDim + fyllnadsring. Vaken: accentchip. */
  private drawPrice(slot: Slot, awake: boolean): void {
    slot.price?.destroy();
    slot.price = null;
    if (slot.state === 'empty') return;
    const P = SH.price;
    const [[res, amount]] = priceParts(ECONOMY.shells[slot.type].price);
    const s = this.scene;
    const poor = slot.state === 'poor';
    const text = s.add
      .text(0, 0, formatAmount(amount), { fontFamily: FONT, fontSize: `${P.textPx}px`, color: awake ? ACCENT : poor ? HUD_DIM : HUD, fontStyle: '800' })
      .setOrigin(0, 0.5);
    const w = P.iconPx + P.gap + text.width;
    const x0 = -w / 2;
    const icon = s.add.image(x0 + P.iconPx / 2, 0, res === 'pearls' ? ECONOMY_ICON_KEYS.pearlCoin : ECONOMY_ICON_KEYS.sand).setScale(P.iconPx / ICON_PX);
    text.setX(x0 + P.iconPx + P.gap);
    const g = s.add.graphics();
    if (awake) {
      const C = WK.priceChip;
      const cw = w + C.padX * 2;
      g.fillStyle(INT.accent, C.fillAlpha);
      g.fillRoundedRect(-cw / 2, -C.h / 2, cw, C.h, C.r);
      g.lineStyle(C.w, INT.accent, 1);
      g.strokeRoundedRect(-cw / 2, -C.h / 2, cw, C.h, C.r);
    }
    if (poor) progressRing(g, icon.x, 0, have(res) / amount);
    slot.price = s.add.container(slot.cx, P.y, [g, icon, text]);
    this.into.add(slot.price);
  }

  // ---------------------------------------------------------------- input

  /** Tryck i fliken Kompisar. true = butiken tog trycket. */
  tap(x: number, y: number): boolean {
    if (this.opening) {
      this.opening.tap();
      return true;
    }
    if (this.buying) return true;
    if (this.pick) {
      this.tapPick(x, y);
      return true;
    }
    const slot = y >= SH.hit.y0 && y <= SH.hit.y1 ? this.slots.find((s) => Math.abs(x - s.cx) <= SH.hit.halfW) : undefined;
    if (!slot) {
      this.sleep();
      return y >= SH.hit.y0 && y <= SH.hit.y1;
    }
    this.tapSlot(slot);
    return true;
  }

  private tapSlot(slot: Slot): void {
    if (slot.state === 'empty') {
      this.sleep();
      const y0 = slot.shell.y;
      this.scene.tweens.add({ targets: slot.shell, y: y0 + 3, duration: 100, yoyo: true, onComplete: () => slot.shell.setY(y0) });
      return;
    }
    if (shopMode() === 'pick3') {
      this.openPick3(slot.type);
      return;
    }
    if (slot.state === 'poor') {
      this.sleep();
      this.poor(slot.shell, ECONOMY.shells[slot.type].price);
      return;
    }
    if (this.awake === slot.type) {
      if (this.scene.time.now - this.wakeAt >= WK.minGapMs) this.buy(slot.type);
      return;
    }
    this.wake(slot);
  }

  /** Räcker inte: skakning ±4 px två gånger, `notEnough`, räknarens ikon punchar. */
  poor(target: Phaser.GameObjects.Components.Transform & Phaser.GameObjects.GameObject, price: Price): void {
    const P = ECONOMY_UI.poor;
    const x0 = target.x;
    this.scene.tweens.killTweensOf(target);
    this.scene.tweens.add({ targets: target, x: x0 + P.shakePx, duration: P.ms / (P.shakes * 2), yoyo: true, repeat: P.shakes - 1, ease: 'Sine.easeInOut', onComplete: () => target.setX(x0) });
    playTone(ECONOMY_SOUND.notEnough);
    for (const [r, amount] of priceParts(price)) if (have(r) < amount) this.counters.punch(r);
  }

  private wake(slot: Slot): void {
    this.sleep(true);
    this.awake = slot.type;
    this.wakeAt = this.scene.time.now;
    const k = SH.shell.px / ICON_PX;
    this.scene.tweens.add({ targets: slot.shell, y: SH.shell.y + WK.dy, scale: k * WK.scale, duration: WK.ms, ease: WK.ease });
    for (const o of this.slots) if (o !== slot) o.shell.setAlpha(WK.othersAlpha);
    this.drawPrice(slot, true);
    const price = slot.price!;
    this.breath = this.scene.tweens.add({ targets: price, scale: WK.breath.scale, duration: WK.breath.halfCycleMs, delay: WK.ms, ease: WK.breath.ease, yoyo: true, repeat: -1 });
    this.sleepTimer = this.scene.time.delayedCall(WK.sleepAfterMs, () => this.sleep());
    playTone(ECONOMY_SOUND.wake);
    vibrate(10);
  }

  /** Musslan går tillbaka; ingenting kostar. */
  sleep(instant = false): void {
    this.sleepTimer?.remove();
    this.sleepTimer = null;
    this.breath?.remove();
    this.breath = null;
    const slot = this.slots.find((s) => s.type === this.awake);
    this.awake = null;
    const k = SH.shell.px / ICON_PX;
    for (const o of this.slots) o.shell.setAlpha(o.state === 'poor' ? SH.poorAlpha : 1);
    if (!slot) return;
    this.scene.tweens.killTweensOf(slot.shell);
    this.scene.tweens.add({ targets: slot.shell, y: SH.shell.y, scale: k, duration: instant ? 0 : WK.sleepMs });
    this.drawPrice(slot, false);
  }

  /** Andra trycket (eller testhooken): köper och öppnar. null = räcker inte eller ospelbart. */
  buy(type: ShellType): BoxResult | null {
    if (this.blocking) return null;
    if (shopMode() === 'pick3') {
      this.openPick3(type);
      return null;
    }
    const d = cached();
    const seed = (Date.now() ^ Math.imul(d.avatars.boxesOpened + 1, 0x9e3779b1)) >>> 0;
    const res = buyShell(d, type, mulberry32(seed));
    const slot = this.slots.find((s) => s.type === type);
    if (!res || !slot) {
      if (slot) this.poor(slot.shell, ECONOMY.shells[type].price);
      return null;
    }
    this.sleepTimer?.remove();
    this.breath?.remove();
    this.awake = null;
    slot.price?.setScale(1);
    this.drawPrice(slot, false);
    this.lastBuy = res;
    void save();
    this.paid(slot.shell.x, slot.shell.y, ECONOMY.shells[type].price);
    this.buying = true;
    this.scene.time.delayedCall(ECONOMY_UI.buy.openAt, () => {
      this.buying = false;
      slot.shell.setVisible(false);
      this.open(res, { x: slot.shell.x, y: slot.shell.y, px: SH.shell.px }, type);
    });
    return res;
  }

  /** Valutan flyger från räknaren till målet och räknaren räknas ned (UI.md §14.2). */
  paid(x: number, y: number, price: Price, sound: AvatarTone = ECONOMY_SOUND.buy): void {
    const F = ECONOMY_UI.buy.fly;
    const CT = ECONOMY_UI.counters;
    for (const [r] of priceParts(price)) {
      for (let i = 0; i < F.count; i++) {
        const img = this.scene.add
          .image(CT[r].iconX, CT.y, r === 'pearls' ? ECONOMY_ICON_KEYS.pearlCoin : ECONOMY_ICON_KEYS.sand)
          .setScale(F.px / ICON_PX)
          .setDepth(20);
        this.scene.tweens.add({ targets: img, x, y, duration: F.ms, delay: i * F.staggerMs, ease: F.ease, onComplete: () => img.destroy() });
      }
    }
    this.counters.countTo(have('pearls'), have('sand'));
    playTone(sound);
    vibrate(30);
  }

  private open(res: BoxResult, from: { x: number; y: number; px: number }, type: ShellType): void {
    const C = ECONOMY_UI.buy.close;
    this.opening = new ShellOpening(this.scene, res, { from, type, closeTo: { x: 180, y: C.toY }, onClosed: this.onDone });
  }

  /** Bakåtknappen: stäng overlay/ceremoni. true = hanterad. */
  back(): boolean {
    if (this.opening) {
      this.opening.tap();
      this.opening?.tap();
      return true;
    }
    if (this.pick) {
      this.closePick3();
      return true;
    }
    return this.buying;
  }

  // ---------------------------------------------------------------- pick3 (UI.md §14.8)

  private openPick3(type: ShellType): void {
    this.sleep(true);
    const s = this.scene;
    const d = cached();
    const offer = pick3Offer(d, type, mulberry32((Date.now() ^ Math.imul(d.avatars.boxesOpened + 7, 0x9e3779b1)) >>> 0));
    void save(); // erbjudandet sparas direkt: stäng/öppna drar inte om
    const c = s.add.container(0, 0).setDepth(30);
    c.add(s.add.rectangle(180, 320, 360, 640, INT.scrim, P3.scrimAlpha));
    c.add(s.add.image(P3.shell.x, P3.shell.y, ECONOMY_ICON_KEYS.shell(type, 'ok')).setScale(P3.shell.px / ICON_PX));
    c.add(s.add.image(P3.close.x, P3.close.y, iconTextureKey('close')).setDisplaySize(P3.close.px, P3.close.px));
    const info = s.add
      .text(180, P3.info.y, '', { fontFamily: FONT, fontSize: `${P3.info.px}px`, color: ECONOMY_COLORS.desc, fontStyle: '700', align: 'center', wordWrap: { width: P3.info.maxW, useAdvancedWrap: true }, maxLines: P3.info.maxLines })
      .setOrigin(0.5, 0);
    c.add(info);
    const buy = s.add.container(P3.buy.cx, P3.buy.cy);
    c.add(buy);
    this.pick = { type, offer, picked: -1, c, cards: [], info, buy };
    offer.forEach((a, i) => {
      const card = this.drawCard(a, i, false);
      card.y += 40;
      card.setAlpha(0);
      s.tweens.add({ targets: card, y: card.y - 40, alpha: 1, duration: P3.riseMs, delay: i * P3.staggerMs, ease: 'Back.easeOut' });
    });
    this.drawPickBuy();
  }

  private drawCard(a: AvatarDef, i: number, selected: boolean): Phaser.GameObjects.Container {
    const s = this.scene;
    const K = P3.cards;
    const p = this.pick!;
    p.cards[i]?.destroy();
    const card = s.add.container(K.cx[i], K.y0 + K.h / 2 + (selected ? P3.selected.dy : 0));
    const g = s.add.graphics();
    g.fillStyle(INT.bg, 1);
    g.fillRoundedRect(-K.w / 2, -K.h / 2, K.w, K.h, K.r);
    g.fillStyle(rarityInt(a.rarity), 0.14);
    g.fillRoundedRect(-K.w / 2, -K.h / 2, K.w, K.h, K.r);
    if (selected) {
      g.lineStyle(P3.selected.frameW, INT.accent, 1);
      g.strokeRoundedRect(-K.w / 2, -K.h / 2, K.w, K.h, K.r);
    } else {
      strokeRarityRoundRect(g, -K.w / 2, -K.h / 2, K.w, K.h, K.r, K.frameW, a.rarity);
    }
    const cy = K.y0 + K.h / 2;
    drawPearlRow(g, 0, K.pearlsY - cy, RARITY.pearls[a.rarity], 3.5, 10, a.rarity);
    const fig = addAvatarImage(s, 0, K.figureY - cy + gripToCenter(K.figurePx), a.id, K.figurePx);
    const name = s.add
      .text(0, K.nameY - cy + 8, t(a.names, getLocale()), { fontFamily: FONT, fontSize: `${K.namePx}px`, color: HUD, fontStyle: '800', align: 'center', wordWrap: { width: K.w - 10, useAdvancedWrap: true }, maxLines: 2 })
      .setOrigin(0.5, 0.5);
    card.add([g, fig, name]);
    if (selected) {
      const b = s.add.graphics();
      const bx = K.w / 2 - 6;
      const by = -K.h / 2 + 6;
      b.fillStyle(INT.accent, 1);
      b.fillCircle(bx, by, P3.selected.badgeR);
      b.lineStyle(2.5, INT.ink, 1);
      b.strokePoints([{ x: bx - 4, y: by }, { x: bx - 1, y: by + 3 }, { x: bx + 4, y: by - 3 }], false);
      card.add(b);
    }
    p.c.add(card);
    p.cards[i] = card;
    return card;
  }

  /** Köpknapp 200×64: accent med pris, grå och streckad med fyllnadsring om det inte räcker. */
  private drawPickBuy(): void {
    const p = this.pick!;
    const s = this.scene;
    const B = P3.buy;
    p.buy.removeAll(true);
    const price = ECONOMY.shells[p.type].price;
    const [[res, amount]] = priceParts(price);
    const ok = canBuy(cached(), p.type);
    const g = s.add.graphics();
    if (ok) {
      g.fillStyle(INT.accent, p.picked >= 0 ? 0.26 : 0.14);
      g.fillRoundedRect(-B.w / 2, -B.h / 2, B.w, B.h, B.r);
      g.lineStyle(3, INT.accent, 1);
      g.strokeRoundedRect(-B.w / 2, -B.h / 2, B.w, B.h, B.r);
    } else {
      g.lineStyle(2, INT.hudDim, 1);
      dashedRoundRect(g, -B.w / 2, -B.h / 2, B.w, B.h, B.r, 6, 5);
    }
    const text = s.add.text(0, 0, formatAmount(amount), { fontFamily: FONT, fontSize: '20px', color: ok ? HUD : HUD_DIM, fontStyle: '800' }).setOrigin(0, 0.5);
    const w = 24 + 8 + text.width;
    const icon = s.add.image(-w / 2 + 12, 0, res === 'pearls' ? ECONOMY_ICON_KEYS.pearlCoin : ECONOMY_ICON_KEYS.sand).setScale(24 / ICON_PX);
    text.setX(-w / 2 + 32);
    if (!ok) progressRing(g, icon.x, 0, have(res) / amount);
    p.buy.add([g, icon, text]);
  }

  private tapPick(x: number, y: number): void {
    const p = this.pick!;
    const X = P3.close;
    if (Math.abs(x - X.x) <= X.hit / 2 && Math.abs(y - X.y) <= X.hit / 2) {
      this.closePick3();
      return;
    }
    const K = P3.cards;
    const i = K.cx.findIndex((cx) => Math.abs(x - cx) <= K.w / 2 && y >= K.y0 - 8 && y <= K.y0 + K.h);
    if (i >= 0 && i < p.offer.length) {
      this.select(i);
      return;
    }
    const B = P3.buy;
    if (p.picked >= 0 && Math.abs(x - B.cx) <= B.w / 2 && Math.abs(y - B.cy) <= B.h / 2) this.confirmPick();
  }

  /** Välj kort i (första bekräftelsen). */
  select(i: number): void {
    const p = this.pick;
    if (!p || i < 0 || i >= p.offer.length) return;
    const prev = p.picked;
    p.picked = i;
    if (prev >= 0 && prev !== i) this.drawCard(p.offer[prev], prev, false);
    this.drawCard(p.offer[i], i, true);
    p.info.setText(t(p.offer[i].desc, getLocale()));
    this.drawPickBuy();
    playTone(ECONOMY_SOUND.wake);
    vibrate(10);
  }

  /** Köpknappen (andra bekräftelsen). */
  confirmPick(): BoxResult | null {
    const p = this.pick;
    if (!p || p.picked < 0) return null;
    const price = ECONOMY.shells[p.type].price;
    const res = buyPick(cached(), p.type, p.offer[p.picked].id);
    if (!res) {
      this.poor(p.buy, price);
      return null;
    }
    this.lastBuy = res;
    void save();
    const type = p.type;
    this.paid(P3.shell.x, P3.shell.y, price);
    this.pick = null;
    p.c.destroy();
    this.open(res, { x: P3.shell.x, y: P3.shell.y, px: P3.shell.px }, type);
    return res;
  }

  /** Stäng: korten sjunker, samma tre ligger kvar (sparade) tills köp. */
  private closePick3(): void {
    const p = this.pick;
    if (!p) return;
    this.pick = null;
    this.scene.tweens.add({ targets: p.c, alpha: 0, duration: 200, onComplete: () => p.c.destroy() });
  }
}

/** Streckad rundad rektangel (räcker inte). */
export function dashedRoundRect(g: Phaser.GameObjects.Graphics, x: number, y: number, w: number, h: number, r: number, dash: number, gap: number): void {
  const pts: { x: number; y: number }[] = [];
  const corner = (cx: number, cy: number, a0: number): void => {
    for (let i = 0; i <= 6; i++) {
      const a = a0 + (i / 6) * (Math.PI / 2);
      pts.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r });
    }
  };
  corner(x + w - r, y + r, -Math.PI / 2);
  corner(x + w - r, y + h - r, 0);
  corner(x + r, y + h - r, Math.PI / 2);
  corner(x + r, y + r, Math.PI);
  pts.push(pts[0]);
  let on = true;
  let left = dash;
  for (let i = 1; i < pts.length; i++) {
    let ax = pts[i - 1].x;
    let ay = pts[i - 1].y;
    const bx = pts[i].x;
    const by = pts[i].y;
    let len = Math.hypot(bx - ax, by - ay);
    while (len > 0) {
      const step = Math.min(left, len);
      const nx = ax + ((bx - ax) * step) / len;
      const ny = ay + ((by - ay) * step) / len;
      if (on) g.lineBetween(ax, ay, nx, ny);
      ax = nx;
      ay = ny;
      len -= step;
      left -= step;
      if (left <= 0) {
        on = !on;
        left = on ? dash : gap;
      }
    }
  }
}
