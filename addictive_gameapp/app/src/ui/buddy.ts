import Phaser from 'phaser';
import { hexToInt } from '../data/theme';
import { AVATAR_UI, UPGRADE, avatarById, type AvatarDef, type GestureTrigger, type TrailDef } from '../data/avatarsIndex';
import type { Juice } from '../systems/juice';
import { playTone } from '../systems/audio';
import { avatarOriginY, avatarParticleKey, bakeAvatar, bakeAvatarParticles, gripToTop } from './avatarArt';
import { AvatarRig } from './avatarRig';

const S = AVATAR_UI.slapparen;
const DEG = Math.PI / 180;

/**
 * Släpparen (DESIGN §14.1, UI.md §13.5): kompisen som håller det hängande objektet, plus all
 * kosmetik (spår, partiklar via juice, ljud via audio, gester). Poolat: update() allokerar inget.
 */
export class Buddy {
  readonly def: AvatarDef;
  readonly img: Phaser.GameObjects.Image;
  readonly rig: AvatarRig;
  private readonly scene: Phaser.Scene;
  private readonly pupils: Phaser.GameObjects.Image | null;
  private readonly lookPx: number;
  /** Greppets y (tweenas vid nytt objekt). */
  private readonly grip = { y: 0 };
  private x = 180;
  private prevX = 180;
  private lean = 0;
  private wobbleDeg = 0;
  // spår
  private readonly trail: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private readonly trailTints: number[] = [];
  private readonly trailEvery: number = 0;
  private trailIdx = 0;
  private tracking: Phaser.GameObjects.Image | null = null;
  private lastTX = 0;
  private lastTY = 0;
  private lookX = 180;
  private lookY = 600;

  constructor(scene: Phaser.Scene, id: string, level: 1 | 2 | 3, calm: boolean, juice: Juice) {
    this.scene = scene;
    this.def = avatarById(id)!;
    const c = this.def.cosmetic;
    bakeAvatarParticles(scene);
    const look = c.look;
    const key = bakeAvatar(scene, id, S.displayPx, false, look ? 'body' : 'full', level - 1);
    this.img = scene.add.image(180, 0, key).setOrigin(0.5, avatarOriginY()).setDepth(S.depth);
    this.pupils = look
      ? scene.add.image(180, 0, bakeAvatar(scene, id, S.displayPx, false, 'pupils')).setOrigin(0.5, avatarOriginY()).setDepth(S.depth)
      : null;
    this.lookPx = look ? (look.lookPx * S.displayPx) / 56 : 0;
    this.rig = new AvatarRig(scene, this.def, S.displayPx, calm, S.calmScale);
    this.rig.resumeLoop();

    const lvl = level - 1;
    if (c.particleShape || c.particleTint) {
      juice.setAvatarParticles({
        texture: c.particleShape ? avatarParticleKey(c.particleShape) : null,
        tint: c.particleTint ?? 'level',
        countMul: UPGRADE.cosmeticParticleMul[lvl] * (calm ? S.calmScale : 1),
      });
    }
    const t = c.trail;
    if (t) {
      this.trail = this.makeTrail(t, UPGRADE.cosmeticTrailMul[lvl]);
      for (const h of typeof t.tint === 'string' ? [t.tint] : t.tint) this.trailTints.push(hexToInt(h));
      this.trailEvery = calm ? t.everyPx / S.calmScale : t.everyPx;
    }
  }

  private makeTrail(t: TrailDef, lifeMul: number): Phaser.GameObjects.Particles.ParticleEmitter {
    const life = t.lifeMs * lifeMul;
    const drift = t.driftPx / (life / 1000);
    return this.scene.add
      .particles(0, 0, avatarParticleKey(t.shape), {
        lifespan: life,
        scale: { start: t.scale[0], end: t.scale[1] },
        alpha: { start: t.alpha[0], end: t.alpha[1] },
        gravityY: t.gravityY,
        speedX: { min: -drift, max: drift },
        speedY: 0,
        blendMode: t.blend,
        emitting: false,
        maxAliveParticles: 64,
      })
      .setDepth(4.9);
  }

  /** Följer det hängande objektets x (varje frame, samma som objektet). */
  followX(x: number): void {
    this.x = x;
  }

  /** Greppunkten = objektets ovankant + 4 px. `animate`: 220 ms Back.easeOut (nytt objekt). */
  setGrip(yWanted: number, animate: boolean): void {
    // Figuren håller sig inom skärmen: greppet aldrig högre än figurens höjd ovanför greppet.
    const y = Math.max(yWanted, gripToTop(S.displayPx));
    this.scene.tweens.killTweensOf(this.grip);
    if (!animate) {
      this.grip.y = y;
      return;
    }
    this.scene.tweens.add({ targets: this.grip, y, duration: S.respawnMs, ease: S.respawnEase });
  }

  /** Pacing-vickningen (grader) på det hängande objektet. */
  setWobble(deg: number): void {
    this.wobbleDeg = deg;
  }

  private sound(t: GestureTrigger, semitones = 0): void {
    const s = this.def.cosmetic.sound?.[t];
    if (s) playTone(s, semitones);
  }

  /** Händelse: rörelse (recept/gest) + figurens eget ljud. */
  on(t: GestureTrigger, semitones = 0): void {
    this.rig.trigger(t);
    this.sound(t, semitones);
  }

  /** Objektet släpptes: spåret följer det tills första kontakt. */
  onDrop(ball: Phaser.GameObjects.Image): void {
    this.on('drop');
    this.tracking = this.trail ? ball : null;
    this.lastTX = ball.x;
    this.lastTY = ball.y;
    this.lookX = ball.x;
    this.lookY = ball.y;
  }

  onLand(ball: Phaser.GameObjects.Image): void {
    if (this.tracking === ball) this.tracking = null;
  }

  setDanger(on: boolean): void {
    this.rig.setDanger(on);
  }

  /** Anropas från scenens update(). Inga allokeringar. */
  update(delta: number, lookAt: Phaser.GameObjects.Image | null): void {
    const dx = this.x - this.prevX;
    this.prevX = this.x;
    if (dx !== 0) this.lean = Phaser.Math.Clamp(dx * S.leanDegPerPxPerFrame, -S.leanMaxDeg, S.leanMaxDeg);
    else this.lean *= Math.max(0, 1 - delta / S.leanReturnMs);
    const rot = (this.lean + this.wobbleDeg * S.wobbleShare) * DEG;
    this.rig.apply(this.img, this.x, this.grip.y, rot);

    const tr = this.tracking;
    if (tr && this.trail) {
      if (!tr.visible) this.tracking = null;
      else {
        const ddx = tr.x - this.lastTX;
        const ddy = tr.y - this.lastTY;
        if (ddx * ddx + ddy * ddy >= this.trailEvery * this.trailEvery) {
          this.trail.setParticleTint(this.trailTints[this.trailIdx++ % this.trailTints.length]);
          this.trail.emitParticleAt(tr.x, tr.y, 1);
          this.lastTX = tr.x;
          this.lastTY = tr.y;
        }
      }
    }

    const p = this.pupils;
    if (p) {
      if (lookAt?.visible) {
        this.lookX = lookAt.x;
        this.lookY = lookAt.y;
      }
      const lx = this.lookX - this.img.x;
      const ly = this.lookY - this.img.y;
      const len = Math.sqrt(lx * lx + ly * ly) || 1;
      p.setPosition(this.img.x + (lx / len) * this.lookPx, this.img.y + (ly / len) * this.lookPx);
      p.setScale(this.img.scaleX, this.img.scaleY).setRotation(this.img.rotation);
    }
  }
}
