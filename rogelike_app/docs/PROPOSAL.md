# Förslag: "Kastgropen" – tärningsroguelike för mobil

*PM-syntes av research 01–03 · 2026-09-21 · Status: väntar på Anders beslut (se sektion 7)*

## 1. Förslaget i tre meningar
Bygg **Kastgropen**: en portrait-roguelike där ditt lag är sex tärningar. Varje runda rullar du, placerar tärningarna i fem slots med egenskaper, och ser en kedjereaktion spela upp sig vänster→höger med stigande siffror, skak och ljud. Mellan striderna smider du om enskilda tärningssidor, så tärningarna *är* din build.

Bygg den i **Godot 4.6 med typed GDScript**, med all spellogik som en ren, seedad funktion `resolve(board, dice, relics) -> events` som testas headless, medan UI-lagret bara spelar upp händelseloggen.

## 2. Varför just detta uppfyller kraven

| Krav från Anders | Hur Kastgropen löser det | Evidens |
|---|---|---|
| Täta dopaminkickar | Varje runda (~30 s) är en variabel belöningshändelse. Varje strid (~3–5 min) slutar i ett val av 1 av 3. | Gemensam nämnare i alla nio referensspel: ett val var 60–90 s (01) |
| "Dras tillbaka" som TikTok | Kort run (8–15 min aktiv tid) med autosave per runda, känd slutpunkt ger near-miss ("bossen hade 3 HP"). Förlust ger alltid unlock-poäng. | Mobil-median 3,1–3,5 min/session; StS/Hades belönar förlust (01) |
| Oväntat, ibland segt, plötsligt askul | Inbyggt i mekaniken: Glasvåningar (segt, tärningar kan spricka) → Ödeskast var 4:e våning byter en spelregel → Spegel/Amboss-slots ger ×8→×32-explosioner. | Balatro-effekten kräver synlig kausalitet, ~300 ms per steg (01); moment-katalog med 10 situationer (03) |
| 13+, inga dark patterns | Inga annonser, timers, gems eller lootboxar. Horisontell meta (nya tärningsmaterial, klasser, Kodex), aldrig statboostar. | Binärt krav i alla kuraterade mobillistor; EU Digital Fairness Act på väg (01, 03) |
| Android först, iOS sedan | Godot exporterar båda från samma projekt. iOS byggs på Codemagics gratis Mac-minuter. | 02 |
| Solo-dev utan grafiker | Tärningar och slots är geometri. Fiender som silhuetter/emoji. Juice (partiklar, tweens, pitch-shift) är inbyggt i Godot. | Genomförbarhet 9/10 (03); Brotato byggt i Godot (02) |

**Varför inte de andra kandidaterna:** deckbuilder ("Handen") är mättad genre med dokumenterade läsbarhetsproblem på liten skärm även för Balatro-porten. Grid-crawler ("Grottan") ger kickar var 5:e minut, inte var 30:e sekund, och konkurrerar direkt med Shattered Pixel Dungeon som är gratis och nästan perfekt.

## 3. Kärnloop

```
30 s   Rulla → placera 6 tärningar i 5 slots (drag, ångra fritt) → förhandsvisa kedjan → bekräfta → kedjan spelas upp
5 min  Strid (3–6 rundor) → välj 1 av 3: ny sida / relik / slot-byte → nästa rum
15 min Run: 12 rum i 3 våningar, boss per våning, Ödeskast efter rum 4 och 8
1 h    2–4 runs → ny tärningstyp, klass eller Kodex-post upplåst
```

Fem synergiregler (hela djupet ska komma härifrån, inte från fler tärningar):
1. **Par/triss/kåk** i angränsande slots multiplicerar ×2/×4/×8.
2. **Överflöd rullar över**: overkill går till nästa fiende, oanvända ögon blir Laddning nästa runda.
3. **Slots har egenskaper** (Eld, Spegel, Amboss, Ladda, Tomrum) och byts via reliker.
4. **Sidor är permanenta items**: smid om en 1:a till en Giftdroppe. Tärningen är din build.
5. **Kedjan är alltid synlig innan bekräftelse.** Ingen dold slump i utfallet. Helig regel.

Tre startklasser: **Smeden** (få, enorma järntärningar), **Spelaren** (åtta bentärningar, fler omkast, högst varians), **Alkemisten** (glastärningar med symbolsidor som reagerar). Full lista med 15 synergi-items och 10 "moment" finns i `research/03_koncept_och_community.md`.

## 4. Designprinciper (från research, gäller alla beslut)
1. Ett belöningsval var 60–90 s, alltid 3 alternativ, minst ett spännande.
2. Synergier med synlig kausalitet: core returnerar en händelselogg, UI spelar upp den sekventiellt med stigande tonhöjd.
3. Run 8–15 min aktiv tid, autosave varje runda, känd slutpunkt.
4. Förlust ger alltid något permanent. Innehåll, aldrig styrka.
5. Portrait, en tumme, ett beslut per tryck, touch targets ≥ 48 dp, hög kontrast som standard.
6. Inga hjul, spakar eller "777"-estetik. Tärningar med placering är strategispel (Dicey Dungeons: PEGI 7). Håller Apple 13+.

