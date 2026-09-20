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
import { MAX_LEVEL, TOP_PAIR_SCORE, radiusOf, scoreForCreating } from '../data/levels';
import { FEEL, JUICE, mergeIntensity } from '../data/juice';
import { INT, LEVEL_COLORS, THEME } from '../data/theme';
import { ballTextureKey, scaleForBodyRadius } from '../ui/textures';
import { drawBackground } from '../ui/background';
import { iconTextureKey } from '../ui/icons';
import { resolveMerges, type MergeCandidate } from '../systems/merge';
import { createDirector, type Director, type DirectorState } from '../systems/director';
import { createComboTracker, type ComboTracker } from '../systems/combo';
import { createDangerTracker, type DangerTracker } from '../systems/danger';
import { Juice } from '../systems/juice';
import { unlockAudio } from '../systems/audio';
import { mulberry32 } from '../systems/rng';
import { cached, save, submitRun } from '../systems/save';

interface Ball {
  body: MatterJS.BodyType;
  img: Phaser.GameObjects.Image;
  level: number;
  aboveMs: number;
  /** Skapad av en merge (används för kedjedetektering). */
  fromMerge: boolean;
  landed: boolean;
}

const L = THEME.layout;
const PREVIEW_R = 24;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');

export class Game extends Phaser.Scene {
  private balls: Ball[] = [];
  private byId = new Map<number, Ball>();
  private pool: Ball[] = [];
  private candidates: MergeCandidate[] = [];
  private boardLevels: number[] = [];

  private director!: Director;
  private dirState: DirectorState = { dropIndex: 0, board: this.boardLevels };
  private combo!: ComboTracker;
  private dangerTracker!: DangerTracker;
  private juice!: Juice;

  private hanging: Phaser.GameObjects.Image | null = null;
  private aimLine!: Phaser.GameObjects.Graphics;
  private preview!: Phaser.GameObjects.Image;
  private scoreText!: Phaser.GameObjects.Text;
  private recordMarker!: Phaser.GameObjects.Container;
  private recordText!: Phaser.GameObjects.Text;
  private recordRing!: Phaser.GameObjects.Graphics;
  private recordTween: Phaser.Tweens.Tween | null = null;
  private comboDots: Phaser.GameObjects.Arc[] = [];
  private hand: Phaser.GameObjects.Container | null = null;

  private currentLevel = 0;
  private nextLevel = 0;
  private score = 0;
  private bestLevel = 0;
  private dropIndex = 0;
  private aiming = false;
  private over = false;
  private dropReadyAt = 0;
  private lastDropAt = 0;
  private baseMerges = 0;
  private runMerges = 0;
  private highscore = 0;
  private recordPulsing = false;
  private passedRecord = false;
  private pending: Ball | null = null;

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
    this.over = false;
    this.aiming = false;
    this.pending = null;
    this.dropReadyAt = 0;
    this.runMerges = 0;
    this.recordPulsing = false;
    this.passedRecord = false;
    this.recordTween = null;
    this.hand = null;
    this.comboDots.length = 0;

    const data = cached();
    this.highscore = data.highscore;
    this.baseMerges = data.stats.merges;
    void save({ stats: { runs: data.stats.runs + 1, merges: data.stats.merges } });

    this.director = createDirector(mulberry32((Date.now() ^ 0x9e3779b9) >>> 0));
    this.combo = createComboTracker();
    this.dangerTracker = createDangerTracker();
    this.nextLevel = this.director.next(this.dirState);

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
      drop(x: number): void {
        if (self.over) return;
        if (!self.hanging) self.spawnHanging();
        self.moveHangingTo(x);
        self.doDrop();
      },
      forceLoss(): void {
        self.gameOver();
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
    const f = this.add.graphics().setDepth(10);
    f.lineStyle(2, INT.jarEdge, 0.9);
    const bx = L.preview.cx - L.preview.boxW / 2;
    const by = L.preview.cy - L.preview.boxH / 2;
    for (let i = 0; i < 4; i++) {
      const along = 14 + i * 12;
      f.lineBetween(bx + along, by, bx + along + 7, by);
      f.lineBetween(bx + along, by + L.preview.boxH, bx + along + 7, by + L.preview.boxH);
      f.lineBetween(bx, by + along, bx, by + along + 7);
      f.lineBetween(bx + L.preview.boxW, by + along, bx + L.preview.boxW, by + along + 7);
    }
    this.preview = this.add
      .image(L.preview.cx, L.preview.cy, ballTextureKey(this.nextLevel))
      .setDepth(10);

    this.aimLine = this.add.graphics().setDepth(3);
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
  }

  private onPointerMove(p: Phaser.Input.Pointer): void {
    if (this.over || !this.aiming) return;
    this.moveHangingTo(p.worldX);
  }

  private onPointerUp(): void {
    if (this.over || !this.aiming) return;
    this.aiming = false;
    this.doDrop();
  }

  private moveHangingTo(x: number): void {
    if (!this.hanging) return;
    const r = radiusOf(this.currentLevel);
    const cx = Phaser.Math.Clamp(x, INNER_LEFT + r, INNER_RIGHT - r);
    this.hanging.x = cx;
    this.aimLine.x = cx;
  }

