# Status

*Uppdaterad 2026-09-21*

**Klart**
- Projektkatalog, CLAUDE.md, agentteam (5 roller)
- Research 01–04 (mekanik, stack, koncept, pixelpipeline), PROPOSAL.md
- Anders beslut: koncept B, Godot, titel PIPWRECK, pixelgrafik för figurer
- GAME_DESIGN.md v1, UI_GUIDE.md v1, wireframes
- **M0 godkänd**: Godot 4.6-projekt, gdUnit4, core (rng, modeller, resolver P0–P5, rewards, policies), 85 tester gröna, run-simulator, CI-workflow **grön på GitHub**, ARCHITECTURE.md
- Balanspass våning 1: +45,3 p.e. Lookahead över Greedy, rum 1–3 tar 3–3,4 rundor

**Pågår**
- **M1 vertical slice** startad: dev bygger spelbar strid + run-loop i `src/game/`, UI bygger asset-pipeline (CC0-sprites, LUT-shader, tärningssprites, ASSET_LICENSES.csv)

**Blockerat**
- Play-konto (25 USD) och 12-testare-listan: Anders manuellt

**Nästa (M1 vertical slice)**
- Dev: `src/game/` spelbar strid med rektangel/placeholder-grafik, uppspelare av händelselogg som överlappande tidslinje, autosave
- UI: revidera UI_GUIDE för pixelfigurer + krit-UI, importera M1-assets enligt licensregeln, ASSET_LICENSES.csv
