# Changelog

Format: en rad per leverans. Nyast överst.

## M0 – Setup (2026-09-21)

Godot 4.6-projekt, seedad och testbar core, headless-CI.

- **Projekt:** `project.godot` (PIPWRECK, portrait 1080×1920, mobile renderer,
  `canvas_items`/`expand`), `.gitignore` för Godot, mappstruktur enligt
  `research/02_tech_stack.md`, minimal `src/game/main.tscn`.
- **Testramverk:** gdUnit4 v6.2.1 vendorerad i `addons/gdUnit4/`, körs headless.
- **Core:** `rng.gd` (seedad ström med `state()`/`restore()`), datamodellerna ur
  GAME_DESIGN §2.1 (`Rules`, `Face`, `Die`, `Slot`, `Board`, `Intent`, `Enemy`,
  `Relic`, `CombatState`, `RunState`) med `to_dict()`/`from_dict()`,
  `resolver.gd` (faserna P0–P5, ingen RNG, muterar inte indata),
  `rewards.gd` (3 alternativ, vikter och garantier ur §4.7),
  `policy.gd` (Greedy + Lookahead).
- **Innehåll:** `src/data/content.gd` med M1:s sidor, reliker, slot-byten,
  fiender, möten och Smedens startuppsättning.
- **Tester:** 85 gdUnit4-fall i 5 sviter – determinism, renhet, RNG-state,
  serialisering, de åtta räkneexemplen i §2.4, eventlogg-invarianterna i §3 och
  belöningsgarantierna i §4.7.
- **Simulator:** `tools/run_simulator.gd` kör N seedade strider och/eller hela
  runs per policy och skriver vinst%, rundor/strid, combo-, överflöds- och
  Charge-frekvens, kåkar, explosionsfrekvens samt greedy-vs-lookahead-deltat.
- **CI:** `.github/workflows/test.yml` – Godot 4.6 headless, gdUnit4 med
  JUnit-output, simulatorn, artefakter.
- **Dokumentation:** `docs/ARCHITECTURE.md`.

Mätvärden vid leverans (Godot 4.6.stable, headless, x86_64):

| Mätning | Resultat |
|---|---|
| gdUnit4 | 85/85 gröna, 0 fel, 0 orphans, 916 ms |
| 1 000 strider, GreedyPolicy | 0,55 s |
| 1 000 strider, LookaheadPolicy (width 8) | 4,66 s |
| 200 hela runs, greedy → lookahead vinst% | 80,5 % → 94,5 % (+14,0 p.e.) |
| 300 bossstrider, greedy → lookahead vinst% | 63,0 % → 100,0 % (+37,0 p.e.) |
| `resolve()` | 244 µs (efter copy-on-write-optimering, från 319 µs) |
