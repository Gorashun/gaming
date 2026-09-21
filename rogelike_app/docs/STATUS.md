# Status

*Uppdaterad 2026-09-21*

**Klart**
- Projektkatalog, CLAUDE.md, agentteam (5 roller)
- Research 01–04 (mekanik, stack, koncept, pixelpipeline), PROPOSAL.md
- Anders beslut: koncept B, Godot, titel PIPWRECK, pixelgrafik för figurer
- GAME_DESIGN.md v1, UI_GUIDE.md v1, wireframes
- **M0 godkänd**: Godot 4.6-projekt, gdUnit4, core (rng, modeller, resolver P0–P5, rewards, policies), 85 tester gröna, run-simulator, CI-workflow **grön på GitHub**, ARCHITECTURE.md
- Balanspass våning 1: +45,3 p.e. Lookahead över Greedy, rum 1–3 tar 3–3,4 rundor
- **M1 godkänd**: våning 1 spelbar (marsch → strid → belöning → boss → vinst/död → ny run), autosave, 160 tester, smoke-run med skärmdumpar
- **M1.5 godkänd**: engelska källsträngar + svensk översättning, sprites integrerade, 188 tester, skärmdumpar i docs/screenshots/m1_5/
- **M2.5 godkänd**: stridsskärm v2 med kvitto, tutorialvåning 0, stad (logik), smedja, könsval, engelska default. 339 tester
- **M2 godkänd**: juice-motor, chalk-UI, ljud (17 own-work WAV), haptik, boss-intro, vinst/död, inställningar, titelskärm, reliklager och dödsframes, färgblindsäkra former. 227 tester
- **M4 godkänd**: Android-workflow grön, signerad debug-APK (61 MB) som artefakt, bakåtknapp/paus/safe area, docs/ANDROID.md. Webbversion publicerad som artefakt i chatten (Web-preset + gzip-loader i tools/web/)
- Asset-pipeline: 93 egengjorda assets, licensregister med CI-check, palett-LUT- och krit-shaders, paperdoll-spec

**Pågår**
- UI: saknade i18n-rader (~45) och kortning av svenska mikrotexter
- **M5 Korridoren (bygge)**: utseende godkänt av Anders. Dev 2 bygger corridor_map (core), korridorvy i Godot 3D, texturer, rörelse, riktningsknappar, autosave per ruta, i nya filer. Integration med strid v2 och character sheet efter att M2.5 landat

**Blockerat**
- Play-konto (25 USD) och 12-testare-listan: Anders manuellt

**Nästa**
- M4 Android-export (keystore, AAB, target API 36) och test på Anders telefon, rekommenderas före M3 så juicen utvärderas på riktig hårdvara
- M3 innehåll: 3 klasser, 40 sidor, 20 reliker, Glasvåningar, Ödeskast, Kodex, våning 2–3
