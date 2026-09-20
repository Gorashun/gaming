import Phaser from 'phaser';
import { WORLD, PHYSICS } from './data/physics';
import { Boot } from './scenes/Boot';
import { Start } from './scenes/Start';
import { Game } from './scenes/Game';
import { GameOver } from './scenes/GameOver';
import { Bench } from './scenes/Bench';

document.addEventListener('touchmove', (e) => e.preventDefault(), { passive: false });

const bench = new URLSearchParams(location.search).has('bench');

new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  backgroundColor: '#000000',
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: WORLD.width,
    height: WORLD.height,
  },
  physics: {
    default: 'matter',
    matter: {
      gravity: { x: 0, y: PHYSICS.gravityY },
      debug: false,
    },
  },
  input: { activePointers: 2 },
  scene: bench ? [Bench] : [Boot, Start, Game, GameOver],
});
