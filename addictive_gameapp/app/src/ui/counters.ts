import Phaser from 'phaser';
import { THEME } from '../data/theme';
import { ECONOMY_ICON_KEYS, ECONOMY_UI, formatAmount } from '../data/economyUi';

const CT = ECONOMY_UI.counters;
/** Ikonerna rastreras i 128 px (2×). */
const ICON_PX = 128;

export type Resource = 'pearls' | 'sand';

/**
 * Resursräknare (UI.md §14.2): pärlor och stjärnsand i överkanten, samma plats i boken och på
 * startskärmen. Inte tryckbara. Räknar ned vid köp; ikonen punchar när resursen inte räcker.
 */
export class Counters {
  readonly icons: Record<Resource, Phaser.GameObjects.Image>;
  private readonly texts: Record<Resource, Phaser.GameObjects.Text>;
  private readonly shown = { pearls: 0, sand: 0 };

  constructor(private readonly scene: Phaser.Scene, pearls: number, sand: number, depth = 10, into?: Phaser.GameObjects.Container) {
    const k = CT.iconPx / ICON_PX;
    const style = { fontFamily: THEME.type.family, fontSize: `${CT.textPx}px`, color: THEME.palette.hud, fontStyle: '800' };
    const add = (r: Resource, key: string): [Phaser.GameObjects.Image, Phaser.GameObjects.Text] => [
      scene.add.image(CT[r].iconX, CT.y, key).setScale(k).setDepth(depth),
      scene.add.text(CT[r].textX, CT.y, '', style).setOrigin(0, 0.5).setDepth(depth),
    ];
    const [pi, pt] = add('pearls', ECONOMY_ICON_KEYS.pearlCoin);
    const [si, st] = add('sand', ECONOMY_ICON_KEYS.sand);
    this.icons = { pearls: pi, sand: si };
    this.texts = { pearls: pt, sand: st };
    into?.add([pi, pt, si, st]);
    this.set(pearls, sand);
  }

  set(pearls: number, sand: number): void {
    this.shown.pearls = pearls;
    this.shown.sand = sand;
    this.texts.pearls.setText(formatAmount(pearls));
    this.texts.sand.setText(formatAmount(sand));
  }

  /** Räknar ned (eller upp) till de nya värdena på 300 ms. */
  countTo(pearls: number, sand: number): void {
    const from = { ...this.shown };
    this.scene.tweens.addCounter({
      from: 0,
      to: 1,
      duration: CT.countDownMs,
      ease: 'Quad.easeOut',
      onUpdate: (tw) => {
        const t = tw.getValue() ?? 1;
        this.texts.pearls.setText(formatAmount(Math.round(from.pearls + (pearls - from.pearls) * t)));
        this.texts.sand.setText(formatAmount(Math.round(from.sand + (sand - from.sand) * t)));
      },
      onComplete: () => this.set(pearls, sand),
    });
  }

  /** "Räcker inte": ikonen för det som fattas punchar en gång. */
  punch(r: Resource): void {
    const img = this.icons[r];
    const base = CT.iconPx / ICON_PX;
    this.scene.tweens.killTweensOf(img);
    img.setScale(base);
    const P = CT.lackPunch;
    this.scene.tweens.add({ targets: img, scale: base * P.scale, duration: P.ms / 2, ease: P.ease, yoyo: true });
  }
}
