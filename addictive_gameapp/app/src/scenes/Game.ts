import Phaser from 'phaser';
import {
  CAN,
  CAN_LEFT,
  INNER_LEFT,
  INNER_RIGHT,
  PHYSICS,
  WORLD,
  densityFor,
} from '../data/physics';
import { MAX_LEVEL, TOP_PAIR_SCORE, radiusOf, scoreForCreating, scoreOf } from '../data/levels';
import { FEEL, JUICE, mergeIntensity } from '../data/juice';
import { DIRECTOR, SPECIALS, type SpecialType } from '../data/director';
import { INT, LEVEL_COLORS, THEME } from '../data/theme';
import {
  FX_GLITTER,
  FX_GLITTER_R,
  SPECIAL_BOMB,
  SPECIAL_RAINBOW,
  ballTextureKey,
  scaleForBodyRadius,
  silhouetteTextureKey,
} from '../ui/textures';
import { drawBackground } from '../ui/background';
import { iconTextureKey } from '../ui/icons';
import { resolveMerges, type MergeCandidate } from '../systems/merge';
import { findNearMiss, type NearMissItem } from '../systems/nearmiss';
import { createDirector, type Director, type DirectorMode, type DirectorState } from '../systems/director';
import { PACING, type PacingMode } from '../data/pacing';
import { AIM, type AimLineMode } from '../data/aim';
import { autoDropMsForDrop, createPacer, type Pacer, type PacerInput } from '../systems/pacing';
import { createComboTracker, type ComboTracker } from '../systems/combo';
import { createDangerTracker, type DangerTracker } from '../systems/danger';
import { Juice } from '../systems/juice';
import { playTone, unlockAudio } from '../systems/audio';
import { mulberry32, type Rng } from '../systems/rng';
import { COLLECTION, COLLECTION_FX, LEVEL_COUNT } from '../data/collection';
import {
  emptyPage,
  hasAnyShiny,
  onLevelCreated,
  pityThreshold,
  type CollectionState,
} from '../systems/collection';
import { cached, save, submitRun } from '../systems/save';

interface Ball {
  body: MatterJS.BodyType;
  img: Phaser.GameObjects.Image;
  level: number;
  aboveMs: number;
  /** Skapad av en merge (används för kedjedetektering). */
  fromMerge: boolean;
  landed: boolean;
  /** Specialobjekt, annars null. Specialobjekt mergear aldrig. */
  special: SpecialType | null;
  /** Tidpunkt för första kontakt (specialobjektens nödaktivering). */
  landedAt: number;
  activated: boolean;
  /** Ingår i ett near-miss-par just nu. */
  nearMiss: boolean;
  /** Puls pausad tills dess (landnings-/merge-tween äger skalan). */
  noPulseUntil: number;
  /** Skimrande (DESIGN §13.2). Försvinner när objektet mergeas vidare. */
  shiny: boolean;
  /** Glitterring, skapas första gången bollen blir skimrande och poolas med den. */
  glitter: Phaser.GameObjects.Image | null;
}

const L = THEME.layout;
const GL = COLLECTION_FX.glitter;
const CH = COLLECTION_FX.chain;
const PREVIEW_R = 24;
const DEG = Math.PI / 180;
/** Tak för mätbufferten i testhooken (DESIGN §11). */
const LATENCY_MAX = 500;
/** Rotation och skalpuls per specialobjekt (UI.md §4). */
const SPECIAL_FX = {
  bomb: {
    spin: THEME.special.bomb.spinDegPerSec * DEG,
    pulseMs: THEME.special.bomb.pulseMs,
    pulseScale: THEME.special.bomb.pulseScale,
    texture: SPECIAL_BOMB,
  },
  rainbow: {
    spin: THEME.special.rainbow.bandSpinDegPerSec * DEG,
    pulseMs: THEME.special.rainbow.pulseMs,
    pulseScale: THEME.special.rainbow.pulseScale,
    texture: SPECIAL_RAINBOW,
  },
} as const;

/** Sätts av testhooken `seed(n)` så e2e-körningar blir deterministiska. */
let SEED: number | null = null;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');

export class Game extends Phaser.Scene {
  private balls: Ball[] = [];
  private byId = new Map<number, Ball>();
  private pool: Ball[] = [];
  private candidates: MergeCandidate[] = [];
  /** Nivåer som kan mergea direkt (DESIGN §4). Återanvänds, aldrig ny Set per drop. */
  private mergeable = new Set<number>();
  private colTopY: number[] = [];
  private colTopIdx: number[] = [];
  /** Specialobjekt som ska aktiveras efter kollisionsloopen. */
  private actSpecial: Ball[] = [];
  private actOther: (Ball | null)[] = [];
  private nmItems: NearMissItem[] = [];
  private nmOut: number[] = [];
  private frame = 0;
  private pulseMs = 0;

  private director!: Director;
  private dirState: DirectorState = { mergeableLevels: this.mergeable };
  private combo!: ComboTracker;
  private dangerTracker!: DangerTracker;
  private juice!: Juice;

  private hanging: Phaser.GameObjects.Image | null = null;
  private aimLine!: Phaser.GameObjects.Graphics;
  private preview!: Phaser.GameObjects.Image;
  private previewFrame!: Phaser.GameObjects.Graphics;
  private previewTween: Phaser.Tweens.Tween | null = null;
  private scoreText!: Phaser.GameObjects.Text;
  private recordMarker!: Phaser.GameObjects.Container;
  private recordText!: Phaser.GameObjects.Text;
  private recordRing!: Phaser.GameObjects.Graphics;
  private recordTween: Phaser.Tweens.Tween | null = null;
  private comboDots: Phaser.GameObjects.Arc[] = [];
  private hand: Phaser.GameObjects.Container | null = null;

  // ---- samlarbok och kedja (DESIGN §13.1–13.2)
  private col!: CollectionState;
  private colRng!: Rng;
  /** Nivåer som skapats i rundan. Nivå 0 är alltid tänd. */
  private chainLit: boolean[] = new Array<boolean>(LEVEL_COUNT).fill(false);
  private chainImgs: Phaser.GameObjects.Image[] = [];
  private chainQ: Phaser.GameObjects.Text[] = [];

