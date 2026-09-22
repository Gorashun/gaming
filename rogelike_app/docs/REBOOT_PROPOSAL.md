# Omtagsförslag efter speltest 4

*PM-syntes av research 06 (motor), PROGRESSION_REDESIGN, ART_DIRECTION_V2 och ASSET_SHOPPING_LIST · 2026-09-22 · Status: väntar på Anders beslut (§6)*

## 1. Vad speltestet sa och vad utredningarna svarar

| Anders | Utredningens svar | Underlag |
|---|---|---|
| "Ingen progression, något saknas rejält" | Rätt. Spelet har inte för få belöningar utan fel sort: allt är regeländringar som konsumeras direkt. Inget kan ägas, jämföras, visas upp eller tappas. Character sheetet har sju slots som inget ligger i. Progressionskänsla i dag 2/10 | PROGRESSION_REDESIGN §1 |
| "Spelet är fult, byt motor till three.js?" | 85–90 % av fulheten är ljus, assets och layout, inte motorn. Korridoren renderas helt utan ljus. three.js saknar UI, ljud, sparning, tester och byggkedja; ingen kommersiell three.js-titel hittad på Play/App Store. Byte: 35–55 agentdagar för att nå dagens nivå. Visuell sprint i Godot: 6–12 | research 06 |
| "Gear man kan tappa som i andra roguelikes" | Reliker blir gear i sju kroppsslots med sällsynthet, droppar från fiender, bärs av en namngiven hjälte, förloras vid död utom det Kistan räddar | PROGRESSION_REDESIGN §3 |
| "Darkest Dungeon som referens" | Vi tar Hamlet-uppgraderingar, roster med permadöd, trinkets. Vi tar inte stress, förnödenheter, veckoekonomi (grind- och tempokritiken, 13+) | PROGRESSION_REDESIGN §2 |
| "Gillar träningsidén" | Tutorialen i källaren behålls, får autosave och loot | – |

## 2. Motor: stanna i Godot

Beslutet fattas inte på "det blir snyggare i three.js", för det blir det inte. Samma 32-pixelfigurer i en ny motor är samma fula spel. Det som finns behålls: 407 tester, korridor, strid, kvitto, tutorial, i18n, Android-CI, webbexport. Omprövas bara om assets och ljus i Godot fortfarande inte duger efter M6, och då mot Unity, inte three.js.

## 3. Utseende: tre steg i ordning

1. **Stilskiktet (0 kr, 3–5 agentdagar):** fackelljus och kantljus i korridoren (vertexbakat), vinjett, tung svart, disdjup, kastskugga under fiender, kraftig skadesiffra, UI-brus ned 60 %, två renderingsbuggar (röda scanlines i taket, bossbannern). Mockup: design/screenshots/art_v2_390x844.png.
2. **Minimikorgen (0 kr, Anders laddar ner, ~1 timme):** sju paket i sammanhållen stil: Screaming Brain Old School Dungeon Crawler Pack (korridor, CC0), Hexany Ives Monster Menagerie + Roguelike Tiles (64 frontala monster + 150 varelser + items, CC0, 1-bit som vi färgar via palett-LUT), game-icons.net (4 180 ikoner, CC-BY), Kenney UI-ramar och ljud (CC0), Incompetech-musik (CC-BY). Lista med länkar: docs/ASSET_SHOPPING_LIST.md §A. Lägg i assets/incoming/.
3. **Beställd konst (1 500–2 500 USD, senare):** hjälte, bossar och nyckelmonster i en handritad stil, först när progressionen sitter och spelet bevisat sig roligt. Enda vägen till Darkest Dungeon-nivå. AI-genererade råassets: fortsatt nej (community, butiksregler, stilspret).

## 4. Progression: gear, Kistan, roster

- **Gear** ersätter reliker: slot (huvud, bröst, händer, vapen, ben, rygg, amulett), sällsynthet common/uncommon/rare/epic med färg och ljudceremoni, nivå. Droppar per fiende med drop-tabeller. Effekter måste synas i kvittot (läsbarhetslag). 22 exempelföremål finns.
- **All styrka är dödlig:** gear bärs av en namngiven hjälte. Trappan mellan våningar är en frivillig bank ("skicka upp med kärran"). Död = allt osäkrat förloras utom det Kistan räddar (spelarens val, Marrow presenterar). Här ligger räddningsannonsen: "se en annons, rädda ett föremål till", frivillig, aldrig avbrott.
- **Hjälteroster** max 4, nivå 1–5 låser upp antal bärbara gear-slots (2→7), XP per run, permadöd, en quirk per hjälte. Ingen stress.
- **Staden** får byggnader som uppgraderas för Pips (smedja, marknad, taverna med roster, Kistan). Pips slutar köpa poolposter. MetaScore-siffran bort ur UI.
- Betyg enligt rollspelsnörden, nu → efter: Roligt 6→8, Replayability 3→7, Progressionskänsla 2→8.

## 5. Plan

| Milstolpe | Innehåll | Anders ser |
|---|---|---|
| **M6 Stil + gear-kärna** (vecka 1–2) | Stilskiktet; gear-modellen i core (Item, slots, sällsynthet, drops, Kistan, bank vid trappan); character sheet fylls; minimikorgen integreras när den ligger i incoming/ | Efter vecka 1: samma spel med ljus, skugga, tystare UI och riktiga monster. Efter vecka 2: loot som droppar, syns på figuren och kan förloras |
| **M7 Roster + stad** (vecka 3–4) | Hjälteroster, XP, permadöd, quirks, stadsbyggnader, räddningsannons som stub, credits-skärm | En hjälte man bryr sig om, en stad som växer |
| **M8 Innehåll + balans** (vecka 5–7) | Våning 2–3, fler fiender ur Menagerie, bossar, Ödeskast, drop-tabeller balanserade i simulatorn, ljud i korridoren | Full run 12 rum |
| **M9 Butik** | Premium-köp (Play Billing), DLC-struktur, AdMob-plugin + samtycke, integritetspolicy, IARC, 12 testare | Closed test på Play |

Tidsangivelserna är uppskattningar i agentdagar i hobbytakt.

## 6. Beslut från Anders

1. Motor: stanna i Godot. **Ja/nej.**
2. Stilskiktet startar nu (0 kr). **Ja/nej.**
3. Minimikorgen: du laddar ner de sju paketen i ASSET_SHOPPING_LIST §A till assets/incoming/. Titta på Monster Menagerie först, stilriktningen hänger på den. **Ja/nej, eller annan stil.**
4. Progression enligt §4: gear i sju slots, all styrka dödlig, Kistan räddar 1–3, roster max 4 med permadöd, quirks ja, stress nej. **Ja/nej per punkt.**
5. Beställd konst för hjälte och bossar senare, budget ca 2 000 USD. **Ja/nej/senare.**

Redan beslutat: affärsmodell premium + DLC + frivilliga räddningsannonser. Heroine Dusk-paketet är förbjudet (CC-BY-SA).
