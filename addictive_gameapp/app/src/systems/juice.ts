import Phaser from 'phaser';
import { EVENTS, JUICE, FEEL, type JuiceEvent } from '../data/juice';
import { THEME } from '../data/theme';
import { FX_DOT } from '../ui/textures';
import { playSound, startDanger, stopDanger } from './audio';
import { hapticForIntensity } from './haptics';

/**
 * En ingång för allt game feel: `trigger(event, intensity, x, y, opts)` (DESIGN.md §6).
 * Alla effekter skalas linjärt från intensity. Lugnt läge: ×0,5, shake och zoom av.
 * Systemet importerar aldrig en scen – bara Phaser och data.
 */

export interface TriggerOpts {
  /** Objektet som ska få scale-punch (vanligtvis det nya objektet). */
  target?: Phaser.GameObjects.Image;
  /** Partikelfärg, normalt nivåns kulör. */
  color?: number;
  /** Hastighet som partiklarna ärver. */
  vx?: number;
  vy?: number;
  /** Combo-steg, styr merge-pitchen. */
  combo?: number;
  /** Poäng som ska flyga till HUD. */
  score?: number;
}

export interface JuiceSettings {
  sound: boolean;
  haptics: boolean;
  calm: boolean;
}

const EMPTY: TriggerOpts = {};

export class Juice {
  private readonly scene: Phaser.Scene;
  private readonly cam: Phaser.Cameras.Scene2D.Camera;
  private readonly hudX: number;
  private readonly hudY: number;
  private emitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private readonly pops: Phaser.GameObjects.Text[] = [];
  private popIndex = 0;

  private calm: boolean;

  // shake-tillstånd (inga allokeringar i update)
  private shakeT = Infinity;
  private shakeAmp = 0;
  private shakeDx = 0;
  private shakeDy = 0;

  private stopUntil = 0;
  private stopped = false;
  private slowmoTween: Phaser.Tweens.Tween | null = null;

