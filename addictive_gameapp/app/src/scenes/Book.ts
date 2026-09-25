import Phaser from 'phaser';
import { INT, THEME, hexToInt } from '../data/theme';
import { LEVEL_COUNT, SLOTS_PER_PAGE } from '../data/collection';
import { META, META_COLORS, META_SOUND, THEME_SETS, setPalette } from '../data/themes';
import {
  FX_GLITTER,
  FX_GLITTER_R,
  bakeSet,
  ballTextureKey,
  bookLevelTexture,
  loadedBallSets,
  scaleForBodyRadius,
} from '../ui/textures';
import { drawBackground } from '../ui/background';
import { iconTextureKey, setIconKey } from '../ui/icons';
import { cached, save } from '../systems/save';
import { filledSlots, markPageSeen, slotIndex } from '../systems/collection';
import { nextSetProgress } from '../systems/unlocks';
import { playSound, playTimbre, playTone } from '../systems/audio';
import { vibrate } from '../systems/haptics';
import {
  AVATARS,
  AVATAR_SOUND,
  AVATAR_UI,
  RARITY,
  avatarById,
  levelHintLabel,
  type AvatarDef,
} from '../data/avatarsIndex';
import { ECONOMY_COLORS, ECONOMY_ICON_KEYS, ECONOMY_SOUND, ECONOMY_UI, formatAmount } from '../data/economyUi';
import { equip, markFriendsSeen } from '../systems/avatars';
import { canUpgrade, upgrade, upgradeCost } from '../systems/economy';
import { getLocale, t, type Locale } from '../systems/i18n';
import { Counters } from '../ui/counters';
import { FriendsShop, dashedRoundRect, priceParts, progressRing } from '../ui/friendsShop';
import { ECO_EXTRA_KEYS } from '../ui/icons';
import { clearBackHandler, setBackHandler } from '../systems/back';
import { BG_GLOW } from '../ui/textures';
import { avatarIconKey } from '../ui/icons';
import {
  avatarOriginY,
  addAvatarImage,
  bakeAvatar,
  bakeAvatarParticles,
  drawPearl,
  drawPearlRow,
  drawRomb,
  gripToCenter,
  rarityInt,
  strokeRarityRoundRect,
} from '../ui/avatarArt';
import { FX_DOT } from '../ui/textures';
import { AvatarRig } from '../ui/avatarRig';
import { playFxCue } from '../ui/avatarFx';
import { fitCamera } from '../ui/view';

const W = THEME.layout.width;
const BK = META.book;
const SW = BK.swipe;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');
/** Setikonens markering (UI.md §12.4). */
const MARK = { ringW: 4, dash: 6, badgeDx: 27, badgeDy: -27, badgeR: 10, selectMs: 240, badgeMs: 200, arpMs: 90 };
/** Låst sida: skaka ±6 px två gånger på 240 ms, stapeln pulsar 1,1 på 300 ms. */
const LOCKED_FB = { px: 6, ms: 240, barScale: 1.1, barMs: 300 };
/** "Nytt sedan sist" nollställs när sidan (eller Kompisar-fliken) har synts så här länge. */
const SEEN_MS = 2000;
const AB = AVATAR_UI.book;
const GR = AB.grid;
/** Scenen med vald kompis, text, stapel och uppgradering (UI.md §14.5). */
const ES = ECONOMY_UI.stage;
const SF = ES.figure;
/** Rutnätet ligger under butiken och scenen (UI.md §14.3). */
const GRID_TOP = ECONOMY_UI.grid.top;
const STAGE_GRIP_Y = SF.cy + gripToCenter(SF.displayPx);
const ICON_PX = 128;
const HUD = THEME.palette.hud;
const HUD_DIM = THEME.palette.hudDim;

/** Sätter texten, max `maxLines` rader; en tredje rad klipps med "…" (skydd för långa översättningar). */
function setClamped(txt: Phaser.GameObjects.Text, value: string, maxLines: number): void {
  txt.setText(value);
  if (txt.getWrappedText(value).length <= maxLines) return;
  const words = value.split(' ');
  while (words.length > 1) {
    words.pop();
    const v = `${words.join(' ')}…`;
    if (txt.getWrappedText(v).length <= maxLines) {
      txt.setText(v);
      return;
    }
  }
}

type Tab = 'sets' | 'friends';

interface FriendCell {
  def: AvatarDef;
  x: number;
  y: number;
  /** Ej ägd: siluett + streckad ram i en egen container, så att bara cellen skakar. */
  node: Phaser.GameObjects.Container | null;
}

/** Platsens position i rutnätet 4-4-3 (nivå 0–3, 4–7, 8–10). */
function slotXY(level: number, rows: readonly number[]): [number, number] {
  const row = level < 4 ? 0 : level < 8 ? 1 : 2;
  const x = row < 2 ? BK.colsX[level - 4 * row] : BK.lastRowX[level - 8];
  return [x, rows[row]];
}

function dashedCircle(g: Phaser.GameObjects.Graphics, x: number, y: number, r: number, dash: number): void {
  const step = dash / r;
  for (let a = 0; a < Math.PI * 2; a += step * 2) {
    g.beginPath();
    g.arc(x, y, r, a, a + step, false);
    g.strokePath();
  }
}

interface Pulse {
  target: Phaser.GameObjects.Image;
  base: number;
  tween: Phaser.Tweens.Tween;
}

/**
 * Samlarboken (DESIGN §13.2–13.3, UI.md §12.4): en sida per temaset i THEME_SETS-ordning,
 * svep i sidled för att bläddra, tryck på en upplåst sida för att välja aktivt set,
 * svep ner eller stäng-ikonen för att gå tillbaka. Ingen text utöver siffror.
 */
export class Book extends Phaser.Scene {
  private strip!: Phaser.GameObjects.Container;
  /** Bokens bakgrund (Kompisar-fliken syns mot den). */
  private bg!: Phaser.GameObjects.Container;
  private page = 0;
  private locked: boolean[] = [];
  private marks: (Phaser.GameObjects.Graphics | null)[] = [];
  private badges: (Phaser.GameObjects.Graphics | null)[] = [];
  private pulses: Pulse[][] = [];
  private dots!: Phaser.GameObjects.Graphics;
  private bar: Phaser.GameObjects.Container | null = null;
  private seenTimer: Phaser.Time.TimerEvent | null = null;
  private down: { x: number; y: number; t: number } | null = null;
  private tab: Tab = 'sets';
  private tabIcons!: Phaser.GameObjects.Graphics;
  private band!: Phaser.GameObjects.Rectangle;
  private friends!: Phaser.GameObjects.Container;
  /** Scen + odds-burk (står still), rutnätet scrollar under. */
  private friendsTop!: Phaser.GameObjects.Container;
  private friendSel!: Phaser.GameObjects.Graphics;
  private cells: FriendCell[] = [];
  private scroll = 0;
  private maxScroll = 0;
  private downScroll = 0;
  private vel = 0;
  private lastMoveY = 0;
  private stageImg: Phaser.GameObjects.Image | null = null;
  private stageGlow: Phaser.GameObjects.Image | null = null;
  /** Namn, text, stapel och uppgraderingsknapp; byggs om vid byte/uppgradering. */
  private stageInfo!: Phaser.GameObjects.Container;
  private upBtn: Phaser.GameObjects.Container | null = null;
  /** Uppgraderingsknappen vaken sedan (speltid), -1 = sover. */
  private upAwakeAt = -1;
  private upSleepTimer: Phaser.Time.TimerEvent | null = null;
  /** Romber per ägd cell i rutnätet (ritas om vid uppgradering). */
  private rombG!: Phaser.GameObjects.Graphics;
  private shop!: FriendsShop;
  private counters!: Counters;
  private stageRig: AvatarRig | null = null;
  private stageId = '';
  private showcasing = false;
  /** Pulser på nyöppnade kompisar (tills fliken synts i 2 s). */
  private friendPulses: Pulse[] = [];
  /** Svep-ledtrådens hand (första öppningen någonsin), null när den är klar. */
  private hintHand: Phaser.GameObjects.Image | null = null;
  private hintShown = false;
  /** Scroll-ledtråden i Kompisar: pil i nederkant tills första scroll. */
  private scrollHint: Phaser.GameObjects.Graphics | null = null;
  private peekShown = false;

