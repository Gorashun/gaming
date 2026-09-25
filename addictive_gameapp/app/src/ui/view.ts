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

/** Dev och testbygget (`?test`): loggar baktider; `?zoom=` och `?art=v1` gäller bara här. */
export const ART_LOG = import.meta.env.DEV || params.has('test');

/** Spelets zoom. Sätts av initZoom() innan Phaser.Game skapas och ändras inte under sessionen. */
export let Z = 1;

/** Z utan fps-vaktens tak (för debugpanelen). */
export let Z_AUTO = 1;

/** Anropas en gång vid appstart med sparat `settings.zoomCap` (null = auto). */
export function initZoom(cap: number | null): void {
  const override = ART_LOG ? params.get('zoom') : null;
  Z_AUTO = zoomFor(window.devicePixelRatio, ART.maxZoom, override);
  Z = zoomFor(window.devicePixelRatio, ART.maxZoom, override, cap);
}

export const ART_MODE: 'v1' | 'v2' = ART_LOG && params.get('art') === 'v1' ? 'v1' : ART.mode;

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
