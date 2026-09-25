# Backlog – addictive_gameapp

Ägare: game-project-manager. Uppgifter är max 1 dag, har acceptanskriterium (AK) och ansvarig roll.
Status: `[ ]` ej påbörjad · `[~]` pågår · `[x]` klar

## Fas 0 – Grund (blockerad av go/no-go)
- [x] P0.1 Vite + Phaser 4 + TS-skelett i `app/`, `npm run dev` visar tom burk. AK: körs i webbläsare på 390×844-viewport. (programmerare)
- [x] P0.2 Playwright-test som startar spelet headless och tar screenshot. AK: `npm test` grönt. (programmerare)
- [x] P0.3 Benchmark-scen med 2 000 partiklar och fps-mätare. AK: fps loggas till konsol. (programmerare)
- [x] P0.4 `docs/TECH.md` med beslutad stack, mappstruktur, kommandon. (programmerare)
- [x] P0.5 `docs/DESIGN.md` med kärnloop, objektnivåer, regissörens lägen, belöningstabell. (projektledare + researcher)
- [x] P0.6 `docs/UI.md` med palett, objektstil, typografi, animationskurvor, ljudkarta. (ui-designer)

## Fas 1 – Kärnloop
- [x] P1.1 Burk med Matter-fysik, väggar, förlustlinje. AK: objekt faller och stannar.
- [x] P1.2 11 objektnivåer, merge vid kontakt mellan lika. AK: två lika → ett större, position = mittpunkt.
- [x] P1.3 Drop-kontroll: drag för att sikta, släpp för att tappa. Nästa-objekt-förhandsvisning. AK: fungerar med ett finger.
- [x] P1.4 Förlust när objekt ligger över linjen i >1,5 s, instant restart <0,5 s. AK: ett tryck → ny runda.
- [x] P1.5 Poäng och lokal highscore via Preferences/localStorage. AK: överlever omladdning.

## Fas 2 – Juice
- [x] P2.1 `systems/juice.ts` med `trigger(event, intensity)`. AK: alla effekter skalas från en siffra.
- [x] P2.2 Ljudsprite + pitch-stegring per combo. AK: hörbar stegring, reset vid miss.
- [x] P2.3 Hit-stop, scale-punch, partiklar, screen shake, scorepop. AK: proportionellt mot merge-nivå.
- [x] P2.4 Haptik via Capacitor med web-fallback. AK: avstängbar.
- [x] P2.5 Slow-mo nära förlustlinjen. AK: triggas bara när det är äkta nära.
- [x] P2.6 Epilepsi-guard: max 3 blink/s, Lugnt läge-ikon. AK: testfall i Playwright.

## Fas 3 – Regissören och meta
- [x] P3.1 `systems/director.ts`, seedbar, lägen torka/flöde/kick, all balansering i `data/`. AK: enhetstest utan rendering.
- [x] P3.2 Specialobjekt bomb, regnbåge, magnet. AK: dyker upp efter 25–60 drops, slumpat.
- [x] P3.3 Äkta near-miss-markering (två näst-största bredvid varandra). AK: puls syns, aldrig falskt positiv.
- [~] P3.4 Startskärm med hylla (bästa objekt) klar i fas 2. Kosmetisk upplåsning flyttad till v1.1.

## Fas 4 – Android
- [x] P4.1 Capacitor 8, `android/` incheckad, manifest utan INTERNET. AK: `npx cap sync android` grönt.
- [x] P4.2 WebView-fällor stängda (viewport, touch-action, overscroll, pointerdown). AK: ingen zoom/bounce på telefon.
- [x] P4.3 GitHub Actions: build → sync → assembleRelease + bundleRelease, signerat via secrets. AK: APK-artifact laddas ner och installeras.
- [ ] P4.4 Prestandamätning på riktig mellanklasstelefon. AK: ≥55 fps i kaskad.

## Fas 5 – Speltest och balans
- [ ] P5.1 Testprotokoll för barn 7–10 och vuxna. (researcher)
- [ ] P5.2 Balansera regissören i data efter test. (projektledare + programmerare)

## Fas 6 – iOS
- [ ] P6.1 `npx cap add ios`, macos-26-workflow, TestFlight. Blockerad av Apple-konto och Mac-frågan.

## v1.1-kandidater (från speltest)
- [ ] U1 Siktlinje-ikonens på-läge ritas i accent (cyan) medan de tre andra är hud-vita. Harmonisera (ui-designer).
- [ ] U2 Rampen räknar alla drops i rundan, även i Torka. Utvärdera om bara Flöde-drops ska räknas efter speltest.

## Fas 7 – Meta-lager v1.1 (DESIGN §13)
- [ ] M1 UI-spec: kedja i HUD, samlarbok (sida, platser, bläddring), rundavslut-sekvens, 4 nya temaset med palett/ljud/partiklar/dekor. (ui-designer)
- [ ] M2 Kedjan i HUD + `stats.createdPerLevel`. AK: siluetter tänds, "?" för aldrig nådda. (programmerare)
- [ ] M3 Samlarbok: datamodell, fångst, skimrande med garanti, boksida med bläddring, ingång från hyllan. AK: unit-tester för p och pity, e2e öppnar boken. (programmerare)
- [ ] M4 Temaset: 5 set i data, upplåsningslogik (två spår), val av aktivt set, texturer/ljud/partiklar per set. AK: unit-tester för upplåsning, e2e byter set. (programmerare)
- [ ] M5 Rundavslut "nytt!" ovanpå förlustskärmen, avbrytbart. AK: omstart <0,5 s även mitt i sekvensen. (programmerare)
