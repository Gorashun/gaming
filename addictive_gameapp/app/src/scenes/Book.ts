import Phaser from 'phaser';
import { INT, THEME, hexToInt } from '../data/theme';
import { LEVEL_COUNT, SLOTS_PER_PAGE } from '../data/collection';
import { META, META_COLORS, META_SOUND, THEME_SETS, setPalette } from '../data/themes';
import {
  FX_GLITTER,
  FX_GLITTER_R,
  bakeSet,
  ballTextureKey,
  scaleForBodyRadius,
  silhouetteTextureKey,
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
  UPGRADE,
  avatarById,
  oddsPearls,
  type AvatarDef,
  type Rarity,
} from '../data/avatarsIndex';
import { equip, markFriendsSeen } from '../systems/avatars';
import { clearBackHandler, setBackHandler } from '../systems/back';
import { BG_GLOW } from '../ui/textures';
import { avatarIconKey } from '../ui/icons';
import {
  AVATAR_TEX_ORIGIN_Y,
  addAvatarImage,
  bakeAvatar,
  bakeAvatarParticles,
  drawPearl,
  drawRomb,
  gripToCenter,
  rarityInt,
  strokeRarityRoundRect,
} from '../ui/avatarArt';
import { AvatarRig } from '../ui/avatarRig';
import { playFxCue } from '../ui/avatarFx';

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
const ST = AB.stage;

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
    const d = cached();
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
    this.band = this.add.rectangle(W / 2, GR.top / 2, W, GR.top, INT.bg, 0.001).setDepth(4);
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
        self.setScroll(c.y - (GR.top + GR.bottom) / 2);
        return { x: c.x, y: c.y - self.scroll };
      },
      /** Kompisen på bokens scen. */
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
      if (this.down.y < GR.top) return;
      this.vel = this.lastMoveY - p.worldY;
      this.lastMoveY = p.worldY;
      this.setScroll(this.downScroll - (p.worldY - this.down.y), true);
      if (Math.abs(p.worldY - this.down.y) >= SW.tapMaxPx) this.hideScrollHint();
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
        if (down.y < GR.top) return;
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

  /** Scen, odds-burk och rutnät (UI.md §13.4). Byggs en gång; valet ritas om vid equip. */
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
    maskG.fillRect(0, GR.top, W, GR.bottom - GR.top);
    c.setMask(maskG.createGeometryMask());

    this.buildJar(av.owned);
    this.buildStage();

    const g = this.add.graphics();
    c.add(g);
    let y = GR.top;
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
    this.maxScroll = Math.max(0, y - GR.bottom);
    // Startposition: raden med en ny kompis om det finns en, annars den valda, centrerad.
    const sel = this.cells.find((k) => av.fresh.includes(k.def.id)) ?? this.cells.find((k) => k.def.id === av.equipped);
    if (sel) this.setScroll(sel.y - (GR.top + GR.bottom) / 2);

    // Tonad överkant (12 px): en remsa av själva bakgrunden, alpha 1 → 0 nedåt (hörn-alpha),
    // så att rutnätet glider in under scenen i stället för att klippas hårt.
    const fade = this.add.renderTexture(0, GR.top, W, GR.fadePx).setOrigin(0);
    fade.draw(this.bg, 0, -GR.top);
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
      // Uppgradering: två rombplatser under cellen.
      const lvl = av.level[def.id] ?? 1;
      const xp = av.xp[def.id] ?? 0;
      for (let k = 0; k < 2; k++) {
        const rx = x + (k - 0.5) * GR.rombPitch;
        const reached = lvl >= k + 2;
        const next = lvl === k + 1;
        const from = k === 0 ? 0 : UPGRADE.xpII;
        const to = k === 0 ? UPGRADE.xpII : UPGRADE.xpIII;
        const pct = next ? Phaser.Math.Clamp((xp - from) / (to - from), 0, 1) : 0;
        drawRomb(g, rx, y + GR.rombY, GR.rombW, GR.rombH, reached, pct, INT.hud, INT.hudDim);
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

  /** Odds-burken: 25 pärlor i raritetsfärger, vanlig längst ner, mytisk överst (UI.md §13.4). */
  private buildJar(owned: readonly string[]): void {
    const J = AB.jar;
    const g = this.add.graphics();
    const left = J.x - J.w / 2;
    const top = J.y - J.h / 2;
    g.fillStyle(INT.jarGlass, 0.55);
    g.fillRoundedRect(left, top, J.w, J.h, 14);
    g.lineStyle(3, INT.jarEdge, 1);
    g.strokeRoundedRect(left, top, J.w, J.h, 14);
    g.fillStyle(INT.jarEdge, 1);
    g.fillRoundedRect(left - 4, top - J.lidH, J.w + 8, J.lidH, 4);
    this.friendsTop.add(g);
    const remaining = {} as Record<Rarity, number>;
    for (const r of RARITY.order) remaining[r] = AVATARS.filter((a) => a.rarity === r && !owned.includes(a.id)).length;
    const counts = oddsPearls(remaining, J.rows.reduce((a, b) => a + b, 0));
    const seq: Rarity[] = [];
    for (const r of RARITY.order) for (let i = 0; i < counts[r]; i++) seq.push(r);
    if (seq.length === 0) {
      this.friendsTop.add(this.add.image(J.x, J.bottomY - 8, avatarIconKey('shellOpen')).setScale(40 / 128));
      return;
    }
    let k = 0;
    J.rows.forEach((n, row) => {
      for (let i = 0; i < n && k < seq.length; i++, k++) {
        const x = J.x + (i - (n - 1) / 2) * J.pitchX;
        drawPearl(g, x, J.bottomY - row * J.pitchY, J.pearlR, seq[k]);
      }
    });
  }

  /** Scenen: vald kompis 80 px som håller en nivå 2-glimt, glöd i raritetsfärg bakom. */
  private buildStage(): void {
    const def = avatarById(cached().avatars.equipped);
    this.stageId = def?.id ?? '';
    if (!def) return;
    const glow = this.add.image(ST.x, ST.gripY - gripToCenter(ST.displayPx), BG_GLOW)
      .setDisplaySize(ST.glowR * 2 * 2, ST.glowR * 2 * 2)
      .setTint(rarityInt(def.rarity))
      .setAlpha(0.25);
    const ball = this.add.image(ST.x, ST.gripY + 14, ballTextureKey(2)).setScale(scaleForBodyRadius(2, ST.objR));
    this.friendsTop.add([glow, ball]);
    this.setStageFigure(def, false);
  }

  private setStageFigure(def: AvatarDef, animate: boolean): void {
    const lvl = cached().avatars.level[def.id] ?? 1;
    const old = this.stageImg;
    if (old) {
      this.stageRig?.destroy();
      this.tweens.add({ targets: old, y: old.y + 40, alpha: 0, duration: 160, ease: 'Quad.easeIn', onComplete: () => old.destroy() });
    }
    const img = this.add
      .image(ST.x, ST.gripY, bakeAvatar(this, def.id, ST.displayPx, false, 'full', lvl - 1))
      .setOrigin(0.5, AVATAR_TEX_ORIGIN_Y);
    this.friendsTop.add(img);
    const rig = new AvatarRig(this, def, ST.displayPx, cached().settings.calm);
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
    const k = ST.displayPx / 56;
    this.time.delayedCall(sc.fxAtMs, () =>
      playFxCue(this, sc.fx, ST.x, ST.gripY - gripToCenter(ST.displayPx), k, 7, cached().settings.calm),
    );
  }

  /** Varje frame: scenens pose och scrollens tröghet. Inga allokeringar. */
  private tick(): void {
    if (this.stageImg && this.stageRig) this.stageRig.apply(this.stageImg, ST.x, ST.gripY);
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
    const S = ST.hit;
    if (x >= S.x && x <= S.x + S.w && y >= S.y && y <= S.y + S.h) {
      this.playStageShowcase();
      return;
    }
    if (y < GR.top || y > GR.bottom) return;
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
      this.setStageFigure(def, true);
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

    bakeSet(this, set.id);
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
    const img = this.add
      .image(x, y, have ? ballTextureKey(level, set.id) : silhouetteTextureKey(level, set.id))
      .setScale(scaleForBodyRadius(level, r));
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
