import Phaser from 'phaser';
import { BUTTON_SOUND, START_COLORS, START_FONT, START_ICON_KEYS, START_UI, type SettingKey } from '../data/startUi';
import { hexToInt } from '../data/theme';
import { str, type Locale } from '../systems/i18n';
import { cached, save } from '../systems/save';
import { playTone, setCalm, setSoundEnabled, unlockAudio } from '../systems/audio';
import { setHapticsEnabled, vibrate } from '../systems/haptics';
import { iconTextureKey, type IconKey } from './icons';
import { UiButton } from './button';

const S = START_UI.settings;
const R = S.rows;
const SW = S.switch;
const C = START_COLORS;
const W = 360;
const H = 640;
/** SVG-ikonerna rastreras i 128 px (2×). */
const ICON_PX = 128;
/** Svep nedåt på arket som stänger det (logiska px). */
const SWIPE_CLOSE_PX = 48;

const ICONS: Record<SettingKey, [on: IconKey, off: IconKey]> = {
  sound: ['soundOn', 'soundOff'],
  haptics: ['hapticOn', 'hapticOff'],
  calm: ['calmOn', 'calmOff'],
  aimLine: ['aimOn', 'aimOff'],
};

interface Row {
  key: SettingKey;
  y: number;
  icon: Phaser.GameObjects.Image;
  track: Phaser.GameObjects.Graphics;
  knob: Phaser.GameObjects.Arc;
  check: Phaser.GameObjects.Image;
}

/** Värdet och vad en ändring gör (sparas som förut: `save({ settings })`). */
function apply(key: SettingKey, v: boolean): void {
  const s = cached().settings;
  s[key] = v;
  if (key === 'sound') {
    setSoundEnabled(v);
    if (v) unlockAudio();
  } else if (key === 'haptics') setHapticsEnabled(v);
  else if (key === 'calm') setCalm(v);
  void save({ settings: { [key]: v } });
}

/**
 * Inställningsarket (UI.md §16.7): bottenark med fyra strömbrytare. Stängs med X, tryck på scrimmen,
 * svep nedåt på arket och bakåt. Scenen skickar input hit medan arket finns.
 */
export class SettingsSheet {
  private readonly scrim: Phaser.GameObjects.Rectangle;
  private readonly box: Phaser.GameObjects.Container;
  private readonly close: UiButton;
  private readonly rows: Row[] = [];
  private downAt: { x: number; y: number; row: Row | null; close: boolean } | null = null;
  private closing = false;

  constructor(private readonly scene: Phaser.Scene, locale: Locale, private readonly onClosed: () => void, depth = 40) {
    const s = scene;
    this.scrim = s.add.rectangle(W / 2, H / 2, W, H, hexToInt(C.scrim), S.scrimAlpha).setDepth(depth).setAlpha(0);
    s.tweens.add({ targets: this.scrim, alpha: 1, duration: S.inMs });

    const g = s.add.graphics();
    g.fillStyle(hexToInt(C.sheet), 1);
    g.fillRoundedRect(0, S.top, W, H - S.top + S.radius, { tl: S.radius, tr: S.radius, bl: 0, br: 0 });
    g.lineStyle(S.edgeW, hexToInt(C.sheetEdge), 1);
    g.strokeRoundedRect(S.edgeW / 2, S.top + S.edgeW / 2, W - S.edgeW, H - S.top + S.radius, { tl: S.radius, tr: S.radius, bl: 0, br: 0 });
    g.fillStyle(hexToInt(C.sheetHandle), 1);
    g.fillRoundedRect(W / 2 - S.handle.w / 2, S.handle.y - S.handle.h / 2, S.handle.w, S.handle.h, S.handle.h / 2);
    const hd = S.header;
    const gear = s.add.image(hd.gearX, hd.y, START_ICON_KEYS.gearDim).setScale(hd.gearPx / ICON_PX);
    const cl = hd.close;
    this.close = new UiButton(s, 'round', cl.x, hd.y, cl.d, cl.d, cl.hit, cl.hit, () => this.hide());
    this.close.body.add(s.add.image(0, 0, iconTextureKey('close')).setScale(cl.iconPx / ICON_PX));
    this.box = s.add.container(0, H - S.top, [g, gear, this.close.root]).setDepth(depth + 1);

    const font = START_FONT.family;
    const IB = R.iconBox;
    R.order.forEach((key, i) => {
      const y = R.y0 + i * R.pitch;
      g.fillStyle(hexToInt(C.sheetIconBox), 1);
      g.fillRoundedRect(IB.x - IB.size / 2, y - IB.size / 2, IB.size, IB.size, IB.r);
      g.lineStyle(1, hexToInt(C.sheetIconBoxEdge), 1);
      g.strokeRoundedRect(IB.x - IB.size / 2, y - IB.size / 2, IB.size, IB.size, IB.r);
      if (i < R.order.length - 1) {
        g.fillStyle(hexToInt(R.divider.color), 1);
        g.fillRect(R.divider.x0, y + R.pitch / 2, R.divider.x1 - R.divider.x0, R.divider.w);
      }
      const icon = s.add.image(IB.x, y, iconTextureKey(ICONS[key][0])).setScale(IB.iconPx / ICON_PX);
      const label = s.add
        .text(R.labelX, y + R.labelDy, str(key, locale), { fontFamily: font, fontSize: `${R.labelPx}px`, fontStyle: R.labelWeight, color: C.hud })
        .setOrigin(0, 0.5);
      const help = s.add
        .text(R.labelX, y + R.helpDy, str(`${key}Help`, locale), { fontFamily: font, fontSize: `${R.helpPx}px`, fontStyle: R.helpWeight, color: C.hudDim })
        .setOrigin(0, 0.5);
      const track = s.add.graphics();
      const knob = s.add.circle(SW.cx, y, SW.knobR, 0);
      const check = s.add.image(SW.cx, y, START_ICON_KEYS.switchCheck).setScale(SW.checkPx / ICON_PX);
      this.box.add([icon, label, help, track, knob, check]);
      const row: Row = { key, y, icon, track, knob, check };
      this.rows.push(row);
      this.drawSwitch(row, cached().settings[key], false);
    });

    s.tweens.add({ targets: this.box, y: 0, duration: S.inMs, ease: S.inEase });
    playTone(BUTTON_SOUND.sheetOpen);
  }