  private currentLevel = 0;
  private currentSpecial: SpecialType | null = null;
  private nextLevel = 0;
  private nextSpecial: SpecialType | null = null;
  private specialsActivated = 0;
  private score = 0;
  private bestLevel = 0;
  private dropIndex = 0;
  private aiming = false;
  /** Antal drops i rundan (manuella + auto). Styr auto-drop-rampen (DESIGN §12). */
  private dropsThisRun = 0;
  // ---- siktlinje (DESIGN §12). Alpha ändras bara vid tillståndsbyten, aldrig i update().
  private aimLineMode: AimLineMode = AIM.defaultMode;
  private aimLineShown = false;
  private aimTween: Phaser.Tweens.Tween | null = null;
  private over = false;
  private dropReadyAt = 0;
  private lastDropAt = 0;
  private baseMerges = 0;
  private runMerges = 0;
  private highscore = 0;
  private recordPulsing = false;
  private passedRecord = false;
  private pending: Ball | null = null;

  // ---- pacing (DESIGN §11). Allt återanvänds, update() allokerar inget.
  /** Kan bytas i testbygget via __game.setPacing(). */
  private pacingMode: PacingMode = PACING.mode;
  private pacer: Pacer = createPacer();
  /** Regissörens läge för objektet som hänger nu, respektive för det i kön. */
  private currentMode: DirectorMode = 'flow';
  private nextMode: DirectorMode = 'flow';
  private pacingIn: PacerInput = {
    mode: 'off',
    nowMs: 0,
    dropIndex: 0,
    directorMode: 'flow',
    isSpecial: false,
    isDanger: false,
    isTimeStopped: false,
    calm: false,
    hasDroppedThisRun: false,
  };
  /** Pacing vilar tills spelaren gjort sitt första egna drop i rundan (DESIGN §11). */
  private manualDropped = false;
  private autoDrops = 0;
  private baseAutoDrops = 0;
  /** Ringbuffert med ms från släppbar till drop (mätning, DESIGN §11). */
  private dropLatencies: number[] = [];
  private latencyIndex = 0;

  private onHide = (): void => {
    if (document.visibilityState === 'hidden') this.persist();
  };

  constructor() {
    super('Game');
  }

