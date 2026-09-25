import Phaser from 'phaser';
import { AVATAR_BOX, type AnimRecipe, type AvatarDef, type GestureTrigger } from '../data/avatarsIndex';

/**
 * Rörelserecept (UI.md §13.1, `AnimRecipe`) som tweens på ett tillståndsobjekt. Bilden läses av i
 * `apply()` varje frame utan allokeringar. Prioritet: idle/danger-loop < drop (2) < merge/gest (3) < kedja (4).
 */

const DEG = Math.PI / 180;

interface Pose {
  dx: number;
  dy: number;
  sx: number;
  sy: number;
  rot: number;
}

export type RigTrigger = GestureTrigger;

export class AvatarRig {
  readonly st: Pose = { dx: 0, dy: 0, sx: 1, sy: 1, rot: 0 };
  /** Skala på hela figuren (öppningens pop, byte i boken). */
  base = 1;
  private readonly scene: Phaser.Scene;
  private readonly def: AvatarDef;
  /** px per box-enhet. */
  private readonly k: number;
  private readonly calmMul: number;
  private readonly calm: boolean;
  private chain: Phaser.Tweens.TweenChain | null = null;
  private prio = 0;
  private danger = false;
  private looping = false;

  constructor(scene: Phaser.Scene, def: AvatarDef, displayPx: number, calm = false, calmMul = 0.5) {
    this.scene = scene;
    this.def = def;
    this.k = displayPx / AVATAR_BOX;
    this.calm = calm;
    this.calmMul = calm ? calmMul : 1;
  }

  /** Spelar ett recept. `prio` 0 = loop (idle/danger). `timeScale` < 1 = snabbare. */
  play(recipe: AnimRecipe, prio: number, timeScale = 1, onDone?: () => void): void {
    this.stop();
    this.prio = prio;
    this.looping = prio === 0;
    const st = this.st;
    const m = this.calmMul;
    const tweens = recipe.steps.map((s) => {
      const spin = Math.abs(s.rot ?? 0) >= 360;
      return {
        dx: s.dx ?? 0,
        dy: (s.dy ?? 0) * m,
        sx: s.sx ?? 1,
        sy: s.sy ?? 1,
        rot: (s.rot ?? 0) * m,
        duration: Math.max(1, s.ms * timeScale),
        ease: s.ease,
        onComplete: spin ? (): void => void (st.rot = 0) : undefined,
      };
    });
    if (tweens.length === 0) return;
    const loop = prio === 0 && recipe.loop === true;
    this.chain = this.scene.tweens.chain({
      targets: st,
      tweens,
      loop: loop ? -1 : 0,
      onComplete: () => {
        this.chain = null;
        this.prio = 0;
        this.looping = false;
        if (onDone) onDone();
        else this.resumeLoop();
      },
    });
  }

  stop(): void {
    if (this.chain) {
      const c = this.chain;
      this.chain = null;
      c.stop();
    }
  }

  /** Lugnt tillbaka till vila (200 ms), sedan loopen. */
  private rest(ms: number): void {
    this.stop();
    this.prio = 0;
    this.looping = false;
    this.chain = this.scene.tweens.chain({
      targets: this.st,
      tweens: [{ dx: 0, dy: 0, sx: 1, sy: 1, rot: 0, duration: ms, ease: 'Sine.easeOut' }],
      onComplete: () => {
        this.chain = null;
        this.resumeLoop();
      },
    });
  }

  /** Startar idle eller danger-loopen. */
  resumeLoop(): void {
    this.play(this.danger ? this.def.anim.danger : this.def.anim.idle, 0);
  }

  setDanger(on: boolean): void {
    if (on === this.danger) return;
    this.danger = on;
    if (this.prio > 0) return; // loopen byts när engångsreceptet är klart
    if (on) this.play(this.def.anim.danger, 0);
    else this.rest(200);
  }

  /** Händelse enligt tabellen i UI.md §13.1. Returnerar true om något spelades. */
  trigger(t: RigTrigger): boolean {
    const a = this.def.anim;
    const g = this.def.cosmetic.gesture;
    const gesture = g && g.on === t ? g.anim : null;
    let recipe: AnimRecipe | null = null;
    let prio = 3;
    if (t === 'drop') {
      recipe = gesture ?? a.drop;
      prio = 2;
    } else if (t === 'merge') {
      recipe = gesture ?? a.merge;
    } else if (t === 'chain') {
      recipe = this.calm ? a.merge : a.chain;
      prio = this.calm ? 3 : 4;
    } else {
      recipe = gesture;
    }
    if (!recipe) return false;
    if (!this.looping && this.chain && (this.prio > prio || (this.prio === prio && prio >= 3))) return false;
    this.play(recipe, prio);
    return true;
  }

  /** Lägger posen på bilden. Positionen är greppunkten. Inga allokeringar. */
  apply(img: Phaser.GameObjects.Image, x: number, y: number, extraRotRad = 0): void {
    const s = this.st;
    img.x = x + s.dx * this.k;
    img.y = y + s.dy * this.k;
    img.setScale(this.base * s.sx, this.base * s.sy);
    img.rotation = s.rot * DEG + extraRotRad;
  }

  /** Längd (ms) för ett recept. */
  static lengthMs(r: AnimRecipe): number {
    let t = 0;
    for (const s of r.steps) t += s.ms;
    return t;
  }

  destroy(): void {
    this.stop();
  }
}
