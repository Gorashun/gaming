import Phaser from 'phaser';
import { THEME, hexToInt } from '../data/theme';
import { CAN, INNER_LEFT, INNER_RIGHT } from '../data/physics';
import { ABILITY_FX as FX } from '../data/abilities';
import { AVATAR_BOX, AVATAR_GRIP, AVATAR_UI, avatarById } from '../data/avatarsIndex';
import type { Abilities } from '../systems/abilities';
import type { Juice } from '../systems/juice';
import { playTone, resetAudioOverrides, setDangerStyle, setMergeEcho, setMergeLayer, setMergeMelody } from '../systems/audio';
import { BG_GLOW, FX_DOT } from './textures';
import { avatarParticleKey, bakeAvatarParticles } from './avatarArt';
import { drawZigzag } from './avatarFx';

const L = THEME.layout;
const AURORA = 'fx-aurora-band';

/**
 * Känsloförmågornas bild och ljud (sällsynt, UI.md §13.8). Ljud-overrides sätts i audio vid
 * rundstart; bild byggs en gång och återanvänds. Ingen förmåga här rör poängen.
 */
export class AbilityFx {
  private readonly scene: Phaser.Scene;
  private readonly ab: Abilities;
  private readonly calm: boolean;
  private readonly juice: Juice;
  private bolts: Phaser.GameObjects.Graphics | null = null;
  private emitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private sepia: Phaser.GameObjects.Rectangle | null = null;
  private clock: Phaser.GameObjects.Graphics | null = null;
  private disco: Phaser.GameObjects.Container | null = null;
  private discoAt = -Infinity;
  private bands: Phaser.GameObjects.Image[] = [];
  private auroraOn = false;
  /** Lisas oljemätare runt lyktan (null för alla andra). */
  private meter: Phaser.GameObjects.Graphics | null = null;
  private meterStep = -1;