  constructor() {
    super('Book');
  }

  create(data?: { tab?: Tab }): void {
    fitCamera(this);
    const d = cached();
    // Scenens objekt och nivåikonen visar aktivt set i full upplösning; sidorna bakas i bokens storlek.
    bakeSet(this, d.activeSet);
    this.bg = this.add.container(0, 0).setDepth(-10);
    drawBackground(this, undefined, { still: true, into: this.bg });
    this.locked = THEME_SETS.map((s) => !d.unlockedSets.includes(s.id));
    this.marks = [];
    this.badges = [];
    this.pulses = THEME_SETS.map(() => []);
    this.seenTimer = null;
    this.down = null;
    this.friendPulses = [];
    this.hintHand = null;
    this.hintShown = false;
    this.scrollHint = null;
    this.peekShown = false;
    this.stageImg = null;
    this.stageRig = null;
    this.stageGlow = null;
    this.upBtn = null;
    this.upAwakeAt = -1;
    this.upSleepTimer = null;
    this.showcasing = false;
    this.page = this.startPage();

    this.strip = this.add.container(-this.page * W, 0);
    for (let i = 0; i < THEME_SETS.length; i++) this.buildPage(i);
    this.dots = this.add.graphics().setDepth(10);
    this.drawDots();
    this.buildBar();
    this.add
      .image(BK.close.x, BK.close.y, iconTextureKey('close'))
      .setDisplaySize(BK.close.icon, BK.close.icon)
      .setDepth(10);
    this.buildFriends();
    this.band = this.add.rectangle(W / 2, GRID_TOP / 2, W, GRID_TOP, INT.bg, 0.001).setDepth(4);
    this.tabIcons = this.add.graphics().setDepth(11);
    this.tabSetImg = this.add.image(AB.tabs.set.x, AB.tabs.set.y, avatarIconKey('tabSetOn')).setDepth(12);
    this.tabFriendsImg = this.add.image(AB.tabs.friends.x, AB.tabs.friends.y, avatarIconKey('tabFriendsOff')).setDepth(12);
    // Ny kompis som inte visats: boken öppnar på Kompisar (UI.md §13.4).
    const friendsFirst = data?.tab === 'friends' || d.avatars.fresh.length > 0;
    this.tab = friendsFirst ? 'friends' : 'sets';
    this.selectTab(this.tab, true);

    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      this.down = { x: p.worldX, y: p.worldY, t: this.time.now };
      this.downScroll = this.scroll;
      this.vel = 0;
      this.lastMoveY = p.worldY;
      if (this.tab === 'sets') {
        this.endHint();
        this.tweens.killTweensOf(this.strip);
      }
    });
    this.events.on(Phaser.Scenes.Events.UPDATE, this.tick, this);
    this.input.on('pointermove', (p: Phaser.Input.Pointer) => this.onMove(p));
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => this.onUp(p));

    // Androids bakåtknapp (och Escape i testbygget) stänger boken.
    const onBack = (): boolean => {
      if (this.shop.back()) return true;
      this.close();
      return true;
    };
    setBackHandler(onBack);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => clearBackHandler(onBack));

    if (TEST_HOOK) this.installTestHook();
  }

  private installTestHook(): void {
    const self = this;
    (window as unknown as Record<string, unknown>).__book = {
      get page(): number {
        return self.page;
      },
      get pages(): number {
        return THEME_SETS.length;
      },
      get filled(): number {
        const p = cached().collection[THEME_SETS[self.page].id];
        return self.locked[self.page] || !p ? 0 : filledSlots(p);
      },
      get locked(): boolean[] {
        return self.locked.slice();
      },
      /** Bläddrar till sida i och trycker på den (samma väg som ett tryck). */
      selectPage(i: number): void {
        self.goTo(i);
        self.select();
      },
      get tab(): string {
        return self.tab;
      },
      selectTab(t: string): void {
        self.selectTab(t === 'friends' ? 'friends' : 'sets');
      },
      equip(id: string): boolean {
        return self.equipFriend(id);
      },
      /** Scrollar cellen till mitten av rutnätet och returnerar dess mitt på skärmen. */
      cellOf(id: string): { x: number; y: number } | null {
        const c = self.cells.find((k) => k.def.id === id);
        if (!c) return null;
        self.vel = 0;
        self.setScroll(c.y - (GRID_TOP + GR.bottom) / 2);
        return { x: c.x, y: c.y - self.scroll };
      },
      /** Kompisen på bokens scen. */
      /** Nivåset i full upplösning i minnet (Art v2-budgeten). */
      get ballSets(): string[] {
        return loadedBallSets(self);
      },
      get stageId(): string {
        return self.stageId;
      },
      /** Nyöppnade kompisar som pulsar just nu. */
      get pulsingFriends(): number {
        return self.friendPulses.length;
      },
      /** Svep-ledtråden visades i den här öppningen / pågår. */
      get hintShown(): boolean {
        return self.hintShown;
      },
      get hintActive(): boolean {
        return self.hintHand !== null;
      },
      /** Scroll-ledtrådens pil i Kompisar syns. */
      get scrollHint(): boolean {
        return self.scrollHint !== null && self.scrollHint.visible && self.tab === 'friends';
      },
      /** Butiken (UI.md §14.3): priser, tillstånd, vaken mussla, pick3-erbjudande, ceremoni. */
      get shop(): unknown {
        return self.shop.snapshot();
      },
      /** Köper musslan (samma väg som andra trycket). pick3: öppnar erbjudandet, returnerar null. */
      buy(type: string): unknown {
        return self.shop.buy(type as 'common' | 'silver' | 'gold');
      },
      /** pick3: väljer kort i och trycker på köpknappen. */
      pick(i: number): unknown {
        self.shop.select(i);
        return self.shop.confirmPick();
      },
      /** Uppgraderar vald kompis (samma väg som andra trycket på knappen). */
      upgradeSelected(): boolean {
        return self.doUpgrade();
      },
      /** Scenens vald kompis: nivå, visad text, nivåetiketter och knappens tillstånd. */
      get stage(): unknown {
        return self.stageSnapshot();
      },
    };
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      delete (window as unknown as Record<string, unknown>).__book;
    });
  }

  /** Sidan med något nytt, annars aktivt set. */
  private startPage(): number {
    const d = cached();
    const ids = THEME_SETS.map((s) => s.id);
    if (d.freshSet && ids.includes(d.freshSet)) return ids.indexOf(d.freshSet);
    const fresh = ids.findIndex((id, i) => !this.locked[i] && d.collection[id]?.fresh.some(Boolean));
    return fresh >= 0 ? fresh : Math.max(0, ids.indexOf(d.activeSet));
  }

  // ---------------------------------------------------------------- input

  private onMove(p: Phaser.Input.Pointer): void {
    if (!this.down || !p.isDown) return;
    if (this.tab === 'friends') {
      if (this.down.y < GRID_TOP || this.shop.blocking) return;
      this.vel = this.lastMoveY - p.worldY;
      this.lastMoveY = p.worldY;
      this.setScroll(this.downScroll - (p.worldY - this.down.y), true);
      if (Math.abs(p.worldY - this.down.y) >= SW.tapMaxPx) {
        this.hideScrollHint();
        this.sleepAll();
      }
      return;
    }
    let dx = p.worldX - this.down.x;
    if (Math.abs(dx) < Math.abs(p.worldY - this.down.y)) return;
    // Gummiband i kanterna.
    if ((this.page === 0 && dx > 0) || (this.page === THEME_SETS.length - 1 && dx < 0)) dx *= SW.rubber;
    this.strip.x = -this.page * W + dx;
  }

  private onUp(p: Phaser.Input.Pointer): void {
    const down = this.down;
    this.down = null;
    if (!down) return;
    const dx = p.worldX - down.x;
    const dy = p.worldY - down.y;
    const dt = Math.max(1, this.time.now - down.t);
    const tap = Math.abs(dx) < SW.tapMaxPx && Math.abs(dy) < SW.tapMaxPx && dt < SW.tapMaxMs;
    if (this.tab === 'friends' && this.shop.blocking) {
      if (tap) this.shop.tap(p.worldX, p.worldY);
      return;
    }
    const tab = tap ? this.tabAt(p.worldX, p.worldY) : null;
    if (tab) {
      if (tab !== this.tab) {
        playSound('ui');
        this.selectTab(tab);
      }
      return;
    }
    if (this.tab === 'friends') {
      if (!tap) {
        if (down.y < GRID_TOP) return;
        this.setScroll(this.scroll);
        return;
      }
      this.vel = 0;
      const c = BK.close;
      if (Math.abs(p.worldX - c.x) <= c.hit / 2 && Math.abs(p.worldY - c.y) <= c.hit / 2) this.close();
      else this.tapFriend(p.worldX, p.worldY);
      return;
    }
    if (dy > SW.minPx && dy > Math.abs(dx)) {
      this.close();
      return;
    }
    if (Math.abs(dx) < SW.tapMaxPx && Math.abs(dy) < SW.tapMaxPx && dt < SW.tapMaxMs) {
      this.snap();
      const c = BK.close;
      if (Math.abs(p.worldX - c.x) <= c.hit / 2 && Math.abs(p.worldY - c.y) <= c.hit / 2) this.close();
      else this.select();
      return;
    }
    if (Math.abs(dx) > SW.minPx || Math.abs(dx) / dt > SW.minVelocity) this.goTo(this.page + (dx < 0 ? 1 : -1));
    else this.snap();
  }

  // ---------------------------------------------------------------- flikar

  private tabSetImg!: Phaser.GameObjects.Image;
  private tabFriendsImg!: Phaser.GameObjects.Image;

  /** Flikarnas träffytor 56×72 (UI.md §13.4). */
  private tabAt(x: number, y: number): Tab | null {
    const T = AB.tabs;
    if (y < 0 || y > T.hit.h) return null;
    if (Math.abs(x - T.set.x) <= T.hit.w / 2) return 'sets';
    if (Math.abs(x - T.friends.x) <= T.hit.w / 2) return 'friends';
    return null;
  }

  private selectTab(t: Tab, initial = false): void {
    const changed = this.tab !== t;
    if (changed) this.sleepAll();
    this.tab = t;
    this.endHint();
    const sets = t === 'sets';
    this.strip.setVisible(sets);
    this.dots.setVisible(sets);
    this.bar?.setVisible(sets);
    this.friends.setVisible(!sets);
    this.friendsTop.setVisible(!sets);
    this.band.setVisible(!sets);
    if (changed) {
      const shown: (Phaser.GameObjects.Container | Phaser.GameObjects.Graphics)[] = sets ? [this.strip, this.dots] : [this.friends, this.friendsTop];
      for (const o of shown) {
        o.setAlpha(0);
        this.tweens.add({ targets: o, alpha: 1, duration: 160 });
      }
    }
    this.drawTabs();
    if (!changed && !initial) return;
    // "Nytt sedan sist" räknas bara medan fliken syns.
    this.seenTimer?.remove();
    this.seenTimer = null;
    if (sets) {
      this.strip.x = -this.page * W;
      this.onPageShown();
      this.startHint();
    } else {
      if (this.friendPulses.length > 0) this.seenTimer = this.time.delayedCall(SEEN_MS, () => this.markFriendsSeen());
      this.startScrollHint();
    }
  }

  /** Nyöppnade kompisar har synts i 2 s: pulsen slutar och `avatars.fresh` töms. */
  private markFriendsSeen(): void {
    for (const p of this.friendPulses) {
      p.tween.remove();
      p.target.setScale(p.base);
    }
    this.friendPulses.length = 0;
    if (markFriendsSeen(cached().avatars)) void save();
  }

  /**
   * Svep-ledtråd, första öppningen någonsin (UI.md §12.4): efter 500 ms glider sidan 36 px åt
   * vänster och tillbaka medan en hand visar svepet. En gång; sparas direkt.
   */
  private startHint(): void {
    const s = cached().settings;
    if (s.bookHintSeen) return;
    s.bookHintSeen = true;
    void save({ settings: { bookHintSeen: true } });
    this.hintShown = true;
    const P = BK.peek;
    const H = P.hand;
    const x0 = -this.page * W;
    // Sista sidan: glid åt andra hållet så att gummibandet inte döljer rörelsen.
    const dir = this.page < THEME_SETS.length - 1 ? 1 : -1;
    const hand = this.add.image(H.x, H.y, iconTextureKey('hand')).setDisplaySize(H.size, H.size).setDepth(13).setAlpha(0);
    this.hintHand = hand;
    this.tweens.add({ targets: this.strip, x: x0 - dir * P.px, duration: P.ms / 2, delay: P.delayMs, ease: 'Sine.easeInOut', yoyo: true });
    this.tweens.chain({
      targets: hand,
      tweens: [
        { alpha: 1, duration: H.inMs, delay: P.delayMs - H.inMs },
        { x: H.x + dir * H.dx, duration: P.ms / 2, ease: 'Sine.easeInOut' },
        { alpha: 0, duration: H.outMs },
      ],
      onComplete: () => this.endHint(),
    });
  }

  /** Avbryter/avslutar svep-ledtråden (tryck, bläddring eller flikbyte). */
  private endHint(): void {
    const h = this.hintHand;
    if (!h) return;
    this.hintHand = null;
    this.tweens.killTweensOf(h);
    h.destroy();
    this.tweens.killTweensOf(this.strip);
    this.strip.x = -this.page * W;
  }

  /**
   * Scroll-ledtråd i Kompisar tills spelaren scrollat en gång (UI.md §13.4): en tonad pil i
   * rutnätets nederkant, och första gången efter 500 ms glider innehållet 40 px och tillbaka.
   */
  private startScrollHint(): void {
    if (cached().settings.friendsHintSeen || this.maxScroll <= 0) return;
    if (!this.scrollHint) {
      const g = this.add.graphics();
      const y = GR.bottom - 14;
      g.lineStyle(4, INT.hudDim, 0.8);
      g.strokePoints([{ x: W / 2 - 12, y: y - 5 }, { x: W / 2, y: y + 5 }, { x: W / 2 + 12, y: y - 5 }], false);
      this.friendsTop.add(g);
      this.scrollHint = g;
    }
    if (this.peekShown) return;
    this.peekShown = true;
    const S = AB.scroll;
    const from = this.scroll;
    const to = from + S.peekPx <= this.maxScroll ? from + S.peekPx : from - S.peekPx;
    this.tweens.addCounter({
      from,
      to,
      delay: BK.peek.delayMs,
      duration: S.peekMs / 2,
      ease: 'Sine.easeInOut',
      yoyo: true,
      onUpdate: (tw) => {
        if (!this.down && this.tab === 'friends') this.setScroll(tw.getValue() ?? from);
      },
    });
  }

  private hideScrollHint(): void {
    const g = this.scrollHint;
    if (!g || cached().settings.friendsHintSeen) return;
    cached().settings.friendsHintSeen = true;
    void save({ settings: { friendsHintSeen: true } });
    this.tweens.add({ targets: g, alpha: 0, duration: 300, onComplete: () => g.setVisible(false) });
  }

  /** Två bokmärkesband: aktivt längre och fyllt, inaktivt kortare. Formen bär informationen. */
  private drawTabs(): void {
    const T = AB.tabs;
    const g = this.tabIcons;
    g.clear();
    for (const t of ['sets', 'friends'] as Tab[]) {
      const on = this.tab === t;
      const x = t === 'sets' ? T.set.x : T.friends.x;
      const h = on ? T.hActive : T.hIdle;
      const pts = [
        { x: x - T.w / 2, y: 0 },
        { x: x + T.w / 2, y: 0 },
        { x: x + T.w / 2, y: h },
        { x, y: h - 10 },
        { x: x - T.w / 2, y: h },
      ];
      g.fillStyle(on ? INT.bg : INT.jarWall, on ? 1 : 0.7);
      g.fillPoints(pts, true);
      if (on) {
        g.fillStyle(INT.accent, 0.16);
        g.fillPoints(pts, true);
      }
      g.lineStyle(on ? 3 : 2, on ? INT.accent : INT.hudDim, 1);
      g.strokePoints(pts, true, true);
    }
    const s = T.icon / 128;
    this.tabSetImg.setTexture(avatarIconKey(this.tab === 'sets' ? 'tabSetOn' : 'tabSetOff')).setScale(s);
    this.tabFriendsImg.setTexture(avatarIconKey(this.tab === 'friends' ? 'tabFriendsOn' : 'tabFriendsOff')).setScale(s);
  }

  // ---------------------------------------------------------------- kompisar

  /** Räknare, butik, scen och rutnät (UI.md §13.4, §14). Byggs en gång; valet ritas om vid equip. */
  private buildFriends(): void {
    const av = cached().avatars;
    bakeAvatarParticles(this);
    this.friendsTop = this.add.container(0, 0).setDepth(6);
    const c = this.add.container(0, 0).setDepth(5);
    this.friends = c;
    this.cells = [];
    this.scroll = 0;
    this.vel = 0;

    // Rutnätet klipps till viewporten.
    const maskG = this.make.graphics({ x: 0, y: 0 }, false);
    maskG.fillStyle(0xffffff, 1);
    maskG.fillRect(0, GRID_TOP, W, GR.bottom - GRID_TOP);
    c.setMask(maskG.createGeometryMask());

    const eco = cached().economy;
    this.counters = new Counters(this, eco.pearls, eco.sand, 10, this.friendsTop);
    this.shop = new FriendsShop(this, this.friendsTop, this.counters, () => this.scene.restart({ tab: 'friends' }));
    this.buildStage();

    const g = this.add.graphics();
    c.add(g);
    this.rombG = this.add.graphics();
    c.add(this.rombG);
    let y = GRID_TOP;
    for (const r of GR.order) {
      const list = AVATARS.filter((a) => a.rarity === r);
      const owned = list.filter((a) => av.owned.includes(a.id)).length;
      // Grupprubrik: N pärlor, linje i raritetsfärg, ägda/antal.
      const H = GR.header;
      const hy = y + GR.headerH / 2;
      for (let i = 0; i < RARITY.pearls[r]; i++) drawPearl(g, H.x0 + i * H.pearlPitch, hy, H.pearlR, r);
      const count = this.add
        .text(H.countX, hy, `${owned}/${list.length}`, {
          fontFamily: THEME.type.family,
          fontSize: `${H.countPx}px`,
          color: THEME.palette.hud,
          fontStyle: '800',
        })
        .setOrigin(1, 0.5);
      c.add(count);
      g.lineStyle(2, rarityInt(r), 0.5);
      g.lineBetween(H.x0 + RARITY.pearls[r] * H.pearlPitch, hy, Math.min(H.lineX1, H.countX - count.width - 8), hy);
      y += GR.headerH;
      list.forEach((def, i) => {
        const x = GR.x0 + (i % GR.cols) * GR.pitchX;
        const cy = y + Math.floor(i / GR.cols) * GR.rowPitch + GR.cell / 2 + 4;
        this.cells.push({ def, x, y: cy, node: this.drawCell(g, def, x, cy, av.owned.includes(def.id)) });
      });
      y += Math.ceil(list.length / GR.cols) * GR.rowPitch + GR.groupGap;
    }
    this.friendSel = this.add.graphics();
    c.add(this.friendSel);
    this.drawFriendSel();
    this.drawGridRombs();
    this.maxScroll = Math.max(0, y - GR.bottom);
    // Startposition: raden med en ny kompis om det finns en, annars den valda, centrerad.
    const sel = this.cells.find((k) => av.fresh.includes(k.def.id)) ?? this.cells.find((k) => k.def.id === av.equipped);
    if (sel) this.setScroll(sel.y - (GRID_TOP + GR.bottom) / 2);

    // Tonad överkant (12 px): en remsa av själva bakgrunden, alpha 1 → 0 nedåt (hörn-alpha),
    // så att rutnätet glider in under scenen i stället för att klippas hårt.
    const fade = this.add.renderTexture(0, GRID_TOP, W, GR.fadePx).setOrigin(0);
    fade.draw(this.bg, 0, -GRID_TOP);
    fade.setAlpha(1, 1, 0, 0);
    this.friendsTop.add(fade);
  }

  /** Ritar en cell. Ej ägd: returnerar cellens egen container (siluett + ram) för skakningen. */
  private drawCell(g: Phaser.GameObjects.Graphics, def: AvatarDef, x: number, y: number, owned: boolean): Phaser.GameObjects.Container | null {
    const half = GR.cell / 2;
    const av = cached().avatars;
    if (owned) {
      g.fillStyle(rarityInt(def.rarity), GR.ownedFillAlpha);
      g.fillRoundedRect(x - half, y - half, GR.cell, GR.cell, GR.cellR);
      strokeRarityRoundRect(g, x - half, y - half, GR.cell, GR.cell, GR.cellR, GR.frameW, def.rarity);
      const img = addAvatarImage(this, x, y + gripToCenter(GR.avatarPx), def.id, GR.avatarPx);
      this.friends.add(img);
      // Nytt sedan sist: skalpuls 0,5 Hz tills fliken synts i 2 s.
      if (av.fresh.includes(def.id)) {
        const base = img.scale;
        const tween = this.tweens.add({
          targets: img,
          scale: base * AB.freshPulse.scale,
          duration: AB.freshPulse.halfCycleMs,
          ease: 'Sine.easeInOut',
          yoyo: true,
          repeat: -1,
        });
        this.friendPulses.push({ target: img, base, tween });
      }
      return null;
    }
    // Ej ägd: siluett + streckad ram, i cellens egen container (origo i cellens mitt).
    const sil = addAvatarImage(this, 0, gripToCenter(GR.avatarPx), def.id, GR.avatarPx, true)
      .setTint(INT.hudDim)
      .setAlpha(GR.silAlpha);
    const fg = this.add.graphics();
    const node = this.add.container(x, y, [sil, fg]);
    this.friends.add(node);
    fg.lineStyle(2, INT.hudDim, GR.emptyFrameAlpha);
    const e = [
      [-half, -half, half, -half],
      [half, -half, half, half],
      [half, half, -half, half],
      [-half, half, -half, -half],
    ];
    for (const [x0, y0, x1, y1] of e) {
      const len = Math.hypot(x1 - x0, y1 - y0);
      for (let d = 0; d < len; d += 10) {
        const t0 = d / len;
        const t1 = Math.min(len, d + 5) / len;
        fg.lineBetween(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0, x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1);
      }
    }
    return node;
  }

  /** Uppgradering: två rombplatser under varje ägd cell (UI.md §13.4). */
  private drawGridRombs(): void {
    const g = this.rombG;
    const av = cached().avatars;
    g.clear();
    for (const cell of this.cells) {
      if (!av.owned.includes(cell.def.id)) continue;
      const lvl = av.level[cell.def.id] ?? 1;
      for (let k = 0; k < 2; k++) {
        const rx = cell.x + (k - 0.5) * GR.rombPitch;
        drawRomb(g, rx, cell.y + GR.rombY, GR.rombW, GR.rombH, lvl >= k + 2, 0, INT.hud, INT.hudDim);
      }
    }
  }

  /** Scenen (UI.md §14.5): vald kompis 60 px som håller en nivå 1-glimt, glöd i raritetsfärg bakom. */
  private buildStage(): void {
    const def = avatarById(cached().avatars.equipped);
    this.stageId = def?.id ?? '';
    const S = ES.separator;
    const sep = this.add.graphics();
    sep.lineStyle(S.w, INT.jarWall, 1);
    sep.lineBetween(S.x0, S.y, S.x1, S.y);
    this.friendsTop.add(sep);
    this.stageInfo = this.add.container(0, 0);
    if (!def) {
      // Ingen kompis ännu: stapel och knapp döljs.
      this.friendsTop.add(this.add.image(SF.x, SF.cy, avatarIconKey('tabFriendsOff')).setScale(SF.displayPx / ICON_PX).setAlpha(0.5));
      this.friendsTop.add(this.stageInfo);
      return;
    }
    this.stageGlow = this.add.image(SF.x, SF.cy, BG_GLOW)
      .setDisplaySize(SF.glowR * 4, SF.glowR * 4)
      .setTint(rarityInt(def.rarity))
      .setAlpha(SF.glowAlpha);
    const ball = this.add
      .image(SF.x, STAGE_GRIP_Y + SF.objR - 4, ballTextureKey(SF.objLevel, cached().activeSet))
      .setScale(scaleForBodyRadius(SF.objLevel, SF.objR));
    this.friendsTop.add([this.stageGlow, ball, this.stageInfo]);
    this.setStageFigure(def, false);
    this.drawStageInfo(def);
  }

  private setStageFigure(def: AvatarDef, animate: boolean): void {
    const lvl = cached().avatars.level[def.id] ?? 1;
    const old = this.stageImg;
    if (old) {
      this.stageRig?.destroy();
      this.tweens.add({ targets: old, y: old.y + 40, alpha: 0, duration: 160, ease: 'Quad.easeIn', onComplete: () => old.destroy() });
    }
    const img = this.add
      .image(SF.x, STAGE_GRIP_Y, bakeAvatar(this, def.id, SF.displayPx, false, 'full', lvl - 1))
      .setOrigin(0.5, avatarOriginY());
    this.friendsTop.add(img);
    const rig = new AvatarRig(this, def, SF.displayPx, cached().settings.calm);
    this.stageImg = img;
    this.stageRig = rig;
    this.stageId = def.id;
    if (!animate) {
      rig.resumeLoop();
      return;
    }
    rig.base = 0;
    this.tweens.add({
      targets: rig,
      base: 1,
      duration: 240,
      ease: 'Back.easeOut',
      onComplete: () => this.playStageShowcase(),
    });
  }

  /** Namn, förmågetext (max 2 rader), raritetspärlor, stapel, nivåetiketter och knapp. */
  private drawStageInfo(def: AvatarDef, opts: { awake?: boolean; animLevel?: number } = {}): void {
    const c = this.stageInfo;
    c.removeAll(true);
    this.upBtn = null;
    const locale = getLocale();
    const lvl = cached().avatars.level[def.id] ?? 1;
    const g = this.add.graphics();
    c.add(g);
    const RP = ES.rarityPearls;
    drawPearlRow(g, SF.x, RP.y, RARITY.pearls[def.rarity], RP.r, RP.pitch, def.rarity);
    const N = ES.name;
    const name = this.add
      .text(N.x, N.y, t(def.names, locale), { fontFamily: THEME.type.family, fontSize: `${N.px}px`, color: HUD, fontStyle: '800' })
      .setOrigin(0, 0.5);
    for (let px = N.px; name.width > N.maxW && px > N.minPx; ) name.setFontSize(--px);
    const D = ES.desc;
    const desc = this.add
      .text(D.x, D.y, '', {
        fontFamily: THEME.type.family,
        fontSize: `${D.px}px`,
        color: ECONOMY_COLORS.desc,
        fontStyle: '700',
        wordWrap: { width: D.maxW },
      })
      .setOrigin(0, 0);
    setClamped(desc, t(def.desc, locale), D.maxLines);
    c.add([name, desc]);

    // Stapel i tre segment: uppnådd fylld, nästa kontur hud, senare kontur hudDim.
    const B = ES.bar;
    const segW = (B.x1 - B.x0 - 2 * B.gap) / 3;
    const top = B.y - B.h / 2;
    for (let i = 0; i < 3; i++) {
      const lv = i + 1;
      const x = B.x0 + i * (segW + B.gap);
      const col = rarityInt(def.rarity, i * 2);
      if (lv <= lvl) {
        const sg = lv === opts.animLevel ? this.add.graphics().setPosition(x, top) : g;
        const ox = sg === g ? x : 0;
        const oy = sg === g ? top : 0;
        sg.fillStyle(col, 1);
        sg.fillRoundedRect(ox, oy, segW, B.h, B.r);
        sg.lineStyle(1.5, INT.ink, 1);
        sg.strokeRoundedRect(ox, oy, segW, B.h, B.r);
        if (sg !== g) {
          c.add(sg);
          sg.scaleX = 0;
          const U = ES.upgraded;
          this.tweens.add({ targets: sg, scaleX: 1, duration: U.fillMs, ease: U.fillEase });
          this.upgradeParticles(x + segW / 2, B.y, col);
        }
      } else if (lv === lvl + 1) {
        if (opts.awake) {
          g.fillStyle(col, 0.35);
          g.fillRoundedRect(x, top, segW, B.h, B.r);
        }
        g.lineStyle(B.outlineW, INT.hud, 1);
        g.strokeRoundedRect(x, top, segW, B.h, B.r);
      } else {
        g.lineStyle(B.outlineW, INT.hudDim, 0.5);
        g.strokeRoundedRect(x, top, segW, B.h, B.r);
      }
      this.drawHint(def, lv as 1 | 2 | 3, lvl, x + segW / 2, locale);
    }
    this.drawUpgradeButton(def, lvl, opts.awake === true);
  }

  /** Värdet per nivå under segmentet (levelHintLabel). Nästa nivå får uppgraderingspilen före. */
  private drawHint(def: AvatarDef, lv: 1 | 2 | 3, lvl: number, cx: number, locale: Locale): void {
    const label = levelHintLabel(def, lv, locale);
    if (!label) return;
    const H = ES.hint;
    const next = lv === lvl + 1;
    const color = lv <= lvl || next ? HUD : HUD_DIM;
    const parts: Phaser.GameObjects.Components.Transform[] = [];
    const widths: number[] = [];
    if (next) {
      parts.push(this.add.image(0, H.y, ECO_EXTRA_KEYS.upgradeHud).setScale(H.arrowPx / ICON_PX));
      widths.push(H.arrowPx);
    }
    if (label.levelIcon !== undefined) {
      const lvIcon = label.levelIcon;
      parts.push(this.add.image(0, H.y, ballTextureKey(lvIcon, cached().activeSet)).setScale(scaleForBodyRadius(lvIcon, H.levelIconR)));
      widths.push(H.levelIconR * 2);
    }
    if (label.text) {
      const txt = this.add.text(0, H.y, label.text, { fontFamily: THEME.type.family, fontSize: `${H.px}px`, color, fontStyle: '800' }).setOrigin(0.5);
      parts.push(txt);
      widths.push(txt.width);
    }
    const total = widths.reduce((a, b) => a + b, 0) + 2 * (widths.length - 1);
    let x = cx - total / 2;
    parts.forEach((o, i) => {
      o.x = x + widths[i] / 2;
      x += widths[i] + 2;
    });
    this.stageInfo.add(parts as unknown as Phaser.GameObjects.GameObject[]);
  }

  /** Uppgraderingsknapp 240×48 med pris (UI.md §14.5). Nivå III: bock, inte tryckbar. */
  private drawUpgradeButton(def: AvatarDef, lvl: number, awake: boolean): void {
    const b = ES.button;
    const c = this.add.container(b.cx, b.cy);
    this.stageInfo.add(c);
    this.upBtn = c;
    if (lvl >= 3) {
      c.add(this.add.image(0, 0, ECONOMY_ICON_KEYS.check).setScale(28 / ICON_PX).setAlpha(0.8));
      return;
    }
    const cost = upgradeCost(def.rarity, lvl)!;
    const eco = cached().economy;
    const ok = canUpgrade(cached(), def.id);
    const g = this.add.graphics();
    if (ok) {
      g.fillStyle(INT.accent, awake ? 0.26 : 0.14);
      g.fillRoundedRect(-b.w / 2, -b.h / 2, b.w, b.h, b.r);
      g.lineStyle(awake ? 4 : 3, INT.accent, 1);
      g.strokeRoundedRect(-b.w / 2, -b.h / 2, b.w, b.h, b.r);
    } else {
      g.lineStyle(2, INT.hudDim, 1);
      dashedRoundRect(g, -b.w / 2, -b.h / 2, b.w, b.h, b.r, 6, 5);
    }
    c.add(g);
    const arrow = this.add.image(0, awake ? -3 : 0, ok ? ECONOMY_ICON_KEYS.upgrade : ECO_EXTRA_KEYS.upgradeDim).setScale(b.iconPx / ICON_PX);
    const items: [Phaser.GameObjects.Components.Transform & Phaser.GameObjects.GameObject, number][] = [[arrow, b.iconPx]];
    for (const [r, amount] of priceParts(cost)) {
      const lack = eco[r] < amount;
      const icon = this.add.image(0, 0, r === 'pearls' ? ECONOMY_ICON_KEYS.pearlCoin : ECONOMY_ICON_KEYS.sand).setScale(b.priceIconPx / ICON_PX);
      const txt = this.add
        .text(0, 0, formatAmount(amount), { fontFamily: THEME.type.family, fontSize: `${b.textPx}px`, color: lack ? HUD_DIM : HUD, fontStyle: '800' })
        .setOrigin(0.5);
      items.push([icon, b.priceIconPx], [txt, txt.width]);
      if (lack) (icon as unknown as { lack: number }).lack = eco[r] / amount;
    }
    // Pil, sedan per resurs ikon + 7 px + siffra, 12 px mellan resurserna.
    const gapAfter = (i: number): number => (i === 0 ? 12 : i % 2 === 1 ? b.gap : 12);
    const total = items.reduce((a, [, w], i) => a + w + (i < items.length - 1 ? gapAfter(i) : 0), 0);
    let x = -total / 2;
    items.forEach(([o, w], i) => {
      o.x = x + w / 2;
      x += w + gapAfter(i);
      const lack = (o as unknown as { lack?: number }).lack;
      if (lack !== undefined) progressRing(g, o.x, 0, lack);
      c.add(o);
    });
    if (awake) {
      this.tweens.add({ targets: arrow, scale: arrow.scale * ECONOMY_UI.wake.breath.scale, duration: ECONOMY_UI.wake.breath.halfCycleMs, delay: ECONOMY_UI.wake.ms, ease: ECONOMY_UI.wake.breath.ease, yoyo: true, repeat: -1 });
    }
  }

  /** 12 partiklar i raritetsfärg från segmentet som fylldes. */
  private upgradeParticles(x: number, y: number, color: number): void {
    const U = ES.upgraded;
    const dist = (U.particleSpeed * U.lifeMs) / 1000;
    for (let i = 0; i < U.particles; i++) {
      const a = (i / U.particles) * Math.PI * 2;
      const p = this.add.image(x, y, FX_DOT).setTint(color).setDepth(8).setScale(0.5);
      this.tweens.add({ targets: p, x: x + Math.cos(a) * dist, y: y + Math.sin(a) * dist, alpha: 0, duration: U.lifeMs, ease: 'Cubic.easeOut', onComplete: () => p.destroy() });
    }
  }

  /** Tryck på uppgraderingsknappen: väck, andra trycket köper; räcker inte = skakning. */
  private tapUpgrade(): void {
    const def = avatarById(this.stageId);
    if (!def) return;
    const lvl = cached().avatars.level[def.id] ?? 1;
    if (lvl >= 3) return;
    if (!canUpgrade(cached(), def.id)) {
      this.sleepAll();
      if (this.upBtn) this.shop.poor(this.upBtn, upgradeCost(def.rarity, lvl)!);
      return;
    }
    if (this.upAwakeAt >= 0) {
      if (this.time.now - this.upAwakeAt >= ECONOMY_UI.wake.minGapMs) this.doUpgrade();
      return;
    }
    this.shop.sleep();
    this.upAwakeAt = this.time.now;
    this.drawStageInfo(def, { awake: true });
    this.upSleepTimer = this.time.delayedCall(ECONOMY_UI.wake.sleepAfterMs, () => this.sleepUpgrade());
    playTone(ECONOMY_SOUND.wake);
    vibrate(10);
  }

  private sleepUpgrade(): void {
    this.upSleepTimer?.remove();
    this.upSleepTimer = null;
    if (this.upAwakeAt < 0) return;
    this.upAwakeAt = -1;
    const def = avatarById(this.stageId);
    if (def) this.drawStageInfo(def);
  }

  /** Allt vaket somnar (tryck utanför, scroll, flikbyte). */
  private sleepAll(): void {
    this.shop?.sleep();
    this.sleepUpgrade();
  }

  /** Köper nästa nivå för vald kompis. false = räcker inte / nivå III / ingen kompis. */
  private doUpgrade(): boolean {
    const def = avatarById(this.stageId);
    if (!def || this.shop.blocking) return false;
    const lvl = cached().avatars.level[def.id] ?? 1;
    const cost = upgradeCost(def.rarity, lvl);
    if (!cost || !upgrade(cached(), def.id)) return false;
    this.upSleepTimer?.remove();
    this.upAwakeAt = -1;
    void save();
    this.shop.paid(ES.button.cx, ES.button.cy, cost, ECONOMY_SOUND.upgrade);
    this.drawStageInfo(def, { animLevel: lvl + 1 });
    this.drawGridRombs();
    // Figuren får sina romber (poppar) och gör sin showcase.
    const img = this.stageImg;
    const rig = this.stageRig;
    if (img && rig) {
      img.setTexture(bakeAvatar(this, def.id, SF.displayPx, false, 'full', lvl));
      rig.base = 0.7;
      this.tweens.add({ targets: rig, base: 1, duration: ES.upgraded.rombPopMs, ease: 'Back.easeOut' });
    }
    this.showcasing = false;
    this.playStageShowcase();
    return true;
  }

  private stageSnapshot(): unknown {
    const def = avatarById(this.stageId);
    if (!def) return null;
    const lvl = cached().avatars.level[def.id] ?? 1;
    const texts = this.stageInfo.list.filter((o): o is Phaser.GameObjects.Text => o instanceof Phaser.GameObjects.Text).map((o) => o.text);
    return {
      id: def.id,
      level: lvl,
      /** Romber på scenfiguren (texturnyckeln "-rN"). */
      rombs: Number(/-r(\d)$/.exec(this.stageImg?.texture.key ?? '')?.[1] ?? 0),
      name: texts[0] ?? '',
      desc: texts[1] ?? '',
      hints: texts.slice(2),
      button: lvl >= 3 ? 'max' : canUpgrade(cached(), def.id) ? (this.upAwakeAt >= 0 ? 'awake' : 'ok') : 'poor',
      cost: upgradeCost(def.rarity, lvl),
    };
  }

  /** Scenens showcase i normal takt. Tryck under pågående showcase ignoreras. */
  private playStageShowcase(): void {
    const rig = this.stageRig;
    const def = avatarById(this.stageId);
    if (!rig || !def || this.showcasing) return;
    this.showcasing = true;
    const sc = def.showcase;
    playTone(sc.sound);
    rig.play(sc.anim, 3, 1, () => {
      this.showcasing = false;
      rig.resumeLoop();
    });
    const k = SF.displayPx / 56;
    this.time.delayedCall(sc.fxAtMs, () =>
      playFxCue(this, sc.fx, SF.x, SF.cy, k, 7, cached().settings.calm),
    );
  }

  /** Varje frame: scenens pose och scrollens tröghet. Inga allokeringar. */
  private tick(): void {
    if (this.stageImg && this.stageRig) this.stageRig.apply(this.stageImg, SF.x, STAGE_GRIP_Y);
    if (this.tab !== 'friends' || this.down || Math.abs(this.vel) < 0.1) return;
    this.vel *= AB.scroll.friction;
    this.setScroll(this.scroll + this.vel);
  }

  /** Vald: yttre accentram 56×56 och bockbricka (UI.md §13.4). */
  private drawFriendSel(): void {
    const g = this.friendSel;
    g.clear();
    const cell = this.cells.find((k) => k.def.id === cached().avatars.equipped);
    if (!cell) return;
    const S = GR.selected;
    const size = GR.cell + S.pad * 2;
    g.lineStyle(S.width, INT.accent, 1);
    g.strokeRoundedRect(cell.x - size / 2, cell.y - size / 2, size, size, GR.cellR + S.pad);
    const bx = cell.x + S.badgeDx;
    const by = cell.y + S.badgeDy;
    g.fillStyle(INT.accent, 1);
    g.fillCircle(bx, by, S.badgeR);
    g.lineStyle(2.5, INT.ink, 1);
    g.strokePoints([{ x: bx - 4, y: by }, { x: bx - 1, y: by + 3 }, { x: bx + 4, y: by - 3 }], false);
  }

  /** Scroll med gummiband i kanterna medan fingret drar, annars klampat. */
  private setScroll(v: number, rubber = false): void {
    if (rubber && (v < 0 || v > this.maxScroll)) {
      const edge = v < 0 ? 0 : this.maxScroll;
      this.scroll = edge + (v - edge) * AB.scroll.rubber;
    } else {
      this.scroll = Phaser.Math.Clamp(v, 0, this.maxScroll);
    }
    this.friends.y = -this.scroll;
  }

  private tapFriend(x: number, y: number): void {
    if (this.shop.tap(x, y)) {
      this.sleepUpgrade();
      return;
    }
    const U = ES.button;
    if (this.upBtn && Math.abs(x - U.cx) <= U.w / 2 && Math.abs(y - U.cy) <= U.hit.h / 2) {
      this.tapUpgrade();
      return;
    }
    this.sleepUpgrade();
    const S = ES.hit;
    if (x >= S.x && x <= S.x + S.w && y >= S.y && y <= S.y + S.h) {
      this.playStageShowcase();
      return;
    }
    if (y < GRID_TOP || y > GR.bottom) return;
    const cell = this.cells.find((k) => Math.abs(k.x - x) <= GR.cell / 2 && Math.abs(k.y - this.scroll - y) <= (GR.cell + 8) / 2 + 4);
    if (!cell) return;
    if (!this.equipFriend(cell.def.id)) this.lockedCell(cell);
  }

  /** Tryck på siluett: bara cellen skakar ±4 px två gånger på 240 ms, och ljudet `locked`. */
  private lockedCell(cell: FriendCell): void {
    playTone(META_SOUND.locked);
    const n = cell.node;
    if (!n) return;
    this.tweens.killTweensOf(n);
    n.x = cell.x;
    this.tweens.add({ targets: n, x: cell.x + 4, duration: 60, yoyo: true, repeat: 1, ease: 'Sine.easeInOut', onComplete: () => n.setX(cell.x) });
  }

  /** Tryck på ägd kompis: vald från nästa runda, sparas direkt, scenen byter figur. */
  private equipFriend(id: string): boolean {
    const av = cached().avatars;
    if (av.equipped === id) return true;
    if (!equip(av, id)) return false;
    void save();
    this.drawFriendSel();
    playTone(AVATAR_SOUND.equip);
    vibrate(10);
    const def = avatarById(id);
    if (def) {
      this.showcasing = false;
      this.stageGlow?.setTint(rarityInt(def.rarity));
      this.setStageFigure(def, true);
      this.drawStageInfo(def);
    }
    return true;
  }

  private close(): void {
    playSound('ui');
    this.scene.start('Start');
  }

  private snap(): void {
    this.tweens.add({ targets: this.strip, x: -this.page * W, duration: SW.snapMs, ease: 'Back.easeOut' });
  }

  private goTo(i: number): void {
    const next = Phaser.Math.Clamp(i, 0, THEME_SETS.length - 1);
    if (next === this.page) {
      this.snap();
      return;
    }
    this.page = next;
    this.endHint();
    this.tweens.killTweensOf(this.strip);
    playTone(META_SOUND.pageTurn);
    this.tweens.add({ targets: this.strip, x: -next * W, duration: SW.pageMs, ease: 'Cubic.easeOut' });
    this.drawDots();
    this.onPageShown();
  }

  /** Tryck på sidan: välj upplåst set som aktivt, eller "inte än" på en låst sida. */
  private select(): void {
    const i = this.page;
    if (this.locked[i]) {
      this.tweens.killTweensOf(this.strip);
      this.strip.x = -i * W;
      this.tweens.add({
        targets: this.strip,
        x: -i * W + LOCKED_FB.px,
        duration: LOCKED_FB.ms / 4,
        yoyo: true,
        repeat: 1,
        ease: 'Sine.easeInOut',
      });
      playTone(META_SOUND.locked);
      if (this.bar) {
        this.tweens.add({ targets: this.bar, scale: LOCKED_FB.barScale, duration: LOCKED_FB.barMs / 2, yoyo: true });
      }
      return;
    }
    const d = cached();
    const set = THEME_SETS[i];
    if (d.activeSet === set.id) return;
    const prev = THEME_SETS.findIndex((s) => s.id === d.activeSet);
    void save({ activeSet: set.id });
    if (prev >= 0) {
      this.drawMark(prev, 1);
      this.badges[prev]?.setVisible(false);
    }
    this.tweens.addCounter({
      from: 0,
      to: 1,
      duration: MARK.selectMs,
      ease: 'Cubic.easeOut',
      onUpdate: (tw) => this.drawMark(i, tw.getValue() ?? 1),
    });
    const badge = this.badges[i];
    if (badge) {
      badge.setVisible(true).setScale(0);
      this.tweens.add({ targets: badge, scale: 1, duration: MARK.badgeMs, ease: 'Back.easeOut' });
    }
    for (let k = 0; k < 3; k++) playTimbre(set.sound, [0, 4, 7][k], k * MARK.arpMs);
    vibrate(10);
    this.drawDots();
  }

  /** Nytt sedan sist nollställs när sidan har synts i 2 s. */
  private onPageShown(): void {
    this.seenTimer?.remove();
    const i = this.page;
    this.seenTimer = this.time.delayedCall(SEEN_MS, () => this.markSeen(i));
  }

  private markSeen(i: number): void {
    if (this.locked[i]) return;
    if (!markPageSeen(cached(), THEME_SETS[i].id)) return;
    for (const p of this.pulses[i]) {
      p.tween.remove();
      p.target.setScale(p.base);
    }
    this.pulses[i].length = 0;
    void save();
  }

  // ---------------------------------------------------------------- bygg

  private buildPage(i: number): void {
    const set = THEME_SETS[i];
    const ox = i * W;
    const locked = this.locked[i];
    const c = this.strip;
    const pal = setPalette(locked ? THEME_SETS[0] : set);
    drawBackground(this, locked ? undefined : set.id, { ox, still: true, plain: locked, into: c });
    c.add(this.add.rectangle(ox + W / 2, THEME.layout.height / 2, W, THEME.layout.height, hexToInt(pal.bg), 0.35));

    const I = BK.setIcon;
    const div = this.add.graphics();
    div.lineStyle(2, hexToInt(pal.jarWall), 1);
    div.lineBetween(ox + 40, BK.separatorY, ox + 160, BK.separatorY);
    div.lineBetween(ox + 200, BK.separatorY, ox + 320, BK.separatorY);
    c.add(div);
    c.add(this.add.image(ox + 180, BK.separatorY, iconTextureKey('sparkle')).setDisplaySize(22, 22));

    if (locked) {
      // Låst: "?" och enkla cirklar utan dekor, så att sidan inte avslöjar vilket set som kommer.
      c.add(this.add.image(ox + I.x, I.y, iconTextureKey('qmark')).setDisplaySize(I.size, I.size));
      this.marks.push(null);
      this.badges.push(null);
      const g = this.add.graphics();
      for (let lvl = 0; lvl < LEVEL_COUNT; lvl++) {
        const r = BK.r0 + BK.rStep * lvl;
        const [x, y] = slotXY(lvl, BK.normalRowsY);
        g.fillStyle(INT.hudDim, BK.lockedAlpha);
        g.fillCircle(ox + x, y, r);
        if (lvl === 0) continue;
        const [sx, sy] = slotXY(lvl, BK.shinyRowsY);
        g.fillCircle(ox + sx, sy, r);
        g.lineStyle(2, INT.hudDim, BK.lockedAlpha);
        dashedCircle(g, ox + sx, sy, r * META.shiny.ringRadius, 4);
      }
      c.add(g);
      return;
    }

    const d = cached();
    const page = d.collection[set.id];
    const icon = this.add.image(ox + I.x, I.y, setIconKey(set.id)).setDisplaySize(I.size, I.size);
    c.add(icon);
    if (d.freshSet === set.id) this.pulse(i, icon);
    const mark = this.add.graphics();
    c.add(mark);
    this.marks.push(mark);
    const badge = this.add.graphics().setPosition(ox + I.x + MARK.badgeDx, I.y + MARK.badgeDy);
    badge.fillStyle(INT.accent, 1);
    badge.fillCircle(0, 0, MARK.badgeR);
    badge.lineStyle(3, INT.ink, 1);
    badge.strokePoints([{ x: -5, y: 0 }, { x: -1.5, y: 4 }, { x: 5, y: -4 }], false);
    badge.setVisible(d.activeSet === set.id);
    c.add(badge);
    this.badges.push(badge);
    this.drawMark(i, 1);

    c.add(
      this.add
        .text(ox + BK.meter.x, BK.meter.y, `${page ? filledSlots(page) : 1}/${SLOTS_PER_PAGE}`, {
          fontFamily: THEME.type.family,
          fontSize: `${BK.meter.px}px`,
          color: THEME.palette.hud,
          fontStyle: THEME.type.weightHeavy,
        })
        .setOrigin(0.5),
    );

    for (let lvl = 0; lvl < LEVEL_COUNT; lvl++) {
      const [x, y] = slotXY(lvl, BK.normalRowsY);
      this.addSlot(i, ox + x, y, lvl, page?.caught[lvl] ?? lvl === 0, false, page?.fresh[slotIndex(lvl, false)] ?? false);
      if (lvl === 0) continue;
      const [sx, sy] = slotXY(lvl, BK.shinyRowsY);
      this.addSlot(i, ox + sx, sy, lvl, page?.shiny[lvl] ?? false, true, page?.fresh[slotIndex(lvl, true)] ?? false);
    }
  }

  /** Aktivt: heldragen ring (ritas in till `progress`). Upplåst: streckad ring. */
  private drawMark(i: number, progress: number): void {
    const g = this.marks[i];
    if (!g) return;
    const I = BK.setIcon;
    const x = i * W + I.x;
    g.clear();
    if (cached().activeSet === THEME_SETS[i].id) {
      g.lineStyle(MARK.ringW, INT.accent, 1);
      g.beginPath();
      g.arc(x, I.y, I.ringR, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress, false);
      g.strokePath();
    } else {
      g.lineStyle(MARK.ringW, INT.hudDim, 1);
      dashedCircle(g, x, I.y, I.ringR, MARK.dash);
    }
  }

  private addSlot(page: number, x: number, y: number, level: number, have: boolean, shiny: boolean, fresh: boolean): void {
    const set = THEME_SETS[page];
    const r = BK.r0 + BK.rStep * level;
    const tex = bookLevelTexture(this, set.id, level, r, !have);
    const img = this.add.image(x, y, tex.key).setScale(tex.scale);
    if (!have) img.setTint(INT.hudDim).setAlpha(BK.lockedAlpha);
    this.strip.add(img);
    if (shiny && have) {
      const ring = this.add.image(x, y, FX_GLITTER).setScale((r * META.shiny.ringRadius) / FX_GLITTER_R);
      this.strip.add(ring);
      // Snurrar 20°/s utan puls (boken är lugn).
      this.tweens.add({ targets: ring, angle: 360, duration: (360 / BK.glitterSpinDegPerSec) * 1000, repeat: -1 });
    } else if (shiny) {
      const g = this.add.graphics();
      g.lineStyle(2, INT.hudDim, BK.lockedAlpha);
      dashedCircle(g, x, y, r * META.shiny.ringRadius, 4);
      this.strip.add(g);
    }
    if (fresh && have) this.pulse(page, img);
  }

  /** Nytt sedan sist: skalpuls 0,5 Hz. */
  private pulse(page: number, target: Phaser.GameObjects.Image): void {
    const base = target.scale;
    const tween = this.tweens.add({
      targets: target,
      scale: base * BK.freshPulse.scale,
      duration: BK.freshPulse.halfCycleMs,
      ease: 'Sine.easeInOut',
      yoyo: true,
      repeat: -1,
    });
    this.pulses[page].push({ target, base, tween });
  }

  /** Sidindikator: aktuell r 6, upplåst fylld r 4, låst ring r 4, aktivt set extra ring. */
  private drawDots(): void {
    const g = this.dots;
    const D = BK.dots;
    const n = THEME_SETS.length;
    const active = cached().activeSet;
    g.clear();
    for (let k = 0; k < n; k++) {
      const x = W / 2 + (k - (n - 1) / 2) * D.pitch;
      if (k === this.page) {
        g.fillStyle(INT.hud, 1);
        g.fillCircle(x, D.y, D.rCurrent);
      } else if (this.locked[k]) {
        g.lineStyle(1.5, INT.hudDim, 1);
        g.strokeCircle(x, D.y, D.r);
      } else {
        g.fillStyle(INT.hudDim, 1);
        g.fillCircle(x, D.y, D.r);
      }
      if (THEME_SETS[k].id === active) {
        g.lineStyle(1.5, INT.accent, 1);
        g.strokeCircle(x, D.y, 9.5);
      }
    }
  }

  /** Stapeln mot nästa set (tidsspåret). Döljs när alla set är upplåsta. */
  private buildBar(): void {
    const d = cached();
    const v = nextSetProgress(d.stats.merges, d.unlockedSets.length);
    if (v === null) return;
    const b = BK.bar;
    const cx = (b.x0 + b.x1) / 2;
    const w = b.x1 - b.x0;
    const g = this.add.graphics();
    g.fillStyle(hexToInt(META_COLORS.barTrack), 1);
    g.fillRoundedRect(-w / 2, -b.h / 2, w, b.h, b.h / 2);
    if (v > 0) {
      g.fillStyle(hexToInt(META_COLORS.barFill), 1);
      g.fillRoundedRect(-w / 2, -b.h / 2, Math.max(b.h, w * v), b.h, b.h / 2);
    }
    const q = this.add.image(b.iconX - cx, 0, iconTextureKey('qmark')).setDisplaySize(b.iconSize, b.iconSize);
    this.bar = this.add.container(cx, b.y, [g, q]).setDepth(10);
  }
}
