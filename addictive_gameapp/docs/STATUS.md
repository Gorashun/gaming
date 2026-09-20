# Status – addictive_gameapp

| Datum | Händelse |
|---|---|
| 2026-09-20 | Projekt och agentteam (PM, R&D, programmerare, UI) uppsatta. |
| 2026-09-20 | Research klar: speldesign + teknikstack (`docs/research/`). |
| 2026-09-20 | Förslag KLUNK skrivet (`docs/PROPOSAL.md`). **Väntar på go/no-go från Anders.** |

## Öppna beslut (Anders)
Se PROPOSAL.md §10: go/no-go, Mac, Google Play-konto och dess ålder, Apple-konto, arbetstitel.

## Kända risker
- iOS-flöde utan Mac ej verifierat.
- 12 testare/14 dagar på Play för nya personliga konton (källa ej verifierad i containern).
- WebView-prestanda måste mätas på riktig telefon tidigt (P0.3, P4.4).
- Phaser 4 är ung (april 2026); fallback Phaser 3.

## Beslut från Anders 2026-09-20
- Arbetstitel KLUNK godkänd, villkorat att idé och namn inte bryter mot upphovsrätt/varumärke. Åtgärd: egen grafik och eget ljud, inga frukter, ordet "Suika"/"Watermelon Game" används aldrig; varumärkessökning (PRV/EUIPO/USPTO) före butiksrelease.
- Inget Google Play-konto ännu. Utveckling sker via sideload av APK. Konto skaffas när produkten finns.
- Three.js utvärderat som alternativ till Phaser: viabelt, men vald stack förblir Phaser för v1 (se svar i sessionen).
| 2026-09-20 | Fas 0–1 klar och committad: kärnloop spelbar i webbläsare, 14 unit-tester + 2 e2e gröna. |
| 2026-09-20 | Capacitor Android-projekt + GitHub Actions. Första gröna APK-build (debug, 4,1 MB): https://github.com/Gorashun/gaming/actions/runs/35503212251 |
| 2026-09-20 | Fas 2 (juice, ljud, haptik, skärmar) pågår. |
