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

*(fylls i vid steg 2)*

## 4. Ceremoni-events (steg 3)

*(fylls i vid steg 3)*
