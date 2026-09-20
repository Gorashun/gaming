/** Siktlinjens lägen (DESIGN.md §12). Ren data, ingen Phaser. */

export type AimLineMode = 'always' | 'aiming' | 'off';

export interface AimConfig {
  /** Läget när inställningen `settings.aimLine` är på. */
  defaultMode: AimLineMode;
  fadeInMs: number;
  fadeOutMs: number;
}

export const AIM: AimConfig = {
  defaultMode: 'aiming',
  fadeInMs: 80,
  fadeOutMs: 120,
};
