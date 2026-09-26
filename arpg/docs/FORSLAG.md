# Förslag: LANTERNA (arbetstitel)

> Studions samlade rekommendation. Underlag med källor: `research/teknik.md`, `research/arpg-system.md`, `research/art-ui-ljud.md`, `research/marknad-engagemang-regler.md`, `lore/UNIVERSUM-PITCH.md`. Siffror är utgångsvärden/uppskattningar tills de simulerats.

## 1. Vision i en mening
Ett 3D chibi-ARPG i Diablo-kamera där du bär det sista ljuset in i en värld som glömt vem den är – varje fiende du besegrar tänds igen, varje föremål kan "tändas" starkare, och bakom varje hörn kan något oväntat vänta.

**Tagline:** *Bär ljuset. / Carry the light.*

## 2. Den viktiga kursändringen: "beroendeframkallande" → "omöjlig att inte längta tillbaka till"
Målgrupp 7+ i EU gör att TikTok-modellen **inte går att bygga lagligt eller etiskt**:
- EU-kommissionens riktlinjer till DSA art. 28: slumpbelöningar, knapphet och övertalande design som driver överdrivet användande ska inte riktas mot minderåriga.
- PEGI (från juni 2026): köpbar slump ⇒ minst PEGI 16. Tidsbegränsade köperbjudanden ⇒ minst PEGI 12.
- Prejudikat: Epic bötfälldes 1,1 M€ (NL) för köptryck mot barn; Konsumentverket agerade mot Star Stable 2025.

**Lösningen:** Vi behåller exakt det som gör ARPG-genren fängslande – variabel loot, överraskningar, juice, progression – men **tar bort allt som tjänar pengar på tvång**. Kickarna kommer från spelet, inte från butiken eller notiserna.

| Behåller (kickmaskinen) | Tar bort (tvångsmaskinen) |
|---|---|
| Slumpad loot från fiender med pity | Loot boxes, gacha, premiumvaluta |
| Guld-goblins, hemliga nivåer, mystiska ägg | Energi/stamina, nedräkningar, FOMO |
| "Golden moment" för Legendary+ | Streaks som nollställs |
| Rift på 3–6 min, delbelöning om avbruten | Push-notiser som lockar tillbaka |
| Dagliga mål utan straff | Lyckohjul/spelautomat-estetik |
| Vilad XP – belönar pauser | Reklam, pay-to-win, öppen chatt |

## 3. Belöningsrytm ("kickschemat")
| Intervall | Kick |
|---|---|
| Sekunder | Hitstop, skadesiffror, fiender "tänds" och flyr, guld-/loot-sprut |
| ~1 min | Magic/Rare-drop med grön uppgraderingspil |
| 3–6 min | Rift/dungeon klar, kista, nivåstreck (4 delstreck per nivå) |
| 15–45 min | Legendary (pity garanterar senast ~45 min) |
| Session | Level up, skill point, nytt crafting-recept upptäckt i Kitteln |
| Oväntat | Guld-goblin → Guldvalvet, Karamellkrypta, tekalaset bakom vattenfallet, rift-events |
| Veckor | Mythic (pity 8–20 h), Named-vapen (25–40 h efter lvl 60), veckoboss |

## 4. Teknik
| Område | Val | Varför |
|---|---|---|
| Motor | **Godot 4.x (GDScript)**, Mobile-renderer | MIT, inga avgifter, textbaserade scener, headless export/test – passar agentutveckling. Unity 6 = plan B |
| Plattform | Android först (AAB, targetSdk 36), iOS via macOS-runner i GitHub Actions | iOS kräver Mac + Apple Developer (99 USD/år) – samma kodbas, så iOS kostar lite extra |
| Prestandamål | 30 fps golv/60 mål på mellanklass (Mali-G57/Adreno 610) | 30–50 animerade fiender + 100–300 "fodder" via VAT/MultiMesh (**obekräftat – första spike**) |
| 3D-assets | Blender headless + bpy-skript → .glb, eget ~20-bens skelett, leksaksleder, palettatlas | Allt egenproducerat, reproducerbart, budgetkontroll i CI |
| Ljud | jsfxr/jfxr/Bfxr + förrenderad syntes | Egenproducerat, fria licenser |
| Data | Allt balansdata i JSON under `game/data/`, seedad RNG, Python-simuleringar | Testbart och justerbart utan kodändring |
| Data/integritet | Offline-först, lokal save, inga konton, ingen tredjepartsanalys | Enklast lagligt för < 13 år |

**Huvudrisker:** Godot saknar släppt kommersiell mobil-3D-ARPG som referens; känd Android-prestandaregression (4.4–4.5). Båda prövas i spikes innan vi låser.