## 5. Tech stack

**Val: Godot 4.6, typed GDScript. Plan B: Flutter + Flame.** Unity, React Native och WebView-wrapper avråds.

| Skäl | Detalj |
|---|---|
| Juice är inbyggt | Tween, AnimationPlayer, GPUParticles2D, `pitch_scale`, `vibrate_handheld`. I Flame skrivs allt detta för hand. |
| Testbart | gdUnit4 kör headless i CI. Run-simulator kör 10 000 seedade runs för balansstatistik (Mega Crits metod). |
| Mobilmoget 2026 | Kraschfrekvens i shippade Godot-mobilspel under 1 %. Officiella Play/StoreKit-plugins. Android-spegling i editorn. |
| Referens i genren | Brotato är byggt i Godot. |
| Gratis | MIT, inga intäktstak. |
| AI-kodbart | Konsekvent API, frontier-LLM:er skriver bra GDScript. Risk: Godot 3-syntax. Åtgärd: version pinnad i CLAUDE.md, tester fångar. |

Kända nackdelar: nytt språk (Python-likt, låg tröskel från JS), APK cirka 40 MB, sämre hot reload än Flutter. Om vecka 1 visar friktion byter vi till Flutter + Flame utan att designdokumenten ändras.

Arkitekturregel från dag 1: `src/core/` importerar aldrig från `src/game/`. Core är data in, händelselogg ut.

## 6. Plan och milstolpar

| Milstolpe | Innehåll | Klart när |
|---|---|---|
| **M0 Setup** (vecka 1) | Godot-projekt, gdUnit4, CI, `rng.gd`, `run_state.gd`, `resolve()` med tester, Play-konto, 12-testare-listan startad | CI grön, 1 000 headless-runs på < 5 s |
| **M1 Vertical slice** (vecka 2–3) | 1 klass, 5 slots, 8 tärningssidor, 6 fiender, 1 boss, belöningsval, död → meta-poäng. Rektangelgrafik. | Rollspelsnörd ger Roligt ≥ 6/10 |
| **M2 Juice** (vecka 4) | Sekventiell kedjeuppspelning, hit-stop, skak, number pop, stigande tonhöjd, haptik | Roligt ≥ 8/10 på telefon |
| **M3 Innehåll** (vecka 5–7) | 3 klasser, 40 sidor, 20 reliker, 8 slot-typer, Glasvåningar, Ödeskast, Kodex, 15 fiender, 3 bossar | Run-simulatorn visar ingen klass > 60 % vinst |
| **M4 Android closed test** (vecka 8) | AAB, IARC, Data safety, privacy policy, 12 testare i 14 dagar | Testare rapporterar D1-retention och "en run till" |
| **M5 iOS** (vecka 10+) | Apple Developer (99 USD), Codemagic iOS-build, TestFlight | Samma build spelbar på iPhone |

Tidsuppskattningarna förutsätter hobbytakt med agenter som bygger. Märkt som uppskattning.

Kostnader: Google Play 25 USD engångs (vecka 1). Apple 99 USD/år (först vid M5). Allt annat gratis.

## 7. Beslut som kräver Anders

1. **Koncept:** Kastgropen (B) enligt ovan. Rekommenderas.
2. **Stack:** Godot 4.6 + GDScript, plan B Flutter + Flame. Rekommenderas.
3. **Affärsmodell:** Rekommendation: gratis utan annonser under closed test, därefter premium (cirka 29–49 kr) eller gratis med frivilligt "köp mig en kaffe"-stöd. Inga IAP som påverkar spelet. Kan skjutas till M4.
4. **Arbetstitel:** "Kastgropen" är placeholder. Byt gärna.

Svara med "kör" för 1–2 så startar M0. Övriga kan vänta.

## 8. Största riskerna
| Risk | Sannolikhet | Åtgärd |
|---|---|---|
| Djupet bär inte: känns som Luck be a Landlord ("passivt slot-spel") | Medel | Sidsmide och slot-egenskaper prioriteras före fler tärningar. Rollspelsnörd betygsätter varje milstolpe. Stoppregel: Roligt < 6 efter M1 ⇒ omdesign av placeringsagens innan M2. |
| Tärnings-RNG-ilska à la Dicey Dungeons | Medel | 1–2 omkast per runda, ångra placering fritt, kedjan visas alltid innan bekräftelse. |
| Godot-friktion för en JS-utvecklare | Låg–medel | Vecka-1-retro med explicit plan B. |
| Play Stores 14-dagars testkrav försenar lansering | Hög om vi väntar | Starta kontot och testarlistan vecka 1. |
| Åldersklassning 18+ på Apple på grund av "simulated gambling" | Låg | Ingen slot-estetik. Tärningar + placering, som Dicey Dungeons. |

## Underlag
- `research/01_engagement_mekanik.md` – mekaniker, mobildata, juridik (35 källor)
- `research/02_tech_stack.md` – stackjämförelse, mappstruktur, vecka-1-plan (26 källor)
- `research/03_koncept_och_community.md` – community-röst, tre kandidater, moment-katalog, items (18 källor)