  constructor(scene: Phaser.Scene, hudX: number, hudY: number, settings: JuiceSettings) {
    this.scene = scene;
    this.cam = scene.cameras.main;
    this.hudX = hudX;
    this.hudY = hudY;
    this.calm = settings.calm;

    this.emitter = scene.add
      .particles(0, 0, FX_DOT, {
        lifespan: JUICE.particles.lifespanMs,
        speed: { min: JUICE.particles.speedMin, max: JUICE.particles.speedMax },
        angle: { min: 0, max: 360 },
        scale: { start: JUICE.particles.scaleStart, end: JUICE.particles.scaleEnd },
        alpha: { start: 1, end: 0 },
        blendMode: 'ADD',
        emitting: false,
        maxAliveParticles: JUICE.particles.poolSize,
      })
      .setDepth(30);

    scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.destroy());
  }

  setCalm(on: boolean): void {
    this.calm = on;
  }

  // ---------------------------------------------------------------- ingång

  trigger(event: JuiceEvent, intensity: number, x = 180, y = 320, opts: TriggerOpts = EMPTY): void {
    const ch = EVENTS[event];
    let i = Phaser.Math.Clamp(intensity, 0, 1);
    if (this.calm) i *= JUICE.calm.intensityScale;

    playSound(event, { intensity: i, combo: opts.combo });
    if (ch.haptics) hapticForIntensity(i);

    if (event === 'danger') {
      this.startSlowmo();
      startDanger();
      return;
    }

    if (ch.hitStop) this.hitStop(i);
    if (opts.target) this.punch(opts.target, i);
    if (ch.particles > 0) this.burst(x, y, i * ch.particles, opts);
    if (ch.shake > 0) this.shake(x, y, i * ch.shake);
    if (ch.scorePop && opts.score) this.scorePop(x, y, opts.score);
    if (ch.zoom) this.zoom(i);
  }

  /** Faran är över: tillbaka till 1,0× och tyst. */
  endDanger(): void {
    stopDanger();
    this.endSlowmo();
  }

  // ---------------------------------------------------------------- kanaler

  private hitStop(i: number): void {
    const c = JUICE.hitStop;
    if (i < c.minIntensity) return;
    const frames = Math.round(c.maxFrames * i);
    const ms = Math.min(c.maxMs, frames * c.frameMs);
    if (ms <= 0) return;
    this.stopUntil = Math.max(this.stopUntil, this.scene.time.now + ms);
    if (this.stopped) return;
    this.stopped = true;
    this.scene.matter?.world?.pause();
    this.scene.tweens.timeScale = 0;
  }

  private punch(target: Phaser.GameObjects.Image, i: number): void {
    const p = JUICE.punch;
    const peak = 1 + p.peak * i;
    this.scene.tweens.killTweensOf(target);
    target.setScale(1);
    this.scene.tweens.add({
      targets: target,
      scale: peak,
      duration: p.durationMs * 0.4,
      ease: p.ease,
      yoyo: true,
      onComplete: () => target.setScale(1),
    });
  }

  private burst(x: number, y: number, i: number, opts: TriggerOpts): void {
    const e = this.emitter;
    if (!e) return;
    const p = JUICE.particles;
    const count = Math.min(p.max, Math.round(p.base + p.perIntensity * i));
    if (count <= 0) return;
    e.setParticleTint(opts.color ?? Phaser.Display.Color.HexStringToColor(THEME.palette.accent).color);
    e.emitParticleAt(x, y, count);
    const vx = opts.vx ?? 0;
    const vy = opts.vy ?? 0;
    if (vx === 0 && vy === 0) return;
    // Partiklarna ärver objektets hastighet.
    // `alive` finns i runtime men saknas i Phasers typer.
    const alive = (e as unknown as { alive: Phaser.GameObjects.Particles.Particle[] }).alive;
    for (let k = Math.max(0, alive.length - count); k < alive.length; k++) {
      alive[k].velocityX += vx * p.inheritVelocity;
      alive[k].velocityY += vy * p.inheritVelocity;
    }
  }

  private shake(x: number, y: number, i: number): void {
    if (this.calm && !JUICE.calm.shake) return;
    const s = JUICE.shake;
    const dx = x - this.cam.width / 2;
    const dy = y - this.cam.height / 2;
    const len = Math.sqrt(dx * dx + dy * dy) || 1;
    this.shakeDx = dx / len;
    this.shakeDy = dy / len;
    this.shakeAmp = Math.min(s.maxPx, s.maxPx * i);
    this.shakeT = 0;
  }

  private scorePop(x: number, y: number, score: number): void {
    const cfg = JUICE.scorePop;
    let t = this.pops[this.popIndex];
    if (!t) {
      t = this.scene.add
        .text(0, 0, '', {
          fontFamily: THEME.type.family,
          fontSize: `${THEME.type.pop}px`,
          color: THEME.palette.accent,
        })
        .setOrigin(0.5)
        .setDepth(31);
      this.pops[this.popIndex] = t;
    }
    this.popIndex = (this.popIndex + 1) % cfg.poolSize;

    this.scene.tweens.killTweensOf(t);
    t.setText(`+${score}`).setPosition(x, y).setAlpha(1).setScale(1).setVisible(true);
    this.scene.tweens.add({
      targets: t,
      x: this.hudX,
      y: this.hudY,
      alpha: { value: 0, delay: cfg.durationMs - THEME.anim.scorePop.fadeMs, duration: THEME.anim.scorePop.fadeMs },
      duration: cfg.durationMs,
      ease: cfg.ease,
      onComplete: () => t.setVisible(false),
    });
  }

  private zoom(i: number): void {
    if (this.calm && !JUICE.calm.zoom) return;
    const z = JUICE.zoom;
    const peak = 1 + (z.peak - 1) * i;
    this.scene.tweens.add({
      targets: this.cam,
      zoom: peak,
      duration: z.durationMs / 2,
      ease: z.ease,
      yoyo: true,
      onComplete: () => this.cam.setZoom(1),
    });
  }

  // ---------------------------------------------------------------- slow-mo

  private setTimeScale(v: number): void {
    const w = this.scene.matter?.world;
    if (w) w.engine.timing.timeScale = v;
  }

  private startSlowmo(): void {
    const d = FEEL.danger;
    this.slowmoTween?.remove();
    this.slowmoTween = this.scene.tweens.addCounter({
      from: this.scene.matter?.world?.engine.timing.timeScale ?? 1,
      to: d.timeScale,
      duration: d.inMs,
      ease: THEME.anim.slowmoIn.ease,
      onUpdate: (tw) => this.setTimeScale(tw.getValue() ?? d.timeScale),
    });
  }

  private endSlowmo(): void {
    const d = FEEL.danger;
    this.slowmoTween?.remove();
    this.slowmoTween = this.scene.tweens.addCounter({
      from: this.scene.matter?.world?.engine.timing.timeScale ?? d.timeScale,
      to: 1,
      duration: d.outMs,
      ease: THEME.anim.slowmoOut.ease,
      onUpdate: (tw) => this.setTimeScale(tw.getValue() ?? 1),
      onComplete: () => this.setTimeScale(1),
    });
  }

  // ---------------------------------------------------------------- loop

  /** Anropas från scenens update(). Inga allokeringar. */
  update(delta: number): void {
    if (this.stopped && this.scene.time.now >= this.stopUntil) {
      this.stopped = false;
      this.stopUntil = 0;
      this.scene.matter?.world?.resume();
      this.scene.tweens.timeScale = 1;
    }

    const s = JUICE.shake;
    if (this.shakeT <= s.durationMs) {
      this.shakeT += delta;
      if (this.shakeT >= s.durationMs) {
        this.shakeT = Infinity;
        this.cam.setScroll(0, 0);
      } else {
        const t = this.shakeT / 1000;
        const a =
          this.shakeAmp * Math.exp(-this.shakeT / s.tauMs) * Math.sin(2 * Math.PI * s.freqHz * t);
        this.cam.setScroll(this.shakeDx * a, this.shakeDy * a);
      }
    }
  }

  destroy(): void {
    stopDanger();
    this.stopped = false;
    this.scene.matter?.world?.resume();
    this.setTimeScale(1);
    this.scene.tweens.timeScale = 1;
    this.cam.setScroll(0, 0);
    this.cam.setZoom(1);
    this.emitter = null;
    this.pops.length = 0;
  }
}
