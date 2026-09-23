# M6 spår B – progression: arbetsanteckningar och gränssnitt

*Ägare: dev B (progression). Senast uppdaterad 2026-09-23. Läses av dev A (art/UI)
och PM. Normativ källa för reglerna är `docs/GAME_DESIGN.md` (§ Gear/Roster/Kistan/Bank).*

## 1. Gränssnitt till dev A (levererat i steg 1)

Allt i `src/core/`, rena `RefCounted`, inga Node-beroenden.

| Vad | Signatur | Anmärkning |
|---|---|---|
| Hjältens plagg | `Hero.equipped(slot: String) -> Item` (null om tomt) | `slot` ur `Content.SHEET_SLOTS` (`HEAD`, `CHEST`, `HANDS`, `WEAPON`, `LEGS`, `BACK`, `AMULET`) |
| Upplåsta slots | `Hero.gear_slots_unlocked() -> int` (2→7), `Hero.unlocked_slots() -> Array[String]`, `Hero.is_slot_unlocked(slot)`, `Hero.level_for_slot(slot) -> int` | Nivå 1 = WEAPON+CHEST, 2 +HEAD, 3 +HANDS, 4 +LEGS+BACK, 5 +AMULET |
| Hjältens data | `name`, `body_variant` (`a`/`b`), `level` 1–5, `xp`, `xp_to_next()`, `quirk` (id i `Content.QUIRKS`), `alive` | Quirkens namn: `tr(Content.quirk_key(id))` |
| Föremål | `Item.icon_id` (manifestets `gear.<ID>`; de sex omgjorda relikerna använder `relic.<ID>` som redan finns i manifestet), `Item.rarity` (`Rules.Rarity`, nu med `EPIC = 3`), `Item.name_key` (`GEAR_<ID>`), `Item.effect_summary_key` (`GEAR_<ID>_DESC`), `Item.level` 0–3, `Item.secured` | Ikon: `Art.gear_icon(item.icon_id)` |
| Var hjälten finns | Under en run: `GameController.run.hero` (och `run.pack` = burna men oburna föremål). I staden: `GameController.meta.roster.active()` | Allt i `run.hero`/`run.pack` är osäkrat |
| Rostret | `meta.roster.heroes`, `meta.roster.active()`, `meta.roster.fallen` (`{name, level, killed_by, run}`) | Max 4 |

## 2. Saker i dev A:s filer som behöver göras (rör jag inte)

1. **Character sheet (`src/game/sheet/*`)** läser fortfarande `state.relics` + `Content.relic_slot()`.
   Relikerna ligger inte längre i `state.relics` (bara klassreliken `ANVIL_BLESSING`);
   de sex omgjorda relikerna och all gear sitter på `run.hero` (`Hero.equipped(slot)`).
   `Content.RELICS`/`RELIC_SLOTS`/`Art.RELIC_LAYERS` står kvar tills sheetet bytt.
2. **`Tokens.rarity_style/rarity_label`** känner inte `Rules.Rarity.EPIC` och faller tillbaka
   på common. `RewardCard` (mitt) sätter epic-färg och etikett (`GEAR_RARITY_EPIC`) lokalt tills vidare.
   **`Tokens.category_label`** känner inte `Rewards.CATEGORY_GEAR`; `RewardCard` översätter `GEAR_CATEGORY` själv.
3. **Kvittot (`receipt_panel.gd`)**: `ChainReceipt.build()` får en ny lista `gear` (se §3). Varje rad
   ska ritas som `"%s: %s" % [tr(name_key), tr(text_key) % args]`.
4. **Sjätte slot / sjunde tärning**: `SIXTH_SEAT` (epic) ger brädet 6 slots och `PIT_STRIDERS`
   ger en sjunde tärning i stridens första runda. Stridsskärmen måste klara `board.size() == 6`
   och `dice.size() == 7`. Båda är låsta bakom run 10 (episkt) respektive boss-drop, så de syns sällan.
5. **Juice**: se §4, `item_dropped`.

## 3. Resolver-events för gear (steg 2)

- **Nytt event** `gear_triggered{item, name_key, effect, detail}` emitteras *före* eventet effekten
  påverkar. `effect` är en `GearRules`-konstant (`PIP_BONUS`, `PLAYER_ARMOR`, `ARMOR_PIERCE_SLOT` …).
  Quirks går samma väg (`item` = `QUIRK_<ID>`, `name_key` = `HERO_QUIRK_<ID>`).
- **`relic_triggered`** får fälten `item` och `name_key` när regeln bärs av ett föremål (de sex omgjorda relikerna).
- **`ward_gained{slot: -1, source: "GEAR"}`** = Ward från `RUST_GREAVES`, inte från ett slag.
  Slot -1 får inte indexera en slot-vy.
