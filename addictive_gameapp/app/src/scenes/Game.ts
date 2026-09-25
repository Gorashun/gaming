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
import { INT, THEME, hexToInt } from '../data/theme';
import { CHAIN_STEPS, META, META_COLORS, META_SOUND, setPalette, themeSetById } from '../data/themes';
import {
  FX_GLITTER,
  FX_GLITTER_R,
  FX_RING,
  FX_RING_R,
  SPECIAL_BOMB,
  SPECIAL_RAINBOW,
  ballTextureKey,
  loadedBallSets,
  particleTextureKey,
  scaleForBodyRadius,
  silhouetteTextureKey,
  useSet,
} from '../ui/textures';
import { drawBackground } from '../ui/background';
import { iconTextureKey } from '../ui/icons';
import { resolveMerges, type MergeCandidate } from '../systems/merge';
import { findNearMiss, type NearMissCfg, type NearMissItem } from '../systems/nearmiss';
import { createDirector, type Director, type DirectorMode, type DirectorState } from '../systems/director';
import { PACING, type PacingMode } from '../data/pacing';
import { AIM, type AimLineMode } from '../data/aim';
import { autoDropMsForDrop, createPacer, type Pacer, type PacerInput } from '../systems/pacing';
import { createComboTracker, type ComboTracker } from '../systems/combo';
import { createDangerTracker, type DangerTracker } from '../systems/danger';
import { Juice } from '../systems/juice';
import { playTone, setMergeTimbre, timbrePlayCount, unlockAudio } from '../systems/audio';
import { mulberry32, type Rng } from '../systems/rng';
import { COLLECTION, COLLECTION_FX, LEVEL_COUNT } from '../data/collection';
import {
  emptyPage,
  filledSlots,
  hasAnyShiny,
  onLevelCreated,
  pityThreshold,
  type CollectionState,
} from '../systems/collection';
import { evaluateUnlocks, nextSetProgress } from '../systems/unlocks';
import { cached, save, submitRun } from '../systems/save';
import { openBox } from '../systems/boxes';
import {
  buyPick,
  buyShell,
  claimFreeShells,
  earnForRun,
  milestoneFlags,
  offerPick3,
  setShopMode,
  shopMode,
  upgrade,
  type Earned,
} from '../systems/economy';
import type { ShellType, ShopMode } from '../data/economy';
import type { RevealCatch, RevealData } from './GameOver';
import { Abilities, findMagnetPair, type AbilityLevel, type MagnetItem } from '../systems/abilities';
import { ABILITY_FX } from '../data/abilities';
import { AVATARS, AVATAR_UI } from '../data/avatarsIndex';
import { Buddy } from '../ui/buddy';
import { AbilityFx } from '../ui/abilityFx';
import { DEBUG } from '../data/debug';
import { pushRun, setRestart, summarizeRun, takeRestartTap } from '../systems/debug';
import { clearBackHandler, setBackHandler } from '../systems/back';
import { ART_LOG, Z, fitCamera } from '../ui/view';
import { ART } from '../data/art';
import { PerfGuard } from '../systems/perfGuard';

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
  /** Lykt-Lisas ring (förmåga), skapas vid behov och poolas med bollen. */
  lamp: Phaser.GameObjects.Image | null;
}

