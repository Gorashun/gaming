import Phaser from 'phaser';
import { BUTTON_SOUND, BUTTON_STYLE, START_COLORS, type ButtonState, type ButtonVariant } from '../data/startUi';
import { hexToInt } from '../data/theme';
import { playTone } from '../systems/audio';
import { vibrate } from '../systems/haptics';
import { buttonBakeInfo, renderButton } from './buttonArt';
import { texDpr } from './view';

/**
 * Knappkomponenten (UI.md §16.3) i Phaser. Ytan bakas en gång per (variant, läge, storlek, Z) med
 * renderButton till en CanvasTexture; ikon, etikett och badge läggs ovanpå i `body`.
 * Scenen äger input (en väg för alla knappar och för modala lager): press/release anropas därifrån.
 */

/** Bakar en Canvas2D-yta i Z; ramen får den logiska storleken, så scale 1 = logisk storlek. */
export function bakeLogical(scene: Phaser.Scene, key: string, w: number, h: number, draw: (ctx: CanvasRenderingContext2D, dpr: number) => void): string {
  if (scene.textures.exists(key)) return key;
  const dpr = texDpr(scene);
  const pw = Math.ceil(w * dpr);
  const ph = Math.ceil(h * dpr);
  const tex = scene.textures.createCanvas(key, pw, ph);
  if (!tex) return key;
  draw(tex.getContext(), dpr);
  tex.refresh();
  if (dpr !== 1) tex.get().setSize(w, h).setUVs(pw, ph, 0, 0, 1, 1);
  return key;
}

export function buttonFaceKey(scene: Phaser.Scene, variant: ButtonVariant, state: ButtonState, w: number, h: number): string {
  const dpr = texDpr(scene);
  const key = `btn-${variant}-${state}-${w}x${h}@${dpr}`;
  if (scene.textures.exists(key)) return key;
  const info = buttonBakeInfo(variant, w, h, dpr);
  const tex = scene.textures.createCanvas(key, info.pxW, info.pxH);
  if (!tex) return key;
  renderButton(tex.getContext(), variant, state, w, h, dpr);
  tex.refresh();
  if (info.dpr !== 1) tex.get().setSize(w + info.pad * 2, h + info.pad * 2).setUVs(info.pxW, info.pxH, 0, 0, 1, 1);
  return key;
}

export class UiButton {
  /** Ytterlager: position och loopar (puls). */
  readonly root: Phaser.GameObjects.Container;
  /** Innerlager: trycket skalar det här, så att ikon, text och badge följer ytan. */
  readonly body: Phaser.GameObjects.Container;
  private readonly face: Phaser.GameObjects.Image;
  private readonly keys: Record<'normal' | 'pressed', string>;
  private readonly hit: { x0: number; y0: number; x1: number; y1: number };
  private down = false;
  /** Loop som pausas medan knappen hålls ned (SPELA-pulsen). */
  pulse: Phaser.Tweens.Tween | null = null;

  constructor(
    private readonly scene: Phaser.Scene,
    readonly variant: ButtonVariant,
    cx: number,
    cy: number,
    w: number,
    h: number,
    hitW: number,
    hitH: number,
    readonly onTap: () => void,
    base: 'normal' | 'badge' = 'normal',
  ) {
    this.keys = { normal: buttonFaceKey(scene, variant, base, w, h), pressed: buttonFaceKey(scene, variant, 'pressed', w, h) };
    this.face = scene.add.image(0, 0, this.keys.normal);
    this.body = scene.add.container(0, 0, [this.face]);
    this.root = scene.add.container(cx, cy, [this.body]);
    this.hit = { x0: cx - hitW / 2, y0: cy - hitH / 2, x1: cx + hitW / 2, y1: cy + hitH / 2 };
  }

  contains(x: number, y: number): boolean {
    const r = this.hit;
    return x >= r.x0 && x <= r.x1 && y >= r.y0 && y <= r.y1;
  }

  /** Visuellt tryckläge utan ljud (handen i onboardingen). */
  showPressed(on: boolean): void {
    const P = BUTTON_STYLE[this.variant].press;
    this.scene.tweens.killTweensOf(this.body);
    this.face.setTexture(on ? this.keys.pressed : this.keys.normal);
    this.scene.tweens.add({
      targets: this.body,
      scale: on ? P.scale : 1,
      duration: on ? P.inMs : P.outMs,
      ease: on ? P.inEase : P.outEase,
    });
  }

  /** Fingret ned i träffytan: tryckläge + tock. */
  press(): void {
    this.down = true;
    this.pulse?.pause();
    this.showPressed(true);
    playTone(BUTTON_SOUND[BUTTON_STYLE[this.variant].sound.press]);
  }

  /** Fingret upp. `fire` = släppt i träffytan: ljud, haptik och handling. Annars tyst. */
  release(fire: boolean): void {
    if (!this.down) return;
    this.down = false;
    this.showPressed(false);
    this.pulse?.resume();
    if (!fire) return;
    const S = BUTTON_STYLE[this.variant];
    playTone(BUTTON_SOUND[S.sound.confirm]);
    vibrate(S.hapticMs.confirm);
    this.onTap();
  }

  /** Guldprick uppe till höger (poppar in, pulsar inte). */
  addBadge(w: number, h: number): Phaser.GameObjects.Graphics {
    const B = BUTTON_STYLE[this.variant].badge;
    const g = this.scene.add.graphics();
    g.fillStyle(hexToInt(START_COLORS.badgeRing), 1);
    g.fillCircle(0, 0, B.d / 2 + B.ring);
    g.fillStyle(hexToInt(START_COLORS.badge), 1);
    g.fillCircle(0, 0, B.d / 2);
    g.fillStyle(0xfff3c4, 0.7);
    g.fillCircle(-B.d * 0.12, -B.d * 0.15, B.d * 0.18);
    g.setPosition(w / 2 - B.dx, -h / 2 + B.dy).setScale(0);
    this.body.add(g);
    this.scene.tweens.add({ targets: g, scale: 1, duration: B.popMs, ease: B.popEase });
    return g;
  }
}