  create(): void {
    this.balls.length = 0;
    this.byId.clear();
    this.pool.length = 0;
    this.score = 0;
    this.bestLevel = 0;
    this.dropIndex = 0;
    this.dropsThisRun = 0;
    this.over = false;
    this.aiming = false;
    this.aimLineShown = false;
    this.aimTween = null;
    this.pending = null;
    this.dropReadyAt = 0;
    this.pacer.reset();
    this.manualDropped = false;
    this.currentMode = 'flow';
    this.nextMode = 'flow';
    this.autoDrops = 0;
    this.dropLatencies.length = 0;
    this.latencyIndex = 0;
    this.runMerges = 0;
    this.recordPulsing = false;
    this.passedRecord = false;
    this.recordTween = null;
    this.previewTween = null;
    this.hand = null;
    this.comboDots.length = 0;
    this.currentSpecial = null;
    this.nextSpecial = null;
    this.specialsActivated = 0;
    this.frame = 0;
    this.pulseMs = 0;
    this.mergeable.clear();

    const data = cached();
    this.aimLineMode = data.settings.aimLine ? AIM.defaultMode : 'off';
    this.highscore = data.highscore;
    this.baseMerges = data.stats.merges;
    this.baseAutoDrops = data.stats.autoDrops;
    void save({
      stats: {
        runs: data.stats.runs + 1,
        merges: data.stats.merges,
        autoDrops: data.stats.autoDrops,
      },
    });

    const seed = SEED ?? ((Date.now() ^ 0x9e3779b9) >>> 0);
    this.director = createDirector(mulberry32(seed));
    // Egen ström för skimrande så regissörens sekvens inte påverkas.
    this.colRng = mulberry32((seed ^ 0x5eed5) >>> 0);
    if (!data.collection[data.activeSet]) data.collection[data.activeSet] = emptyPage();
    this.col = {
      page: data.collection[data.activeSet],
      createdPerLevel: data.stats.createdPerLevel,
      shinyPity: data.stats.shinyPity,
      run: data.stats.runs + 1,
      everShiny: hasAnyShiny(data.collection),
    };
    this.chainLit.fill(false);
    this.chainLit[0] = true;
    this.chainImgs.length = 0;
    this.chainQ.length = 0;
    this.combo = createComboTracker();
    this.dangerTracker = createDangerTracker();
    this.takeNext();

    drawBackground(this);
    this.buildCan();
    this.buildHud();
    this.juice = new Juice(this, L.hud.scoreX, L.hud.scoreY, { ...data.settings });

    this.input.on('pointerdown', this.onPointerDown, this);
    this.input.on('pointermove', this.onPointerMove, this);
    this.input.on('pointerup', this.onPointerUp, this);
    this.matter.world.resume();
    this.matter.world.engine.timing.timeScale = 1;
    this.matter.world.on('collisionstart', this.onCollisionStart, this);
    document.addEventListener('visibilitychange', this.onHide);

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      document.removeEventListener('visibilitychange', this.onHide);
      this.matter.world?.off('collisionstart', this.onCollisionStart, this);
      this.juice.destroy();
      if (TEST_HOOK) delete (window as unknown as Record<string, unknown>).__game;
    });

    this.spawnHanging();
    this.lastDropAt = this.time.now;
    if (data.stats.runs === 0) this.showHand();

    if (TEST_HOOK) this.installTestHook();
  }

  private installTestHook(): void {
    const self = this;
    (window as unknown as Record<string, unknown>).__game = {
      get bodyCount(): number {
        return self.balls.length;
      },
      get score(): number {
        return self.score;
      },
      get over(): boolean {
        return self.over;
      },
      get combo(): number {
        return self.combo.state.combo;
      },
      get mode(): string {
        return self.director.mode;
      },
      get dropsSinceKick(): number {
        return self.director.dropsSinceKick;
      },
      /** Vad som ligger i förhandsvisningen: 'level' | 'bomb' | 'rainbow'. */
      get nextKind(): string {
        return self.nextSpecial ?? 'level';
      },
      get specialsActivated(): number {
        return self.specialsActivated;
      },
      /** Fast seed + omstart av rundan, för deterministiska e2e-körningar. */
      seed(n: number): void {
        SEED = n >>> 0;
        self.scene.restart();
      },
      drop(x: number): void {
        if (self.over) return;
        if (!self.hanging) self.spawnHanging();
        self.moveHangingTo(x);
        self.doDrop();
      },
      /** Antal objekt som just nu pulsar av near-miss. */
      get nearMissCount(): number {
        let n = 0;
        for (let i = 0; i < self.balls.length; i++) if (self.balls[i].nearMiss) n++;
        return n;
      },
      /** Tömmer burken (håller långa e2e-körningar vid liv utan att röra balansen). */
      clear(): void {
        for (let i = self.balls.length - 1; i >= 0; i--) self.removeBall(self.balls[i]);
      },
      /** Placerar ett objekt direkt (scenarier som near-miss och jackpot). */
      spawn(level: number, x: number, y: number): void {
        if (!self.over) self.addBall(x, y, level, false);
      },
      forceLoss(): void {
        self.gameOver();
      },
      /** Antal auto-drops i rundan (DESIGN §11). */
      get autoDrops(): number {
        return self.autoDrops;
      },
      /** ms från släppbar till drop, senaste 500. */
      get dropLatencies(): number[] {
        return self.dropLatencies.slice();
      },
      get pacingPhase(): string {
        return self.pacer.result.phase;
      },
      setPacing(mode: string): void {
        self.pacingMode = mode === 'off' ? 'off' : 'flow';
      },
      /** Auto-drop-tiden för det objekt som hänger nu (rampen, DESIGN §12). */
      get autoDropAtMs(): number {
        return autoDropMsForDrop(self.dropsThisRun);
      },
      /** 'always' | 'aiming' | 'off'. */
      get aimLineMode(): string {
        return self.aimLineMode;
      },
      get aimLineVisible(): boolean {
        return self.aimLine.alpha > 0.05;
      },
      setAimLine(mode: string): void {
        self.aimLineMode =
          mode === 'off' ? 'off' : mode === 'always' ? 'always' : 'aiming';
        self.refreshAimLine();
      },
      /** Kopia av samlarboken (DESIGN §13.2). */
      get collection(): unknown {
        return JSON.parse(JSON.stringify(cached().collection));
      },
      get chainLit(): boolean[] {
        return self.chainLit.slice();
      },
      /** Antal skimrande objekt i burken vars glitterring syns. */
      get glitterVisible(): number {
        let n = 0;
        for (let i = 0; i < self.balls.length; i++) {
          const b = self.balls[i];
          if (b.shiny && b.glitter?.visible) n++;
        }
        return n;
      },
      /** Nästa skapade objekt av nivån blir skimrande (via pity-garantin). */
      forceShiny(level: number): void {
        self.col.shinyPity[level] = pityThreshold(level, COLLECTION) - 1;
      },
    };
  }

  // ---------------------------------------------------------------- burk

  private buildCan(): void {
    const t = CAN.wallThickness;
    const h = CAN.floorY - CAN.topY;
    const g = this.add.graphics().setDepth(-5);
    g.fillStyle(INT.jarGlass, 0.55);
    g.fillRect(INNER_LEFT, CAN.topY, INNER_RIGHT - INNER_LEFT, h);
    g.fillStyle(INT.jarWall, 1);
    g.fillRect(CAN_LEFT, CAN.topY, t, h + t);
    g.fillRect(INNER_RIGHT, CAN.topY, t, h + t);
    g.fillStyle(INT.floor, 1);
    g.fillRect(CAN_LEFT, CAN.floorY, CAN.outerWidth, t);
    g.lineStyle(3, INT.jarEdge, 1);
    g.strokeRoundedRect(CAN_LEFT + 1.5, CAN.topY, CAN.outerWidth - 3, h + t, L.jar.cornerRadius);

    // Två diagonala reflexstreck (UI.md §7.2)
    const shine = this.add.graphics().setDepth(2);
    shine.lineStyle(8, INT.jarShine, 0.12);
    shine.lineBetween(44, 120, 80, 300);
    shine.lineStyle(4, INT.jarShine, 0.12);
    shine.lineBetween(62, 150, 88, 290);

    this.matter.add.rectangle(CAN_LEFT + t / 2, CAN.topY + h / 2, t, h, { isStatic: true });
    this.matter.add.rectangle(INNER_RIGHT + t / 2, CAN.topY + h / 2, t, h, { isStatic: true });
    this.matter.add.rectangle(WORLD.width / 2, CAN.floorY + t / 2, CAN.outerWidth, t, {
      isStatic: true,
    });

    this.buildDangerLine();
  }

  /** Streckad farolinje med tänder, pulsar 1 Hz i alpha (flash-guard ≤3 Hz). */
  private buildDangerLine(): void {
    const d = this.add.graphics().setDepth(4);
    d.lineStyle(3, INT.danger, 1);
    for (let x = INNER_LEFT; x < INNER_RIGHT; x += 22) {
      d.lineBetween(x, CAN.dangerY, Math.min(x + 12, INNER_RIGHT), CAN.dangerY);
    }
    for (let x = INNER_LEFT + 8; x < INNER_RIGHT; x += 40) {
      d.lineBetween(x, CAN.dangerY, x, CAN.dangerY + 7);
    }
    d.setAlpha(THEME.anim.dangerPulse.alphaFrom);
    this.tweens.add({
      targets: d,
      alpha: THEME.anim.dangerPulse.alphaTo,
      duration: JUICE.pulseHalfCycleMs.danger,
      ease: THEME.anim.dangerPulse.ease,
      yoyo: true,
      repeat: -1,
    });
  }

  // ---------------------------------------------------------------- HUD

  private buildHud(): void {
    this.scoreText = this.add
      .text(L.hud.scoreX, L.hud.scoreY, '0', {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.score}px`,
        color: THEME.palette.hud,
        fontStyle: THEME.type.weightHeavy,
      })
      .setDepth(10);

    this.recordRing = this.add.graphics().setDepth(9).setVisible(false);
    this.recordRing.lineStyle(3, INT.gold, 0.9);
    this.recordRing.strokeRoundedRect(L.hud.scoreX - 10, L.hud.scoreY - 6, 110, 46, 20);

    const crown = this.add.image(8, 0, iconTextureKey('crown')).setDisplaySize(16, 16);
    this.recordText = this.add
      .text(22, 0, `${this.highscore}`, {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.hudSmall}px`,
        color: THEME.palette.gold,
        fontStyle: THEME.type.weightHeavy,
      })
      .setOrigin(0, 0.5);
    this.recordMarker = this.add
      .container(L.hud.recordX, L.hud.recordY, [crown, this.recordText])
      .setDepth(10);

    for (let i = 0; i < FEEL.combo.maxDots; i++) {
      this.comboDots.push(
        this.add.circle(22 + i * 14, 86, 4, INT.accent).setDepth(10).setVisible(false),
      );
    }

    // Förhandsvisning: streckad ram + objektet.
    this.previewFrame = this.add.graphics().setDepth(10);
    this.drawPreviewFrame(INT.jarEdge);
    this.preview = this.add
      .image(L.preview.cx, L.preview.cy, ballTextureKey(this.nextLevel))
      .setDepth(10);
    this.showPreview();

    this.aimLine = this.add.graphics().setDepth(3).setAlpha(0);
    this.buildChain();
  }

  /** Kedjan (DESIGN §13.1): 11 siluetter i en rad under poängen. Byggs en gång per runda. */
  private buildChain(): void {
    const step = CH.size + CH.gap;
    const x0 = CH.cx - (LEVEL_COUNT * step - CH.gap) / 2 + CH.size / 2;
    const created = this.col.createdPerLevel;
    for (let i = 0; i < LEVEL_COUNT; i++) {
      const x = x0 + i * step;
      const lit = this.chainLit[i];
      const img = this.add
        .image(x, CH.y, lit ? ballTextureKey(i) : silhouetteTextureKey(i))
        .setScale(scaleForBodyRadius(i, CH.bodyR))
        .setAlpha(lit ? 1 : CH.unlitAlpha)
        .setDepth(5.5);
      const q = this.add
        .text(x, CH.y, '?', {
          fontFamily: THEME.type.family,
          fontSize: '12px',
          color: THEME.palette.hud,
          fontStyle: THEME.type.weightHeavy,
        })
        .setOrigin(0.5)
        .setDepth(5.6)
        .setVisible(!lit && i > 0 && created[i] === 0);
      this.chainImgs.push(img);
      this.chainQ.push(q);
    }
  }

  /** Tänder en nivå i kedjan: scale-punch 0,3 + kort pling. */
  private lightChain(level: number): void {
    this.chainLit[level] = true;
    const img = this.chainImgs[level];
    const base = scaleForBodyRadius(level, CH.bodyR);
    img.setTexture(ballTextureKey(level)).setAlpha(1);
    this.chainQ[level].setVisible(false);
    this.tweens.killTweensOf(img);
    this.tweens.add({
      targets: img,
      scale: { from: base * (1 + CH.punch), to: base },
      duration: CH.punchMs,
      ease: THEME.anim.mergePunch.ease,
    });
    playTone(COLLECTION_FX.sound.chain, level);
  }

  /**
   * En nivå har SKAPATS (merge eller regnbåge): fångst, skimrande och kedja.
   * Returnerar true om objektet blev skimrande.
   */
  private registerCreated(ball: Ball): boolean {
    const r = onLevelCreated(ball.level, this.col, this.colRng, COLLECTION);
    if (!this.chainLit[ball.level]) this.lightChain(ball.level);
    if (r.shiny) {
      this.makeShiny(ball);
      playTone(COLLECTION_FX.sound.shiny);
    }
    // Fångst skrivs direkt: progression får aldrig tappas.
    if (r.caught || r.newShiny) void save();
    return r.shiny;
  }

  private makeShiny(ball: Ball): void {
    ball.shiny = true;
    if (!ball.glitter) ball.glitter = this.add.image(0, 0, FX_GLITTER).setDepth(5.2);
    ball.glitter.setPosition(ball.body.position.x, ball.body.position.y).setVisible(true);
  }

  /** Ramen byter färg när ett specialobjekt ligger i kön (UI.md §4). */
  private drawPreviewFrame(color: number): void {
    const f = this.previewFrame;
    f.clear();
    f.lineStyle(2, color, 0.9);
    const bx = L.preview.cx - L.preview.boxW / 2;
    const by = L.preview.cy - L.preview.boxH / 2;
    for (let i = 0; i < 4; i++) {
      const along = 14 + i * 12;
      f.lineBetween(bx + along, by, bx + along + 7, by);
      f.lineBetween(bx + along, by + L.preview.boxH, bx + along + 7, by + L.preview.boxH);
      f.lineBetween(bx, by + along, bx, by + along + 7);
      f.lineBetween(bx + L.preview.boxW, by + along, bx + L.preview.boxW, by + along + 7);
    }
  }

  /** Visar nästa objekt. Specialobjekt: annan form, accent2-ram och puls ≤1 Hz. */
  private showPreview(): void {
    this.previewTween?.remove();
    this.previewTween = null;
    const sp = this.nextSpecial;
    const base = sp
      ? PREVIEW_R / SPECIALS.radius
      : scaleForBodyRadius(this.nextLevel, PREVIEW_R);
    this.preview.setTexture(this.textureFor(sp, this.nextLevel)).setScale(base).setRotation(0);
    this.drawPreviewFrame(sp ? INT.accent2 : INT.jarEdge);
    if (!sp) return;
    this.previewTween = this.tweens.add({
      targets: this.preview,
      scale: base * THEME.anim.previewPulse.scale,
      duration: JUICE.pulseHalfCycleMs.preview,
      ease: THEME.anim.previewPulse.ease,
      yoyo: true,
      repeat: -1,
    });
  }

  private textureFor(special: SpecialType | null, level: number): string {
    return special ? SPECIAL_FX[special].texture : ballTextureKey(level);
  }

  private radiusFor(special: SpecialType | null, level: number): number {
    return special ? SPECIALS.radius : radiusOf(level);
  }

  /**
   * Nivåer som kan mergea direkt (DESIGN §4): ovansidan inom 120 px från farolinjen,
   * eller översta objektet i sin kolumn. Återanvänder Set och arrayer.
   */
  private computeMergeable(): void {
    this.mergeable.clear();
    const cols = DIRECTOR.columns;
    const colW = (INNER_RIGHT - INNER_LEFT) / cols;
    for (let c = 0; c < cols; c++) {
      this.colTopY[c] = Infinity;
      this.colTopIdx[c] = -1;
    }
    for (let i = 0; i < this.balls.length; i++) {
      const b = this.balls[i];
      if (b.special) continue;
      const top = b.body.position.y - radiusOf(b.level);
      if (top - CAN.dangerY <= DIRECTOR.mergeableWithinPx) this.mergeable.add(b.level);
      let c = Math.floor((b.body.position.x - INNER_LEFT) / colW);
      if (c < 0) c = 0;
      else if (c >= cols) c = cols - 1;
      if (top < this.colTopY[c]) {
        this.colTopY[c] = top;
        this.colTopIdx[c] = i;
      }
    }
    for (let c = 0; c < cols; c++) {
      const i = this.colTopIdx[c];
      if (i >= 0) this.mergeable.add(this.balls[i].level);
    }
  }

  /** Hämtar nästa köobjekt från regissören. */
  private takeNext(): void {
    this.computeMergeable();
    const pick = this.director.next(this.dirState);
    this.nextMode = this.director.mode;
    if (pick.kind === 'special') {
      this.nextSpecial = pick.type;
    } else {
      this.nextSpecial = null;
      this.nextLevel = pick.level;
    }
  }

  private updateComboDots(): void {
    const n = Math.min(this.combo.state.combo, FEEL.combo.maxDots);
    for (let i = 0; i < this.comboDots.length; i++) this.comboDots[i].setVisible(i < n);
  }

  private checkRecord(): void {
    if (this.highscore <= 0) return;
    if (!this.passedRecord && this.score > this.highscore) {
      this.passedRecord = true;
      this.recordTween?.remove();
      this.recordTween = null;
      this.recordMarker.setScale(1);
      this.recordRing.setVisible(true);
      this.juice.trigger('newRecord', FEEL.record.newRecordIntensity, L.hud.scoreX + 40, L.hud.scoreY + 16);
      return;
    }
    if (!this.recordPulsing && !this.passedRecord && this.score >= this.highscore * FEEL.record.thresholdPct) {
      this.recordPulsing = true;
      this.juice.trigger('record', FEEL.record.intensity);
      this.recordTween = this.tweens.add({
        targets: this.recordMarker,
        scale: THEME.anim.recordPulse.scale,
        duration: JUICE.pulseHalfCycleMs.record,
        ease: THEME.anim.recordPulse.ease,
        yoyo: true,
        repeat: -1,
      });
    }
  }

  // ---------------------------------------------------------------- input

  private onPointerDown(p: Phaser.Input.Pointer): void {
    unlockAudio();
    if (this.over) return;
    this.aiming = true;
    this.moveHangingTo(p.worldX);
    this.refreshAimLine();
  }

  private onPointerMove(p: Phaser.Input.Pointer): void {
    if (this.over || !this.aiming) return;
    this.moveHangingTo(p.worldX);
  }

  private onPointerUp(): void {
    if (this.over || !this.aiming) return;
    this.aiming = false;
    this.refreshAimLine();
    this.doDrop();
  }

  private moveHangingTo(x: number): void {
    if (!this.hanging) return;
    const r = this.radiusFor(this.currentSpecial, this.currentLevel);
    const cx = Phaser.Math.Clamp(x, INNER_LEFT + r, INNER_RIGHT - r);
    this.hanging.x = cx;
    this.aimLine.x = cx;
  }

  private spawnHanging(): void {
    this.currentLevel = this.nextLevel;
    this.currentSpecial = this.nextSpecial;
    this.currentMode = this.nextMode;
    // Objektet är släppbart direkt när det hängts upp: pacing-timern startar här (§11).
    this.pacer.ready(this.time.now);
    this.dropIndex++;
    this.takeNext();

    const r = this.radiusFor(this.currentSpecial, this.currentLevel);
    const x = Phaser.Math.Clamp(
      this.hanging ? this.hanging.x : WORLD.width / 2,
      INNER_LEFT + r,
      INNER_RIGHT - r,
    );
    this.hanging = this.add
      .image(x, CAN.spawnY, this.textureFor(this.currentSpecial, this.currentLevel))
      .setDepth(6);
    this.showPreview();
    this.tweens.add({
      targets: this.hanging,
      scale: { from: 0.7, to: 1 },
      duration: THEME.anim.queueSlide.durationMs,
      ease: THEME.anim.queueSlide.ease,
    });
    this.drawAimLine(r);
    this.aimLine.x = x;
    this.refreshAimLine();
  }

  /** Streckad siktlinje, ritas om bara när radien ändras (aldrig per frame). */
  private drawAimLine(r: number): void {
    this.aimLine.clear();
    this.aimLine.lineStyle(2, INT.accent, 0.35);
    const len = 595 - (CAN.spawnY + r);
    for (let y = 0; y < len; y += 12) {
      this.aimLine.lineBetween(0, y, 0, Math.min(y + 4, len));
    }
    this.aimLine.y = CAN.spawnY + r;
  }

  /**
   * Siktlinjens synlighet (DESIGN §12): alltid i 'always', bara medan fingret siktar i
   * 'aiming', aldrig i 'off'. Anropas vid tillståndsbyten – aldrig per frame.
   */
  private refreshAimLine(): void {
    const show =
      this.hanging !== null &&
      (this.aimLineMode === 'always' || (this.aimLineMode === 'aiming' && this.aiming));
    if (show === this.aimLineShown) return;
    this.aimLineShown = show;
    this.aimTween?.remove();
    this.aimTween = this.tweens.add({
      targets: this.aimLine,
      alpha: show ? 1 : 0,
      duration: show ? AIM.fadeInMs : AIM.fadeOutMs,
      ease: 'Sine.easeOut',
      onComplete: () => {
        this.aimTween = null;
      },
    });
  }

  /** Enda vägen ner i burken. `auto` = mjuk auto-drop (§11), annars spelarens eget drop. */
  private doDrop(auto = false): void {
    if (this.over || !this.hanging) return;
    const x = this.hanging.x;
    const ready = this.pacer.readySinceMs;
    if (ready !== null) this.recordLatency(this.time.now - ready);
    if (auto) this.autoDrops++;
    else this.manualDropped = true;
    this.dropsThisRun++;
    this.pacer.drop();
    this.hanging.setRotation(0);
    this.hanging.destroy();
    this.hanging = null;
    this.aimTween?.remove();
    this.aimTween = null;
    this.aimLineShown = false;
    this.aimLine.clear();
    this.aimLine.setAlpha(0);
    const ball = this.addBall(x, CAN.spawnY, this.currentLevel, false, this.currentSpecial);
    if (this.currentSpecial) {
      this.juice.trigger('specialDrop', SPECIALS[this.currentSpecial].intensity, x, CAN.spawnY, {
        color: INT.accent2,
      });
    }
    this.pending = ball;
    this.dropReadyAt = this.time.now + PHYSICS.dropCooldownMs;
    this.lastDropAt = this.time.now;
    this.juice.trigger('drop', 0.2, x, CAN.spawnY);
    this.hideHand();
  }

  /** Ringbuffert, max 500 poster. Allokerar bara tills bufferten är full. */
  private recordLatency(ms: number): void {
    if (this.dropLatencies.length < LATENCY_MAX) {
      this.dropLatencies.push(ms);
      return;
    }
    this.dropLatencies[this.latencyIndex] = ms;
    this.latencyIndex = (this.latencyIndex + 1) % LATENCY_MAX;
  }

  // ---------------------------------------------------------------- bodies

  private addBall(
    x: number,
    y: number,
    level: number,
    fromMerge: boolean,
    special: SpecialType | null = null,
  ): Ball {
    const r = this.radiusFor(special, level);
    const body = this.matter.add.circle(x, y, r, {
      restitution: PHYSICS.restitution,
      friction: PHYSICS.friction,
      frictionStatic: PHYSICS.frictionStatic,
      frictionAir: PHYSICS.frictionAir,
      density: densityFor(r),
    }) as MatterJS.BodyType;

    const texture = this.textureFor(special, level);
    let ball = this.pool.pop();
    if (ball) {
      ball.body = body;
      ball.img.setTexture(texture).setScale(1).setRotation(0).setVisible(true).setPosition(x, y);
      ball.level = level;
      ball.aboveMs = 0;
      ball.fromMerge = fromMerge;
      ball.landed = false;
    } else {
      ball = {
        body,
        img: this.add.image(x, y, texture).setDepth(5),
        level,
        aboveMs: 0,
        fromMerge,
        landed: false,
        special: null,
        landedAt: 0,
        activated: false,
        nearMiss: false,
        noPulseUntil: 0,
        shiny: false,
        glitter: null,
      };
    }
    ball.shiny = false;
    ball.glitter?.setVisible(false);
    ball.special = special;
    ball.landedAt = 0;
    ball.activated = false;
    ball.nearMiss = false;
    ball.noPulseUntil = 0;
    this.balls.push(ball);
    this.byId.set(body.id, ball);
    if (!special && level > this.bestLevel) this.bestLevel = level;
    return ball;
  }

  private removeBall(ball: Ball): void {
    const i = this.balls.indexOf(ball);
    if (i >= 0) this.balls.splice(i, 1);
    this.byId.delete(ball.body.id);
    if (this.pending === ball) this.pending = null;
    this.matter.world.remove(ball.body);
    this.tweens.killTweensOf(ball.img);
    ball.img.setVisible(false).setScale(1);
    ball.shiny = false;
    ball.glitter?.setVisible(false);
    this.pool.push(ball);
  }

  private addScore(points: number): void {
    this.score += points;
    this.scoreText.setText(`${this.score}`);
    this.checkRecord();
  }

  // ---------------------------------------------------------- merge/kollision

  private onCollisionStart(event: {
    pairs: Phaser.Types.Physics.Matter.MatterCollisionData[];
  }): void {
    if (this.over) return;
    const pairs = event.pairs;
    this.candidates.length = 0;
    this.actSpecial.length = 0;
    this.actOther.length = 0;
    for (let i = 0; i < pairs.length; i++) {
      const bodyA = pairs[i].bodyA as MatterJS.BodyType;
      const bodyB = pairs[i].bodyB as MatterJS.BodyType;
      const a = this.byId.get(bodyA.id);
      const b = this.byId.get(bodyB.id);
      if (this.pending !== null && (a === this.pending || b === this.pending)) this.pending = null;
      if (a && !a.landed) this.land(a);
      if (b && !b.landed) this.land(b);
      // Specialobjekt aktiveras efter loopen (de kan ta bort andra objekt).
      if (a?.special) this.queueActivation(a, b ?? null);
      if (b?.special) this.queueActivation(b, a ?? null);
      if (!a || !b || a.special || b.special) continue;
      this.candidates.push({ a: bodyA.id, b: bodyB.id, levelA: a.level, levelB: b.level });
    }

    for (let i = 0; i < this.actSpecial.length; i++) {
      this.activateSpecial(this.actSpecial[i], this.actOther[i]);
    }

    if (this.candidates.length === 0) return;
    const merges = resolveMerges(this.candidates);
    for (let i = 0; i < merges.length; i++) {
      const a = this.byId.get(merges[i].a);
      const b = this.byId.get(merges[i].b);
      if (!a || !b) continue;
      this.applyMerge(a, b, merges[i].level);
    }
  }

  // ------------------------------------------------------------ specialobjekt

  /**
   * Bomben aktiveras vid första kontakt med VAD SOM HELST, regnbågen bara vid
   * kontakt med ett vanligt objekt (DESIGN §4).
   */
  private queueActivation(s: Ball, other: Ball | null): void {
    if (s.activated) return;
    if (s.special === 'rainbow' && (!other || other.special)) return;
    if (this.actSpecial.indexOf(s) >= 0) return;
    this.actSpecial.push(s);
    this.actOther.push(other && !other.special ? other : null);
  }

  private activateSpecial(s: Ball, other: Ball | null): void {
    if (s.activated || !s.special) return;
    s.activated = true;
    this.specialsActivated++;
    if (s.special === 'bomb') this.detonate(s);
    else this.upgrade(s, other);
  }

  /** Bomb: förstör allt inom blastRadius, poäng = summan av nivåernas poäng ×2. */
  private detonate(bomb: Ball): void {
    const x = bomb.body.position.x;
    const y = bomb.body.position.y;
    const r2 = SPECIALS.bomb.blastRadius * SPECIALS.bomb.blastRadius;
    this.removeBall(bomb);
    let sum = 0;
    for (let i = this.balls.length - 1; i >= 0; i--) {
      const b = this.balls[i];
      const dx = b.body.position.x - x;
      const dy = b.body.position.y - y;
      if (dx * dx + dy * dy > r2) continue;
      if (!b.special) sum += scoreOf(b.level);
      else b.activated = true;
      this.removeBall(b);
    }
    const points = sum * SPECIALS.bomb.scoreMultiplier;
    if (points > 0) this.addScore(points);
    this.juice.trigger('bomb', SPECIALS.bomb.intensity, x, y, {
      color: INT.accent2,
      score: points,
    });
  }

  /** Regnbåge: den och ett vanligt objekt av nivå n blir ett objekt av nivå n+1. */
  private upgrade(rainbow: Ball, other: Ball | null): void {
    const x = rainbow.body.position.x;
    const y = rainbow.body.position.y;
    this.removeBall(rainbow);
    if (!other || other.special || !this.byId.has(other.body.id)) {
      this.juice.trigger('special', SPECIALS.rainbow.intensity, x, y);
      return;
    }
    const level = other.level;
    const ox = other.body.position.x;
    const oy = other.body.position.y;
    this.removeBall(other);
    this.fuse(level, ox, oy, SPECIALS.rainbow.intensity);
  }

  /**
   * Två objekt av `level` blir ett av level+1 (nivå 10 → båda försvinner, 1000 p).
   * Sköter poäng och juice; jackpot får sitt eget event (UI.md §6).
   */
  private fuse(level: number, x: number, y: number, intensity: number): void {
    if (level >= MAX_LEVEL) {
      this.addScore(TOP_PAIR_SCORE);
      this.juice.trigger('jackpot', 1, x, y, { color: INT.gold, score: TOP_PAIR_SCORE });
      return;
    }
    const created = this.addBall(x, y, level + 1, true);
    created.noPulseUntil = this.time.now + JUICE.punch.durationMs;
    const shiny = this.registerCreated(created);
    const points = scoreForCreating(level + 1);
    this.addScore(points);
    const jackpot = level + 1 >= MAX_LEVEL;
    const bonus = shiny ? COLLECTION_FX.shinyIntensityBonus : 0;
    this.juice.trigger(jackpot ? 'jackpot' : 'special', jackpot ? 1 : Math.min(1, intensity + bonus), x, y, {
      target: created.img,
      color: LEVEL_COLORS[level + 1],
      score: points,
    });
  }

  /** Nödaktivering: ett specialobjekt får aldrig ligga kvar (DESIGN §4). */
  private forceActivate(s: Ball): void {
    if (s.special === 'bomb') {
      this.activateSpecial(s, null);
      return;
    }
    let best: Ball | null = null;
    let bestGap: number = SPECIALS.rainbow.reachPx;
    for (let i = 0; i < this.balls.length; i++) {
      const b = this.balls[i];
      if (b === s || b.special) continue;
      const dx = b.body.position.x - s.body.position.x;
      const dy = b.body.position.y - s.body.position.y;
      const gap = Math.sqrt(dx * dx + dy * dy) - SPECIALS.radius - radiusOf(b.level);
      if (gap < bestGap) {
        bestGap = gap;
        best = b;
      }
    }
    this.activateSpecial(s, best);
  }

  /** Första kontakten: "klunk" + squash. */
  private land(ball: Ball): void {
    ball.landed = true;
    ball.landedAt = this.time.now;
    const speed = Math.abs(ball.body.velocity.y);
    if (speed < 1.5) return;
    ball.noPulseUntil = this.time.now + THEME.anim.landSquash.durationMs;
    this.juice.trigger('land', Math.min(0.35, speed / 20), ball.img.x, ball.img.y);
    this.tweens.add({
      targets: ball.img,
      scaleY: { from: THEME.anim.landSquash.squashY, to: 1 },
      duration: THEME.anim.landSquash.durationMs,
      ease: THEME.anim.landSquash.ease,
    });
  }

  private applyMerge(a: Ball, b: Ball, level: number): void {
    const x = (a.body.position.x + b.body.position.x) / 2;
    const y = (a.body.position.y + b.body.position.y) / 2;
    const vx = (a.body.velocity.x + b.body.velocity.x) * 30;
    const vy = (a.body.velocity.y + b.body.velocity.y) * 30;
    const causedByMerge = a.fromMerge || b.fromMerge;
    this.removeBall(a);
    this.removeBall(b);

    const state = this.combo.merge(this.time.now, causedByMerge);
    this.runMerges++;

    let points: number;
    let target: Phaser.GameObjects.Image | undefined;
    let newLevel = level;
    let shiny = false;
    if (level >= MAX_LEVEL) {
      points = TOP_PAIR_SCORE;
    } else {
      newLevel = level + 1;
      const created = this.addBall(x, y, newLevel, true);
      created.noPulseUntil = this.time.now + JUICE.punch.durationMs;
      target = created.img;
      shiny = this.registerCreated(created);
      points = scoreForCreating(newLevel);
    }
    this.addScore(points);
    this.updateComboDots();

    const jackpot = newLevel >= MAX_LEVEL;
    const color = jackpot ? INT.gold : LEVEL_COLORS[newLevel];
    const chain = state.chain >= FEEL.chain.minLength;
    const event = jackpot ? 'jackpot' : chain ? 'chain' : 'merge';
    const base = jackpot
      ? 1
      : chain
        ? FEEL.chain.intensity
        : mergeIntensity(newLevel, state.combo);
    const intensity = Math.min(1, base + (shiny ? COLLECTION_FX.shinyIntensityBonus : 0));
    this.juice.trigger(event, intensity, x, y, {
      target,
      color,
      vx,
      vy,
      combo: state.combo,
      score: points,
    });

    this.kickNeighbours(x, y);
  }

  private kickNeighbours(x: number, y: number): void {
    const rad = PHYSICS.mergeNeighbourRadius;
    for (let i = 0; i < this.balls.length; i++) {
      const o = this.balls[i];
      const dx = o.body.position.x - x;
      const dy = o.body.position.y - y;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d < 0.001 || d > rad) continue;
      const f = (PHYSICS.mergeNeighbourImpulse * (1 - d / rad)) / d;
      this.matter.body.applyForce(o.body, o.body.position, { x: dx * f, y: dy * f });
    }
  }

  // ---------------------------------------------------------------- onboarding

  private showHand(): void {
    if (this.hand) return;
    const hand = this.add.image(0, 0, iconTextureKey('hand')).setDisplaySize(56, 56);
    const swipe = this.add.image(0, 56, iconTextureKey('swipe')).setDisplaySize(84, 22);
    // y ovanför farolinjen (110) så gesten aldrig överlappar den.
    this.hand = this.add
      .container(150, FEEL.onboarding.handY, [hand, swipe])
      .setDepth(15)
      .setAlpha(0);
    this.tweens.chain({
      targets: this.hand,
      loop: -1,
      tweens: [
        { alpha: 1, duration: 200 },
        { scale: 0.88, duration: 200, ease: THEME.anim.buttonPress.ease },
        { x: 230, duration: 800, ease: THEME.anim.handLoop.ease },
        { x: 150, duration: 400, ease: THEME.anim.handLoop.ease },
        { scale: 1, alpha: 0, duration: 200, ease: THEME.anim.buttonRelease.ease },
        { alpha: 0, duration: 400 },
      ],
    });
  }

  private hideHand(): void {
    if (!this.hand) return;
    this.tweens.killTweensOf(this.hand);
    this.hand.destroy();
    this.hand = null;
  }

  // ---------------------------------------------------------------- loop

  override update(_time: number, delta: number): void {
    if (this.over) return;
    const now = this.time.now;

    // Near-miss räknas om throttlat (DESIGN §5), aldrig varje frame.
    this.frame++;
    if (this.frame % FEEL.nearMiss.checkEveryFrames === 0) this.checkNearMiss();

    // Synkron puls för alla near-miss-objekt: 500/600 ms ⇒ 0,83 Hz.
    this.pulseMs += delta;
    const nmPhase = (this.pulseMs / (FEEL.nearMiss.halfCycleMs * 2)) * Math.PI * 2;
    const nmScale = 1 + (FEEL.nearMiss.scale - 1) * (0.5 - 0.5 * Math.cos(nmPhase));
    // Glitterpuls ≤1 Hz, gemensam för alla skimrande objekt (flash-guard).
    const glw = 0.5 - 0.5 * Math.cos((this.pulseMs / (GL.halfCycleMs * 2)) * Math.PI * 2);
    const glAlpha = GL.alphaMin + (GL.alphaMax - GL.alphaMin) * glw;
    const glScale = 1 + GL.scaleAmp * glw;
    const glRot = (this.pulseMs / 1000) * GL.spinDegPerSec * DEG;

    // Bild följer fysikkroppen. Inga allokeringar.
    for (let i = 0; i < this.balls.length; i++) {
      const b = this.balls[i];
      b.img.x = b.body.position.x;
      b.img.y = b.body.position.y;
      if (b.special) {
        const fx = SPECIAL_FX[b.special];
        b.img.rotation += fx.spin * (delta / 1000);
        const p = (this.pulseMs / (fx.pulseMs * 2)) * Math.PI * 2;
        b.img.setScale(1 + (fx.pulseScale - 1) * (0.5 - 0.5 * Math.cos(p)));
        if (!b.activated && b.landed && now - b.landedAt > SPECIALS.fallbackMs) {
          this.forceActivate(b);
        }
        continue;
      }
      b.img.rotation = b.body.angle;
      if (b.shiny && b.glitter) {
        b.glitter.x = b.img.x;
        b.glitter.y = b.img.y;
        b.glitter.rotation = glRot;
        b.glitter.alpha = glAlpha;
        b.glitter.setScale(((radiusOf(b.level) * GL.ringRadius) / FX_GLITTER_R) * glScale);
      }
      if (b.nearMiss) {
        b.img.setScale(nmScale);
      } else if (b.img.scaleX !== 1 && now >= b.noPulseUntil && !this.tweens.isTweening(b.img)) {
        b.img.setScale(1);
      }
    }

    this.juice.update(delta);
    if (this.combo.tick(now)) this.updateComboDots();

    if (!this.hanging && (this.pending === null || now >= this.dropReadyAt)) {
      this.spawnHanging();
      if (cached().stats.runs === 0 && now - this.lastDropAt > FEEL.onboarding.idleMs) {
        this.showHand();
      }
    }

    this.updatePacing(now);

    let near = false;
    for (let i = 0; i < this.balls.length; i++) {
      const ball = this.balls[i];
      if (ball === this.pending) {
        ball.aboveMs = 0;
        continue;
      }
      const y = ball.body.position.y;
      if (y < CAN.dangerY + FEEL.danger.marginPx) near = true;
      if (y < CAN.dangerY) {
        ball.aboveMs += delta;
        if (ball.aboveMs >= PHYSICS.lossGraceMs) {
          this.gameOver();
          return;
        }
      } else {
        ball.aboveMs = 0;
      }
    }

    const signal = this.dangerTracker.update(now, near);
    if (signal === 'start') this.juice.trigger('danger', 1);
    else if (signal === 'end') this.juice.endDanger();
  }

  /**
   * Mjuk auto-drop (DESIGN §11): vickning på bilden (aldrig på fysikkroppen), och efter
   * 6 s samma kodväg som ett pointerup. Håller spelaren fingret nere väntar auto-droppet.
   */
  private updatePacing(now: number): void {
    if (!this.hanging) return;
    const p = this.pacingIn;
    p.mode = this.pacingMode;
    p.nowMs = now;
    p.dropIndex = this.dropsThisRun;
    p.directorMode = this.currentMode;
    p.isSpecial = this.currentSpecial !== null;
    p.isDanger = this.dangerTracker.active;
    p.isTimeStopped = this.juice.timeAltered;
    p.calm = cached().settings.calm;
    p.hasDroppedThisRun = this.manualDropped;

    const out = this.pacer.update(p);
    this.hanging.setRotation(out.wobbleAngleDeg * DEG);
    if (out.phase === 'autodrop' && !this.aiming) this.doDrop(true);
  }

  /** Flaggar objekten (nivå ≥8) som ligger nära varandra utan att nudda. */
  private checkNearMiss(): void {
    const n = this.balls.length;
    for (let i = 0; i < n; i++) {
      const b = this.balls[i];
      let it = this.nmItems[i];
      if (!it) {
        it = { level: 0, x: 0, y: 0, r: 0 };
        this.nmItems[i] = it;
      }
      it.level = b.special ? -1 : b.level;
      it.x = b.body.position.x;
      it.y = b.body.position.y;
      it.r = this.radiusFor(b.special, b.level);
      b.nearMiss = false;
    }
    findNearMiss(this.nmItems, n, FEEL.nearMiss, this.nmOut);
    const now = this.time.now;
    for (let k = 0; k < this.nmOut.length; k++) {
      const b = this.balls[this.nmOut[k]];
      if (now >= b.noPulseUntil) b.nearMiss = true;
    }
  }

  // ---------------------------------------------------------------- slut

  private persist(): void {
    void save({
      stats: {
        runs: cached().stats.runs,
        merges: this.baseMerges + this.runMerges,
        autoDrops: this.baseAutoDrops + this.autoDrops,
      },
    });
    void submitRun(this.score, this.bestLevel);
  }

  private gameOver(): void {
    if (this.over) return;
    this.over = true;
    this.hideHand();
    this.juice.endDanger();
    this.juice.trigger('loss', 0.5, WORLD.width / 2, CAN.dangerY);
    const score = this.score;
    const bestLevel = this.bestLevel;
    void save({
      stats: {
        runs: cached().stats.runs,
        merges: this.baseMerges + this.runMerges,
        autoDrops: this.baseAutoDrops + this.autoDrops,
      },
    });
    void submitRun(score, bestLevel).then((record) => {
      this.scene.pause();
      this.scene.launch('GameOver', { score, bestLevel, record, highscore: cached().highscore });
    });
  }
}
