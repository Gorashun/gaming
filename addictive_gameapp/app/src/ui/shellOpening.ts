import Phaser from 'phaser';
import { INT, THEME } from '../data/theme';
import { themeSetById } from '../data/themes';
import { AVATAR_SOUND, AVATAR_UI, RARITY, avatarById, type AvatarDef } from '../data/avatarsIndex';
import type { ShellType } from '../data/economy';
import type { BoxResult } from '../systems/boxes';
import { Juice } from '../systems/juice';
import { cached } from '../systems/save';
import { playSound, playTone } from '../systems/audio';
import { vibrate } from '../systems/haptics';
import { BG_GLOW, FX_RING, FX_RING_R } from './textures';
import { avatarIconKey, shellHalfKey } from './icons';
import { addAvatarImage, avatarParticleKey, bakeAvatarParticles, drawPearlRow, drawRomb, gripToCenter, rarityInt } from './avatarArt';
import { AvatarRig } from './avatarRig';
import { playFxCue } from './avatarFx';

const L = THEME.layout;
const OP = AVATAR_UI.open;
/** SVG-ikonerna rastreras i 128 px (2×). */
const ICON_PX = 128;

export interface OpeningOpts {
  /** Musslans startplats och storlek (hyllan eller butikens plats). */
  from: { x: number; y: number; px: number };
  type?: ShellType;
  /** Figuren flyger hit när ceremonin stängs. */
  closeTo: { x: number; y: number };
  onClosed: () => void;
}

/**
 * Musslans öppning (UI.md §13.3), fast 1 200 ms. Musslan ser likadan ut och låter likadant fram
 * till att figuren syns; först där skiljer sig rariteterna i antal kanaler. Delas av startskärmen
 * (hyllan) och boken (butiken, UI.md §14.4).
 */
export class ShellOpening {
  /** 'play' före 1 200 ms (tryck = hoppa över), 'done' efter (tryck = stäng). */
  phase: 'play' | 'done' = 'play';
  private objs: Phaser.GameObjects.GameObject[] = [];
  private timers: Phaser.Time.TimerEvent[] = [];
  private final: () => void = () => undefined;
  private figure!: Phaser.GameObjects.Image;
  private update: () => void = () => undefined;
  private closed = false;

  constructor(private readonly scene: Phaser.Scene, res: BoxResult, private readonly opts: OpeningOpts, depth = 25) {
    this.play(res, depth);
  }

  /** Ett tryck: hoppa över (före 1 200) eller stäng. */
  tap(): void {
    if (this.phase === 'play') this.final();
    else this.close();
  }

  private op<T extends Phaser.GameObjects.GameObject>(o: T): T {
    this.objs.push(o);
    return o;
  }

  private at(ms: number, fn: () => void): void {
    this.timers.push(this.scene.time.delayedCall(ms, fn));
  }

