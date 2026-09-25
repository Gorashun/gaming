import Phaser from 'phaser';
import { INT, THEME } from '../data/theme';
import { COLLECTION_FX, DEFAULT_SET, LEVEL_COUNT } from '../data/collection';
import {
  FX_GLITTER,
  FX_GLITTER_R,
  ballTextureKey,
  scaleForBodyRadius,
  silhouetteTextureKey,
} from '../ui/textures';
import { drawBackground } from '../ui/background';
import { iconTextureKey } from '../ui/icons';
import { cached } from '../systems/save';
import { filledSlots, type CollectionPage } from '../systems/collection';
import { playSound } from '../systems/audio';

const L = THEME.layout;
const B = COLLECTION_FX.book;
const GL = COLLECTION_FX.glitter;
const TOUCH = THEME.touch.minLogical;
const SLOTS = LEVEL_COUNT * 2;
const TEST_HOOK = import.meta.env.DEV || new URLSearchParams(location.search).has('test');

/**
 * Samlarboken (DESIGN §13.2): en sida per temaset, svep i sidled för att bläddra,
 * svep ner eller stäng-ikonen för att gå tillbaka. Ingen text utöver siffror.
 */
export class Book extends Phaser.Scene {
  private strip!: Phaser.GameObjects.Container;
  private dots: Phaser.GameObjects.Arc[] = [];
  private ids: string[] = [];
  private page = 0;
  private downX = 0;
  private downY = 0;

  constructor() {
    super('Book');
  }

  create(): void {
    drawBackground(this);
    const data = cached();
    // Grundsetet först, sedan övriga i sparordning.
    this.ids = [DEFAULT_SET, ...Object.keys(data.collection).filter((id) => id !== DEFAULT_SET)];
    this.page = Math.max(0, this.ids.indexOf(data.activeSet));
    this.dots = [];

    this.strip = this.add.container(-this.page * L.width, 0);
    for (let i = 0; i < this.ids.length; i++) {
      this.buildPage(i * L.width, data.collection[this.ids[i]]);
    }
    this.buildDots();
    this.add.image(B.closeX, B.closeY, iconTextureKey('close')).setDisplaySize(48, 48).setDepth(10);

    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      this.downX = p.worldX;
      this.downY = p.worldY;
    });
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => this.onUp(p));

    if (TEST_HOOK) {
      const self = this;
      (window as unknown as Record<string, unknown>).__book = {
        get page(): number {
          return self.page;
        },
        get pages(): number {
          return self.ids.length;
        },
        get filled(): number {
          return filledSlots(cached().collection[self.ids[self.page]]);
        },
      };
      this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
        delete (window as unknown as Record<string, unknown>).__book;
      });
    }
  }

  private onUp(p: Phaser.Input.Pointer): void {
    const dx = p.worldX - this.downX;
    const dy = p.worldY - this.downY;
    if (dy > B.swipePx && dy > Math.abs(dx)) {
      this.close();
      return;
    }
    if (Math.abs(dx) > B.swipePx) {
      this.goTo(this.page + (dx < 0 ? 1 : -1));
      return;
    }
    if (Math.abs(p.worldX - B.closeX) <= TOUCH / 2 && Math.abs(p.worldY - B.closeY) <= TOUCH / 2) {
      this.close();
    }
  }

  private close(): void {
    playSound('ui');
    this.scene.start('Start');
  }

  private goTo(i: number): void {
    const next = Phaser.Math.Clamp(i, 0, this.ids.length - 1);
    if (next === this.page) return;
    this.page = next;
    playSound('ui');
    this.tweens.add({
      targets: this.strip,
      x: -next * L.width,
      duration: B.pageMs,
      ease: THEME.anim.queueSlide.ease,
    });
    for (let d = 0; d < this.dots.length; d++) {
      this.dots[d].setFillStyle(d === next ? INT.hud : INT.hudDim, d === next ? 1 : 0.5);
    }
  }

  private buildDots(): void {
    const n = this.ids.length;
    const step = 16;
    const x0 = L.width / 2 - ((n - 1) * step) / 2;
    for (let i = 0; i < n; i++) {
      const on = i === this.page;
      this.dots.push(
        this.add.circle(x0 + i * step, B.dotsY, 5, on ? INT.hud : INT.hudDim, on ? 1 : 0.5).setDepth(10),
      );
    }
  }

  private buildPage(ox: number, page: CollectionPage): void {
    const cx = ox + L.width / 2;
    // Setets ikon (platshållare: nivå 10 tills temaseten finns).
    this.strip.add(
      this.add.image(cx, B.iconY, ballTextureKey(10)).setScale(scaleForBodyRadius(10, B.iconR)),
    );
    this.strip.add(
      this.add
        .text(cx, B.meterY, `${filledSlots(page)}/${SLOTS}`, {
          fontFamily: THEME.type.family,
          fontSize: `${THEME.type.sub}px`,
          color: THEME.palette.hud,
          fontStyle: THEME.type.weightHeavy,
        })
        .setOrigin(0.5),
    );
    const div = this.add.graphics();
    div.lineStyle(2, INT.jarEdge, 0.4);
    const midY = (B.normalY + B.pitch + B.shinyY) / 2;
    div.lineBetween(cx - 120, midY, cx + 120, midY);
    this.strip.add(div);

    for (let lvl = 0; lvl < LEVEL_COUNT; lvl++) {
      const row = Math.floor(lvl / B.cols);
      const inRow = row === 0 ? B.cols : LEVEL_COUNT - B.cols;
      const col = lvl - row * B.cols;
      const x = cx + (col - (inRow - 1) / 2) * B.pitch;
      this.addSlot(x, B.normalY + row * B.pitch, lvl, page.caught[lvl], false);
      this.addSlot(x, B.shinyY + row * B.pitch, lvl, page.shiny[lvl], true);
    }
  }

  private addSlot(x: number, y: number, level: number, have: boolean, shiny: boolean): void {
    const scale = scaleForBodyRadius(level, B.bodyR);
    const img = this.add
      .image(x, y, have ? ballTextureKey(level) : silhouetteTextureKey(level))
      .setScale(scale)
      .setAlpha(have ? B.litAlpha : B.lockedAlpha);
    this.strip.add(img);
    if (!shiny) return;
    const ring = this.add
      .image(x, y, FX_GLITTER)
      .setScale((B.bodyR * GL.ringRadius) / FX_GLITTER_R)
      .setAlpha(have ? GL.alphaMin : B.lockedAlpha);
    this.strip.add(ring);
    if (!have) return;
    // Puls 0,83 Hz (flash-guard ≤1 Hz), kontinuerlig rotation.
    this.tweens.add({
      targets: ring,
      alpha: GL.alphaMax,
      duration: GL.halfCycleMs,
      ease: 'Sine.easeInOut',
      yoyo: true,
      repeat: -1,
    });
    this.tweens.add({
      targets: ring,
      angle: 360,
      duration: (360 / GL.spinDegPerSec) * 1000,
      repeat: -1,
    });
  }
}
