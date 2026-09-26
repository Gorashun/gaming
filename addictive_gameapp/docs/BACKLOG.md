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
- [x] P5.1 Testprotokoll för barn 7–10 och vuxna: `docs/PLAYTEST.md`.
- [x] P5.1a Debugpanel bakom långtryck på logotypen: rundlogg (tid till första merge, återstart, mussla-tider), Kopiera JSON, Nollställ, Ge kompis, Auto-drop av/på. Bara i testbygge-flagga eller alltid dold bakom långtryck 2 s.
- [ ] P5.2 Balansera regissören i data efter test. (projektledare + programmerare)

## Fas 6 – iOS
- [ ] P6.1 `npx cap add ios`, macos-26-workflow, TestFlight. Blockerad av Apple-konto och Mac-frågan.

## v1.1-kandidater (från speltest)
- [x] U1 Siktlinje-ikonens på-läge ritas i accent (cyan) medan de tre andra är hud-vita. Harmonisera (ui-designer).
- [ ] U2 Rampen räknar alla drops i rundan, även i Torka. Utvärdera om bara Flöde-drops ska räknas efter speltest.

## Fas 7 – Meta-lager v1.1 (DESIGN §13)
- [x] M1 UI-spec: kedja i HUD, samlarbok (sida, platser, bläddring), rundavslut-sekvens, 4 nya temaset med palett/ljud/partiklar/dekor. (ui-designer)
- [x] M2 Kedjan i HUD + `stats.createdPerLevel`. AK: siluetter tänds, "?" för aldrig nådda. (programmerare)
- [x] M3 Samlarbok: datamodell, fångst, skimrande med garanti, boksida med bläddring, ingång från hyllan. AK: unit-tester för p och pity, e2e öppnar boken. (programmerare)
- [x] M4 Temaset: 5 set i data, upplåsningslogik (två spår), val av aktivt set, texturer/ljud/partiklar per set. AK: unit-tester för upplåsning, e2e byter set. (programmerare)
- [x] M5 Rundavslut "nytt!" ovanpå förlustskärmen, avbrytbart. AK: omstart <0,5 s även mitt i sekvensen. (programmerare)
- [x] U3 `freshSet` ska pulsa i boken tills boken besökts, inte nollställas i rundavslutet.
- [x] U4 Svep-ledtråd första gången boken öppnas; Androids bakåtknapp stänger boken.
- [x] U5 Sex guldstjärnor när skimrande skapas; dubbelring vid "?"-tändning (UI.md §12).

## Fas 8 – Kompisar v1.2 (DESIGN §14)
- [x] K1 UI: 48 avatarer som ritrecept i `data/avatars.ts` (Släpparen-figur, raritet, kosmetik, animationsrecept), musslans öppning, odds-burk, fliken Kompisar, uppgraderingspärlor, förhandsbild. (ui-designer)
- [x] K2 Logik: musslor (intjäning, odds, ingen dubblett, ingen pity), inventarie, XP/nivåer, sparning, öppningsflöde på startskärmen, fliken Kompisar. (programmerare)
- [x] K3 Rendering av Släpparen + alla kosmetiska effekter + förmågor (sällsynt–mytisk) med nivåskalning. (programmerare)
- [x] U6 Lisas lykta ska krympa synligt när tiden tar slut.
- [x] U7 Boken: scroll-ledtråd, puls på nya kompisar, öppna på Kompisar-fliken när ny kompis finns.
- [x] U8 Tryck på siluett skakar bara cellen; tonad överkant på rutnätet.
- [ ] U9 Mät öppningens 1,2 s på riktig telefon (räknas i speltid).
- [x] U10 Speltesta Siris kö-fördröjning och Havsdrottningens extra specialobjekt (drop 22/44).
- [x] U11 Språk: `{en, sv}`-namn, i18n-modul, butikstext EN/SV.
- [x] U12 Låt en engelsktalande läsa avatarnamnen ("Echo the Echo" är svagt).
- [ ] U13 Debugpanel: sessionsfält firstBoxEarnedMs/firstBoxOpenedMs/firstBookOpenMs/firstFriendsTabMs (PLAYTEST §3).

