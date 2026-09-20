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
import { INT, THEME } from '../data/theme';
import { ballTextureKey } from '../ui/textures';
import { resolveMerges, type MergeCandidate } from '../systems/merge';
import { createDirector, type Director, type DirectorState } from '../systems/director';
import { mulberry32 } from '../systems/rng';
import { cached, submitRun } from '../systems/save';

interface Ball extends Phaser.Physics.Matter.Image {
  level: number;
  aboveMs: number;
}

const PREVIEW_SIZE = 44;

const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');

export class Game extends Phaser.Scene {
  private balls: Ball[] = [];
  private byId = new Map<number, Ball>();
  private candidates: MergeCandidate[] = [];
  private boardLevels: number[] = [];

  private director!: Director;
  private dirState: DirectorState = { dropIndex: 0, board: this.boardLevels };

  private hanging: Phaser.GameObjects.Image | null = null;
  private preview!: Phaser.GameObjects.Image;
  private scoreText!: Phaser.GameObjects.Text;

  private currentLevel = 0;
  private nextLevel = 0;
  private score = 0;
  private bestLevel = 0;
  private dropIndex = 0;
  private aiming = false;
  private over = false;
  private dropReadyAt = 0;
  /** Senast tappade objektet – räknas inte mot förlust förrän det nuddat något. */
  private pending: Ball | null = null;
  private onHide = (): void => {
    if (document.visibilityState === 'hidden') void submitRun(this.score, this.bestLevel);
  };

  constructor() {
    super('Game');
  }

