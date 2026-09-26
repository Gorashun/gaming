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
| 2026-09-20 | Fas 2 och 3 klara: juice, syntetiskt ljud, haptik, regissör, bomb/regnbåge, jackpot, near-miss. 47 unit + 8 e2e gröna. |
| 2026-09-20 | **Testversion 1 levererad.** Webb: https://claude.ai/artifact/DNkPAJ9nfJuYRRtMYyrcwd · APK: https://github.com/Gorashun/gaming/actions/runs/35505844823 (artefakt `klunk-debug-apk`) |

## Nästa steg (fas 5)
- Anders testar på Android-telefon: prestanda i kaskad, touchkänsla, ljudlatens.
- Speltest med barn 7–10. Justera regissören i `app/src/data/director.ts` efter observationer.
- Kända luckor: kosmetisk upplåsning (v1.1), desaturering vid fara, tabulära siffror i HUD, pool för Matter-bodies.
| 2026-09-20 | Rullande release `test-latest`: varje push ger ny APK på https://github.com/Gorashun/gaming/releases/download/test-latest/klunk-debug.apk |
| 2026-09-20 | Mjuk auto-drop (DESIGN §11) klar: bara i Flöde, efter första egna drop, vickning 3 s, fall 6 s, timer nollställs när fara/slow-mo släpper. 75 unit + 13 e2e gröna. **Testversion 2** på samma länkar. |
| 2026-09-20 | Ramp 6→3,5 s över 60 drops + siktlinje bara vid sikte, med inställningsikon. 80 unit + 17 e2e gröna. **Testversion 3.** |
| 2026-09-25 | Meta-lager v1.1 klart: kedja i HUD, samlarbok med skimrande, 5 temaset med upplåsning på två spår, rundavslut "nytt!". 113 unit + 23 e2e gröna. **Testversion 4.** |
| 2026-09-25 | Kompisar v1.2 klart: 48 avatarer i 6 rariteter, musslor utan pity/dubbletter, XP-nivåer I–III, 20 unika förmågor. 147 unit + 32 e2e gröna. **Testversion 5.** |
| 2026-09-25 | Engelska primärspråk + svensk lokalisering, butikstext EN/SV, polish-omgång, bakåtknapp, testprotokoll (`docs/PLAYTEST.md`) och debugpanel (långtryck 2 s på logotypen). 168 unit + 39 e2e gröna. **Testversion 6.** |
| 2026-09-25 | Ekonomi v1.3 (pärlor, stjärnsand, tre musslor i butik, uppgradering mot kostnad, förmågetext EN/SV), Art v2 med hi-DPI (tak 2×) och fps-vakt, nystart via schema 2. 214 unit + 47 e2e gröna. **Testversion 7.** |
| 2026-09-26 | Start v2 (tydliga knappar med etiketter, inställningsark, butiksbadge) + robust e2e. 222 unit + 56 e2e gröna. **Testversion 8.** |
