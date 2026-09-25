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
    installStorageAdapter();
    const data = await load();
    // Texturerna för det aktiva setet (UI.md §12.4). Andra set bakas vid behov.
    bakeTextures(this, data.activeSet);
    await loadIcons(this.textures);
    setSoundEnabled(data.settings.sound);
    setHapticsEnabled(data.settings.haptics);
    setCalm(data.settings.calm);
    this.scene.start('Start');
  }
}