  create(): void {
    this.cameras.main.setBackgroundColor(INT.bg);
    this.balls.length = 0;
    this.byId.clear();
    this.score = 0;
    this.bestLevel = 0;
    this.dropIndex = 0;
    this.over = false;
    this.aiming = false;
    this.pending = null;
    this.dropReadyAt = 0;

    this.director = createDirector(mulberry32((Date.now() ^ 0x9e3779b9) >>> 0));
    this.nextLevel = this.director.next(this.dirState);

    this.buildCan();
    this.buildHud();

    this.input.on('pointerdown', this.onPointerDown, this);
    this.input.on('pointermove', this.onPointerMove, this);
    this.input.on('pointerup', this.onPointerUp, this);
    this.matter.world.on('collisionstart', this.onCollisionStart, this);
    document.addEventListener('visibilitychange', this.onHide);

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      document.removeEventListener('visibilitychange', this.onHide);
      this.matter.world?.off('collisionstart', this.onCollisionStart, this);
      if (TEST_HOOK) delete (window as unknown as Record<string, unknown>).__game;
    });

    this.spawnHanging();

    if (TEST_HOOK) {
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
        drop(x: number): void {
          self.moveHangingTo(x);
          self.doDrop();
        },
      };
    }
  }

  // ---------- uppbyggnad ----------

  private buildCan(): void {
    const t = CAN.wallThickness;
    const h = CAN.floorY - CAN.topY;
    const g = this.add.graphics();
    g.fillStyle(INT.jarGlass, 1);
    g.fillRect(INNER_LEFT, CAN.topY, INNER_RIGHT - INNER_LEFT, CAN.floorY - CAN.topY);
    g.fillStyle(INT.jarWall, 1);
    g.fillRect(CAN_LEFT, CAN.topY, t, h + t);
    g.fillRect(INNER_RIGHT, CAN.topY, t, h + t);
    g.fillStyle(INT.floor, 1);
    g.fillRect(CAN_LEFT, CAN.floorY, CAN.outerWidth, t);
    g.lineStyle(3, INT.jarEdge, 1);
    g.strokeRect(CAN_LEFT, CAN.topY, CAN.outerWidth, CAN.floorY + t - CAN.topY);

    this.matter.add.rectangle(CAN_LEFT + t / 2, CAN.topY + h / 2, t, h, { isStatic: true });
    this.matter.add.rectangle(INNER_RIGHT + t / 2, CAN.topY + h / 2, t, h, { isStatic: true });
    this.matter.add.rectangle(WORLD.width / 2, CAN.floorY + t / 2, CAN.outerWidth, t, {
      isStatic: true,
    });

    const d = this.add.graphics();
    d.lineStyle(2, INT.danger, 0.8);
    for (let x = INNER_LEFT; x < INNER_RIGHT; x += 16) {
      d.lineBetween(x, CAN.dangerY, Math.min(x + 9, INNER_RIGHT), CAN.dangerY);
    }
  }

  private buildHud(): void {
    this.scoreText = this.add
      .text(THEME.layout.hud.scoreX, THEME.layout.hud.scoreY, '0', {
        fontFamily: THEME.type.family,
        fontSize: `${THEME.type.score}px`,
        color: THEME.palette.hud,
      })
      .setDepth(10);
    this.preview = this.add
      .image(THEME.layout.preview.cx, THEME.layout.preview.cy, ballTextureKey(this.nextLevel))
      .setDepth(10)
      .setDisplaySize(PREVIEW_SIZE, PREVIEW_SIZE);
  }

  // ---------- input ----------

  private onPointerDown(p: Phaser.Input.Pointer): void {
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
    this.hanging.x = Phaser.Math.Clamp(x, INNER_LEFT + r, INNER_RIGHT - r);
  }

  private spawnHanging(): void {
    this.currentLevel = this.nextLevel;
    this.dropIndex++;
    this.dirState.dropIndex = this.dropIndex;
    this.boardLevels.length = 0;
    for (let i = 0; i < this.balls.length; i++) this.boardLevels.push(this.balls[i].level);
    this.nextLevel = this.director.next(this.dirState);

    const r = radiusOf(this.currentLevel);
    const x = this.hanging ? this.hanging.x : WORLD.width / 2;
    this.hanging = this.add
      .image(Phaser.Math.Clamp(x, INNER_LEFT + r, INNER_RIGHT - r), CAN.spawnY, ballTextureKey(this.currentLevel))
      .setDepth(5);
    this.preview.setTexture(ballTextureKey(this.nextLevel)).setDisplaySize(PREVIEW_SIZE, PREVIEW_SIZE);
  }

  private doDrop(): void {
    if (this.over || !this.hanging) return;
    const x = this.hanging.x;
    this.hanging.destroy();
    this.hanging = null;
    const ball = this.addBall(x, CAN.spawnY, this.currentLevel);
    this.pending = ball;
    this.dropReadyAt = this.time.now + PHYSICS.dropCooldownMs;
  }

  // ---------- bodies ----------

  private addBall(x: number, y: number, level: number): Ball {
    const r = radiusOf(level);
    const ball = this.matter.add.image(x, y, ballTextureKey(level), undefined, {
      shape: { type: 'circle', radius: r },
      restitution: PHYSICS.restitution,
      friction: PHYSICS.friction,
      frictionStatic: PHYSICS.frictionStatic,
      frictionAir: PHYSICS.frictionAir,
      density: densityFor(r),
    }) as Ball;
    ball.level = level;
    ball.aboveMs = 0;
    this.balls.push(ball);
    this.byId.set((ball.body as MatterJS.BodyType).id, ball);
    if (level > this.bestLevel) this.bestLevel = level;
    return ball;
  }

  private removeBall(ball: Ball): void {
    const i = this.balls.indexOf(ball);
    if (i >= 0) this.balls.splice(i, 1);
    this.byId.delete((ball.body as MatterJS.BodyType).id);
    if (this.pending === ball) this.pending = null;
    ball.destroy();
  }

  private addScore(points: number): void {
    this.score += points;
    this.scoreText.setText(`${this.score}`);
  }

  // ---------- kollisioner och merge ----------

  private onCollisionStart(event: { pairs: Phaser.Types.Physics.Matter.MatterCollisionData[] }): void {
    if (this.over) return;
    const pairs = event.pairs;
    this.candidates.length = 0;
    for (let i = 0; i < pairs.length; i++) {
      const idA = (pairs[i].bodyA as MatterJS.BodyType).id;
      const idB = (pairs[i].bodyB as MatterJS.BodyType).id;
      const a = this.byId.get(idA);
      const b = this.byId.get(idB);
      if (this.pending !== null && (a === this.pending || b === this.pending)) this.pending = null;
      if (!a || !b) continue;
      this.candidates.push({ a: idA, b: idB, levelA: a.level, levelB: b.level });
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

  private applyMerge(a: Ball, b: Ball, level: number): void {
    const x = (a.x + b.x) / 2;
    const y = (a.y + b.y) / 2;
    this.removeBall(a);
    this.removeBall(b);
    if (level >= MAX_LEVEL) {
      this.addScore(TOP_PAIR_SCORE);
    } else {
      this.addBall(x, y, level + 1);
      this.addScore(scoreForCreating(level + 1));
    }
    this.kickNeighbours(x, y);
  }

  private kickNeighbours(x: number, y: number): void {
    const rad = PHYSICS.mergeNeighbourRadius;
    for (let i = 0; i < this.balls.length; i++) {
      const o = this.balls[i];
      const dx = o.x - x;
      const dy = o.y - y;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d < 0.001 || d > rad) continue;
      const f = (PHYSICS.mergeNeighbourImpulse * (1 - d / rad)) / d;
      o.applyForce(new Phaser.Math.Vector2(dx * f, dy * f));
    }
  }

  // ---------- loop ----------

  override update(_time: number, delta: number): void {
    if (this.over) return;

    if (!this.hanging && (this.pending === null || this.time.now >= this.dropReadyAt)) {
      this.spawnHanging();
    }

    for (let i = 0; i < this.balls.length; i++) {
      const ball = this.balls[i];
      if (ball === this.pending) {
        ball.aboveMs = 0;
        continue;
      }
      if (ball.y < CAN.dangerY) {
        ball.aboveMs += delta;
        if (ball.aboveMs >= PHYSICS.lossGraceMs) {
          this.gameOver();
          return;
        }
      } else {
        ball.aboveMs = 0;
      }
    }
  }

  private gameOver(): void {
    this.over = true;
    const score = this.score;
    const bestLevel = this.bestLevel;
    void submitRun(score, bestLevel).then((record) => {
      // Overlay: Game-scenen pausas och syns bakom.
      this.scene.pause();
      this.scene.launch('GameOver', { score, bestLevel, record, highscore: cached().highscore });
    });
  }
}
