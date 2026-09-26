# ARPG-system: research och förslag

*Projekt: 3D chibi dark-fantasy ARPG för mobil (7+). Författare: arpg-systems-designer. Datum: 2026-09-26.*
*Alla siffror märkta **[UV]** är utgångsvärden som ska simuleras och speltestas. **[UPPSK]** betyder uppskattning.*

---

## 0. Vad genren lärt oss (kort)

| Spel | Lärdom vi tar | Lärdom vi undviker |
|---|---|---|
| Diablo II | Treasure Class + ilvl skiljer *vilken bas* från *vilken kvalitet*. Magic Find har avtagande effekt ([Diablo Wiki](https://diablo-archive.fandom.com/wiki/Magic_Find_(Diablo_II))). Runewords = recept med kända ingredienser. | Kan gå hundratals timmar utan ett visst Unique. Inget skydd mot torka. |
| Diablo III | Loot 2.0: smart loot (~85 % av dropparna rullar för din klass), dold legendary-pity (~2 h max) ([Smart Loot](https://www.diablowiki.net/Smart_Loot), [Pity Timer](https://www.diablowiki.net/Legendary_Pity_Timer)). Goblins och portaler till hemliga nivåer ([Goblins](https://www.diablowiki.net/Treasure_Goblin)). Paragon utan tak ([Paragon XP](https://www.diablowiki.net/Paragon_experience_charts)). | För många legendaries gör dem tråkiga. Setbonusar på ×100 % gör allt annat värdelöst. |
| Diablo IV | S4 "Loot Reborn": *färre men bättre drops*, färre och tydligare affixer, Tempering (lägg till affix) och Masterworking (förstärk affix) ([GameSpot](https://www.gamespot.com/articles/diablo-4-massive-loot-reborn-update-is-live-now-read-the-full-season-4-patch-notes/1100-6523441/), [Maxroll](https://maxroll.gg/d4/resources/tempering-guide)). Paragon-brädor med glyphs, 4 poäng per nivå ([Maxroll](https://maxroll.gg/d4/resources/paragon-boards)). | Launch-versionen med 5+ nischade affixer per item: skräpet begravde de bra fynden. |
| Path of Exile | Item level styr vilka affix-tiers som kan rulla. Viktade affixpooler via taggar ([PoE Wiki](https://pathofexile.fandom.com/wiki/Modifiers)). Currency = crafting-material = ekonomi. Atlas-träd för endgame-targeting. | Komplexiteten är långt över vad en 7-åring (eller en mobilsession) tål. |
| Last Epoch | Forging Potential: garanterad craft, slumpat slitage. Critical success ([LE Support](https://support.lastepoch.com/hc/en-us/articles/46361900702363-What-is-Forging-Potential)). Inbyggt loot filter. Circle of Fortune / Prophecies för target farming ([Maxroll](https://maxroll.gg/last-epoch/resources/loot-filter-guide)). | – (bästa crafting-modellen för oss) |
| Grim Dawn | Blueprints lärs permanent och bygger en pyramid av komponenter ([GD Wiki](https://grimdawn.fandom.com/wiki/Blueprints)). Devotion: 105 stjärnbilder, affiniteter, tiers ([GD Wiki](https://grimdawn.fandom.com/wiki/Devotion)). | UI:t är för tätt för mobil. |
| Torchlight (Infinite) | Mobil-ARPG med nyckel/karta-loop ("Beacons"), ingen stamina, säsonger med ny hjälte ([Games Fuze](https://gamesfuze.com/guides/torchlight-infinite-ultimate-endgame-guide/)). | Gacha-lager ovanpå. |
| Titan Quest | Dubbla masteries = kombinatorik som ger många klasser av få träd. | Långsam loot-pacing. |
| Diablo Immortal | Mobilkontroller och korta aktiviteter (bounties, rifts) funkar. | **Varnande exempel:** legendary gems bakom betalda crests, 0,045 % för 5/5 och missvisande "garanti" ([Kotaku](https://kotaku.com/diablo-immortal-gems-legendary-spend-economy-loot-box-b-1849043437), [GameRant](https://gamerant.com/diablo-immortal-pity-system-problem/)). **Detta får vi aldrig göra.** Barn är 7+. |

**Hård regel:** ingen slumpad belöning kan köpas för riktiga pengar. All RNG betalas med speltid och skicklighet.

---

## 1. Loot och RNG: best practice

### 1.1 Pipeline för en drop (efter D2/PoE, förenklat)
1. **Drop-roll:** blir det något alls? (monstertyp × svårighet)
2. **Bas-roll:** vilken itemtyp? Smart loot väger in klassen: **[UV] 75 %** rullas för aktiv klass, 25 % fritt (för alts och överraskningar).
3. **Item level (ilvl)** = monsternivå (boss +2). ilvl styr vilka affix-**tiers** som får rulla (T1 kräver ilvl ≥ 190 osv.).
4. **Raritet-roll:** viktad tabell (avsnitt 2), modifierad av Magic Find med **avtagande effekt**: `effMF = MF × K / (MF + K)`, K = 250 för Legendary+ **[UV]** (samma idé som D2).
5. **Affix-roll:** dra affixer utan återläggning ur klassens pool med vikter. Varje affix har en tier (T1–T7) och ett värde inom tierns intervall.

### 1.2 Affixpooler
- **Få, tydliga affixer (~30 st totalt per slot-typ)** i stället för 100 nischade (D4 S4-läxan). På mobil ska ett item gå att bedöma på 1 sekund.
- Tre familjer: **Offensiva** (skada, crit, attackfart), **Defensiva** (liv, rustning, resist), **Nytta** (fart, cooldown, MF, resurs).
- **Klass-affixer** (+1 till en skill) finns bara i klassens pool och vägs upp av smart loot.
- **Greater affix** (D4): 3 % chans **[UV]** att en affix får 1,5× värde och en glödande stjärna i UI:t. Billig spänning.

### 1.3 Bad-luck protection / pity (dolt men garanterat)
- **Legendary-pity:** räknaren ökar per fiende som dödas; varje gång utan Legendary+ höjs chansen linjärt. Hårt tak: **[UV] 45 min aktiv speltid** (D3 hade ~2 h, men mobilsessioner är korta).
- **Mythic-pity:** mjuk ökning efter **[UV] 8 h**, hårt tak **[UV] 20 h**.
- **Unique/Named-resurser:** "Shard"-system i stället för ren tur. Varje boss-kill ger 1 fragment; 10 fragment = en garanterad resurs **[UV]**. Tur kan korta vägen, men vägen tar alltid slut.
- **Dubblettskydd:** en Unique du redan äger rullar om en gång (bara tills samlingen är komplett).
- Pity ska vara **transparent för föräldrar/spelare i en hjälpruta** ("Du får alltid en Legendary minst var 45:e minut"). Motsatsen till Diablo Immortals otydliga "garanti".

### 1.4 Loot filter (mobilanpassat)
- Förinställda nivåer: **Visa allt / Dölj vitt / Bara uppgraderingar / Bara Epic+**. Auto-salvage av dolt = material, så inget känns bortkastat.
- **Uppgraderingspil** (grön ↑) direkt på marken jämför mot utrustat item. Viktigaste enskilda UX-grejen för 7-åringar.
- Auto-pickup för guld, material och förbrukningsvaror.

### 1.5 Target farming
- Varje **boss har en egen loot-tabell** med 2–4 "signaturdrops" (D2 Mephisto-modellen) som visas i bossens kodex.
- **Bestiarium/kodex:** efter 1 kill ser du vad bossen kan tappa, efter 10 kills ser du droprate.
- **Sigill/Profetior** (Last Epoch): endgame-kartor kan laddas med ett sigill som viktar t.ex. "vapen ×3" eller "Frostvärlden-uniques ×2".
- **Världstema:** varje värld har egna Named-resurser. Vill du ha Isdrakens hjärta så vet du var du ska farma.

### 1.6 Spännande vs. frustrerande
| Spännande | Frustrerande |
|---|---|
| Ljudsignal + ljuspelare + färgad stråle *innan* du ser itemet (förväntan) | Skärmen full av skräp man måste sortera |
| Sällsynta drops som *faktiskt* är bättre | Ett "sällsynt" item som är sämre än det man har |
| Chans att hitta något bra var som helst, även i en vanlig kista | Bästa loot bara från en enda aktivitet |
| Nära-miss-känsla: T1-affix, greater affix, uppgraderingspil | Torka på flera timmar utan någon uppgradering |
| Crafting kan rädda ett "nästan perfekt" item | Rena RNG-väggar utan deterministisk reserv |
| Transparens: "10 % närmare garanterad Mythic" | Dolda, orimliga odds (Immortal-gems) |

---

## 2. Förslag: rariteter

| # | Raritet | Färg (hex) | Grundchans per item-drop **[UV]** | Affixer | Kommentar |
|---|---|---|---|---|---|
| 1 | Common (Vanlig) | Vit/grå `#C8C8C8` | 56 % | 0–1 | Salvage-föda. Döljs av filter efter lvl 15. |
| 2 | Magic (Magisk) | Blå `#4A90FF` | 30 % | 1–2 | Tidiga uppgraderingar. |
| 3 | Rare (Sällsynt) | Gul `#FFD23F` | 9,5 % | 3–4 | Crafting-baser. |
| 4 | Epic (Episk) | Lila `#A64DFF` | 2,8 % | 4 + 1 greater-chans | Kärnan i mid-game. |
| 5 | Legendary (Legendarisk) | Orange `#FF8C1A` | 1,6 % | 4 + 1 **legendary power** | Förändrar hur en skill fungerar. Pity 45 min. |
| 6 | Mythic (Mytisk) | Röd `#FF3355` + glöd | 0,1 % (från lvl 60) | 5, alla T1–T2 + legendary power | Stor jackpot. Pity 8–20 h. |
| – | **Unique** | Guld `#D4A94A` | Specifika bossar, ~1/40 kill **[UV]** | Fasta affixer + unik effekt | Handdesignade, "build-definierande". |
| – | **Named (Namngiven)** | Turkos/eterisk `#35E0D0` + eget ljud | **Droppar aldrig.** Craftas (avsnitt 5). | Fasta + 1 valbar + Named-förmåga, växer med dig | Toppen. Ett per slot, med namn och lore ("Gravmors Lykta"). |

- Typisk trash-mob: 12 % chans att tappa ett item alls **[UV]**, elite 100 % (1–2 items), boss 3–5 items + garanterad Epic+.
- Med ca 180 kills och ~30 item-drops per 10 min **[UPPSK]** blir förväntan ungefär 1 Legendary var ~20 min (1,6 % × 3/min), 1 Mythic var ~5,5 h och pity som golv. Med filter på "Dölj vitt" syns bara ~13 items per 10 min.
- Siffrorna ska verifieras i `arpg/game/data/` med ett Python-simuleringsskript (Monte Carlo, 10 000 simulerade spelare, percentilerna P50/P90/P99 för tid till första drop per raritet).

---

## 3. Klassdesign (chibi mörk fantasy)

| Klass | Fantasi | Resurs | Spelstil | Tre grenar i trädet |
|---|---|---|---|---|
| **Gravriddare** (Grave Knight) | Liten riddare i för stor hjälm, lyktbärare mot mörkret | **Glöd** (byggs av att ta/ge skada) | Närstrid, tank, sköldslag | Lyktan (helig eld) · Bastionen (försvar) · Ed (motattacker) |
| **Häxlärling** (Hex Apprentice) | Häxa med levande hatt och kokande kittel | **Mana** (regen) + **Brygd**-laddningar | Caster, AoE, elementkombos | Frost · Förbannelser · Kittelmagi |
| **Skuggräv** (Shadowfox) | Kappklädd tjuv med rävmask | **Energi** (snabb regen) + **Kombopunkter** | Snabba strejker, fällor, dodge | Dolkar · Fällor · Skuggsteg |
| **Benvaktare** (Bone Warden) | Nekromantiker vars skelett är söta men läskiga | **Själar** (från döda fiender) | Summoner, kontroll | Skelettarmé · Benmagi · Andar |
| **Vildhjärta** (Wildheart) | Druidbarn med totemdjur, förvandlas till björn/uggla | **Ilska** (byggs av att slåss) | Hybrid, formbyten | Björn · Uggla · Törnen |
| **Klockmekanikern** (Clockwright), klass 6/säsong | Uppfinnare med ångdrivna leksaker | **Ånga** (överhettning = bonus/risk) | Torn, drönare, kanoner | Torn · Drönare · Överhettning |

**Resurserna skiljer sig mekaniskt** (regen, byggs av strid, från lik, risk/belöning) så att varje klass *känns* olik med samma tumknappar.

### 3.1 Progressionsstruktur 1–200 (hybrid D4/Grim Dawn/Titan Quest)
- **Lvl 1–60 – Skill-träd:** 1 skill point per nivå + 10 från quests = **70 poäng**. Trädet har ~22 aktiva/passiva noder, max 5 rang per aktiv skill. Varje gren har en **Keystone** vid 20/40 poäng i grenen. 4 aktiva knappar + dodge på mobil **[UV]**.
- **Lvl 30 – Specialisering** (Titan Quest-inspirerat): välj en sekundär "Pakt" av tre per klass som ger ett modifierande minträd. 5 klasser × 3 pakter = 15 arketyper.
- **Lvl 60–200 – Stjärnbilder** (Grim Dawn Devotion + D4 Paragon): 2 **Stjärnpoäng** per nivå = **280 poäng**. Himmelskarta med ~40 stjärnbilder i 3 ringar (5–9 stjärnor var) och fem affiniteter kopplade till världarna. Den yttersta ringen har stjärnbilder som ger en ny *förmåga* (t.ex. "Kometregn procar på crit").
  - Poäng räcker till ~70 % av kartan vid 200 **[UV]**: val blir kvar hela vägen.
  - Gratis respec av stjärnor i stad, mot guld för skill-trädet (billig, barnvänlig).
- **Milstolpar var 10:e nivå** efter 60: kosmetisk ram/titel + en extra "Stjärnbildssockel" för en **Glyph**-liknande juvel som levlas genom spel (D4-glyph).

---

## 4. XP-kurva 1–200

### 4.1 Formel **[UV]**
Designa kurvan från **måltid per nivå** och räkna ut XP därifrån (enklare att balansera):

```
minuter_per_nivå(L) = 1 + 0.45 · L^1.05                 om L ≤ 60
                    = 30 + 0.9 · (L − 60)^1.15          om L > 60
xp_per_minut(L)     = 20 · L^1.6                        om L ≤ 60   (monster-XP skalar med nivå)
                    = 20 · 60^1.6 · (1 + 0.012·(L−60))  om L > 60
XP_krävs(L)         = round(minuter_per_nivå(L) · xp_per_minut(L))
```
Mjuk rubber band: +50 % XP om spelaren ligger 5+ nivåer under världens nivå, −(5 % per nivå) om den ligger över. Dagens första 3 sessioner ger **Vilad XP** +50 % (D3/WoW-idén, och belönar korta besök utan att straffa pauser).

### 4.2 Tidsmilstolpar **[UPPSK]** (medelspelare, beräknat med formeln ovan)
| Nivå | Min/nivå vid milstolpen | Ackumulerad tid | Vad som händer |
|---|---|---|---|
| 10 | ~5 | ~0,5 h | Alla 4 skill-knappar låsta upp |
| 30 | ~16 | ~4 h | Pakt-val, värld 2–3 |
| 60 | ~34 | ~17 h | Kampanj klar, stjärnkartan öppnas, Mythics börjar droppa |
| 100 | ~90 | ~56 h | Andra stjärnringen, Named-crafting tillgänglig i praktiken |
| 150 | ~190 | ~170 h | Yttersta ringen |
| 200 | ~290 | ~370 h | Max. Därefter "Stjärnstoft"-overflow som ger kosmetik och glyph-XP |

- Med 30–45 min/dag **[UPPSK]** blir det lvl 60 på ~4 veckor och lvl 200 på ~1–1,5 år. Det passar en livstjänst med säsonger.
- **Mobilsessioner 3–15 min:** en rift/dungeon ska ta 3–8 min, och vid 60+ ska *varje session ge minst en fjärdedels nivå* (4 delstreck per nivå, D4-modellen) så att framsteg alltid syns.

---

## 5. Crafting

### 5.1 Vad som fungerar i genren
| System | Kärnidé | Tar vi? |
|---|---|---|
| **Last Epoch – Forging Potential** | Craften lyckas alltid; itemets "hållbarhet" slits slumpat. Kritisk succé ger gratis craft + tier-uppgradering ([Icy Veins](https://www.icy-veins.com/last-epoch/crafting-guide)) | **Ja, kärnan.** Deterministiskt resultat, bara budgeten är slump. Lätt att förstå. |
| **PoE currency** | Orbs som modifierar items = material = handelsvaluta | Delvis: 5–6 tydliga "runor", ingen fri handel (barn, bedrägerier). |
| **D4 Tempering + Masterworking** | Lägg till affix ur ett recept, uppgradera sedan i steg ([PC Gamer](https://www.pcgamer.com/games/action/diablo-4-tempering-manuals-masterworking/)) | **Ja:** "Härdning" och "Mästarsmide" med 12 steg och milstolpe var 4:e steg. |
| **Grim Dawn blueprints** | Recept lärs permanent och komponenter bygger en pyramid | **Ja, för Named-recept och komponenter.** |
| **D2 Runewords / Horadric Cube** | Kända recept, hemliga kombinationer | Ja: hemliga recept upptäcks i Kitteln (se nedan). |

### 5.2 Hantverk med egna skill-nivåer (1–50 per yrke) **[UV]**
| Yrke | Gör | Nivå-milstolpar |
|---|---|---|
| **Smed** | Vapen/rustning, Härdning, Mästarsmide | 10: T5-affix, 20: reroll av 1 affix, 30: Forge-glyph, 40: crit-chans +5 %, 50: Named-städ |
| **Alkemist** | Drycker, elixir (30 min-buffar), "Brygd"-runor | 25: dubbla batcher, 50: Mytiskt elixir |
| **Juvelerare** | Ädelstenar, socklar, ringar/amuletter | 20: lägg till sockel, 40: fusion av ädelstenar |
| **Runristare** | Runor som styr affix-crafting (Förvandla, Förstärk, Rensa, Förse, Försegla) | 30: försegla en affix (LE sealed affix), 50: Tvillingruna |

- **XP för yrken:** kommer av *salvage* och *craftande*, inte av grind-klick. Salvage av ett helt Common-förråd ger yrkes-XP så att skräpet blir meningsfullt.
- **Materialtiers:** 5 tiers (Järn → Svartstål → Själsilver → Stjärnmetall → Tomrumsglas), en per värld-par. Högre tier kräver yrkesnivå 10/20/30/40.
- **Forging Potential:** Rare 20–30, Epic 30–45, Legendary 15–25 (färre crafts, starkare bas), Mythic 10 **[UV]**. Kritisk succé 5 % + 0,1 %/yrkesnivå.
- **Kitteln** (hemliga recept): lägg 3 saker i kitteln. En okänd kombination som råkar vara ett recept upptäcks och sparas i receptboken. Hint-fragment droppar från bossar. Mycket "upptäckarglädje" för barn.

### 5.3 Named-recept (svåra resurser)
Varje Named-vapen = **Blueprint + 3 bossresurser + 1 världsresurs + 1 Mythic-bas + yrkesnivå 50**.

| Named | Slot/klass | Kräver (utöver ritning) **[UV]** | Named-förmåga |
|---|---|---|---|
| **Gravmors Lykta** | Sköld, Gravriddare | 3× Gravmors glödkärna (Värld 3-boss, 1/15), 1× Evigt ljus (hemlig nivå), Mythic sköld | Lyktans ljus återuppväcker dig en gång per rift |
| **Kittelns Moder** | Stav, Häxlärling | 5× Häxsotsflinga (elite-affix "Förhäxad"), 1× Månvattenpärla (Rift-event), Mythic stav | Varje 5:e trollformel kastas två gånger |
| **Nattvisslaren** | Dolkar, Skuggräv | 3× Skuggrävens svans (dold boss), 20× Rökglas, Mythic dolk | Dodge lämnar en skuggklon |
| **Benkronan** | Hjälm, Benvaktare | 1× Liche-kungens krona (veckoboss, garanterad var 4:e vecka via fragment), Mythic hjälm | +3 max skelett, skelett ärver 25 % av dina affixer |
| **Urskogens Hjärta** | Totem, Vildhjärta | 3× Kärnbark (Värld 2 världsboss), 1× Stjärnfrö (Stjärnkarta-event), Mythic totem | Formbyte ger 3 s osårbarhet |

- **Named växer:** varje Named har 5 "Ekon" (nivåer) som låses upp genom att döda X bossar med vapnet utrustat. Vapnet får en historia ("Har fällt 1 000 demoner").
- Blueprints droppar från veckobossar (1/20) med fragmentpity (10 fragment = garanterad) **[UV]**.
- Förväntad tid till första Named **[UPPSK]**: 25–40 h efter lvl 60. Det ska kännas som en bedrift, men aldrig vara omöjligt.

---

## 6. Belöningsrytm

| Intervall | Belöning | Typ |
|---|---|---|
| **1–5 s** | Träff-feedback, guld, XP-siffror, små fynd, kombo-räknare | Fast, konstant "juice" |
| **15–60 s** | Elite-pack med garanterad drop, kista, Magic/Rare-drop, hälsobrunn | Variabel ratio (låg varians) |
| **2–5 min** | Rare/Epic, delnivå (¼ nivå), minibosser, event-portar | Variabel |
| **5–15 min (session)** | Rift-/dungeonslut: bosskista, ~1 Legendary per 15–25 min, material, sessionens "sammanfattningsskärm" med höjdpunkter | Semi-garanterad + pity |
| **Dagligen** | 3 dagliga bounties (5 min var), Vilad XP, daglig kista | Fast |
| **Vecka** | Veckoboss (Named-fragment), Stjärnbilds-utmaning, veckans "Förbannade rift" med modifierare | Fast + variabel topp |
| **Säsong (8–10 v)** | Ny mekanik, säsongsresa med kosmetik (spelas fram, köps inte), ny Named | Långsiktigt mål |

### 6.1 Överraskningsmoment (variabel belöning inom spelet)
- **Skattgoblin → "Girighets-mullvaden"**: ~1 per 20 min **[UV]**, springer iväg, tappar guld. Dödad: 5 % chans på portal till *Guldvalvet* (D3 Vault).
- **Hemliga nivåer:** "Regnbågsmullvad" → *Karamellkrypta* (chibi-varianten av Whimsyshire): 1/100 goblins **[UV]**, bara kosmetik och en prestation. Ren snackbarhet på skolgården.
- **Rift-events** (15 % av rifts **[UV]**): Förbannad kista (överlev 30 s för dubbel loot), Stjärnfall (plocka stjärnor före tiden), Gyllene fiende, Pilgrims-vandrare (skydda NPC).
- **"Jackpot-stråle"**: Mythic-drops får en unik ljudsignatur och slow-motion på 0,5 s.
- **Mystiskt ägg:** droppar sällan. Kläcks efter 3 sessioner och innehåller en husdjurskosmetik eller en Epic+.
- **Regel:** överraskningar får aldrig vara den *enda* vägen till något spelnödvändigt. Alla power-items har en deterministisk reserv (fragment/pity/crafting).

---

## 7. Endgame-loopar som fungerar på mobil

| Loop | Längd | Beskrivning | Förebild |
|---|---|---|---|
| **Rifter (Sprickor)** | 3–6 min | Slumpad karta + värld, fyll mätare, boss. Grundloopen för XP/loot. | D3 Rifts, Immortal |
| **Stjärnrifter (Greater)** | 5–8 min | Timer, nivå 1–150+. Klarad i tid = nyckelnivå +1 till +3. Ger glyph-XP. Topplista per klass. | D3 Greater Rift, D4 Pit |
| **Världskarta med sigill** | 5–10 min/karta | Endgame-kartor med modifierare, sigill för target farming. Kartpoäng låser upp en liten "Atlas"-träd per värld. | PoE Atlas, TLI Beacons, LE Monoliths |
| **Veckobossar** | 3–5 min | En per värld, större mekanik, Named-fragment. Kan spelas solo eller i grupp om 2–4. | D2 Ubers, D4 Tormented bosses |
| **Förbannade rift (veckomodifierare)** | 5–10 min | Samma seed för alla, speciella regler. | D3 Challenge Rift |
| **Crafting-session** | 2–5 min | Salvage, smide, kitteln. "Avkopplingsloop" när man inte kan spela aktivt (t.ex. på bussen). | LE Forge |
| **Säsongsresa** | 8–10 veckor | Kapitel med mål som passar alla sessionslängder. | D3/D4 Seasons |

**Mobilprinciper:**
- Allt endgame-innehåll ska gå att **pausa/spara mellan vågor** eller klara på under 8 min. Inget energi-/stamina-system (TLI-principen).
- **Offline-säkert:** avbruten rift ger delbelöning (proportionellt mot framsteget).
- **Grupp är frivillig**, aldrig ett krav för power. Ingen öppen chatt för 7+ (bara förinställda emotes).
- Ingen spelare-till-spelare-handel: skyddar barn och håller RNG-spänningen ärlig.

---

## 8. Nästa steg (för systemdesign)
1. Lägga in rariteter, affixpooler och drop-tabeller som JSON i `arpg/game/data/`.
2. Skriva `simulate_loot.py` och `simulate_xp.py` (Monte Carlo, P50/P90/P99 för tid till drop och nivå).
3. Stämma av klassnamn och världar mot lore i `arpg/docs/lore/`.
4. Speltesta pity-taket 45 min mot faktisk sessionsdata från betan.

### Källor
- Diablo Wiki: [Smart Loot](https://www.diablowiki.net/Smart_Loot), [Legendary Pity Timer](https://www.diablowiki.net/Legendary_Pity_Timer), [Treasure Goblin](https://www.diablowiki.net/Treasure_Goblin), [Paragon XP](https://www.diablowiki.net/Paragon_experience_charts), [D2 Magic Find](https://diablo-archive.fandom.com/wiki/Magic_Find_(Diablo_II))
- D4: [Loot Reborn patch notes (GameSpot)](https://www.gamespot.com/articles/diablo-4-massive-loot-reborn-update-is-live-now-read-the-full-season-4-patch-notes/1100-6523441/), [Tempering (Maxroll)](https://maxroll.gg/d4/resources/tempering-guide), [Paragon (Maxroll)](https://maxroll.gg/d4/resources/paragon-boards)
- PoE: [Modifiers (PoE Wiki)](https://pathofexile.fandom.com/wiki/Modifiers)
- Last Epoch: [Forging Potential](https://support.lastepoch.com/hc/en-us/articles/46361900702363-What-is-Forging-Potential), [Crafting (Icy Veins)](https://www.icy-veins.com/last-epoch/crafting-guide), [Loot filter (Maxroll)](https://maxroll.gg/last-epoch/resources/loot-filter-guide)
- Grim Dawn: [Blueprints](https://grimdawn.fandom.com/wiki/Blueprints), [Devotion](https://grimdawn.fandom.com/wiki/Devotion)
- Torchlight Infinite: [Endgame guide (Games Fuze)](https://gamesfuze.com/guides/torchlight-infinite-ultimate-endgame-guide/)
- Diablo Immortal (varnande exempel): [Kotaku](https://kotaku.com/diablo-immortal-gems-legendary-spend-economy-loot-box-b-1849043437), [GameRant](https://gamerant.com/diablo-immortal-pity-system-problem/)
- Belöningspsykologi: [Reward Schedules (Game Developer)](https://www.gamedeveloper.com/business/reward-schedules-and-when-to-use-them)
- Titan Quest (dubbla masteries) och Torchlight I/II-detaljer bygger på allmän genrekunskap, utan specifik källa.