const L = THEME.layout;
const GL = COLLECTION_FX.glitter;
const CH = META.chain;
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
/** Testhookens `setPacing` gäller även efter omstart (som SEED). */
let PACING_OVERRIDE: PacingMode | null = null;
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
  /** Fps-vakten (DESIGN §17). Bara när Z > 1 och inget tak är satt; ny per runda (egen uppvärmning). */
  private perf: PerfGuard | null = null;

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
  private chainGlitter: boolean[] = new Array<boolean>(LEVEL_COUNT).fill(false);
  private chain!: Phaser.GameObjects.Container;
  /** Raden är osynlig tills första merge (allra första rundan). */
  private chainHidden = false;
  private chainDim = false;
  private chainDimTween: Phaser.Tweens.Tween | null = null;
  private chainGoalIdx = -1;
  private chainGoalTween: Phaser.Tweens.Tween | null = null;

  // ---- temaset och rundavslut (DESIGN §13.3–13.4)
  private levelColors: number[] = [];
  private seedUsed = 0;
  private startMerges = 0;
  private baseDoubleKlunks = 0;
  private runDoubleKlunks = 0;
  private filledAtStart = 0;
  /** Platser som fyllts i rundan, i ordning (flyger in i boken i rundavslutet). */
  private runCatches: RevealCatch[] = [];

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
  /** Avataren som var vald vid rundstart (byte gäller från nästa runda, DESIGN §14.6). */
  private runAvatar = '';
  /** Merges som redan skrivits som XP (XP batchas till rundslut och visibilitychange). */
  /** Rundans räknare för stjärnsand (DESIGN §16.1) och vad rundan redan fått utbetalt. */
  private runShinies = 0;
  private runChains3 = 0;
  private runLevel10s = 0;
  private runPaid = { pearls: 0, sand: 0 };
  /** Allt rundan betalat ut (inkl. milstolpar), för rundavslutets räkning (UI.md §14.6). */
  private runEarned = { pearls: 0, sand: 0 };
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
  /** Regissörens läge per latens (index i DEBUG.modes), samma ringindex som dropLatencies. */
  private latencyModes: number[] = [];
  private latencyIndex = 0;
  /** Rundlogg för debugpanelen (PLAYTEST.md §3): drop per läge, starttid, första merge. */
  private modeDrops: number[] = [0, 0, 0];
  private runT0 = 0;
  private runStartedAt = 0;
  private firstMergeMs: number | null = null;

  // ---- kompisar och förmågor (DESIGN §14, UI.md §13.5/13.8). Allt skapas vid rundstart.
  private buddy: Buddy | null = null;
  private abil!: Abilities;
  private afx!: AbilityFx;
  private nmCfg!: NearMissCfg;
  /** Siri: objektet efter nästa. */
  private afterReady = false;
  private afterLevel = 0;
  private afterSpecial: SpecialType | null = null;
  private afterMode: DirectorMode = 'flow';
  private ghost: Phaser.GameObjects.Image | null = null;
  /** Sixten: landningsprick. */
  private landing: Phaser.GameObjects.Graphics | null = null;
  /** Bubbel: objektet som faller utan studs och dess bubbelhinna. */
  private bubbleBall: Ball | null = null;
  private bubble: Phaser.GameObjects.Image | null = null;
  /** Maja: kandidatpar, tid sedan det uppstod, pågående drag. */
  private magnetItems: MagnetItem[] = [];
  private magnetOut: number[] = [0, 0];
  private magnetA = -1;
  private magnetB = -1;
  private magnetSince = 0;
  private pullA: Ball | null = null;
  private pullB: Ball | null = null;
  private pullUntil = 0;
  private pullV = 0;
  private pullLines: Phaser.GameObjects.Graphics | null = null;
  private readonly tmpV = { x: 0, y: 0 };
  /** Klick: rundans längsta kedja och högsta nivå (polaroid). */
  private bestChain = 0;
  private photoLevel = 0;
  private photos: string[] = [];
  private snapQueue: number[] = [];
  /** Guldstjärnor (skimrande skapas) och "?"-tändningens partiklar i setets form (UI.md §12.2–12.3). */
  private starFx!: Phaser.GameObjects.Particles.ParticleEmitter;
  private chainFx!: Phaser.GameObjects.Particles.ParticleEmitter;
  private calm = false;
  /** Testhook: antal utbrott i rundan. */
  private fxCounts = { stars: 0, chainFirst: 0 };

  private onHide = (): void => {
    if (document.visibilityState === 'hidden') this.persist();
  };

  constructor() {
    super('Game');
  }

  create(): void {
    fitCamera(this);
    this.perf = Z > 1 && cached().settings.zoomCap === null ? new PerfGuard(ART.perfGuard) : null;
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
    this.latencyModes.length = 0;
    this.latencyIndex = 0;
    this.modeDrops.fill(0);
    this.runT0 = performance.now();
    this.runStartedAt = Date.now();
    this.firstMergeMs = null;
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
    this.pacingMode = data.debug.autoDropOff ? 'off' : (PACING_OVERRIDE ?? PACING.mode);
    const firstRun = data.stats.runs === 0;
    this.aimLineMode = data.settings.aimLine ? AIM.defaultMode : 'off';
    this.highscore = data.highscore;
    this.baseMerges = data.stats.merges;
    this.startMerges = data.stats.merges;
    this.baseAutoDrops = data.stats.autoDrops;
    this.baseDoubleKlunks = data.stats.doubleKlunks;
    this.runDoubleKlunks = 0;
    this.runCatches = [];
    this.runAvatar = data.avatars.equipped;
    this.runShinies = 0;
    this.runChains3 = 0;
    this.runLevel10s = 0;
    this.runPaid = { pearls: 0, sand: 0 };
    this.runEarned = { pearls: 0, sand: 0 };
    // Förmågan (DESIGN §14.5) för kompisen som var vald vid rundstart, på dess nivå.
    const avLevel = (data.avatars.level[this.runAvatar] ?? 1) as AbilityLevel;
    this.abil = new Abilities(this.runAvatar, avLevel, PHYSICS.lossGraceMs);
    const ov = this.abil.o;
    this.buddy = null;
    this.afterReady = false;
    this.ghost = null;
    this.landing = null;
    this.bubbleBall = null;
    this.bubble = null;
    this.magnetA = -1;
    this.magnetB = -1;
    this.pullA = null;
    this.pullB = null;
    this.pullLines = null;
    this.bestChain = 0;
    this.photoLevel = 0;
    this.photos = [];
    this.snapQueue = [];
    // Aktivt set gäller från rundstart och byts aldrig mitt i en runda (DESIGN §13.3).
    const set = themeSetById(data.activeSet);
    useSet(this, set.id, ov.glowBonus);
    setMergeTimbre(set.sound);
    this.levelColors = set.levels.map((l) => hexToInt(l.color));
    void save({
      stats: {
        runs: data.stats.runs + 1,
        merges: data.stats.merges,
        autoDrops: data.stats.autoDrops,
      },
    });

    const seed = SEED ?? ((Date.now() ^ 0x9e3779b9) >>> 0);
    this.seedUsed = seed;
    this.director = createDirector(mulberry32(seed));
    this.director.setSeedQueue(ov.seedQueue);
    this.nmCfg = {
      minLevel: ov.nearMissMinLevel ?? FEEL.nearMiss.minLevel,
      minGapPx: FEEL.nearMiss.minGapPx,
      maxGapPx: FEEL.nearMiss.maxGapPx,
    };
    // Egen ström för skimrande så regissörens sekvens inte påverkas.
    this.colRng = mulberry32((seed ^ 0x5eed5) >>> 0);
    if (!data.collection[data.activeSet]) data.collection[data.activeSet] = emptyPage();
    this.col = {
      page: data.collection[data.activeSet],
      createdPerLevel: data.stats.createdPerLevel,
      shinyPity: data.stats.shinyPity,
      run: data.stats.runs + 1,
      everShiny: hasAnyShiny(data.collection),
      shinyMul: ov.shinyMul,
    };
    this.filledAtStart = filledSlots(this.col.page);
    this.chainLit.fill(false);
    this.chainLit[0] = true;
    this.chainGlitter.fill(false);
    this.chainImgs.length = 0;
    this.chainQ.length = 0;
    this.chainHidden = firstRun;
    this.chainDim = false;
    this.chainDimTween = null;
    this.chainGoalIdx = -1;
    this.chainGoalTween = null;
    this.combo = createComboTracker();
    this.dangerTracker = createDangerTracker();
    this.takeNext();

    drawBackground(this, set.id, { still: data.settings.calm, starSky: ov.starSky ? ABILITY_FX.starWhale : undefined });
    const pal = setPalette(set);
    const Q = ABILITY_FX.queen;
    this.buildCan(ov.goldJar ? { ...pal, jarEdge: Q.jarEdge, jarShine: Q.jarShine } : pal);
    this.buildHud();
    this.juice = new Juice(this, L.hud.scoreX, L.hud.scoreY, { ...data.settings }, set.particle);
    this.afx = new AbilityFx(this, this.abil, data.settings.calm, this.juice);
    this.calm = data.settings.calm;
    this.fxCounts.stars = 0;
    this.fxCounts.chainFirst = 0;
    const ST = META.shiny.stars;
    this.starFx = this.add
      .particles(0, 0, particleTextureKey('star'), {
        lifespan: ST.lifeMs,
        speed: { min: ST.speedMin, max: ST.speedMax },
        angle: { min: 0, max: 360 },
        scale: { start: ST.scale, end: 0 },
        alpha: { start: 1, end: 0 },
        rotate: { start: 0, end: ST.spinDeg },
        emitting: false,
        maxAliveParticles: META.shiny.sparks * 4,
      })
      .setDepth(5.6);
    const CF = CH.first;
    this.chainFx = this.add
      .particles(0, 0, particleTextureKey(set.particle.shape), {
        lifespan: CF.lifeMs,
        speed: { min: CF.speedMin, max: CF.speedMax },
        angle: { min: 0, max: 360 },
        scale: { start: CF.scale, end: 0 },
        alpha: { start: 1, end: 0 },
        emitting: false,
        maxAliveParticles: CF.particles * 6,
      })
      .setDepth(5.6);
    if (AVATARS.some((a) => a.id === this.runAvatar)) {
      this.buddy = new Buddy(this, this.runAvatar, avLevel, data.settings.calm, this.juice);
    }

    this.input.on('pointerdown', this.onPointerDown, this);
    this.input.on('pointermove', this.onPointerMove, this);
    this.input.on('pointerup', this.onPointerUp, this);
    this.matter.world.resume();
    // resume() sätter runnerns klocka till "nu", efter den här framens tid: första deltat blir negativt
    // och fastnar om spelet går under 15 fps (Matter återanvänder då senaste delta) – fysiken står still.
    // Nollställd klocka ⇒ första framen använder standarddeltat.
    (this.matter.world.runner as unknown as { timeLastTick: number }).timeLastTick = 0;
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
    if (firstRun) this.showHand();

    // Omstart från förlustskärmen: rundan är spelbar nu (rundloggen).
    const tap = takeRestartTap();
    if (tap) {
      setRestart(data.debug.runs, tap.afterLossMs, performance.now() - tap.tapAt);
      void save();
    }

    // Bakåtknappen mitt i rundan: rundan avslutas som en förlust och spelet går till startskärmen.
    const onBack = (): boolean => {
      this.quitToStart();
      return true;
    };
    setBackHandler(onBack);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => clearBackHandler(onBack));

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
        PACING_OVERRIDE = self.pacingMode;
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
      // ---- temaset (DESIGN §13.3)
      get activeSet(): string {
        return cached().activeSet;
      },
      get unlockedSets(): string[] {
        return cached().unlockedSets.slice();
      },
      get freshSet(): string | null {
        return cached().freshSet;
      },
      /** Lägger till merges på tidsspåret (räknas vid rundavslutet). */
      grantMerges(n: number): void {
        self.baseMerges += n;
      },
      // ---- kompisar (DESIGN §14)
      get avatars(): unknown {
        return JSON.parse(JSON.stringify(cached().avatars));
      },
      get pendingBoxes(): number {
        return cached().avatars.pendingBoxes;
      },
      /** Öppnar en mussla direkt (även utan oöppnad på hyllan) och sparar. */
      openBox(): unknown {
        const av = cached().avatars;
        const r = openBox(av, mulberry32((self.seedUsed ^ (av.boxesOpened * 0x9e3779b1)) >>> 0));
        void save();
        return r;
      },
      // ---- ekonomi (DESIGN §16)
      get economy(): unknown {
        return JSON.parse(JSON.stringify(cached().economy));
      },
      grantPearls(n: number): void {
        cached().economy.pearls += Math.max(0, Math.floor(n));
        void save();
      },
      grantSand(n: number): void {
        cached().economy.sand += Math.max(0, Math.floor(n));
        void save();
      },
      buyShell(type: string): unknown {
        const d = cached();
        const r = buyShell(d, type as ShellType, mulberry32((self.seedUsed ^ Math.imul(d.avatars.boxesOpened + 1, 0x9e3779b1)) >>> 0));
        void save();
        return r;
      },
      upgrade(id: string): boolean {
        const ok = upgrade(cached(), id);
        void save();
        return ok;
      },
      get shopMode(): string {
        return shopMode();
      },
      setShopMode(m: string): void {
        setShopMode(m as ShopMode);
      },
      offerPick3(type: string): string[] {
        const d = cached();
        return offerPick3(d, type as ShellType, mulberry32((self.seedUsed ^ Math.imul(d.avatars.boxesOpened + 7, 0x9e3779b1)) >>> 0)).map((a) => a.id);
      },
      buyPick(type: string, id: string): unknown {
        const r = buyPick(cached(), type as ShellType, id);
        void save();
        return r;
      },
      /** Väljer aktivt set (bara upplåsta). Gäller från nästa runda. */
      setActiveSet(id: string): boolean {
        if (!cached().unlockedSets.includes(id)) return false;
        void save({ activeSet: id });
        return true;
      },
      /** Texturnyckeln för objektet som hänger nu, t.ex. 'ball-planeterna-2'. */
      get textureKey(): string {
        return (self.hanging ?? self.preview).texture.key;
      },
      /** Antal merge-klanger som spelats (ljudvägen per set körs). */
      get timbrePlays(): number {
        return timbrePlayCount();
      },
      // ---- Släpparen och förmågor (DESIGN §14.1, §14.5)
      /** Äger och väljer en kompis på nivån (1–3) och startar om rundan. */
      equipForTest(id: string, level = 1): void {
        const av = cached().avatars;
        if (!av.owned.includes(id)) av.owned.push(id);
        const lv = (level >= 3 ? 3 : level === 2 ? 2 : 1) as AbilityLevel;
        av.level[id] = lv;
        av.equipped = id;
        void save();
        self.scene.restart();
      },
      get abilityState(): unknown {
        const a = self.abil;
        return {
          id: a.id,
          key: a.key,
          level: a.level,
          lisa: { active: a.lisaActive, oilMs: a.lisaOilMs },
          maja: { usesLeft: a.magnetLeft, pulling: self.pullA !== null },
          vala: { usesLeft: a.breathLeft, breathing: a.breathing, graceMs: self.dangerTracker.graceMs },
          bubbel: { left: a.noBounceLeft },
          siri: { afterKind: self.ghost ? self.afterSpecial ?? 'level' : null },
          nearMissMinLevel: self.nmCfg.minLevel,
          shinyMul: self.col.shinyMul ?? 1,
          chainShakeMul: self.juice.chainShakeMul,
        };
      },
      /** Släpparen syns (figur på greppunkten). */
      get buddy(): { id: string; x: number; y: number; visible: boolean } | null {
        const b = self.buddy;
        return b ? { id: b.def.id, x: b.img.x, y: b.img.y, visible: b.img.visible } : null;
      },
      /** Nivån på objektet som hänger nu (-1 = specialobjekt). */
      /** Fps-vakten: fönstrens medel-fps, fönster i rad under gränsen, utlöst. null = inaktiv (Z = 1 eller tak satt). */
      get perf(): { windows: number[]; low: number; tripped: boolean; z: number; zoomCap: number | null } | null {
        const p = self.perf;
        return p && { windows: p.recent.slice(), low: p.low, tripped: p.tripped, z: Z, zoomCap: cached().settings.zoomCap };
      },
      /** Matar vakten med `ms` millisekunder frames i `fps` (samma väg som update). */
      perfSimulate(fps: number, ms: number): void {
        for (let t = 0; t < ms; t += 1000 / fps) self.feedPerf(1000 / fps);
      },
      /** Det hängande objektets x (logiska px), -1 utan objekt. */
      get hangingX(): number {
        return self.hanging ? self.hanging.x : -1;
      },
      /** Nivåset i full upplösning i minnet (Art v2-budgeten). */
      get ballSets(): string[] {
        return loadedBallSets(self);
      },
      get hangingLevel(): number {
        return self.currentSpecial ? -1 : self.currentLevel;
      },
      /** Utbrott i rundan: guldstjärnor (skimrande) och "?"-tändningar i kedjan. */
      get fxCounts(): { stars: number; chainFirst: number } {
        return { ...self.fxCounts };
      },
      /** Lisas oljemätare syns (Lykt-Lisa). */
      get lanternMeterVisible(): boolean {
        return self.afx.lanternMeterVisible;
      },
      /** Antal objekt med synlig lyktring (Lykt-Lisa). */
      get lampsVisible(): number {
        let n = 0;
        for (let i = 0; i < self.balls.length; i++) if (self.balls[i].lamp?.visible) n++;
        return n;
      },
      /** Ett objekt som sitter fast (statisk kropp), för farogräns-scenarier. */
      pin(level: number, x: number, y: number): void {
        if (self.over) return;
        const b = self.addBall(x, y, level, false);
        self.matter.body.setStatic(b.body, true);
      },
    };
  }

  // ---------------------------------------------------------------- burk

  private buildCan(pal: { jarGlass: string; jarWall: string; floor: string; jarEdge: string; jarShine: string }): void {
    const t = CAN.wallThickness;
    const h = CAN.floorY - CAN.topY;
    const g = this.add.graphics().setDepth(-5);
    g.fillStyle(hexToInt(pal.jarGlass), 0.55);
    g.fillRect(INNER_LEFT, CAN.topY, INNER_RIGHT - INNER_LEFT, h);
    g.fillStyle(hexToInt(pal.jarWall), 1);
    g.fillRect(CAN_LEFT, CAN.topY, t, h + t);
    g.fillRect(INNER_RIGHT, CAN.topY, t, h + t);
    g.fillStyle(hexToInt(pal.floor), 1);
    g.fillRect(CAN_LEFT, CAN.floorY, CAN.outerWidth, t);
    g.lineStyle(3, hexToInt(pal.jarEdge), 1);
    g.strokeRoundedRect(CAN_LEFT + 1.5, CAN.topY, CAN.outerWidth - 3, h + t, L.jar.cornerRadius);

    // Två diagonala reflexstreck (UI.md §7.2)
    const shine = this.add.graphics().setDepth(2);
    shine.lineStyle(8, hexToInt(pal.jarShine), 0.12);
    shine.lineBetween(44, 120, 80, 300);
    shine.lineStyle(4, hexToInt(pal.jarShine), 0.12);
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
        this.add.circle(22 + i * 14, CH.comboDotsY, 4, INT.accent).setDepth(10).setVisible(false),
      );
    }

    // Förhandsvisning: streckad ram + objektet.
    this.previewFrame = this.add.graphics().setDepth(10);
    this.drawPreviewFrame(INT.jarEdge);
    this.preview = this.add
      .image(L.preview.cx, L.preview.cy, ballTextureKey(this.nextLevel))
      .setDepth(10);
    if (this.abil.o.peekSteps >= 2) {
      // Siri: objektet efter nästa, mindre och till vänster, i streckad ram (UI.md §13.8).
      const S = ABILITY_FX.siri;
      const f = this.add.graphics().setDepth(10);
      f.lineStyle(2, INT.jarEdge, 0.7);
      const h = S.frame / 2;
      for (let d = -h; d < h; d += 8) {
        const e = Math.min(d + 4, h);
        f.lineBetween(S.x + d, S.y - h, S.x + e, S.y - h);
        f.lineBetween(S.x + d, S.y + h, S.x + e, S.y + h);
        f.lineBetween(S.x - h, S.y + d, S.x - h, S.y + e);
        f.lineBetween(S.x + h, S.y + d, S.x + h, S.y + e);
      }
      this.ghost = this.add.image(S.x, S.y, ballTextureKey(0)).setDepth(10).setAlpha(this.abil.param('ghostAlpha'));
    }
    this.showPreview();

    this.aimLine = this.add.graphics().setDepth(3).setAlpha(0);
    if (this.abil.key === 'landingDot') this.landing = this.add.graphics().setDepth(5.05);
    this.buildChain();
  }

  /** Kedjans kroppsradie per nivå: 5,0 … 8,5 px (UI.md §12.2). */
  private chainR(level: number): number {
    return CH.r0 + CH.rStep * level;
  }

  /**
   * Kedjan (DESIGN §13.1, UI.md §12.2): 11 siluetter vänsterställda under highscore-markören.
   * Siluetterna är vita texturer som tintas. Byggs en gång per runda.
   */
  private buildChain(): void {
    const created = this.col.createdPerLevel;
    const sil = hexToInt(META_COLORS.silhouette);
    this.chain = this.add.container(0, 0).setDepth(5.5).setAlpha(this.chainHidden ? 0 : 1);
    for (let i = 0; i < LEVEL_COUNT; i++) {
      const x = CH.x0 + CH.pitch * i;
      const lit = this.chainLit[i];
      const img = this.add
        .image(x, CH.y, lit ? ballTextureKey(i) : silhouetteTextureKey(i))
        .setScale(scaleForBodyRadius(i, this.chainR(i)));
      if (!lit) img.setTint(sil);
      const q = this.add
        .text(x, CH.y, '?', {
          fontFamily: THEME.type.family,
          fontSize: `${CH.qmarkPx}px`,
          color: META_COLORS.qmark,
          fontStyle: THEME.type.weightHeavy,
          stroke: THEME.palette.bg,
          strokeThickness: 2,
        })
        .setOrigin(0.5)
        .setVisible(!lit && created[i] === 0);
      this.chain.add([img, q]);
      this.chainImgs.push(img);
      this.chainQ.push(q);
    }
    this.updateChainGoal();
  }

  /** Målpuls (0,5 Hz) på nästa "?" ovanför högsta tända nivå. Bara en plats åt gången. */
  private updateChainGoal(): void {
    let top = 0;
    for (let i = 0; i < LEVEL_COUNT; i++) if (this.chainLit[i]) top = i;
    let goal = -1;
    for (let i = top + 1; i < LEVEL_COUNT; i++) {
      if (this.chainQ[i].visible) {
        goal = i;
        break;
      }
    }
    if (goal === this.chainGoalIdx) return;
    this.chainGoalTween?.remove();
    this.chainGoalTween = null;
    const old = this.chainGoalIdx;
    if (old >= 0 && !this.chainLit[old]) this.chainImgs[old].setScale(scaleForBodyRadius(old, this.chainR(old)));
    this.chainGoalIdx = goal;
    if (goal < 0) return;
    const base = scaleForBodyRadius(goal, this.chainR(goal));
    this.chainGoalTween = this.tweens.add({
      targets: this.chainImgs[goal],
      scale: base * CH.goalPulse.scale,
      duration: CH.goalPulse.halfCycleMs,
      ease: CH.goalPulse.ease,
      yoyo: true,
      repeat: -1,
    });
  }

  /** Raden tonas ned när det hängande objektet ligger över den (siktet går före HUD). */
  private updateChainDim(): void {
    if (!this.hanging || this.chainHidden) return;
    const r = this.radiusFor(this.currentSpecial, this.currentLevel);
    const over = this.hanging.x <= CH.dim.right + r;
    if (over === this.chainDim) return;
    this.chainDim = over;
    this.chainDimTween?.remove();
    this.chainDimTween = this.tweens.add({
      targets: this.chain,
      alpha: over ? CH.dim.alpha : 1,
      duration: over ? CH.dim.inMs : CH.dim.outMs,
    });
  }

  /** Tänder en nivå i kedjan: punch 0,6 → 1,3 → 1,0, ring i nivåns färg och pling. */
  private lightChain(level: number): void {
    this.chainLit[level] = true;
    const img = this.chainImgs[level];
    const q = this.chainQ[level];
    const first = q.visible;
    const r = this.chainR(level);
    const base = scaleForBodyRadius(level, r);
    if (this.chainGoalIdx === level) {
      this.chainGoalTween?.remove();
      this.chainGoalTween = null;
      this.chainGoalIdx = -1;
    }
    this.tweens.killTweensOf(img);
    img.setTexture(ballTextureKey(level)).clearTint().setScale(base * 0.6);
    this.tweens.chain({
      targets: img,
      tweens: [
        { scale: base * CH.punch.peak, duration: CH.punch.upMs, ease: CH.punch.easeUp, delay: CH.lightDelayMs },
        { scale: base, duration: CH.punch.downMs, ease: CH.punch.easeDown },
      ],
    });
    if (first) {
      this.tweens.add({
        targets: q,
        scale: 0,
        duration: CH.qmarkOutMs,
        onComplete: () => q.setVisible(false).setScale(1),
      });
    }
    // "?" tänds: ringen dubbleras (andra 100 ms senare) och 3 partiklar i setets form.
    const rings = first ? CH.first.rings : 1;
    for (let k = 0; k < rings; k++) {
      const ring = this.add
        .image(img.x, img.y, FX_RING)
        .setTint(this.levelColors[level])
        .setScale(r / FX_RING_R)
        .setAlpha(0);
      this.chain.add(ring);
      this.tweens.add({
        targets: ring,
        scale: (r * CH.ring.toR) / FX_RING_R,
        alpha: { from: CH.ring.alpha, to: 0 },
        delay: CH.lightDelayMs + k * CH.first.ringStepMs,
        duration: CH.ring.ms,
        ease: CH.ring.ease,
        onComplete: () => ring.destroy(),
      });
    }
    if (first) {
      this.fxCounts.chainFirst++;
      this.time.delayedCall(CH.lightDelayMs, () => {
        this.chainFx.setParticleTint(this.levelColors[level]);
        this.chainFx.emitParticleAt(img.x, img.y, CH.first.particles);
      });
    }
    playTone(first ? META_SOUND.chainFirst : META_SOUND.chainLight, CHAIN_STEPS[level]);
    this.updateChainGoal();
  }

  /** Statisk mini-glitterring på kedjeplatsen när en skimrande skapats i rundan. */
  private chainShiny(level: number): void {
    if (this.chainGlitter[level]) return;
    this.chainGlitter[level] = true;
    const img = this.chainImgs[level];
    this.chain.add(
      this.add
        .image(img.x, img.y, FX_GLITTER)
        .setScale((this.chainR(level) * GL.ringRadius) / FX_GLITTER_R),
    );
  }

  /**
   * En nivå har SKAPATS (merge eller regnbåge): fångst, skimrande och kedja.
   * Returnerar true om objektet blev skimrande.
   */
  private registerCreated(ball: Ball): boolean {
    const r = onLevelCreated(ball.level, this.col, this.colRng, COLLECTION);
    if (r.shiny) this.runShinies++;
    if (ball.level >= MAX_LEVEL) this.runLevel10s++;
    if (this.chainHidden) {
      this.chainHidden = false;
      this.tweens.add({ targets: this.chain, alpha: 1, duration: CH.firstRunFadeMs });
    }
    if (!this.chainLit[ball.level]) {
      this.lightChain(ball.level);
      this.buddy?.on('newLevel');
      if (this.abil.key === 'sonarNewLevel') this.sonar(ball.level);
    }
    if (r.shiny) {
      this.makeShiny(ball);
      this.shinyStars(ball.body.position.x, ball.body.position.y);
      this.chainShiny(ball.level);
      playTone(COLLECTION_FX.sound.shiny);
    }
    if (r.caught) this.runCatches.push({ level: ball.level, shiny: false });
    if (r.newShiny) this.runCatches.push({ level: ball.level, shiny: true });
    // Fångst skrivs direkt: progression får aldrig tappas.
    if (r.caught || r.newShiny) void save();
    return r.shiny;
  }

  /** Ekko: alla objekt av nivån får en expanderande ring, N gånger 1 Hz (flash-guard). */
  private sonar(level: number): void {
    const E = ABILITY_FX.ekko;
    const n = this.abil.param('pulses');
    const period = this.abil.param('periodMs');
    const scale = this.abil.param('ringScale');
    const r = radiusOf(level);
    for (let k = 0; k < n; k++) {
      this.time.delayedCall(k * period, () => {
        if (this.over) return;
        for (let i = 0; i < this.balls.length; i++) {
          const b = this.balls[i];
          if (b.special || b.level !== level) continue;
          this.juice.ringAt(b.img.x, b.img.y, { count: 1, fromR: r, maxR: r * scale, durationMs: E.ms, stepMs: 0, color: E.color, alpha: E.alpha });
        }
        playTone(META_SOUND.chainLight, CHAIN_STEPS[level]);
      });
    }
  }

  /** Sex guldstjärnor (varannan vit) när en skimrande skapas, oavsett set. Lugnt läge: hälften. */
  private shinyStars(x: number, y: number): void {
    const n = this.calm ? Math.ceil(META.shiny.sparks / 2) : META.shiny.sparks;
    const gold = Math.ceil(n / 2);
    this.starFx.setParticleTint(INT.gold);
    this.starFx.emitParticleAt(x, y, gold);
    this.starFx.setParticleTint(INT.hud);
    this.starFx.emitParticleAt(x, y, n - gold);
    this.fxCounts.stars++;
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
    if (this.ghost) {
      const gr = this.abil.param('ghostR');
      const a = this.afterSpecial;
      this.ghost
        .setTexture(this.textureFor(a, this.afterLevel))
        .setScale(a ? gr / SPECIALS.radius : scaleForBodyRadius(this.afterLevel, gr));
    }
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

  /** Hämtar nästa köobjekt från regissören. Siri (förmåga): kön är ett steg längre. */
  private takeNext(): void {
    if (this.abil.o.peekSteps < 2) {
      this.pull();
      return;
    }
    if (!this.afterReady) {
      this.pull();
      this.afterReady = true;
    } else {
      this.nextLevel = this.afterLevel;
      this.nextSpecial = this.afterSpecial;
      this.nextMode = this.afterMode;
    }
    const level = this.nextLevel;
    const special = this.nextSpecial;
    const mode = this.nextMode;
    this.pull();
    this.afterLevel = this.nextLevel;
    this.afterSpecial = this.nextSpecial;
    this.afterMode = this.nextMode;
    this.nextLevel = level;
    this.nextSpecial = special;
    this.nextMode = mode;
  }

  /** Ett val från regissören till next*-fälten. */
  private pull(): void {
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
      const own = this.afx.onNewRecord();
      this.juice.trigger('newRecord', FEEL.record.newRecordIntensity, L.hud.scoreX + 40, L.hud.scoreY + 16, own ? { mute: true } : undefined);
      this.buddy?.on('record');
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
    this.buddy?.followX(cx);
    this.updateChainDim();
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
    this.updateChainDim();
    if (this.buddy) {
      const first = this.dropIndex === 1;
      this.buddy.followX(x);
      this.buddy.setGrip(CAN.spawnY - r + AVATAR_UI.slapparen.gripBelowTop, !first);
    }
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
    const mode = DEBUG.modes.indexOf(this.currentMode);
    if (ready !== null) this.recordLatency(this.time.now - ready, mode);
    this.modeDrops[mode]++;
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
    this.buddy?.onDrop(ball.img);
    if (this.abil.takeNoBounce()) this.startBubble(ball);
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
  private recordLatency(ms: number, mode: number): void {
    if (this.dropLatencies.length < LATENCY_MAX) {
      this.dropLatencies.push(ms);
      this.latencyModes.push(mode);
      return;
    }
    this.dropLatencies[this.latencyIndex] = ms;
    this.latencyModes[this.latencyIndex] = mode;
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
        lamp: null,
      };
    }
    ball.shiny = false;
    ball.glitter?.setVisible(false);
    ball.lamp?.setVisible(false).setAlpha(0);
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
    ball.lamp?.setVisible(false).setAlpha(0);
    if (this.bubbleBall === ball) this.endBubble();
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
      // Bubbel: paret löses före studsen, så restitution 0 gäller just den här landningen.
      if (this.bubbleBall && (a === this.bubbleBall || b === this.bubbleBall)) (pairs[i] as unknown as { restitution: number }).restitution = 0;
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
      this.runDoubleKlunks++;
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
      color: this.levelColors[level + 1],
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

  /** Bubbel: rundans första N drop landar utan studs, med en bubbelhinna tills landning. */
  private startBubble(ball: Ball): void {
    const B = ABILITY_FX.bubbel;
    ball.body.restitution = 0;
    this.bubbleBall = ball;
    if (!this.bubble) this.bubble = this.add.image(0, 0, FX_RING).setDepth(5.3).setTint(hexToInt(B.color));
    this.bubble
      .setPosition(ball.img.x, ball.img.y)
      .setScale((this.radiusFor(ball.special, ball.level) * B.rMul) / FX_RING_R)
      .setAlpha(B.alpha)
      .setVisible(true);
  }

  private endBubble(): void {
    if (this.bubbleBall) this.bubbleBall.body.restitution = PHYSICS.restitution;
    this.bubbleBall = null;
    this.bubble?.setVisible(false);
  }

  /** Första kontakten: "klunk" + squash. */
  private land(ball: Ball): void {
    ball.landed = true;
    ball.landedAt = this.time.now;
    if (this.bubbleBall === ball) this.endBubble();
    if (!ball.fromMerge) this.buddy?.on('land');
    this.buddy?.onLand(ball.img);
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
    if (state.chainTriggered) this.runChains3++;
    if (this.firstMergeMs === null) this.firstMergeMs = Math.round(performance.now() - this.runT0);

    let points: number;
    let target: Phaser.GameObjects.Image | undefined;
    let newLevel = level;
    let shiny = false;
    if (level >= MAX_LEVEL) {
      points = TOP_PAIR_SCORE;
      this.runDoubleKlunks++;
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
    const color = jackpot ? INT.gold : this.levelColors[newLevel];
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

    // Kompisen och förmågorna (ingen av dem rör poängen).
    const bud = this.buddy;
    if (bud) {
      if (level >= MAX_LEVEL) bud.on('klunk');
      else if (chain) bud.on('chain');
      else bud.on('merge', state.combo);
      if (state.combo === 3) bud.on('combo3');
    }
    this.afx.onMerge(x, y, newLevel, state.combo);
    if (chain) this.afx.onChain(x, y, state.chain);
    if (this.abil.key === 'polaroid') this.maybePhoto(state.chain, newLevel);

    this.kickNeighbours(x, y);
  }

  /** Klick: ögonblicksbild av burken när rundans längsta kedja (och III: högsta nivå) toppar. */
  private maybePhoto(chain: number, level: number): void {
    if (chain > this.bestChain) {
      this.bestChain = chain;
      this.snapJar(0);
    }
    if (this.abil.param('photos') >= 2 && level > this.photoLevel) {
      this.photoLevel = level;
      this.snapJar(1);
    }
  }

  /** Renderaren tar en ögonblicksbild i taget; fler köas. */
  private snapJar(i: number): void {
    if (this.snapQueue.includes(i)) return;
    this.snapQueue.push(i);
    if (this.snapQueue.length === 1) this.nextSnap();
  }

  private nextSnap(): void {
    if (this.snapQueue.length === 0 || !this.sys.isActive()) return;
    const key = `polaroid-${this.snapQueue[0]}`;
    const P = ABILITY_FX.polaroid;
    const w = INNER_RIGHT - INNER_LEFT;
    const h = Math.round((w * P.h) / P.w);
    // snapshotArea läser enhetspixlar i canvasen (hi-DPI: logiskt × Z).
    this.game.renderer.snapshotArea(INNER_LEFT * Z, (CAN.floorY - h) * Z, w * Z, h * Z, (img) => {
      this.snapQueue.shift();
      if (img instanceof HTMLImageElement) {
        if (this.textures.exists(key)) this.textures.remove(key);
        this.textures.addImage(key, img);
        if (!this.photos.includes(key)) this.photos.push(key);
      }
      this.nextSnap();
    });
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

  /** Låg fps i Z > 1 ⇒ tak Z = cap från nästa appstart (aldrig mitt i rundan). */
  private feedPerf(delta: number): void {
    if (!this.perf?.feed(delta)) return;
    void save({ settings: { zoomCap: ART.perfGuard.cap } });
    if (ART_LOG) console.log(`[perf] fps-vakt: ${this.perf.recent.map((f) => f.toFixed(1)).join(', ')} ⇒ zoomCap ${ART.perfGuard.cap}`);
  }

  override update(_time: number, delta: number): void {
    this.feedPerf(delta);
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
    // Lykt-Lisa: lyktan lyser medan man siktar, så länge oljan räcker (förmåga).
    const lamp = this.abil.tickAim(delta, this.aiming && this.hanging !== null && this.currentSpecial === null);
    const lampK = Math.min(1, delta / ABILITY_FX.lisa.inMs);

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
      if (b.lamp || (lamp && b.level === this.currentLevel)) this.updateLamp(b, lamp && b.level === this.currentLevel, lampK);
      if (b.nearMiss) {
        b.img.setScale(nmScale);
      } else if (b.img.scaleX !== 1 && now >= b.noPulseUntil && !this.tweens.isTweening(b.img)) {
        b.img.setScale(1);
      }
    }

    this.juice.update(delta);
    if (this.combo.tick(now)) {
      this.updateComboDots();
      this.afx.onComboEnd();
    }
    this.buddy?.update(delta, this.pending?.img ?? null);
    if (this.buddy) this.afx.lantern(this.buddy.img);
    if (this.bubbleBall && this.bubble) this.bubble.setPosition(this.bubbleBall.img.x, this.bubbleBall.img.y);
    if (this.landing && this.frame % 2 === 0) this.drawLanding();
    if (this.abil.key === 'magnetPull') this.updateMagnet(now);

    if (!this.hanging && (this.pending === null || now >= this.dropReadyAt)) {
      this.spawnHanging();
      if (cached().stats.runs === 0 && now - this.lastDropAt > FEEL.onboarding.idleMs) {
        this.showHand();
      }
    }

    this.updatePacing(now);

    let near = false;
    let maxAbove = 0;
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
        if (ball.aboveMs > maxAbove) maxAbove = ball.aboveMs;
      } else {
        ball.aboveMs = 0;
      }
    }
    // Förlustgränsen kan förlängas av en förmåga (Andrums-Vala), annars PHYSICS.lossGraceMs.
    const wasBreathing = this.abil.breathing;
    this.dangerTracker.graceMs = this.abil.lossGrace(maxAbove);
    if (this.abil.breathing && !wasBreathing) this.breathFx();
    if (maxAbove >= this.dangerTracker.graceMs) {
      this.gameOver();
      return;
    }

    const signal = this.dangerTracker.update(now, near);
    if (signal === 'start') {
      this.juice.trigger('danger', 1);
      this.buddy?.setDanger(true);
      this.afx.onDanger(true);
    } else if (signal === 'end') {
      this.juice.endDanger();
      this.buddy?.setDanger(false);
      this.afx.onDanger(false);
    }
  }

  /** Lisas ring runt ett objekt av samma nivå: tonas in/ut, ingen puls. */
  private updateLamp(b: Ball, on: boolean, k: number): void {
    const A = ABILITY_FX.lisa;
    if (!b.lamp) b.lamp = this.add.image(0, 0, FX_RING).setDepth(5.1).setTint(hexToInt(A.color)).setAlpha(0);
    const lamp = b.lamp;
    const to = on && !b.special ? this.abil.param('ringAlpha') : 0;
    lamp.alpha += (to - lamp.alpha) * k;
    lamp.visible = lamp.alpha > 0.01;
    if (!lamp.visible) return;
    lamp.x = b.img.x;
    lamp.y = b.img.y;
    lamp.setScale((radiusOf(b.level) * A.ringR) / FX_RING_R);
  }

  /** Andrums-Vala: en blå fontän i burkens hals när ett andetag används. */
  private breathFx(): void {
    const c = ABILITY_FX.vala.color;
    this.juice.ringAt(WORLD.width / 2, CAN.dangerY, { count: 2, fromR: 10, maxR: 60, durationMs: 600, stepMs: 200, color: c, alpha: 0.8 });
    this.buddy?.setDanger(true);
  }

  /**
   * Sikt-Sixten: prick där det hängande objektet först träffar något (golv eller objekt), rakt
   * under siktet. II–III: streckad kontur på landningsplatsen. Följer siktlinjens inställning.
   */
  private drawLanding(): void {
    const g = this.landing!;
    g.clear();
    const show = this.hanging !== null && (this.aimLineMode === 'always' || this.aiming);
    if (!show) return;
    const x = this.hanging!.x;
    const r = this.radiusFor(this.currentSpecial, this.currentLevel);
    let cy = CAN.floorY - r;
    let px = x;
    let py = CAN.floorY;
    for (let i = 0; i < this.balls.length; i++) {
      const b = this.balls[i];
      if (b === this.pending) continue;
      const br = this.radiusFor(b.special, b.level);
      const dx = b.body.position.x - x;
      const R = r + br;
      if (Math.abs(dx) >= R) continue;
      const y = b.body.position.y - Math.sqrt(R * R - dx * dx);
      if (y >= cy) continue;
      cy = y;
      px = x + (dx * r) / R;
      py = y + ((b.body.position.y - y) * r) / R;
    }
    if (cy < CAN.spawnY) return;
    const c = hexToInt(ABILITY_FX.sixten.color);
    const ghost = this.abil.param('ghostAlpha');
    if (ghost > 0) {
      g.lineStyle(2, c, ghost);
      for (let a = 0; a < Math.PI * 2; a += 0.5) {
        g.beginPath();
        g.arc(x, cy, r, a, a + 0.25, false);
        g.strokePath();
      }
    }
    g.fillStyle(c, 0.9);
    g.fillCircle(px, py, this.abil.param('dotR'));
  }

  /**
   * Magnet-Maja: två lika (ej nivå 10) som ligger stilla med gap < range i 400 ms dras ihop på
   * 300 ms, med fältlinjer. Automatiskt, N gånger per runda, aldrig under fara.
   */
  private updateMagnet(now: number): void {
    const M = ABILITY_FX.maja;
    if (this.pullA && this.pullB) {
      const a = this.pullA;
      const b = this.pullB;
      const g = this.pullLines!;
      g.clear();
      if (now >= this.pullUntil || !this.byId.has(a.body.id) || !this.byId.has(b.body.id)) {
        this.pullA = null;
        this.pullB = null;
        return;
      }
      const dx = b.body.position.x - a.body.position.x;
      const dy = b.body.position.y - a.body.position.y;
      const d = Math.sqrt(dx * dx + dy * dy) || 1;
      const v = this.tmpV;
      v.x = (dx / d) * this.pullV;
      v.y = (dy / d) * this.pullV;
      this.matter.body.setVelocity(a.body, v);
      v.x = -v.x;
      v.y = -v.y;
      this.matter.body.setVelocity(b.body, v);
      g.lineStyle(2, hexToInt(M.lineColor), 0.7);
      for (let k = -1; k <= 1; k++) {
        const ox = (-dy / d) * k * 6;
        const oy = (dx / d) * k * 6;
        g.lineBetween(a.img.x + ox, a.img.y + oy, b.img.x + ox, b.img.y + oy);
      }
      return;
    }
    if (this.abil.magnetLeft <= 0 || this.frame % M.checkEveryFrames !== 0) return;
    const n = this.balls.length;
    for (let i = 0; i < n; i++) {
      const b = this.balls[i];
      let it = this.magnetItems[i];
      if (!it) {
        it = { level: 0, x: 0, y: 0, r: 0, speed: 0 };
        this.magnetItems[i] = it;
      }
      it.level = b.special || b === this.pending ? -1 : b.level;
      it.x = b.body.position.x;
      it.y = b.body.position.y;
      it.r = this.radiusFor(b.special, b.level);
      it.speed = b.body.speed;
    }
    const found = findMagnetPair(this.magnetItems, n, this.abil.param('rangePx'), M.maxLevel, M.stillSpeed, this.magnetOut);
    if (!found) {
      this.magnetA = -1;
      return;
    }
    const ida = this.balls[this.magnetOut[0]].body.id;
    const idb = this.balls[this.magnetOut[1]].body.id;
    if (ida !== this.magnetA || idb !== this.magnetB) {
      this.magnetA = ida;
      this.magnetB = idb;
      this.magnetSince = now;
      return;
    }
    if (now - this.magnetSince < M.stillMs || !this.abil.tryMagnet(this.dangerTracker.active)) return;
    const a = this.balls[this.magnetOut[0]];
    const b = this.balls[this.magnetOut[1]];
    const ia = this.magnetItems[this.magnetOut[0]];
    const ib = this.magnetItems[this.magnetOut[1]];
    const gap = Math.hypot(ib.x - ia.x, ib.y - ia.y) - ia.r - ib.r;
    this.pullA = a;
    this.pullB = b;
    this.pullUntil = now + M.pullMs;
    // px per fysiksteg (16,7 ms) så att gapet sluts inom pullMs, plus lite marginal.
    this.pullV = gap / 2 / (M.pullMs / 16.7) + 0.3;
    this.magnetA = -1;
    if (!this.pullLines) this.pullLines = this.add.graphics().setDepth(5.4);
    playTone(META_SOUND.chainFirst);
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
    this.buddy?.setWobble(out.wobbleAngleDeg);
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
    findNearMiss(this.nmItems, n, this.nmCfg, this.nmOut);
    const now = this.time.now;
    for (let k = 0; k < this.nmOut.length; k++) {
      const b = this.balls[this.nmOut[k]];
      if (now >= b.noPulseUntil) b.nearMiss = true;
    }
  }

  // ---------------------------------------------------------------- slut

  /** Rundans statistik som absoluta värden (tål att skrivas flera gånger). */
  private runStats(): Partial<ReturnType<typeof cached>['stats']> {
    const d = cached();
    return {
      runs: d.stats.runs,
      merges: this.baseMerges + this.runMerges,
      autoDrops: this.baseAutoDrops + this.autoDrops,
      doubleKlunks: this.baseDoubleKlunks + this.runDoubleKlunks,
      maxLevelEver: Math.max(d.stats.maxLevelEver, this.bestLevel),
    };
  }

  /**
   * Pärlor och stjärnsand för rundan hittills (DESIGN §16.1). Tål flera anrop: bara det rundan
   * inte redan fått betalas ut, så att bakgrundsläggning mitt i rundan aldrig tappar något.
   */
  private bankRun(): Earned {
    const d = cached();
    const stats = this.runStats();
    const e = earnForRun(
      {
        merges: this.runMerges,
        shinies: this.runShinies,
        chains3: this.runChains3,
        level10s: this.runLevel10s,
        ...milestoneFlags({ maxLevelEver: stats.maxLevelEver!, doubleKlunks: stats.doubleKlunks! }, d.collection),
      },
      d,
      this.runPaid,
    );
    this.runEarned.pearls += e.pearls;
    this.runEarned.sand += e.sand;
    return e;
  }

  private persist(): void {
    this.bankRun();
    void save({ stats: this.runStats() });
    void submitRun(this.score, this.bestLevel, this.runAvatar);
  }

  /**
   * Upplåsning vid rundslut (DESIGN §13.3), innan rundavslutet visas. Returnerar det som
   * rundavslutet ska spela upp (DESIGN §13.4).
   */
  private settleRun(): RevealData {
    const d = cached();
    const stats = this.runStats();
    const before = d.unlockedSets;
    const res = evaluateUnlocks(
      { merges: stats.merges!, maxLevelEver: stats.maxLevelEver!, doubleKlunks: stats.doubleKlunks! },
      d.collection,
      before,
      mulberry32((this.seedUsed ^ 0x5e75) >>> 0),
    );
    const newSet = res.newSet ?? null;
    // Pärlor, sand och gratismusslor (DESIGN §16) skrivs i samma save som statistiken.
    this.bankRun();
    const boxes = claimFreeShells({ economy: d.economy, avatars: d.avatars, stats: { merges: stats.merges! } }).shells;
    if (newSet) {
      if (!d.collection[newSet]) d.collection[newSet] = emptyPage();
      void save({ stats, unlockedSets: [...before, newSet], freshSet: newSet });
    } else {
      void save({ stats });
    }
    return {
      setId: d.activeSet,
      catches: this.runCatches.slice(),
      filledBefore: this.filledAtStart,
      barFrom: nextSetProgress(this.startMerges, before.length),
      barTo: nextSetProgress(stats.merges!, before.length),
      newSet,
      boxes,
      pearls: this.runEarned.pearls,
      sand: this.runEarned.sand,
      pearlsBefore: d.economy.pearls - this.runEarned.pearls,
      photos: this.photos.slice().sort().slice(0, Math.max(0, this.abil.param('photos'))),
      photoTint: this.abil.flag('frameTint'),
    };
  }

  /** Rundloggen (debugpanelen): sammanfattas och sparas i samma skrivning som rundslutet. */
  private logRun(ended: 'loss' | 'quit', boxes: number): void {
    const d = cached();
    pushRun(
      d.debug.runs,
      summarizeRun({
        startedAt: this.runStartedAt,
        durationMs: Math.round(performance.now() - this.runT0),
        drops: this.dropsThisRun,
        merges: this.runMerges,
        autoDrops: this.autoDrops,
        latencies: this.dropLatencies,
        latencyModes: this.latencyModes,
        modeDrops: this.modeDrops,
        firstMergeMs: this.firstMergeMs,
        boxesEarned: boxes,
        score: this.score,
        maxLevel: this.bestLevel,
        activeSet: d.activeSet,
        equipped: this.runAvatar,
        pacingMode: this.pacingMode,
        calm: d.settings.calm,
        ended,
      }),
    );
  }

  /**
   * Bakåtknappen mitt i rundan: avslutas som en förlust (poäng, fångster, upplåsningar och
   * musslor via samma settleRun-väg), utan rundavslut, och spelet går till startskärmen.
   */
  private quitToStart(): void {
    if (this.over) return;
    this.over = true;
    this.hideHand();
    this.juice.endDanger();
    const reveal = this.settleRun();
    this.logRun('quit', reveal.boxes);
    void submitRun(this.score, this.bestLevel, this.runAvatar).then(() => this.scene.start('Start'));
  }

  private gameOver(): void {
    if (this.over) return;
    this.over = true;
    this.hideHand();
    this.juice.endDanger();
    this.juice.trigger('loss', 0.5, WORLD.width / 2, CAN.dangerY);
    const score = this.score;
    const bestLevel = this.bestLevel;
    const reveal = this.settleRun();
    this.logRun('loss', reveal.boxes);
    void submitRun(score, bestLevel, this.runAvatar).then((record) => {
      this.scene.pause();
      this.scene.launch('GameOver', { score, bestLevel, record, highscore: cached().highscore, reveal });
    });
  }
}
