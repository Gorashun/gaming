# M6 spår A – integrationsanteckningar

*Dev A, 2026-09-23. Det här är vad spår A förväntar sig av dev B, `game_controller.gd`
och asset-agenten. Spår A rör inte de filerna; raderna nedan är färdiga att klistra in.*

## 1. Character sheetet läser gear via hjälten

`CharacterSheet.open_for(ctx)` tar en ny, valfri nyckel:

```gdscript
sheet.open_for({
	"state": run.combat if run != null else null,
	"meta": meta,
	"hero": run.hero if run != null else null,   # NY: Hero eller null
	"in_town": _screen_name == SCREEN_TOWN,
	"room": run.room_index if run != null else 0,
	"seed": run.seed_value if run != null else next_seed(),
	"highlight": highlight_id,
})
sheet.look_changed.connect(_on_sheet_look_changed)   # NY, se nedan
```

Gränssnittet sheetet använder (finns redan i `src/core/hero.gd` / `item.gd`, commit cdb6b77):

| Anrop | Används till |
|---|---|
| `Hero.equipped(slot: String) -> Item \| null` | vad som ritas i sloten |
| `Hero.is_slot_unlocked(slot) -> bool`, `Hero.level_for_slot(slot) -> int` | låst slot visar "LV n" |
| `Hero.name`, `Hero.body_variant` | rubriken och porträttet (`hero.portrait.<a\|b>`) |
| `Item.icon_id` (tom ⇒ `Item.id`) | `Art.gear_icon(id)` → manifestets `gear.<ID>` |
| `Item.rarity` | `Rules.rarity_name()` → `rarity.frame.<namn>`; saknas ramen blir plattan en ram i `Tokens.rarity_color()` |
| `Item.name_key` / `display_name`, `Item.effect_summary_key` | detaljraden vid tapp |

Utan `"hero"` (källaren, tester, gamla sparfiler) läses relikerna som i M5 via `Content.RELIC_SLOTS`.

**`look_changed(variant: String)`**: CHANGE LOOK (bara i staden) skriver `Settings.smith_variant`
och, om sheetet fick en hjälte, `hero.body_variant`. Controllern ska spara metan/rostret då:

```gdscript
func _on_sheet_look_changed(_variant: String) -> void:
	SaveIO.save_meta(meta)   # eller rostrets egen sparväg
```

**Highlight:** `highlight` får vara ett relik-id (`RELIC_<ID>`) som förut, eller ett gear-id
(`<ID>` eller `GEAR_<ID>`); sloten som bär föremålet blixtrar.

## 2. Korridoren

- `CorridorMesh.tile_texture()` tar nu ett manifest-id (`&"env.corridor.wall"`). En sökväg
  som börjar med `res://` fungerar fortfarande (bakåtkompatibelt för `town_view.gd:102`), men
  torget bör byta till `Art.tex(&"env.corridor.torch")` så att facklan följer manifestet.
- `CorridorView.FOG_COLOR` är nu void `#07090B`. `town_view.gd` läser konstanten och får samma
  ton automatiskt; torgets mesh får det bakade ljuset via `CorridorMesh.build()`.
- `CorridorView.narrate(kind, salt)` finns för controllern om den vill ge narratorn fler
  ögonblick (Kistan, trappan, död). Nycklarna ligger i `CorridorView.NARRATOR_LINES`.

## 3. Rader som saknas i `assets/i18n/translations.csv` (asset-agenten / PM)

Koden går via `Tokens.translate_or()` med konstanta nycklar, så engelska visas tills raderna finns.

```csv
NARRATOR_ENCOUNTER_1,The torch holds. The wall does not.,Facklan håller. Det gör inte muren.
NARRATOR_ENCOUNTER_2,Something breathes in the dark ahead.,Något andas i mörkret framför dig.
NARRATOR_ENCOUNTER_3,Count them before they count you.,Räkna dem innan de räknar dig.
NARRATOR_BOSS,The door breathes. So does whatever is behind it.,Dörren andas. Det gör det bakom den också.
NARRATOR_CLEARED_1,Quiet again. For now.,Tyst igen. För stunden.
NARRATOR_CLEARED_2,The dark takes back what it lent.,Mörkret tar tillbaka det det lånat ut.
NARRATOR_FLOOR,Deeper. The air tastes of slag.,Djupare. Luften smakar slagg.
CHARSHEET_LOCKED_LV,LV %d,NV %d
```

## 4. Till asset-agenten

- `relic.ANVIL_BLESSING` saknas i manifestet (klassreliken). Sheetets relikrad visar då bara
  namnet; resten av spelet får platshållaren (rött kryss).
- `env.corridor.torch` och `env.corridor.sign` saknas; korridoren använder M5:s pixelsprites
  (Nearest) tills de finns. En målad fackla får gärna vara en horisontell remsa med
  `"frames": n`.
- `slot.<typ>` och `node.<typ>` saknas; M1.5-ikonerna används (Nearest).
- Fiendernas storlek tas ur manifestets `size` med en fast skala (256 px = 1,76 m) och passas in
  i en ruta per nivå; `"scale": 1.2` i en post justerar en enskild figur utan kodändring.
  `"tier": "boss"` ger bossrutan.

## 5. Kända avvikelser

- `src/game/reward/reward_card.gd` (dev B) ritar relik- och slotikoner som pixelsprites med
  Nearest och heltalsskala. Med målade relikikoner ur manifestet (128 px) blir de stora och
  hårda där. Förslag: `Art.filter_for(StringName("relic." + id))` och en skala som passar in
  ikonen i kortets ruta.