  private play(res: BoxResult, depth: number): void {
    const s = this.scene;
    const def = avatarById(res.avatarId)!;
    const r = res.rarity;
    const settings = cached().settings;
    const calm = settings.calm;
    const C = OP.center;
    const F = OP.figure;
    const from = this.opts.from;
    const type = this.opts.type ?? 'common';
    const scale0 = from.px / ICON_PX;
    const scale1 = (AVATAR_UI.shelf.box.size / ICON_PX) * OP.fly.toScale;
    bakeAvatarParticles(s);

    const scrim = this.op(s.add.rectangle(L.width / 2, L.height / 2, L.width, L.height, INT.scrim, 1).setDepth(depth).setAlpha(0));
    s.tweens.add({ targets: scrim, alpha: OP.scrim.alpha, duration: OP.scrim.inMs });

    // Strålar (legendarisk/mytisk) och glöd bakom figuren.
    const nRays = calm ? 0 : r === 'legendary' ? OP.rays.legendary : r === 'mythic' ? OP.rays.mythic : 0;
    const rays = this.op(s.add.graphics().setPosition(C.x, F.toY).setDepth(depth + 1).setAlpha(0));
    for (let i = 0; i < nRays; i++) {
      const a = (i / nRays) * Math.PI * 2;
      const w = Math.PI / nRays / 2;
      rays.fillStyle(rarityInt(r, i), OP.rays.alpha);
      rays.fillTriangle(
        Math.cos(a - w) * OP.rays.innerR, Math.sin(a - w) * OP.rays.innerR,
        Math.cos(a) * OP.rays.outerR, Math.sin(a) * OP.rays.outerR,
        Math.cos(a + w) * OP.rays.innerR, Math.sin(a + w) * OP.rays.innerR,
      );
    }
    if (nRays > 0) s.tweens.add({ targets: rays, angle: 360, duration: (360 / OP.rays.degPerSec) * 1000, repeat: -1 });
    const glow = this.op(s.add.image(C.x, F.toY, BG_GLOW).setTint(rarityInt(r)).setDepth(depth + 1).setAlpha(0).setScale(0));
    const glowScale = (OP.glow.r * 2) / 256;

    // Musslan: undre halvan + övre halvan med origin i gångjärnet (y 38/64). Färgen följer typen.
    const bottom = s.add.image(0, 0, shellHalfKey(type, 'bottom'));
    const top = s.add.image(0, (38 / 64 - 0.5) * ICON_PX, shellHalfKey(type, 'top')).setOrigin(0.5, 38 / 64);
    const shell = this.op(s.add.container(from.x, from.y, [bottom, top]).setDepth(depth + 2).setScale(scale0));
    const path = { t: 0 };
    s.tweens.add({
      targets: path,
      t: 1,
      duration: OP.fly.ms,
      ease: OP.fly.ease,
      onUpdate: () => {
        const t = path.t;
        const u = 1 - t;
        shell.x = u * u * from.x + 2 * u * t * OP.fly.ctrlX + t * t * C.x;
        shell.y = u * u * from.y + 2 * u * t * OP.fly.ctrlY + t * t * C.y;
        shell.setScale(scale0 + (scale1 - scale0) * t);
      },
    });
    const wd = OP.fly.wobbleDeg;
    s.tweens.chain({
      targets: shell,
      tweens: [
        { angle: wd, duration: OP.fly.ms / 3 },
        { angle: -wd, duration: OP.fly.ms / 3 },
        { angle: 0, duration: OP.fly.ms / 3 },
      ],
    });
    playTone(AVATAR_SOUND.shellOpen);
    playSound('ui');

    // Figur, pärlor och romber (skapas nu, visas vid 320 ms).
    const px = F.displayPx;
    const g2c = gripToCenter(px);
    const fig = this.op(addAvatarImage(s, C.x, F.fromY + g2c, def.id, px).setDepth(depth + 3).setScale(0));
    this.figure = fig;
    const rig = new AvatarRig(s, def, px, calm);
    const figPos: { y: number; s: number } = { y: F.fromY, s: 0 };
    const applyFig = (): void => {
      rig.base = figPos.s;
      rig.apply(fig, C.x, figPos.y + g2c);
    };
    s.events.on(Phaser.Scenes.Events.UPDATE, applyFig);
    this.update = applyFig;
    const pearls = this.op(s.add.graphics().setPosition(C.x, OP.pearls.y).setDepth(depth + 3).setScale(0));
    drawPearlRow(pearls, 0, 0, RARITY.pearls[r], OP.pearls.r, OP.pearls.pitch, r);
    const rombs = this.op(s.add.graphics().setDepth(depth + 3).setAlpha(0));
    const RB = OP.rombs;
    drawRomb(rombs, C.x - RB.pitch / 2, RB.y, RB.w, RB.h, false, 0, INT.hud, INT.hudDim);
    drawRomb(rombs, C.x + RB.pitch / 2, RB.y, RB.w, RB.h, false, 0, INT.hud, INT.hudDim);

    this.at(OP.shellOpenAt, () => {
      let swapped = false;
      s.tweens.add({
        targets: top,
        scaleY: OP.shellOpen.toScaleY,
        duration: OP.shellOpen.ms,
        ease: OP.shellOpen.ease,
        onUpdate: () => {
          if (!swapped && top.scaleY <= OP.shellOpen.swapAtScaleY) {
            swapped = true;
            top.setTexture(avatarIconKey('shellTopInside'));
          }
        },
      });
    });
    this.at(OP.glowAt, () => {
      s.tweens.add({ targets: glow, scale: glowScale, alpha: OP.glow.alpha, duration: OP.glow.ms, ease: OP.glow.ease });
      if (nRays > 0) s.tweens.add({ targets: rays, alpha: 1, duration: OP.glow.ms });
    });
    this.at(OP.figureAt, () => {
      s.tweens.add({ targets: figPos, y: F.toY, duration: F.ms, ease: F.ease });
      figPos.s = F.fromScale;
      s.tweens.add({ targets: figPos, s: 1, duration: F.ms, ease: F.ease, easeParams: [F.overshoot] });
      s.tweens.add({ targets: pearls, scale: 1, duration: OP.pearls.ms, ease: OP.pearls.ease });
      s.tweens.add({ targets: rombs, alpha: 1, duration: OP.pearls.ms });
      // Ringar i raritetsfärg + partiklar i figurens form (jackpot utan shake/zoom/hit-stop).
      const nRings = calm ? Math.min(1, OP.rings[r]) : OP.rings[r];
      const RG = OP.ring;
      for (let i = 0; i < nRings; i++) {
        const ring = this.op(s.add.image(C.x, F.toY, FX_RING).setTint(rarityInt(r, i * 2)).setDepth(depth + 2).setAlpha(0));
        ring.setScale(RG.fromR / FX_RING_R);
        s.tweens.add({ targets: ring, scale: RG.toR / FX_RING_R, alpha: { from: RG.alpha, to: 0 }, delay: i * RG.stepMs, duration: RG.ms, ease: RG.ease });
      }
      const juice = new Juice(s, C.x, F.toY, { ...settings }, themeSetById(cached().activeSet).particle);
      const c = def.cosmetic;
      juice.setAvatarParticles({
        texture: c.particleShape ? avatarParticleKey(c.particleShape) : null,
        tint: c.particleTint && c.particleTint !== 'level' && c.particleTint !== 'combo' ? c.particleTint : RARITY.color[r],
        countMul: 1,
      });
      juice.trigger('jackpot', RARITY.juice[r], C.x, F.toY, { overlay: true, avatarParticles: true, noTint: true, ring: { count: 0, maxR: 0, durationMs: 0, stepMs: 0, color: RARITY.color[r], alpha: 0 } });
      playTone(AVATAR_SOUND.reveal[r]);
      vibrate(calm ? 10 : OP.haptic[r]);
    });
    // Showcase en gång, tidsskalad så att den är klar vid 1 200 ms.
    const len = AvatarRig.lengthMs(def.showcase.anim);
    const ts = Math.min(1, (OP.doneAt - OP.showcaseAt) / Math.max(1, len));
    this.at(OP.showcaseAt, () => this.showcase(def, rig, ts, C.x, F.toY, px / 56, depth + 4, calm));
    this.at(OP.doneAt, () => {
      this.phase = 'done';
    });

    // Slutläget (hoppa över): allt på plats, ingen showcase.
    this.final = (): void => {
      for (const t of this.timers) t.remove(false);
      this.timers.length = 0;
      s.tweens.killTweensOf([scrim, glow, shell, top, pearls, rombs, figPos, path, rig.st]);
      rig.stop();
      rig.st.dx = 0;
      rig.st.dy = 0;
      rig.st.sx = 1;
      rig.st.sy = 1;
      rig.st.rot = 0;
      scrim.setAlpha(OP.scrim.alpha);
      glow.setScale(glowScale).setAlpha(OP.glow.alpha);
      rays.setAlpha(1);
      shell.setPosition(C.x, C.y).setScale(scale1).setAngle(0);
      top.setScale(1, OP.shellOpen.toScaleY).setTexture(avatarIconKey('shellTopInside'));
      figPos.y = F.toY;
      figPos.s = 1;
      pearls.setScale(1);
      rombs.setAlpha(1);
      this.phase = 'done';
    };
  }

  /** Figurens showcase: recept + effekt vid fxAtMs + ljud. */
  private showcase(def: AvatarDef, rig: AvatarRig, ts: number, x: number, cy: number, k: number, depth: number, calm: boolean): void {
    const sc = def.showcase;
    rig.play(sc.anim, 3, ts, () => undefined);
    playTone(sc.sound);
    this.at(sc.fxAtMs * ts, () => playFxCue(this.scene, sc.fx, x, cy, k, depth, calm));
  }

  /** Tryck efter 1 200 ms: figuren krymper och flyger till målet, scrimmen tonas ut. */
  private close(): void {
    if (this.closed) return;
    this.closed = true;
    const s = this.scene;
    const C = OP.close;
    const fig = this.figure;
    playTone(AVATAR_SOUND.equip);
    for (const o of this.objs) if (o !== fig) s.tweens.add({ targets: o, alpha: 0, duration: C.scrimOutMs });
    s.events.off(Phaser.Scenes.Events.UPDATE, this.update);
    s.tweens.add({ targets: fig, x: this.opts.closeTo.x, y: this.opts.closeTo.y, scale: 0.3, duration: C.ms, ease: C.ease });
    s.time.delayedCall(C.ms, this.opts.onClosed);
  }
}
