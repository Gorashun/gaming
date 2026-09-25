/**
 * Fps-vakt (DESIGN §17). Ren logik, ingen Phaser: testbar. Game matar den med frame-delta.
 * Efter uppvärmningen räknas medel-fps i på varandra följande fönster (frames · 1000 / fönstrets tid).
 * `windows` fönster i rad under `minFps` löser ut vakten. Ett fönster på eller över gränsen nollställer
 * räkningen, så att fps som pendlar runt gränsen (44/46) inte löser ut. Utlöst vakt är låst (ingen flapp).
 */
export interface PerfGuardConfig {
  readonly warmupMs: number;
  readonly windowMs: number;
  readonly minFps: number;
  readonly windows: number;
}

/** Så många fönster sparas för testhook och logg. */
const KEEP = 4;
/** Avrundningsmarginal (ms) för fönstergränser. */
const EPS = 1e-6;

export class PerfGuard {
  /** Senaste fönstrens medel-fps, äldst först (högst KEEP). */
  readonly recent: number[] = [];
  tripped = false;
  /** Fönster i rad under gränsen. */
  low = 0;
  private elapsed = 0;
  private winMs = 0;
  private winFrames = 0;

  constructor(private readonly cfg: PerfGuardConfig) {}

  /** En frame. Returnerar true exakt en gång: när vakten löser ut. Inga allokeringar. */
  feed(deltaMs: number): boolean {
    if (this.tripped || !(deltaMs > 0)) return false;
    if (this.elapsed < this.cfg.warmupMs - EPS) {
      this.elapsed += deltaMs;
      return false;
    }
    this.winMs += deltaMs;
    this.winFrames++;
    if (this.winMs < this.cfg.windowMs - EPS) return false;
    const fps = (this.winFrames * 1000) / this.winMs;
    this.winMs = 0;
    this.winFrames = 0;
    if (this.recent.length >= KEEP) this.recent.shift();
    this.recent.push(fps);
    this.low = fps < this.cfg.minFps ? this.low + 1 : 0;
    if (this.low < this.cfg.windows) return false;
    this.tripped = true;
    return true;
  }
}
