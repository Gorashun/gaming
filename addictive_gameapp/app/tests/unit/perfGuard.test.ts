import { describe, expect, it } from 'vitest';
import { PerfGuard } from '../../src/systems/perfGuard';
import { zoomFor, zoomLine } from '../../src/systems/zoom';
import { ART } from '../../src/data/art';
import { defaultSave, mergeWithDefaults } from '../../src/systems/save';

const CFG = ART.perfGuard;

/** Matar `ms` millisekunder frames i `fps`. Returnerar om vakten löste ut under tiden. */
function run(g: PerfGuard, fps: number, ms: number): boolean {
  let hit = false;
  for (let t = 0; t < ms - 1e-6; t += 1000 / fps) hit = g.feed(1000 / fps) || hit;
  return hit;
}

describe('PerfGuard (fps-vakt, DESIGN §17)', () => {
  it('data: 2 s uppvärmning, 3 s fönster, 45 fps, två fönster, tak 1', () => {
    expect(CFG).toEqual({ warmupMs: 2000, windowMs: 3000, minFps: 45, windows: 2, cap: 1 });
  });

  it('uppvärmningen räknas inte: 2 s på 5 fps och sedan 60 fps löser inte ut', () => {
    const g = new PerfGuard(CFG);
    expect(run(g, 5, 2000)).toBe(false);
    expect(g.recent).toEqual([]);
    expect(run(g, 60, 12_000)).toBe(false);
    expect(g.recent).toHaveLength(4);
    for (const f of g.recent) expect(f).toBeCloseTo(60, 0);
  });

  it('två fönster i rad under 45 löser ut, exakt en gång, efter uppvärmning + 2 fönster', () => {
    const g = new PerfGuard(CFG);
    expect(run(g, 30, 2000 + 3000)).toBe(false);
    expect(g.low).toBe(1);
    expect(run(g, 30, 3000)).toBe(true);
    expect(g.tripped).toBe(true);
    expect(run(g, 30, 10_000)).toBe(false);
  });

  it('ett fönster under gränsen räcker inte', () => {
    const g = new PerfGuard(CFG);
    run(g, 60, 2000);
    expect(run(g, 30, 3000)).toBe(false);
    expect(run(g, 60, 3000)).toBe(false);
    expect(g.low).toBe(0);
    expect(run(g, 30, 3000)).toBe(false);
    expect(g.tripped).toBe(false);
  });

  it('hysteres: fps som pendlar 44/46 löser aldrig ut; 45 räknas inte som lågt', () => {
    const g = new PerfGuard(CFG);
    run(g, 60, 2000);
    for (let i = 0; i < 20; i++) expect(run(g, i % 2 === 0 ? 44 : 46, 3000)).toBe(false);
    expect(g.tripped).toBe(false);
    const h = new PerfGuard(CFG);
    run(h, 45, 2000 + 30_000);
    expect(h.tripped).toBe(false);
  });

  it('utlöst vakt är låst: bra fps efteråt ändrar inget (ingen flapp)', () => {
    const g = new PerfGuard(CFG);
    run(g, 20, 2000 + 6000);
    expect(g.tripped).toBe(true);
    run(g, 60, 30_000);
    expect(g.tripped).toBe(true);
  });

  it('ignorerar ogiltiga delta (0, negativ, NaN)', () => {
    const g = new PerfGuard(CFG);
    for (const d of [0, -16, NaN]) expect(g.feed(d)).toBe(false);
    run(g, 60, 2000 + 3000);
    expect(g.recent[0]).toBeCloseTo(60, 0);
  });
});

describe('zoomCap', () => {
  it('sparfältet är null (auto) som default och i gamla filer', () => {
    expect(defaultSave().settings.zoomCap).toBeNull();
    expect(mergeWithDefaults({ settings: { sound: false } } as never).settings.zoomCap).toBeNull();
  });
  it('zoomFor tar hänsyn till taket, som bara sänker', () => {
    expect(zoomFor(3, 2, null, null)).toBe(2);
    expect(zoomFor(3, 2, null, 1)).toBe(1);
    expect(zoomFor(1, 2, null, 2)).toBe(1);
    expect(zoomFor(3, 2, '1.5', 1)).toBe(1);
  });
  it('debugpanelens rad', () => {
    expect(zoomLine(2, 2, null)).toBe('Zoom: 2 (auto)');
    expect(zoomLine(1, 2, 1)).toBe('Zoom: 1 (vakt)');
    expect(zoomLine(2, 2, 1)).toBe('Zoom: 2 → 1 (vakt, från nästa appstart)');
  });
});
