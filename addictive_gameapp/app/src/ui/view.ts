import Phaser from 'phaser';
import { ART } from '../data/art';
import { WORLD } from '../data/physics';
import { zoomFor } from '../systems/zoom';

/**
 * Hi-DPI (DESIGN §17, UI.md §15.2). Canvasen är 360·Z × 640·Z enhetspixlar; varje scens kamera
 * zoomar Z och visar den logiska rymden 360×640, som är den enda koordinatrymden i scenkoden
 * (input via pointer.worldX/worldY).
 */

const params = new URLSearchParams(location.search);

export const Z = zoomFor(window.devicePixelRatio, ART.maxZoom, params.get('zoom'));

export const ART_MODE: 'v1' | 'v2' = params.get('art') === 'v1' ? 'v1' : ART.mode;

/** Baktider och texturbudget loggas i dev och testbygget. */
export const ART_LOG = import.meta.env.DEV || params.has('test');

/** Först i varje scens create(). */
export function fitCamera(scene: Phaser.Scene): void {
  scene.cameras.main.setZoom(Z).centerOn(WORLD.width / 2, WORLD.height / 2);
}

/** Bakningsfaktor för texturer: Z i WebGL. Canvas-renderaren kan inte visa texturer i annan storlek än sin pixelstorlek. */
export function texDpr(scene: Phaser.Scene): number {
  return scene.game.renderer.type === Phaser.WEBGL ? Z : 1;
}

/** All Text renderas i Z (samma som setResolution(Z) på varje text). Anropas en gång innan spelet skapas. */
export function installHiDpiText(): void {
  const F = Phaser.GameObjects.GameObjectFactory.prototype;
  const text = F.text;
  F.text = function (this: Phaser.GameObjects.GameObjectFactory, x, y, t, style) {
    return text.call(this, x, y, t, { resolution: Z, ...style });
  };
}