  /** Strömbrytaren: PÅ = cyan spår, mörk knopp till höger med bock. AV = mörkt spår, hudDim-kant och knopp till vänster. */
  private drawSwitch(r: Row, on: boolean, animate: boolean): void {
    const t = r.track;
    const x = SW.cx - SW.w / 2;
    const y = r.y - SW.h / 2;
    t.clear();
    t.fillStyle(hexToInt(on ? C.switchOnTrack : C.switchOffTrack), 1);
    t.fillRoundedRect(x, y, SW.w, SW.h, SW.h / 2);
    if (!on) {
      t.lineStyle(SW.edgeW, hexToInt(C.switchOffEdge), 1);
      t.strokeRoundedRect(x + SW.edgeW / 2, y + SW.edgeW / 2, SW.w - SW.edgeW, SW.h - SW.edgeW, (SW.h - SW.edgeW) / 2);
    }
    r.knob.setFillStyle(hexToInt(on ? C.switchOnKnob : C.switchOffKnob), 1);
    const kx = SW.cx + (on ? 1 : -1) * (SW.w / 2 - SW.h / 2);
    r.icon.setTexture(iconTextureKey(ICONS[r.key][on ? 0 : 1]));
    this.scene.tweens.killTweensOf([r.knob, r.check]);
    if (!animate) {
      r.knob.x = kx;
      r.check.setPosition(kx, r.y).setAlpha(on ? 1 : 0);
      return;
    }
    this.scene.tweens.add({ targets: [r.knob, r.check], x: kx, duration: SW.ms, ease: SW.ease });
    this.scene.tweens.add({ targets: r.check, alpha: on ? 1 : 0, duration: SW.ms });
  }

  private rowAt(x: number, y: number): Row | null {
    if (x < R.x0 || x > R.x1) return null;
    return this.rows.find((r) => Math.abs(y - r.y) <= R.pitch / 2) ?? null;
  }

  down(x: number, y: number): void {
    if (this.closing) return;
    const close = this.close.contains(x, y);
    if (close) this.close.press();
    this.downAt = { x, y, row: close ? null : this.rowAt(x, y), close };
  }

  move(x: number, y: number): void {
    const d = this.downAt;
    if (d?.close && !this.close.contains(x, y)) {
      this.close.release(false);
      d.close = false;
    }
  }

  up(x: number, y: number): void {
    const d = this.downAt;
    this.downAt = null;
    if (!d || this.closing) return;
    if (d.close) {
      this.close.release(this.close.contains(x, y));
      return;
    }
    // Svep nedåt var som helst på arket stänger; tryck ovanför arket (scrimmen) stänger.
    if (y - d.y >= SWIPE_CLOSE_PX && d.y >= S.top) return this.hide();
    if (d.y < S.top && y < S.top) return this.hide();
    const row = this.rowAt(x, y);
    if (!row || row !== d.row) return;
    const on = !cached().settings[row.key];
    apply(row.key, on);
    this.drawSwitch(row, on, true);
    playTone(on ? BUTTON_SOUND.switchOn : BUTTON_SOUND.switchOff);
    vibrate(10);
  }

  /** Stänger (X, scrim, svep, bakåt). */
  hide(): void {
    if (this.closing) return;
    this.closing = true;
    playTone(BUTTON_SOUND.sheetClose);
    this.scene.tweens.add({ targets: this.scrim, alpha: 0, duration: S.outMs });
    this.scene.tweens.add({
      targets: this.box,
      y: H - S.top,
      duration: S.outMs,
      ease: S.outEase,
      onComplete: () => {
        this.scrim.destroy();
        this.box.destroy();
        this.onClosed();
      },
    });
  }
}
