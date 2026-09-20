# Backlog – addictive_gameapp

Ägare: game-project-manager. Uppgifter är max 1 dag, har acceptanskriterium (AK) och ansvarig roll.
Status: `[ ]` ej påbörjad · `[~]` pågår · `[x]` klar

## Fas 0 – Grund (blockerad av go/no-go)
- [ ] P0.1 Vite + Phaser 4 + TS-skelett i `app/`, `npm run dev` visar tom burk. AK: körs i webbläsare på 390×844-viewport. (programmerare)
- [ ] P0.2 Playwright-test som startar spelet headless och tar screenshot. AK: `npm test` grönt. (programmerare)
- [ ] P0.3 Benchmark-scen med 2 000 partiklar och fps-mätare. AK: fps loggas till konsol. (programmerare)
- [ ] P0.4 `docs/TECH.md` med beslutad stack, mappstruktur, kommandon. (programmerare)
- [ ] P0.5 `docs/DESIGN.md` med kärnloop, objektnivåer, regissörens lägen, belöningstabell. (projektledare + researcher)
- [ ] P0.6 `docs/UI.md` med palett, objektstil, typografi, animationskurvor, ljudkarta. (ui-designer)

## Fas 1 – Kärnloop
- [ ] P1.1 Burk med Matter-fysik, väggar, förlustlinje. AK: objekt faller och stannar.
- [ ] P1.2 11 objektnivåer, merge vid kontakt mellan lika. AK: två lika → ett större, position = mittpunkt.
- [ ] P1.3 Drop-kontroll: drag för att sikta, släpp för att tappa. Nästa-objekt-förhandsvisning. AK: fungerar med ett finger.
- [ ] P1.4 Förlust när objekt ligger över linjen i >1,5 s, instant restart <0,5 s. AK: ett tryck → ny runda.
- [ ] P1.5 Poäng och lokal highscore via Preferences/localStorage. AK: överlever omladdning.

## Fas 2 – Juice
- [ ] P2.1 `systems/juice.ts` med `trigger(event, intensity)`. AK: alla effekter skalas från en siffra.
- [ ] P2.2 Ljudsprite + pitch-stegring per combo. AK: hörbar stegring, reset vid miss.
- [ ] P2.3 Hit-stop, scale-punch, partiklar, screen shake, scorepop. AK: proportionellt mot merge-nivå.
- [ ] P2.4 Haptik via Capacitor med web-fallback. AK: avstängbar.
- [ ] P2.5 Slow-mo nära förlustlinjen. AK: triggas bara när det är äkta nära.
- [ ] P2.6 Epilepsi-guard: max 3 blink/s, Lugnt läge-ikon. AK: testfall i Playwright.

## Fas 3 – Regissören och meta
- [ ] P3.1 `systems/director.ts`, seedbar, lägen torka/flöde/kick, all balansering i `data/`. AK: enhetstest utan rendering.
- [ ] P3.2 Specialobjekt bomb, regnbåge, magnet. AK: dyker upp efter 25–60 drops, slumpat.
- [ ] P3.3 Äkta near-miss-markering (två näst-största bredvid varandra). AK: puls syns, aldrig falskt positiv.
- [ ] P3.4 Startskärm med hylla (bästa objekt) och kosmetisk upplåsning. AK: noll text krävs.

## Fas 4 – Android
- [ ] P4.1 Capacitor 8, `android/` incheckad, manifest utan INTERNET. AK: `npx cap sync android` grönt.
- [ ] P4.2 WebView-fällor stängda (viewport, touch-action, overscroll, pointerdown). AK: ingen zoom/bounce på telefon.
- [ ] P4.3 GitHub Actions: build → sync → assembleRelease + bundleRelease, signerat via secrets. AK: APK-artifact laddas ner och installeras.
- [ ] P4.4 Prestandamätning på riktig mellanklasstelefon. AK: ≥55 fps i kaskad.

## Fas 5 – Speltest och balans
- [ ] P5.1 Testprotokoll för barn 7–10 och vuxna. (researcher)
- [ ] P5.2 Balansera regissören i data efter test. (projektledare + programmerare)

## Fas 6 – iOS
- [ ] P6.1 `npx cap add ios`, macos-26-workflow, TestFlight. Blockerad av Apple-konto och Mac-frågan.