## Fas 9 – Ekonomi v1.3 (DESIGN §16)
- [x] E1 UI: butikshylla i Kompisar (tre musslor, pris, oddsburk var), resursikoner pärla/stjärnsand, förmågetext-yta, uppgraderingsknapp + stapel, rundavslutets resursräkning; text `desc: {en, sv}` ≤60 tecken för alla 48. (ui-designer)
- [x] E2 Logik: resurser, intjäning, gratismussla från baseline, tre musseltyper med odds/golv, köp, uppgradering med kostnad, migrering utan retroaktivitet, pick3-flagga. (programmerare)
- [x] E3 Integration i bok, rundavslut och startskärm; tester; testversion 7. (programmerare)

## Fas 10 – Art v2 (DESIGN §17)
- [x] A1 Koppla artv2 till CanvasTexture, hi-DPI-rendering med tak 2×, bakning av aktivt set + kompisar, fallback v1. (programmerare)
- [ ] A2 v2 på bomb, regnbåge, pärlor, romber, musslor, partiklar. Glöd som gemensam sprite.
- [x] U14 e2e `artv2.spec (d,e)` flakar under parallell last i DPR 2 (grön ensam). Gör den robust eller kör serial.

## Fas 11 – Start v2 (DESIGN §18)
- [x] S1 Start v2: resurspiller, kugghjul/inställningsark, hjälte, SPELA, tre kort, set-stapel, Fredoka.
- [ ] S2 Utvärdera `Scale.EXPAND` på Start för att använda höjden på långa telefoner.
- [ ] S3 Byt namn på/ta bort föråldrade skärmdumpar (start-shelf, start-four-icons, start-aim-off, start-settings-off, shelf-box).
- [ ] L1 Språkval i inställningsarket (English / Svenska), sparas i `settings.lang`, `setPreferredLocale` vid Boot och vid byte; standard engelska.

## Fas 12 – Child-safety baseline (docs/reviews/2026-09-26-baseline.md, PASS WITH CHANGES)
- [ ] CS1 (P1) Odds jars: rarities under 4 % shown as a hollow "very rare" speck, plus an odds sheet with exact percentages.
- [ ] CS2 (P1) Store listing: update to current economy (pearls buy shells/upgrades, earned currency only), add privacy policy text/page.
- [ ] CS3 (P1) Near-miss: require same level in `findNearMiss` (8 and 9 must not pulse).
- [ ] CS4 (P1) Game over: Home button, replay icon stops pulsing after a few cycles, gentle "good place to stop" moment.
- [ ] CS5 (P2) Rename Shop/Free! to Shells/Gift!; own sound for affordable hint; peeking shell max 3 bounces.
- [ ] CS6 (P2) First shell as a "choose 1 of 3" gift instead of always-rare random.
- [ ] CS7 (P2) Unit test: director never reads save data. Playtest: children's auto-drop share.

## Fas 13 – Legal/IP fixes (docs/legal/ip-review-2026-09-26.md)
- [ ] LG1 (HIGH) Replace stock Capacitor icon/splash with our own (release engineer, in progress); verify in built APK.
- [ ] LG2 Own score curve (not Suika's triangular 1,3,6…66); replace fruit-like level names (e.g. "Peach"); no Suika/watermelon/fruit in store text; lead screenshots with buddies.
- [ ] LG3 Renames: SV "Spådamen Siri" → "Spådamen Vera" / EN "Vera the Seer", id `siri` → `vera` with save migration; "Freddie the Frog" → "Figgy the Frog" + redraw eyes (away from Keroppi); "Pirate Pete" → "Captain Kip"; set "The Frosties" → "The Icelings" / "Isbitarna".
- [ ] LG4 Mouse silhouette in the Book: oval head, lower ears (no Mickey read).
- [ ] LG5 Ship open-source notices: generated notices file (Phaser, Capacitor, Android libs, Fredoka OFL) + "Licenses" row in the settings sheet.
- [ ] LG6 Store text: no PEGI claim in text, add privacy policy, drop "only" in "saved on your device only" (Android backup is on) or disable backup.
- [ ] LG7 Replace the two-note sound that shares Mario coin pitches (audio batch).
- [ ] LG8 Before public store launch: lawyer clearance search for "KLUNK" in Nice classes 9/28/41 (Mattel KERPLUNK risk). Fallbacks: Glimjar, Plopkin, Glimta.
