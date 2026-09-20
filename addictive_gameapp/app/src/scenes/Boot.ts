import Phaser from 'phaser';
import { ensureBallTextures } from '../ui/textures';
import { load } from '../systems/save';

export class Boot extends Phaser.Scene {
  constructor() {
    super('Boot');
  }

  async create(): Promise<void> {
    ensureBallTextures(this);
    await load();
    this.scene.start('Start');
  }
}
