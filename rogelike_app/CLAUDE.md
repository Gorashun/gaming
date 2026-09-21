# rogelike_app – PIPWRECK, projektregler

Spelets titel: **PIPWRECK** (svenskt arbetsnamn "Kastgropen"). Tärningsroguelike: 6 tärningar, 5 slots med egenskaper, kedja resolvas vänster→höger, sidor smids om mellan strider.

Roguelike-mobilspel, Android först, iOS därefter. Målgrupp 13+. Kärnkrav: täta, variabla dopaminkickar och "en run till"-känsla utan dark patterns eller pengaspel.

## Läs först
- `docs/PROPOSAL.md` – konceptförslag och tech-val (beslutsunderlag)
- `docs/DECISIONS.md` – fattade beslut, ändra inte utan nytt beslut
- `docs/GAME_DESIGN.md` – speldesign
- `team/README.md` – agentroller

## Tech stack (beslutad, byt inte)
- Godot **4.6 stable**, **typed GDScript 2.0** (Godot 4-syntax: `@export`, `@onready`, `func f() -> void`, `signal`, `await`; aldrig Godot 3-syntax som `export var`, `yield`, `onready var`). Ingen C#.
- Tester: gdUnit4, körs headless (`godot --headless`). CI via GitHub Actions.
- Portrait 1080×1920, mobil-renderer. Target Android API 36, arm64 + armv7.
- `src/core/` = ren spellogik utan Node-beroenden. Importerar aldrig från `src/game/`. Core tar data in och returnerar en händelselogg (Array of events) som UI-lagret spelar upp.

## Regler
- Spellogik är deterministisk, seedad och testbar utan UI.
- Ingen backend för MVP. Offline-first.
- Inga lootboxar för pengar, inga energi-timers, inga pay-to-win. Belöningsvariation sker inuti spelet, inte i butiken.
- Svenska i dokumentation, engelska i kod. Commits på engelska.
- Varje leverans: build + tester körda, resultat rapporterat ordagrant.
