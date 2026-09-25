import Phaser from 'phaser';
import { WORLD, PHYSICS } from './data/physics';
import { Boot } from './scenes/Boot';
import { Start } from './scenes/Start';
import { Game } from './scenes/Game';
import { GameOver } from './scenes/GameOver';
import { Bench } from './scenes/Bench';
import { Book } from './scenes/Book';
import { installBackButton } from './systems/back';
import { Z, initZoom, installHiDpiText } from './ui/view';
import { installStorageAdapter } from './systems/storage';
import { load } from './systems/save';

document.addEventListener('touchmove', (e) => e.preventDefault(), { passive: false });

const params = new URLSearchParams(location.search);
const bench = params.has('bench');
installBackButton(import.meta.env.DEV || params.has('test'));
installHiDpiText();
installStorageAdapter();

// Zoomen (och fps-vaktens tak) måste vara känd innan spelet skapas: canvasens storlek är 360·Z × 640·Z.
void load()
  .then((d) => d.settings.zoomCap, () => null)
  .then((cap) => {
    initZoom(cap);
    startGame();
  });

function startGame(): void {
  new Phaser.Game({
    type: Phaser.AUTO,
    parent: 'game',
    backgroundColor: '#000000',
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
      // Enhetspixlar; scenerna ser 360×640 via kamerazoom Z (ui/view.ts).
      width: WORLD.width * Z,
      height: WORLD.height * Z,
    },
    physics: {
      default: 'matter',
      matter: {
        gravity: { x: 0, y: PHYSICS.gravityY },
        debug: false,
      },
    },
    input: { activePointers: 2 },
    scene: bench ? [Bench] : [Boot, Start, Game, GameOver, Book],
  });
}