  constructor(scene: Phaser.Scene, ab: Abilities, calm: boolean, juice: Juice) {
    this.scene = scene;
    this.ab = ab;
    this.calm = calm;
    this.juice = juice;
    resetAudioOverrides();
    bakeAvatarParticles(scene);
    const p = ab;
    switch (ab.key) {
      case 'thunderChain':
        juice.chainShakeMul = ab.o.chainShakeMul;
        this.bolts = scene.add.graphics().setDepth(7).setAlpha(0);
        break;
      case 'comboMelody': {
        const m = ab.p.melody;
        setMergeMelody({ melody: Array.isArray(m) ? (m as number[]) : [0], harmony: p.flag('harmony'), bass: p.flag('bass'), ...FX.melody });
        break;
      }
      case 'dangerStyle': {
        const T = FX.tick;
        setDangerStyle({ gain: p.param('tickGain'), hz: T.tickHz, clickMs: T.clickMs });
        this.sepia = scene.add.rectangle(L.width / 2, L.height / 2, L.width, L.height, hexToInt(T.sepia), 1).setDepth(27).setAlpha(0);
        if (p.flag('clockRing')) {
          const g = scene.add.graphics().setDepth(6).setAlpha(0);
          const R = T.ring;
          const c = hexToInt(R.color);
          g.lineStyle(R.width, c, 0.9);
          g.strokeCircle(R.x, CAN.dangerY, R.r);
          for (let i = 0; i < R.ticks; i++) {
            const a = (i / R.ticks) * Math.PI * 2;
            g.lineBetween(R.x + Math.cos(a) * R.r * 0.7, CAN.dangerY + Math.sin(a) * R.r * 0.7, R.x + Math.cos(a) * R.r, CAN.dangerY + Math.sin(a) * R.r);
          }
          g.lineBetween(R.x, CAN.dangerY, R.x, CAN.dangerY - R.r * 0.6);
          g.lineBetween(R.x, CAN.dangerY, R.x + R.r * 0.45, CAN.dangerY);
          this.clock = g;
        }
        break;
      }
      case 'recordFanfare':
        this.emitter = this.makeEmitter('star', FX.fanfare.speed, 60, 900);
        break;
      case 'lavaMerge':
        this.emitter = this.makeEmitter('drop', FX.lava.speed, FX.lava.gravityY, FX.lava.lifeMs);
        break;
      case 'discoBg': {
        const D = FX.disco;
        const n = p.param('spots');
        const spots = [];
        for (let i = 0; i < n; i++) {
          const a = (i / n) * Math.PI * 2;
          spots.push(
            scene.add
              .image(Math.cos(a) * D.radius, Math.sin(a) * D.radius, BG_GLOW)
              .setDisplaySize(D.spotPx, D.spotPx)
              .setTint(hexToInt(D.colors[i % D.colors.length])),
          );
        }
        this.disco = scene.add.container(L.width / 2, 330, spots).setDepth(-4.5).setAlpha(0);
        scene.tweens.add({ targets: this.disco, angle: 360, duration: (360 / D.degPerSec) * 1000, repeat: -1 });
        break;
      }
      case 'echoMerge':
        setMergeEcho({ delayMs: p.param('delayMs'), feedback: p.param('feedback'), wet: p.param('wet'), repeats: FX.echo.repeats });
        break;
      case 'auroraChain': {
        const A = FX.aurora;
        if (!scene.textures.exists(AURORA)) {
          const g = scene.make.graphics({ x: 0, y: 0 }, false);
          for (let k = 0; k < 3; k++) {
            g.lineStyle(A.width - k * 6, 0xffffff, 0.35 + k * 0.2);
            const pts = new Phaser.Curves.QuadraticBezier(
              new Phaser.Math.Vector2(0, 40),
              new Phaser.Math.Vector2(170, 0),
              new Phaser.Math.Vector2(340, 40),
            ).getPoints(24);
            g.strokePoints(pts, false);
          }
          g.generateTexture(AURORA, 340, 64);
          g.destroy();
        }
        for (let i = 0; i < p.param('bands'); i++) {
          this.bands.push(
            scene.add
              .image(L.width / 2, A.y + i * A.spacing - A.spacing, AURORA)
              .setTint(hexToInt(A.colors[i % A.colors.length]))
              .setBlendMode('ADD')
              .setDepth(4.5)
              .setAlpha(0),
          );
        }
        break;
      }
      case 'sameLevelGlow':
        this.meter = scene.add.graphics().setDepth(AVATAR_UI.slapparen.depth + 0.1);
        break;
      case 'queenRound':
        if (ab.o.orchestra) setMergeLayer(FX.queen.strings, FX.queen.stringsSemitones);
        break;
    }
  }

  get lanternMeterVisible(): boolean {
    return this.meter !== null && this.meter.visible && this.meter.alpha > 0;
  }

  /**
   * Lisa (UI.md §13.8): bågen runt lyktan krymper när siktningen förbrukar oljan och tonas bort
   * vid 0. Följer figuren varje frame; ritas bara om när bågen ändrats ett steg. Inga allokeringar.
   */
  lantern(img: Phaser.GameObjects.Image): void {
    const g = this.meter;
    if (!g || !g.visible) return;
    const M = FX.lisa.meter;
    const full = this.ab.param('seconds') * 1000;
    const step = full > 0 ? Math.ceil((this.ab.lisaOilMs / full) * M.steps) : 0;
    const k = AVATAR_UI.slapparen.displayPx / AVATAR_BOX;
    const ox = (M.box[0] - AVATAR_GRIP[0]) * k * img.scaleX;
    const oy = (M.box[1] - AVATAR_GRIP[1]) * k * img.scaleY;
    const c = Math.cos(img.rotation);
    const sn = Math.sin(img.rotation);
    g.setPosition(img.x + ox * c - oy * sn, img.y + ox * sn + oy * c);
    g.setVisible(img.visible);
    if (step === this.meterStep) return;
    this.meterStep = step;
    if (step <= 0) {
      this.scene.tweens.add({ targets: g, alpha: 0, scale: 0.4, duration: M.outMs, onComplete: () => g.setVisible(false) });
      return;
    }
    const col = hexToInt(M.color);
    g.clear();
    g.lineStyle(M.width, col, M.trackAlpha);
    g.strokeCircle(0, 0, M.r);
    g.lineStyle(M.width, col, 1);
    g.beginPath();
    g.arc(0, 0, M.r, -Math.PI / 2, -Math.PI / 2 + (step / M.steps) * Math.PI * 2, false);
    g.strokePath();
  }

