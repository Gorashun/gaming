import Phaser from 'phaser';
import { EVENTS, JUICE, FEEL, RINGS, SOUND_ALIAS, type JuiceEvent, type RingWave } from '../data/juice';
import { THEME, hexToInt } from '../data/theme';
import { THEME_SETS, type ParticleShape, type SetParticles } from '../data/themes';
import { FX_RING, FX_RING_R, particleTextureKey } from '../ui/textures';
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
  /**
   * Ovanpå en overlay (rundavslutet): ingen shake, zoom, hit-stop eller slow-mo och inget
   * eget ljud – anroparen spelar sitt eget (UI.md §12.5).
   */
  overlay?: boolean;
  /** Ersätter eventets ringvåg. */
  ring?: RingWave;
  /** Inget eget ljud (en förmåga spelar sitt, t.ex. Fias fanfar). */
  mute?: boolean;
  /** Kompisens partiklar (setAvatarParticles) även för detta event, t.ex. öppningen. */
  avatarParticles?: boolean;
  /** Ingen guldton över skärmen (öppningen har sin egen glöd, UI.md §13.3). */
  noTint?: boolean;
}

/** Kompisens egna partiklar vid merge (UI.md §13.1): form, färg och antal ×. */
export interface AvatarParticles {
  /** Texturnyckel (vit, tintas). null = setets form. */
  texture: string | null;
  /** Hex, 'combo' (nyans roterar med combon) eller 'level' (objektets färg). */
  tint: string;
  /** Antal × (uppgraderingsnivå). */
  countMul: number;
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
  /** Andra partikeltypen i samma utbrott (t.ex. Glödens glödprickar). */
  private mixEmitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private readonly pc: SetParticles;
  private readonly lightTint = hexToInt(THEME.palette.hud);
  private readonly mixTint: number;
  private readonly pops: Phaser.GameObjects.Text[] = [];
  private popIndex = 0;
  private readonly rings: Phaser.GameObjects.Image[] = [];
  private ringIndex = 0;
  private tint: Phaser.GameObjects.Rectangle | null = null;
  private dangerActive = false;
  private jackpotSlowmo = false;
  /** Kompisens partiklar ersätter setets vid merge/kedja. */
  private avatarEmitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private avatarP: AvatarParticles | null = null;
  /** Shake × vid kedja (förmåga, Muller). Taket JUICE.shake.maxPx gäller alltid. */
  chainShakeMul = 1;

  private calm: boolean;

  // shake-tillstånd (inga allokeringar i update)
  private shakeT = Infinity;
  private shakeAmp = 0;
  private shakeDx = 0;
  private shakeDy = 0;

  private stopUntil = 0;
  private stopped = false;
  private slowmoTween: Phaser.Tweens.Tween | null = null;

