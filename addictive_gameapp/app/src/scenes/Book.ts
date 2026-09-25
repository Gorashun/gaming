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
import { filledSlots, slotIndex } from '../systems/collection';
import { nextSetProgress } from '../systems/unlocks';
import { playSound, playTimbre, playTone } from '../systems/audio';
import { vibrate } from '../systems/haptics';
import { AVATARS, RARITY, type AvatarDef } from '../data/avatarsIndex';
import { BOX_FX } from '../data/boxes';
import { equip } from '../systems/avatars';
import { currentOdds, pearlCounts } from '../systems/boxes';
import { addAvatarBadge, drawPearls } from '../ui/avatarBadge';

const W = THEME.layout.width;
const BK = META.book;
const SW = BK.swipe;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');
/** Setikonens markering (UI.md §12.4). */
const MARK = { ringW: 4, dash: 6, badgeDx: 27, badgeDy: -27, badgeR: 10, selectMs: 240, badgeMs: 200, arpMs: 90 };
/** Låst sida: skaka ±6 px två gånger på 240 ms, stapeln pulsar 1,1 på 300 ms. */
const LOCKED_FB = { px: 6, ms: 240, barScale: 1.1, barMs: 300 };
/** "Nytt sedan sist" nollställs när sidan har synts så här länge. */
const SEEN_MS = 2000;
const FR = BOX_FX.friends;

type Tab = 'sets' | 'friends';

interface FriendCell {
  def: AvatarDef;
  x: number;
  y: number;
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
  private friendSel!: Phaser.GameObjects.Graphics;
  private cells: FriendCell[] = [];
  private scroll = 0;
  private maxScroll = 0;
  private downScroll = 0;

  constructor() {
    super('Book');
  }