  private spawnHanging(): void {
    this.currentLevel = this.nextLevel;
    this.dropIndex++;
    this.dirState.dropIndex = this.dropIndex;
    this.boardLevels.length = 0;
    for (let i = 0; i < this.balls.length; i++) this.boardLevels.push(this.balls[i].level);
    this.nextLevel = this.director.next(this.dirState);

    const r = radiusOf(this.currentLevel);
    const x = Phaser.Math.Clamp(
      this.hanging ? this.hanging.x : WORLD.width / 2,
      INNER_LEFT + r,
      INNER_RIGHT - r,
    );
    this.hanging = this.add.image(x, CAN.spawnY, ballTextureKey(this.currentLevel)).setDepth(6);
    this.preview
      .setTexture(ballTextureKey(this.nextLevel))
      .setScale(scaleForBodyRadius(this.nextLevel, PREVIEW_R));
    this.tweens.add({
      targets: this.hanging,
      scale: { from: 0.7, to: 1 },
      duration: THEME.anim.queueSlide.durationMs,
      ease: THEME.anim.queueSlide.ease,
    });
    this.drawAimLine(r);
    this.aimLine.x = x;
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

  private doDrop(): void {
    if (this.over || !this.hanging) return;
    const x = this.hanging.x;
    this.hanging.destroy();
    this.hanging = null;
    this.aimLine.clear();
    const ball = this.addBall(x, CAN.spawnY, this.currentLevel, false);
    this.pending = ball;
    this.dropReadyAt = this.time.now + PHYSICS.dropCooldownMs;
    this.lastDropAt = this.time.now;
    this.juice.trigger('drop', 0.2, x, CAN.spawnY);
    this.hideHand();
  }

  // ---------------------------------------------------------------- bodies

  private addBall(x: number, y: number, level: number, fromMerge: boolean): Ball {
    const r = radiusOf(level);
    const body = this.matter.add.circle(x, y, r, {
      restitution: PHYSICS.restitution,
      friction: PHYSICS.friction,
      frictionStatic: PHYSICS.frictionStatic,
      frictionAir: PHYSICS.frictionAir,
      density: densityFor(r),
    }) as MatterJS.BodyType;

    let ball = this.pool.pop();
    if (ball) {
      ball.body = body;
      ball.img.setTexture(ballTextureKey(level)).setScale(1).setVisible(true).setPosition(x, y);
      ball.level = level;
      ball.aboveMs = 0;
      ball.fromMerge = fromMerge;
      ball.landed = false;
    } else {
      ball = {
        body,
        img: this.add.image(x, y, ballTextureKey(level)).setDepth(5),
        level,
        aboveMs: 0,
        fromMerge,
        landed: false,
      };
    }
    this.balls.push(ball);
    this.byId.set(body.id, ball);
    if (level > this.bestLevel) this.bestLevel = level;
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
    for (let i = 0; i < pairs.length; i++) {
      const bodyA = pairs[i].bodyA as MatterJS.BodyType;
      const bodyB = pairs[i].bodyB as MatterJS.BodyType;
      const a = this.byId.get(bodyA.id);
      const b = this.byId.get(bodyB.id);
      if (this.pending !== null && (a === this.pending || b === this.pending)) this.pending = null;
      if (a && !a.landed) this.land(a);
      if (b && !b.landed) this.land(b);
      if (!a || !b) continue;
      this.candidates.push({ a: bodyA.id, b: bodyB.id, levelA: a.level, levelB: b.level });
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

  /** Första kontakten: "klunk" + squash. */
  private land(ball: Ball): void {
    ball.landed = true;
    const speed = Math.abs(ball.body.velocity.y);
    if (speed < 1.5) return;
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
    if (level >= MAX_LEVEL) {
      points = TOP_PAIR_SCORE;
    } else {
      newLevel = level + 1;
      const created = this.addBall(x, y, newLevel, true);
      target = created.img;
      points = scoreForCreating(newLevel);
    }
    this.addScore(points);
    this.updateComboDots();

    const color = LEVEL_COLORS[newLevel];
    const jackpot = newLevel >= MAX_LEVEL;
    const chain = state.chain >= FEEL.chain.minLength;
    const event = jackpot ? 'special' : chain ? 'chain' : 'merge';
    const intensity = jackpot
      ? 1
      : chain
        ? FEEL.chain.intensity
        : mergeIntensity(newLevel, state.combo);
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
    this.hand = this.add.container(150, 96, [hand, swipe]).setDepth(15).setAlpha(0);
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

    // Bild följer fysikkroppen. Inga allokeringar.
    for (let i = 0; i < this.balls.length; i++) {
      const b = this.balls[i];
      b.img.x = b.body.position.x;
      b.img.y = b.body.position.y;
      b.img.rotation = b.body.angle;
    }

    this.juice.update(delta);
    if (this.combo.tick(now)) this.updateComboDots();

    if (!this.hanging && (this.pending === null || now >= this.dropReadyAt)) {
      this.spawnHanging();
      if (cached().stats.runs === 0 && now - this.lastDropAt > FEEL.onboarding.idleMs) {
        this.showHand();
      }
    }

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

  // ---------------------------------------------------------------- slut

  private persist(): void {
    void save({
      stats: { runs: cached().stats.runs, merges: this.baseMerges + this.runMerges },
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
      stats: { runs: cached().stats.runs, merges: this.baseMerges + this.runMerges },
    });
    void submitRun(score, bestLevel).then((record) => {
      this.scene.pause();
      this.scene.launch('GameOver', { score, bestLevel, record, highscore: cached().highscore });
    });
  }
}