- **`charge_stored.source`** kan vara `"GEAR"`.
- **`enemy_attacks.armor_used`** (valfritt fält) = vad `SLAG_PLATE` tog.
- **`round_start.ward_in`** (valfritt fält) = Ward som `TICK_CARAPACE` höll kvar från förra rundan.
  `EventPlayer` nollar Ward vid `round_end`; vill ni visa den kvarhållna Warden, läs `ward_in`.
- **`slot_modifier_failed.threshold`** (valfritt) = Amboss-tröskeln när `TONG_GLOVES` sänkt den.
- **Kvittot:** `ChainReceipt.build()` returnerar nu även `"gear": Array[Dictionary]` med
  `{item, name_key, effect, text_key, args, slot}`. Text: `"%s: %s" % [tr(name_key), tr(text_key) % args]`,
  t.ex. "Pipsight Lens: +1 on 1s". Nycklarna `GEAR_FX_*` finns i CSV:n (en + sv).
  Runda 1 listar också passiva effekter (`MAX_HP`, omkast, `START_CHARGE` …) så att allt syns minst en gång per strid.

## 4. Ceremoni-events (steg 3)

- **Signal** `GameController.item_dropped(event: Dictionary)`, ett per föremål, när dropparna
  dras (efter strid, bossdrop, altare, tutorialens gåva i rum 0.3).
  `event = {t: "item_dropped", item, name_key, icon_id, rarity, rarity_name, source, ms_hint}`.
  `ms_hint` = 200/350/600/900 ms för common/uncommon/rare/epic (§3.3). Koppla ljud/färg på `rarity`.
- Dropparna ligger sedan som kort bland de tre (`Rewards.CATEGORY_GEAR`, högst två av tre, aldrig
  på sista sidkortets plats). Kortets `data` = `{item: Item.to_dict(), target: {slot, to_pack, replaces, replaces_key, unlock_level}, source}`.
- **Signal** `GameController.rescue_offer_requested()` (räddningsannonsen) och
  `GameController.bank_offered(item_count)` (trappbanken) finns för juice/ljud om ni vill.
- Paneler jag byggt i min katalog (enkel torg-panelstil, snygga gärna senare men flytta inte
  logik): `src/game/reward/item_picker.gd` (trappbanken och Kistan-valet),
  dödsskärmen `src/game/gameover/gameover_screen.gd`, tavernan i `src/game/town/town_screen.gd`.

## 5. Balans: vad simulatorn säger (seed 1, 40 karriärer × 10 runs, bredd 8)

| Mått | mixed (vanlig spelare) | lookahead (taket) | Mål §5 |
|---|---|---|---|
| Droppar per run | 3,49 | 3,51 | run 1: 2–3, run 5: 4–6, run 10: 7–10 (15-min-runs) |
| Sällsynthet common/uncommon/rare/epic | 62,0 / 20,3 / 17,0 / 0,6 % | 61,4 / 20,8 / 17,2 / 0,6 % | – |
| Rare+ per run | 0,61 | 0,62 | 0,6 |
| Kickar per minut | 0,86 | 1,15 | 0,9–1,1 |
| Minuter per run | 9,4 | 7,0 | ~15 (tre våningar) |
| Run-vinst | 96,8 % | 100 % | – |

- Tuning mot §3.3: vanliga fiender 12 → 20 %, tåligare 22 → 35 %, bossen "alltid RARE" → UNCOMMON med
  60 % RARE (första boss-kill alltid ett unikt RARE). Med §3.3:s siffror blev det 0,82 kickar/min och
  1,0 rare+ per run.
- **Strukturellt:** M6 har en våning, så droppar per run växer inte över run 1–10 som §5 förutsätter
  (där växer de av djupare runs). Per minut ligger vi i §5:s mitt.
- **Legacy-måttet** `--runs` (utan gear, M5-vägen) sjönk 47,5 → 32,0 % (greedy) och 93,0 → 87,0 %
  (lookahead) när relikerna lämnade belöningspoolen: styrkan flyttade till gear, som bara finns i
  `--careers`. Lookahead − greedy = +55 p.e. (stoppregeln ≥ 10 håller).
- Våning 1 är lätt med gear (mixed vinner 97 %): döden och Kistan syns sällan i simulatorn. Det är
  en fråga för balanspasset när våning 2–3 byggs, inte för M6.

## 6. Idéer och öppet (inte byggt – till BACKLOG om PM vill)

- Smedjan nivå 3 "omslipning" (byt effekt inom slot, §4.1) är inte byggd; nivå 3 höjer bara taket till +3.
- Kritväggens samling som silhuetter (§4.3): räknaren "Gear found n / 22" finns, bilden inte.
- Packningen syns inte i character sheetet (dev A): `run.pack`.
- Trappbanken ligger före bossen eftersom M6 har en våning; när våning 2 finns bör den flyttas till
  trappan efter bossen (§3.4) – `_on_floor_cleared` är redan kroken.