## 5. Universum: *Den Slocknade Lyktan*
Den Grå Gästen blåste ut Världslyktan. Tystnaden äter färg, ljud och minnen. Monstren är "Släckta" – varelser som glömt vilka de är. Besegrade tänds de igen och flyr (ingen gore = 7+). Slutbossen är en ensam väktare som du inte förgör utan tänder.

**Världar/akter:** Vekemyren → Viskskogen → Ekogruvorna → Rimhovet → Tystnadens Brunn (+ endgame: Djupmörkret).

## 6. System (kravlistan)
| Krav | Förslag |
|---|---|
| ≥ 5 klasser | 6 planerade, 5 vid release: **Lyktbäraren** (tank, Glöd), **Klockslagaren** (bärsärk, Ilska), **Sömmerskan** (syr tygdjur – snäll nekromantiker, Trådar), **Stjärnläsaren** (magiker, Mana), **Taklöparen** (rogue, Energi+Kombo). **Rotvävaren** (druid) som första expansion |
| Lvl 200 + skill points | 1–60: skill tree (3 grenar, 70 poäng, pakt-val lvl 30). 60–200: "Ljusstyrka"-stjärnkarta (~40 stjärnbilder, 280 poäng). Uppsk. lvl 60 ≈ 17 h, lvl 200 ≈ 370 h |
| ≥ 6 rariteter | Common · Magic · Rare · Epic · Legendary · Mythic (lvl 60+) + **Unique** (bossspecifika) + **Named** (endast craftade). Färg + ramform + ikon (färgblindsäkert) |
| Bra RNG | Smart loot (75 % aktiv klass), item level styr affix-tiers, avtagande Magic Find, öppen pity, bossfragment (10 = garanterad resurs), loot-filter i 4 lägen, target farming via bestiarium |
| Named-vapen | 5 recept med "omöjliga" resurser knutna till mysterier (t.ex. ett eko du bara får genom att stå still 30 s i en bossfight) |
| Djup crafting med nivåer | 4 yrken (Smed, Alkemist, Juvelerare, Runristare) lvl 1–50. "Tändning" à la Last Epoch Forging Potential + tempering/masterwork. Kitteln: experimentera fram hemliga recept |
| Inventory | En ruta per föremål, snabbjämförelse, auto-salvage per rarity, stash, filter |
| Monster/bossar | 5 fiendefamiljer × 6–10 typer + elitvarianter + 5 aktbossar + veckobossar. Bossar varnar med markmarkeringar |
| Endgame | Rifter, greater rifts med topplista (lokal/ingen chatt), sigill-kartor, veckoboss |

## 7. Stil
Cult of the Lamb/Don't Starve-receptet: gulliga chibi-figurer (2–3 huvuden höga) mot dova, avmättade miljöer; mättade färger bara på spelare, fiendeattacker och loot. Toon-shader med 2–3 ljussteg + rim light, dimma, glödande ljuskällor. Loot-strålar i rarity-färg.

**Kontroller:** flytande joystick vänster, attack + 3–4 skills i båge höger, auto-sikte (håll för manuellt), valbart auto-attackläge för de yngsta.

## 8. Affärsmodell
**Engångsköp** (eller gratis demo + en upplåsning) + betalda expansioner (nya akter/klasser). Eventuell kosmetik: känt innehåll, bakom föräldraspärr. Ingen reklam. Ger PEGI 7-möjlighet och ren butiksgranskning.

## 9. Plan
| Milstolpe | Innehåll | Klart när |
|---|---|---|
| M0 Spikes | Godot på Android-enhet: 200 fiender, touch-känsla, bpy→glb-pipeline | fps-mätning på riktig telefon |
| M1 Prototyp | 1 klass, 1 dungeon, 3 fiender, loot 6 rariteter, inventory | Kärnloopen är kul i 5 min |
| M2 Vertical slice | Akt 1 komplett: 2 klasser, boss, crafting lvl 1–10, ljud, UI-polish | Testad av riktiga barn + vuxna |
| M3 Alpha | 5 klasser, 5 akter, lvl 1–60 | Hela storyn spelbar |
| M4 Beta | Endgame lvl 60–200, Named, balans via simulering | Intern test + Play intern testning |
| M5 Release Android | Families-granskning, PEGI 7 | Play Store |
| M6 iOS | macOS CI, TestFlight, Kids-kategori | App Store |

## 10. Rättningar studion redan gjort
- Writerns "tråd som bara kan hämtas kl. 03:00–03:10" stryks – belönar nattspel för barn. Ersätts med in-game-tid.
- Klassnamnen från systemdesign och lore harmoniserade till lore-namnen ovan.
- PLAYER_WELFARE.md skrivs innan M1.