  create(): void {
    const d = cached();
    drawBackground(this, undefined, { still: true });
    this.locked = THEME_SETS.map((s) => !d.unlockedSets.includes(s.id));
    this.marks = [];
    this.badges = [];
    this.pulses = THEME_SETS.map(() => []);
    this.seenTimer = null;
    this.down = null;
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
    this.band = this.add.rectangle(W / 2, FR.headerH / 2, W, FR.headerH, INT.bg, 1).setDepth(9);
    this.tabIcons = this.add.graphics().setDepth(10);
    this.selectTab('sets');

    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      this.down = { x: p.worldX, y: p.worldY, t: this.time.now };
      this.downScroll = this.scroll;
      if (this.tab === 'sets') this.tweens.killTweensOf(this.strip);
    });
    this.input.on('pointermove', (p: Phaser.Input.Pointer) => this.onMove(p));
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => this.onUp(p));
    this.onPageShown();

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
      cellOf(id: string): { x: number; y: number } | null {
        const c = self.cells.find((k) => k.def.id === id);
        return c ? { x: c.x, y: c.y - self.scroll } : null;
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
      this.setScroll(this.downScroll - (p.worldY - this.down.y));
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
      if (tab !== this.tab) playSound('ui');
      this.selectTab(tab);
      return;
    }
    if (this.tab === 'friends') {
      if (!tap) return;
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

  private tabAt(x: number, y: number): Tab | null {
    const T = FR.tabs;
    if (Math.abs(y - T.y) > T.hit / 2) return null;
    if (Math.abs(x - T.xSet) <= T.hit / 2) return 'sets';
    if (Math.abs(x - T.xFriends) <= T.hit / 2) return 'friends';
    return null;
  }

  private selectTab(t: Tab): void {
    this.tab = t;
    const sets = t === 'sets';
    this.strip.setVisible(sets);
    this.dots.setVisible(sets);
    this.bar?.setVisible(sets);
    this.friends.setVisible(!sets);
    this.band.setVisible(!sets);
    this.drawTabs();
  }

  /** Två ikoner utan text: bok (set) och ansikte (kompisar). Aktiv: full färg + streck under. */
  private drawTabs(): void {
    const T = FR.tabs;
    const g = this.tabIcons;
    const s = T.icon / 2;
    g.clear();
    const on = (t: Tab): number => (this.tab === t ? 1 : 0.45);
    // Bok: två sidor och en rygg.
    g.lineStyle(3, INT.accent, on('sets'));
    g.strokeRoundedRect(T.xSet - s, T.y - s * 0.75, s, s * 1.5, 3);
    g.strokeRoundedRect(T.xSet, T.y - s * 0.75, s, s * 1.5, 3);
    // Kompis: huvud med ögon och leende.
    g.lineStyle(3, INT.accent, on('friends'));
    g.strokeCircle(T.xFriends, T.y, s * 0.85);
    g.fillStyle(INT.accent, on('friends'));
    g.fillCircle(T.xFriends - s * 0.3, T.y - s * 0.15, 2.5);
    g.fillCircle(T.xFriends + s * 0.3, T.y - s * 0.15, 2.5);
    g.beginPath();
    g.arc(T.xFriends, T.y + s * 0.05, s * 0.4, 0.3, Math.PI - 0.3, false);
    g.strokePath();
    g.fillStyle(INT.accent, 1);
    g.fillRoundedRect((this.tab === 'sets' ? T.xSet : T.xFriends) - s, T.y + s + 6, s * 2, 3, 1.5);
  }

  // ---------------------------------------------------------------- kompisar

  /** Odds-burk + rutnät 6 kolumner per raritet. Byggs en gång; valet ritas om vid equip. */
  private buildFriends(): void {
    const d = cached();
    const av = d.avatars;
    const c = this.add.container(0, 0).setDepth(5);
    this.friends = c;
    this.cells = [];
    this.scroll = 0;

    // Odds-burken: 25 pärlor i raritetsfärger, vanligast längst ner.
    const J = FR.jar;
    const jar = this.add.graphics();
    jar.fillStyle(INT.jarGlass, 0.6);
    jar.fillRoundedRect(J.x - J.w / 2, J.y - J.h / 2, J.w, J.h, 16);
    jar.lineStyle(3, INT.jarEdge, 1);
    jar.strokeRoundedRect(J.x - J.w / 2, J.y - J.h / 2, J.w, J.h, 16);
    jar.lineBetween(J.x - J.w / 2 - 4, J.y - J.h / 2 - 6, J.x + J.w / 2 + 4, J.y - J.h / 2 - 6);
    const counts = pearlCounts(currentOdds(av.owned), J.pearls);
    let k = 0;
    for (const r of RARITY.order) {
      jar.fillStyle(hexToInt(RARITY.color[r]), 1);
      for (let i = 0; i < counts[r]; i++, k++) {
        const col = k % J.cols;
        const row = Math.floor(k / J.cols);
        jar.fillCircle(J.x + (col - (J.cols - 1) / 2) * J.pitch, J.y + J.h / 2 - 16 - row * J.pitch, J.pearlR);
      }
    }
    c.add(jar);

    const pitch = FR.cell + FR.gap;
    const left = (W - (FR.cols * FR.cell + (FR.cols - 1) * FR.gap)) / 2 + FR.cell / 2;
    const g = this.add.graphics();
    c.add(g);
    let y = FR.gridTop;
    for (const r of RARITY.order) {
      const list = AVATARS.filter((a) => a.rarity === r);
      const color = hexToInt(RARITY.color[r]);
      g.lineStyle(2, color, 0.6);
      g.lineBetween(left - FR.cell / 2, y, W - left + FR.cell / 2, y);
      y += FR.gap;
      list.forEach((def, i) => {
        const x = left + (i % FR.cols) * pitch;
        const cy = y + Math.floor(i / FR.cols) * pitch + FR.cell / 2;
        this.cells.push({ def, x, y: cy });
        const ay = cy - 5;
        if (!av.owned.includes(def.id)) {
          g.fillStyle(INT.hudDim, FR.silhouetteAlpha);
          g.fillCircle(x, ay, FR.avatarR);
          return;
        }
        c.add(addAvatarBadge(this, x, ay, FR.avatarR, def));
        g.lineStyle(FR.ringW, color, 1);
        g.strokeCircle(x, ay, FR.avatarR + FR.ringW);
        drawPearls(g, x, cy + FR.avatarR + 2, av.level[def.id] ?? 1, 3, FR.levelPearlR, FR.levelPearlPitch, color);
      });
      y += Math.ceil(list.length / FR.cols) * pitch + FR.groupGap;
    }
    this.friendSel = this.add.graphics();
    c.add(this.friendSel);
    this.drawFriendSel();
    this.maxScroll = Math.max(0, y + FR.bottomPad - THEME.layout.height);
  }

  /** Vald avatar: accent-ring utanför raritetsringen. */
  private drawFriendSel(): void {
    const g = this.friendSel;
    g.clear();
    const cell = this.cells.find((k) => k.def.id === cached().avatars.equipped);
    if (!cell) return;
    g.lineStyle(3, INT.accent, 1);
    g.strokeRoundedRect(cell.x - FR.cell / 2, cell.y - FR.cell / 2, FR.cell, FR.cell + 4, 10);
  }

  private setScroll(v: number): void {
    this.scroll = Phaser.Math.Clamp(v, 0, this.maxScroll);
    this.friends.y = -this.scroll;
  }

  private tapFriend(x: number, y: number): void {
    const half = FR.cell / 2 + FR.gap / 2;
    const cell = this.cells.find((k) => Math.abs(k.x - x) <= half && Math.abs(k.y - this.scroll - y) <= half);
    if (cell) this.equipFriend(cell.def.id);
  }

  /** Tryck på ägd avatar: vald från nästa runda, sparas direkt. */
  private equipFriend(id: string): boolean {
    const av = cached().avatars;
    if (av.equipped === id) return true;
    if (!equip(av, id)) return false;
    void save();
    this.drawFriendSel();
    playSound('ui');
    vibrate(10);
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
    const d = cached();
    const id = THEME_SETS[i].id;
    const page = d.collection[id];
    const had = d.freshSet === id || (page?.fresh.some(Boolean) ?? false);
    if (!had) return;
    page?.fresh.fill(false);
    for (const p of this.pulses[i]) {
      p.tween.remove();
      p.target.setScale(p.base);
    }
    this.pulses[i].length = 0;
    void save({ freshSet: d.freshSet === id ? null : d.freshSet });
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
