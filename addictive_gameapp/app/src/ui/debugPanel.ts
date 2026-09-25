import Phaser from 'phaser';
import { DEBUG, type DebugButton } from '../data/debug';
import { THEME, hexToInt } from '../data/theme';
import { avatarById } from '../data/avatarsIndex';
import { cached, resetSave, save } from '../systems/save';
import { giveAvatar } from '../systems/avatars';
import { exportJson, nextGift, type RunLog } from '../systems/debug';
import { setCalm, setSoundEnabled } from '../systems/audio';
import { setHapticsEnabled } from '../systems/haptics';
import { Z, Z_AUTO } from './view';
import { zoomLine } from '../systems/zoom';

const P = DEBUG.panel;
/** "Ge kompis" fortsätter i cykeln så länge appen är igång. */
let giftK = 0;

function sec(ms: number | null, dp = 1): string {
  return ms === null ? '-' : (ms / 1000).toFixed(dp);
}

function pct(v: number): string {
  return String(Math.round(v * 100));
}

/** Kolumnbredder (tecken). Raden blir 52 tecken: ryms i 10 px monospace på 360 px. */
const COLS = [4, 4, 4, 4, 3, 10, 5, 5, 8, 2] as const;

function row(cells: readonly string[]): string {
  return cells.map((c, i) => c.padStart(COLS[i])).join(' ');
}

/** En rad per runda. "q" efter numret = avslutad med bakåtknappen. */
function runLine(r: RunLog, n: number): string {
  const lat = r.latency?.all ? `${r.latency.all[0]}/${r.latency.all[1]}` : '-';
  const m = r.modeShare ?? { drought: 0, flow: 0, kick: 0 };
  return row([
    `${n}${r.ended === 'quit' ? 'q' : ' '}`,
    sec(r.durationMs, 0),
    String(r.drops),
    String(r.merges),
    String(r.autoDrops),
    lat,
    sec(r.firstMergeMs),
    sec(r.restartMs),
    `${pct(m.drought)}/${pct(m.flow)}/${pct(m.kick)}`,
    String(r.boxesEarned),
  ]);
}

const HEADER = row(['# ', 's', 'drop', 'mrg', 'aut', 'p50/p90ms', '1:a', 'åter', 'T/F/K%', 'm']);

/**
 * Debugpanel för speltest (PLAYTEST.md §3, P5.1a). Öppnas bara med långtryck på logotypen.
 * Text och Graphics räcker: panelen är för testledaren, inte för barn.
 */
export class DebugPanel {
  /** Senaste JSON som kopierades/visades (testhook). */
  lastExport: string | null = null;
  private readonly scene: Phaser.Scene;
  private readonly root: Phaser.GameObjects.Container;
  private readonly list: Phaser.GameObjects.Text;
  private readonly status: Phaser.GameObjects.Text;
  private readonly zoom: Phaser.GameObjects.Text;
  private readonly labels = new Map<DebugButton, Phaser.GameObjects.Text>();
  private readonly onClose: () => void;
  private confirmUntil = 0;
  private area: HTMLTextAreaElement | null = null;