  private makeEmitter(shape: 'star' | 'drop', speed: number, gravityY: number, life: number): Phaser.GameObjects.Particles.ParticleEmitter {
    return this.scene.add
      .particles(0, 0, avatarParticleKey(shape), {
        lifespan: life,
        speed: { min: speed * 0.4, max: speed },
        angle: shape === 'drop' ? { min: 230, max: 310 } : { min: 0, max: 360 },
        scale: { start: 1, end: 0.2 },
        alpha: { start: 1, end: 0 },
        gravityY,
        emitting: false,
        maxAliveParticles: 96,
      })
      .setDepth(8);
  }

  private count(n: number): number {
    return this.calm ? Math.max(1, Math.round(n / 2)) : n;
  }

  /** Showcase-ljudet med ersatta fält (Mullers muller, Vulles sub, Fias fanfar). */
  private tone(patch: Record<string, unknown>): void {
    const s = avatarById(this.ab.id)?.showcase.sound;
    if (s) playTone({ ...s, ...patch });
  }

  /** Kedja ≥3 (Muller, Nora). */
  onChain(x: number, y: number, len: number): void {
    const p = this.ab;
    if (p.key === 'thunderChain' && this.bolts) {
      const g = this.bolts;
      const T = FX.thunder;
      g.clear();
      const n = this.count(p.param('bolts'));
      for (let i = 0; i < n; i++) {
        const bx = Phaser.Math.Clamp(x + (i - (n - 1) / 2) * (T.spreadPx / Math.max(1, n - 1)), INNER_LEFT, INNER_RIGHT);
        drawZigzag(g, bx, y - T.len - 20, Math.PI / 2 + (i % 2 ? 0.2 : -0.2), T.len, T.zigs, hexToInt(T.color), T.width);
      }
      this.scene.tweens.killTweensOf(g);
      g.setAlpha(1);
      this.scene.tweens.add({ targets: g, alpha: 0, duration: p.param('boltMs'), ease: 'Quad.easeIn' });
      this.tone({ gain: p.param('rumbleGain') });
    }
    if (p.key === 'auroraChain' && len >= p.param('minChain') && !this.auroraOn && this.bands.length > 0) {
      const A = FX.aurora;
      this.auroraOn = true;
      const hold = p.param('holdMs');
      this.bands.forEach((b, i) => {
        this.scene.tweens.killTweensOf(b);
        b.x = L.width / 2;
        this.scene.tweens.chain({
          targets: b,
          tweens: [
            { alpha: p.param('alpha'), duration: A.inMs, ease: 'Sine.easeOut' },
            { alpha: p.param('alpha'), duration: hold },
            { alpha: 0, duration: A.outMs, ease: 'Sine.easeIn' },
          ],
          onComplete: () => {
            if (i === 0) this.auroraOn = false;
          },
        });
        this.scene.tweens.add({
          targets: b,
          x: L.width / 2 + (i % 2 ? -1 : 1) * A.swayPx,
          duration: 500 / A.swayHz,
          ease: 'Sine.easeInOut',
          yoyo: true,
          repeat: Math.ceil((A.inMs + hold + A.outMs) * A.swayHz / 1000),
        });
      });
    }
  }

