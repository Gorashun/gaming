import Phaser from 'phaser';
import { WORLD } from '../data/physics';
import { bakeTextures, ballTextureKey } from '../ui/textures';
import { fitCamera } from '../ui/view';

/** Benchmark: ~2000 levande partiklar, loggar medel-fps. Nås via ?bench=1. */
export class Bench extends Phaser.Scene {
  private frames = 0;
  private elapsed = 0;
  private totalFrames = 0;
  private totalTime = 0;
  private label!: Phaser.GameObjects.Text;

  constructor() {
    super('Bench');
  }

  create(): void {
    fitCamera(this);
    this.cameras.main.setBackgroundColor(0x000000);
    bakeTextures(this);
    // lifespan 2000 ms med 1 partikel per ms ger ~2000 levande partiklar.
    this.add.particles(WORLD.width / 2, WORLD.height / 2, ballTextureKey(0), {
      lifespan: 2000,
      frequency: 1,
      quantity: 1,
      speed: { min: 20, max: 160 },
      angle: { min: 0, max: 360 },
      scale: { start: 0.5, end: 0.1 },
      alpha: { start: 1, end: 0.3 },
      blendMode: 'ADD',
    });
    this.label = this.add.text(8, 8, 'fps …', {
      fontFamily: 'monospace',
      fontSize: '16px',
      color: '#ffffff',
    });
    (window as unknown as Record<string, unknown>).__fps = 0;
  }

  override update(_time: number, delta: number): void {
    this.frames++;
    this.elapsed += delta;
    this.totalFrames++;
    this.totalTime += delta;
    if (this.elapsed >= 1000) {
      const avg = (this.totalFrames / this.totalTime) * 1000;
      const last = (this.frames / this.elapsed) * 1000;
      (window as unknown as Record<string, unknown>).__fps = avg;
      this.label.setText(`fps ${last.toFixed(1)} · avg ${avg.toFixed(1)}`);
      console.log(`[bench] fps=${last.toFixed(1)} avg=${avg.toFixed(1)}`);
      this.frames = 0;
      this.elapsed = 0;
    }
  }
}