  constructor(scene: Phaser.Scene, onClose: () => void) {
    this.scene = scene;
    this.onClose = onClose;
    const W = THEME.layout.width;
    const H = THEME.layout.height;
    const style = { fontFamily: P.font, fontSize: `${P.px}px`, color: P.text };
    const bg = scene.add.rectangle(W / 2, H / 2, W, H, hexToInt(P.bg), P.bgAlpha);
    const title = scene.add.text(10, 14, 'DEBUG · rundlogg (senaste först)', { ...style, color: P.accent, fontSize: '12px' });
    this.list = scene.add.text(6, P.listY, '', { ...style, lineSpacing: P.lineH - P.px - 2 });
    this.status = scene.add.text(W / 2, P.statusY, '', { ...style, color: P.dim, align: 'center', wordWrap: { width: W - 20 } }).setOrigin(0.5, 0);
    this.zoom = scene.add.text(10, P.zoomY, '', { ...style, color: P.accent });
    const g = scene.add.graphics();
    this.root = scene.add.container(0, 0, [bg, title, this.list, this.zoom, this.status, g]).setDepth(P.depth);
    for (const b of P.buttons) {
      g.lineStyle(2, hexToInt(P.accent), 1);
      g.strokeRoundedRect(b.x - P.buttonW / 2, b.y - P.buttonH / 2, P.buttonW, P.buttonH, 10);
      const t = scene.add.text(b.x, b.y, b.label, { ...style, fontSize: '13px' }).setOrigin(0.5);
      this.labels.set(b.id, t);
      this.root.add(t);
    }
    scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.removeArea());
    this.refresh();
  }

  private refresh(): void {
    const d = cached();
    const runs = d.debug.runs;
    const lines = [HEADER];
    for (let i = runs.length - 1; i >= 0; i--) lines.push(runLine(runs[i], d.stats.runs - (runs.length - 1 - i)));
    if (runs.length === 0) lines.push('  (inga rundor ännu)');
    this.list.setText(lines.join('\n'));
    this.zoom.setText(zoomLine(Z, Z_AUTO, d.settings.zoomCap));
    this.labels.get('zoom')?.setText(d.settings.zoomCap === null ? 'Zoom: auto' : 'Zoom: nollställ');
    this.labels.get('autodrop')?.setText(`Auto-drop: ${d.debug.autoDropOff ? 'AV' : 'på'}`);
    this.labels.get('reset')?.setText(this.scene.time.now < this.confirmUntil ? 'Tryck igen!' : 'Nollställ sparfil');
  }

  private say(msg: string): void {
    this.status.setText(msg);
  }

  /** Tryck i panelen. Returnerar alltid true (panelen äter alla tryck). */
  tap(x: number, y: number): boolean {
    const b = P.buttons.find((k) => Math.abs(x - k.x) <= P.buttonW / 2 && Math.abs(y - k.y) <= P.buttonH / 2);
    if (b) void this.run(b.id);
    return true;
  }

  private async run(id: DebugButton): Promise<void> {
    const d = cached();
    switch (id) {
      case 'copy': {
        const json = exportJson(d);
        this.lastExport = json;
        try {
          await navigator.clipboard.writeText(json);
          this.say(`Kopierat: ${d.debug.runs.length} rundor, ${json.length} tecken.`);
        } catch {
          this.showArea(json);
          this.say('Urklipp gick inte. Markera texten ovanför och kopiera.');
        }
        break;
      }
      case 'reset':
        if (this.scene.time.now < this.confirmUntil) {
          await resetSave();
          const st = cached().settings;
          setSoundEnabled(st.sound);
          setHapticsEnabled(st.haptics);
          setCalm(st.calm);
          this.onClose();
          return;
        }
        this.confirmUntil = this.scene.time.now + DEBUG.confirmMs;
        this.say('Nollställ: tryck igen inom 3 s.');
        this.scene.time.delayedCall(DEBUG.confirmMs, () => this.refresh());
        break;
      case 'gift': {
        const g = nextGift(d.avatars.owned, giftK);
        if (!g) {
          this.say('Alla kompisar med förmåga ägs redan.');
          break;
        }
        giftK = g.k;
        giveAvatar(d.avatars, g.id);
        void save();
        const a = avatarById(g.id);
        this.say(`Gav ${a?.names.sv ?? g.id} (${a?.rarity}, nivå I), vald från nästa runda.`);
        break;
      }
      case 'autodrop':
        d.debug.autoDropOff = !d.debug.autoDropOff;
        void save();
        this.say(`Auto-drop ${d.debug.autoDropOff ? 'AV' : 'på'} från nästa runda.`);
        break;
      case 'zoom':
        if (d.settings.zoomCap === null) {
          this.say('Fps-vakten har inte satt något tak.');
          break;
        }
        await save({ settings: { zoomCap: null } });
        this.say(`Zoom-taket nollställt: ${Z_AUTO} (auto) från nästa appstart.`);
        break;
      case 'close':
        this.onClose();
        return;
    }
    this.refresh();
  }

  /** Fallback när urklipp saknas: texten i ett markerbart fält ovanpå spelet. */
  private showArea(text: string): void {
    this.removeArea();
    const a = document.createElement('textarea');
    a.readOnly = true;
    a.value = text;
    a.setAttribute('data-debug-export', '');
    Object.assign(a.style, { position: 'fixed', left: '4%', top: '4%', width: '92%', height: '44%', zIndex: '10', fontSize: '10px' });
    document.body.appendChild(a);
    a.select();
    this.area = a;
  }

  private removeArea(): void {
    this.area?.remove();
    this.area = null;
  }

  destroy(): void {
    this.removeArea();
    this.root.destroy();
  }
}