  /** Varje merge: Vulle (nivå ≥ minLevel), Disco (combo), Eko (ringar). */
  onMerge(x: number, y: number, newLevel: number, combo: number): void {
    const p = this.ab;
    if (p.key === 'lavaMerge' && newLevel >= p.param('minLevel') && this.emitter) {
      const cs = FX.lava.colors;
      const n = this.count(p.param('drops'));
      for (let i = 0; i < cs.length; i++) {
        this.emitter.setParticleTint(hexToInt(cs[i]));
        this.emitter.emitParticleAt(x, y, Math.ceil(n / cs.length));
      }
      this.tone({ baseHz: p.param('subHz'), gain: p.param('subGain') });
    }
    if (p.key === 'discoBg' && this.disco) {
      const now = this.scene.time.now;
      // Flash-guard: högst en puls per minIntervalMs.
      if (now - this.discoAt < p.param('minIntervalMs')) return;
      this.discoAt = now;
      const a = Math.min(p.param('maxAlpha'), p.param('stepAlpha') * combo);
      this.scene.tweens.killTweensOf(this.disco);
      this.scene.tweens.add({ targets: this.disco, angle: this.disco.angle + 360, duration: (360 / FX.disco.degPerSec) * 1000, repeat: -1 });
      this.scene.tweens.add({ targets: this.disco, alpha: a, duration: 200, ease: 'Sine.easeOut' });
    }
    if (p.key === 'echoMerge') {
      const E = FX.echo;
      this.scene.time.delayedCall(p.param('delayMs'), () =>
        this.juice.ringAt(x, y, {
          count: this.calm ? 1 : p.param('rings'),
          fromR: 10,
          maxR: E.ringMaxR,
          durationMs: E.ringMs,
          stepMs: p.param('delayMs'),
          color: E.ringColor,
          alpha: 0.6,
        }),
      );
    }
  }

  /** Combon tog slut: Disco tonar ut. */
  onComboEnd(): void {
    if (!this.disco) return;
    this.scene.tweens.add({ targets: this.disco, alpha: 0, duration: FX.disco.decayMs, ease: 'Sine.easeIn' });
  }

  /** Fara (Tick): sepia + klockring i stället för desaturering. Ljudet byts i audio. */
  onDanger(on: boolean): void {
    const T = FX.tick;
    for (const o of [this.sepia, this.clock]) {
      if (!o) continue;
      this.scene.tweens.killTweensOf(o);
      const to = on ? (o === this.sepia ? this.ab.param('sepiaAlpha') : 1) : 0;
      this.scene.tweens.add({ targets: o, alpha: to, duration: on ? T.inMs : T.outMs });
    }
  }

  /** Nytt rekord (Fia): raketer + egen fanfar. Returnerar true om ordinarie ljud ska tystas. */
  onNewRecord(): boolean {
    if (this.ab.key !== 'recordFanfare' || !this.emitter) return false;
    const F = FX.fanfare;
    const n = this.count(this.ab.param('rockets'));
    const stars = this.count(this.ab.param('starsPerRocket'));
    for (let i = 0; i < n; i++) {
      const x = INNER_LEFT + ((i + 1) / (n + 1)) * (INNER_RIGHT - INNER_LEFT);
      const top = F.topY[i % F.topY.length];
      const color = hexToInt(F.colors[i % F.colors.length]);
      const r = this.scene.add.image(x, CAN.floorY, FX_DOT).setTint(color).setDepth(8).setBlendMode('ADD');
      this.scene.tweens.add({
        targets: r,
        y: top,
        delay: i * F.staggerMs,
        duration: F.riseMs,
        ease: 'Cubic.easeOut',
        onComplete: () => {
          r.destroy();
          this.emitter?.setParticleTint(color);
          this.emitter?.emitParticleAt(x, top, stars);
        },
      });
    }
    const steps = this.ab.p.fanfare;
    this.tone(Array.isArray(steps) ? { steps } : {});
    return true;
  }
}
