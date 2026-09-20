import Phaser from 'phaser';
import { bakeTextures } from '../ui/textures';
import { loadIcons } from '../ui/icons';
import { load } from '../systems/save';
import { installStorageAdapter } from '../systems/storage';
import { setSoundEnabled, setCalm } from '../systems/audio';
import { setHapticsEnabled } from '../systems/haptics';

export class Boot extends Phaser.Scene {
  constructor() {
    super('Boot');
  }

  async create(): Promise<void> {
    bakeTextures(this);
    await loadIcons(this.textures);
    installStorageAdapter();
    const data = await load();
    setSoundEnabled(data.settings.sound);
    setHapticsEnabled(data.settings.haptics);
    setCalm(data.settings.calm);
    this.scene.start('Start');
  }
}