  constructor(
    scene: Phaser.Scene,
    hudX: number,
    hudY: number,
    settings: JuiceSettings,
    particles: SetParticles = THEME_SETS[0].particle,
  ) {
    this.scene = scene;
    this.cam = scene.cameras.main;
    this.hudX = hudX;
    this.hudY = hudY;
    this.calm = settings.calm;
    this.pc = particles;
    this.mixTint = particles.mix ? hexToInt(particles.mix.tint) : 0;

    // Partikelform per set (UI.md §12.1.3), bakad textur per form.
    const p = JUICE.particles;
    const mk = (
      shape: ParticleShape,
      gravityY: number,
      scale: { start: number; end: number },
      alpha: { start: number; end: number },
    ): Phaser.GameObjects.Particles.ParticleEmitter =>
      scene.add
        .particles(0, 0, particleTextureKey(shape), {
          lifespan: particles.lifespanMs,
          speed: { min: p.speedMin * particles.speedScale, max: p.speedMax * particles.speedScale },
          angle: { min: 0, max: 360 },
          scale,
          alpha,
          rotate: { start: 0, end: (particles.spinDegPerSec * particles.lifespanMs) / 1000 },
          gravityY,
          blendMode: particles.blend,
          emitting: false,
          maxAliveParticles: p.poolSize,
        })
        .setDepth(30);
    this.emitter = mk(particles.shape, particles.gravityY, particles.scale, particles.alpha);
    if (particles.mix) {
      this.mixEmitter = mk(
        particles.mix.shape,
        particles.mix.gravityY,
        { start: p.scaleStart, end: p.scaleEnd },
        { start: 1, end: 0 },
      );
    }

    scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.destroy());
  }

  /** Kompisens partikelform/färg vid merge (vanlig/ovanlig kosmetik). null = setets. */
  setAvatarParticles(p: AvatarParticles | null): void {
    this.avatarP = p;
    if (!p) return;
    const base = this.emitter;
    this.avatarEmitter?.destroy();
    const J = JUICE.particles;
    this.avatarEmitter = this.scene.add
      .particles(0, 0, p.texture ?? particleTextureKey(this.pc.shape), {
        lifespan: this.pc.lifespanMs,
        speed: { min: J.speedMin * this.pc.speedScale, max: J.speedMax * this.pc.speedScale },
        angle: { min: 0, max: 360 },
        scale: { start: J.scaleStart, end: J.scaleEnd },
        alpha: { start: 1, end: 0 },
        rotate: { start: 0, end: 180 },
        gravityY: this.pc.gravityY,
        emitting: false,
        maxAliveParticles: J.poolSize,
      })
      .setDepth(base?.depth ?? 30);
  }

  /** Expanderande ringar vid (x, y) utan övriga kanaler (förmågor: Eko, Ekko). */
  ringAt(x: number, y: number, cfg: RingWave): void {
    this.ringWave(x, y, cfg);
  }

  setCalm(on: boolean): void {
    this.calm = on;
  }

  /** Hit-stop eller slow-mo pågår just nu (pacing vilar då, DESIGN §11). */
  get timeAltered(): boolean {
    return this.stopped || this.dangerActive || this.jackpotSlowmo;
  }

  // ---------------------------------------------------------------- ingång

  trigger(event: JuiceEvent, intensity: number, x = 180, y = 320, opts: TriggerOpts = EMPTY): void {
    const ch = EVENTS[event];
    let i = Phaser.Math.Clamp(intensity, 0, 1);
    if (this.calm) i *= JUICE.calm.intensityScale;

    const overlay = opts.overlay === true;
    if (!overlay && !opts.mute) playSound(SOUND_ALIAS[event] ?? event, { intensity: i, combo: opts.combo });
    if (ch.haptics) hapticForIntensity(i);

    if (event === 'danger') {
      this.dangerActive = true;
      this.startSlowmo();
      startDanger();
      return;
    }

    if (ch.hitStop && !overlay) this.hitStop(i);
    if (opts.target) this.punch(opts.target, i);
    if (ch.particles > 0) this.burst(x, y, i * ch.particles, opts, event === 'merge' || event === 'chain' || opts.avatarParticles === true);
    if (ch.shake > 0 && !overlay) this.shake(x, y, i * ch.shake * (event === 'chain' ? this.chainShakeMul : 1));
    if (ch.scorePop && opts.score) this.scorePop(x, y, opts.score);
    if (ch.zoom && !overlay) this.zoom(i);
    const ring = opts.ring ?? RINGS[event];
    if (ring) this.ringWave(x, y, ring);
    if (event === 'jackpot' && !opts.noTint) this.jackpot(overlay);
  }

  /** Faran är över: tillbaka till 1,0× och tyst. */
  endDanger(): void {
    this.dangerActive = false;
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

  private burst(x: number, y: number, i: number, opts: TriggerOpts, avatar = false): void {
    const e = this.emitter;
    if (!e) return;
    const p = JUICE.particles;
    const count = Math.min(p.max, Math.round((p.base + p.perIntensity * i) * this.pc.countScale));
    if (count <= 0) return;
    const color = opts.color ?? hexToInt(THEME.palette.accent);
    const ap = this.avatarP;
    if (avatar && ap && this.avatarEmitter) {
      const t =
        ap.tint === 'level'
          ? color
          : ap.tint === 'combo'
            ? Phaser.Display.Color.HSVToRGB((((opts.combo ?? 0) * 47) % 360) / 360, 0.55, 1).color
            : hexToInt(ap.tint);
      this.emit(this.avatarEmitter, x, y, Math.min(p.max, Math.round(count * ap.countMul)), t, opts);
      return;
    }
    const nMix = this.mixEmitter && this.pc.mix ? Math.round(count * this.pc.mix.share) : 0;
    const n = count - nMix;
    // 'levelLight': varannan partikel i hud-vit (glittrigt utan att något blinkar).
    const nLight = this.pc.tint === 'levelLight' ? Math.floor(n / 2) : 0;
    this.emit(e, x, y, n - nLight, color, opts);
    this.emit(e, x, y, nLight, this.lightTint, opts);
    if (this.mixEmitter) this.emit(this.mixEmitter, x, y, nMix, this.mixTint, opts);
  }

  private emit(
    e: Phaser.GameObjects.Particles.ParticleEmitter,
    x: number,
    y: number,
    count: number,
    tint: number,
    opts: TriggerOpts,
  ): void {
    if (count <= 0) return;
    e.setParticleTint(tint);
    e.emitParticleAt(x, y, count);
    const vx = opts.vx ?? 0;
    const vy = opts.vy ?? 0;
    if (vx === 0 && vy === 0) return;
    // Partiklarna ärver objektets hastighet.
    // `alive` finns i runtime men saknas i Phasers typer.
    const k0 = JUICE.particles.inheritVelocity;
    const alive = (e as unknown as { alive: Phaser.GameObjects.Particles.Particle[] }).alive;
    for (let k = Math.max(0, alive.length - count); k < alive.length; k++) {
      alive[k].velocityX += vx * k0;
      alive[k].velocityY += vy * k0;
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

  /** Expanderande strokad ring (aldrig en vitblixt, UI.md §6). */
  private ringWave(x: number, y: number, cfg: RingWave): void {
    for (let k = 0; k < cfg.count; k++) {
      const img = this.ring();
      img
        .setPosition(x, y)
        .setTint(hexToInt(cfg.color))
        .setAlpha(cfg.alpha)
        .setScale((cfg.fromR ?? 0) / FX_RING_R || 0.08)
        .setVisible(true);
      this.scene.tweens.add({
        targets: img,
        scale: cfg.maxR / FX_RING_R,
        alpha: 0,
        delay: k * cfg.stepMs,
        duration: cfg.durationMs,
        ease: 'Quad.easeOut',
        onComplete: () => img.setVisible(false),
      });
    }
  }

  private ring(): Phaser.GameObjects.Image {
    let img = this.rings[this.ringIndex];
    if (!img) {
      img = this.scene.add.image(0, 0, FX_RING).setDepth(29).setBlendMode('ADD');
      this.rings[this.ringIndex] = img;
    }
    this.ringIndex = (this.ringIndex + 1) % JUICE.ringPoolSize;
    this.scene.tweens.killTweensOf(img);
    return img;
  }

  /** Jackpot: guldton över hela burken + slow-mo. Enda tidsändringen utanför fara. */
  private jackpot(overlay: boolean): void {
    const j = JUICE.jackpot;
    if (!this.tint) {
      this.tint = this.scene.add
        .rectangle(
          THEME.layout.width / 2,
          THEME.layout.height / 2,
          THEME.layout.width,
          THEME.layout.height,
          hexToInt(THEME.palette.gold),
        )
        .setDepth(28)
        .setAlpha(0);
    }
    const tint = this.tint;
    this.scene.tweens.killTweensOf(tint);
    tint.setAlpha(0);
    this.scene.tweens.add({
      targets: tint,
      alpha: j.tintAlpha,
      duration: j.tintMs / 2,
      yoyo: true,
      ease: 'Sine.easeInOut',
      onComplete: () => tint.setAlpha(0),
    });

    if (this.dangerActive || overlay) return;
    this.jackpotSlowmo = true;
    this.startSlowmo();
    this.scene.time.delayedCall(j.slowmoMs, () => {
      if (!this.jackpotSlowmo || this.dangerActive) return;
      this.jackpotSlowmo = false;
      this.endSlowmo();
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
    this.dangerActive = false;
    this.jackpotSlowmo = false;
    stopDanger();
    this.stopped = false;
    this.scene.matter?.world?.resume();
    this.setTimeScale(1);
    this.scene.tweens.timeScale = 1;
    this.cam.setScroll(0, 0);
    this.cam.setZoom(1);
    this.emitter = null;
    this.mixEmitter = null;
    this.avatarEmitter = null;
    this.avatarP = null;
    this.pops.length = 0;
    this.rings.length = 0;
    this.tint = null;
  }
}
