class_name Tutorial
extends RefCounted
## Våning 0, [b]THE SHALLOW CUT[/b]. TOWN_AND_ONBOARDING §B.2.
##
## Sju handskrivna rum som spelas [b]exakt en gång[/b] (flaggan
## [member Meta.tutorial_done]). Efter dem är våning 1 precis som specad i
## GAME_DESIGN §1.
##
## [b]Ingen regel ändras här.[/b] Hela tutorialen är [i]data[/i]: bräden,
## tärningar, fiender och belöningar, plus presentation. Det är avsiktligt –
## begriplighet ska aldrig lösas genom att göra spelet enklare, och
## [Resolver] är orörd.
##
## [b]Tärningarna är fasta, inte slumpade.[/b] Varje rum anger exakt vilka
## värden som ligger uppåt, så att lektionen alltid går att lära sig:
## rum 0.3 har ett par och inget annat, rum 0.5 har inget par alls, rum 0.6 har
## bara värden som studsar på rustning 8. Vi drar ändå ur den seedade strömmen
## för intents, så flödet är identiskt med en riktig run.
##
## [b]Träningshjulsregeln, uttalad för spelaren[/b] (§B.2): i våning 0 kan man
## inte dö. Når HP 0 kommer Marrow med kärran, spelaren står kvar med 1 HP och
## texten säger rakt ut att det bara gäller här uppe. Att ljuga om det vore
## värre än att dö.

## Rumsantal.
const ROOM_COUNT: int = 7
## Steg mellan två rum i källaren. CORRIDOR_DESIGN §5.2 punkt 2 är normativ:
## "korridoren mellan dem är två steg lång och helt rak".
const CORRIDOR_STEPS: int = 2
## HP spelaren står kvar med när kärran kommer (§B.2).
const REVIVE_HP: int = 1

## Loot-valet i källaren (M5.7). Rum 0.3 lämnar [b]tre riktiga belöningskort[/b]
## ur samma pool som en vanlig run, inte ett berättande kort: en spelare som
## aldrig sett ett val av tre vet inte att spelet har loot, och Anders letade
## efter det i webbtestet och hittade inget. Korten är sidor – kategorin
## [constant Rewards.CATEGORY_FORGE_FACE] – eftersom en sida är den enda
## belöningen som syns direkt på tärningarna i nästa rum.
const LOOT_OPTIONS: int = 3
const LOOT_TITLE_KEY: String = "TUT_LOOT_TITLE"
const LOOT_TITLE_EN: String = "Loot. Pick one."

## Kärrans replik. Engelsk källsträng; svenskan är en CSV-rad.
const CART_LINE_KEY: String = "TUT_CART_LINE"
const CART_LINE_EN: String = "The cart still comes for you down here. After this, it doesn't."

## Rummen, i ordning. Fälten:
## [br]• [code]board[/code] – slot-typerna vid rummets start.
## [br]• [code]dice[/code] – de uppåtvända värdena, ett per tärning.
## [br]• [code]enemies[/code] – [code]{id, hp, armor, attack, special}[/code].
## [br]• [code]reveal[/code] – [Reveal]-flaggor som tänds när rummet börjar.
## [br]• [code]tip[/code] – [code][nyckel, engelsk källsträng][/code], max en
##   mening, försvinner vid handling (§B.2).
## [br]• [code]point_at[/code] – vad kritpilen pekar på. Namnen matchar
##   [code]CombatScreen.pointer_anchors()[/code].
## [br]• [code]intents[/code] – tvingade intents per runda, se
##   [method apply_intents].
const ROOMS: Array[Dictionary] = [
	{
		"id": "0.1",
		"idea": "PLACE_AND_CONFIRM",
		"board": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN],
		"dice": [2, 3, 4],
		"enemies": [{"id": "CHALK_DUMMY", "hp": 12, "armor": 0, "attack": 2, "name": "Chalk Dummy"}],
		"reveal": ["tray_ext"],
		"tip": ["TUT_01_PLACE", "Drag a die into a slot. The button shows the damage."],
		"point_at": "tray",
		# Dummyn slår inte första rundan: det enda misstag som är möjligt i 0.1
		# är att inte göra någonting, och då står tipset kvar (§B.2).
		"intents": {"1": {"kind": Rules.IntentKind.ATTACK, "value": 0}},
		"reward": null,
	},
	{
		"id": "0.2",
		"idea": "OVERFLOW",
		"board": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN],
		"dice": [6, 4, 2],
		# Framråttan har 3 HP. Vilken tärning som helst dödar den, och
		# överskottet MÅSTE gå någonstans. Lärdomen kommer av handling (§B.2).
		"enemies": [
			{"id": "RUST_MITE", "hp": 3, "armor": 0, "attack": 2, "name": "Rust Mite"},
			{"id": "RUST_MITE", "hp": 9, "armor": 0, "attack": 2, "name": "Rust Mite"},
		],
		"reveal": ["overflow"],
		"tip": ["TUT_02_OVERFLOW", "Damage left over rolls on to the next enemy."],
		# M5.5: leveransremsan är borta med den platta skärmen. Kvittot är där
		# överskottet står i ord ("… spills 9 onto Rust Mite 2"), så pilen pekar
		# dit i stället för på en rad som inte finns.
		"point_at": "receipt",
		"intents": {},
		"reward": {"key": "TUT_REWARD_SLOT4", "en": "A fourth slot. One more die in the chain."},
	},
	{
		"id": "0.3",
		"idea": "PAIR",
		"board": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN],
		# Fyra tärningar utan par ≤ 13 skada; med paret 23. Fienden har 24 HP
		# och slår för 8: utan paret tar man två träffar, med paret en. Spelaren
		# straffas mjukt men känner det (§B.2).
		"dice": [5, 5, 2, 1],
		"enemies": [{"id": "SLAG_PUP", "hp": 24, "armor": 0, "attack": 8, "name": "Slag Pup"}],
		"reveal": ["slot_types"],
		"tip": ["TUT_03_PAIR", "Equal values side by side: ×2. Three in a row: ×4."],
		"point_at": "arcs",
		"intents": {},
		"reward": {"key": "TUT_REWARD_SLOT5", "en": "A fifth slot. The board is full size now."},
		# M5.7: det första riktiga loot-valet ligger här, efter paret, och inte
		# senare. Två rum in har spelaren just lärt sig att placeringen betyder
		# något; då betyder tre kort också något. Kommer valet först i rum 0.5
		# har halva tutorialen gått utan att spelet visat att det HAR loot.
		"loot": true,
	},
	{
		"id": "0.4",
		"idea": "ARMOR",
		"board": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN,
			Rules.SlotType.PLAIN, Rules.SlotType.PLAIN],
		# Två par i handen mot rustning 3: 5×2 − 3 = 7 är bra, 1 − 3 = 0 är ett
		# slag som gör INGENTING. Första gången spelaren ser en nolla, och
		# kvittot förklarar varför.
		"dice": [3, 3, 5, 5, 1],
		"enemies": [{"id": "TICK_PUP", "hp": 26, "armor": 3, "attack": 4, "name": "Tick Pup"}],
		"reveal": ["armor"],
		"tip": ["TUT_04_ARMOR", "Armor is subtracted from every hit. One big hit beats four small."],
		"point_at": "receipt",
		"intents": {},
		"reward": {"key": "TUT_REWARD_MIRROR", "en": "A Mirror on slot 3. It copies the value on its left."},
	},
	{
		"id": "0.5",
		"idea": "MIRROR",
		"board": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.MIRROR,
			Rules.SlotType.PLAIN, Rules.SlotType.PLAIN],
		# Fem olika värden: det finns inget par att hitta. Spegeln är enda
		# sättet att göra ett (§B.2).
		"dice": [1, 2, 3, 4, 6],
		"enemies": [{"id": "SLAG_MOTH", "hp": 34, "armor": 1, "attack": 4, "name": "Slag Moth"}],
		"reveal": ["mirror"],
		"tip": ["TUT_05_MIRROR", "Mirror copies the value on its left. Its own pips do nothing."],
		"point_at": "slot_2",
		"intents": {},
		"reward": {"key": "TUT_REWARD_REROLL", "en": "One reroll per round. Use it before you commit."},
	},
	{
		"id": "0.6",
		"idea": "CHARGE",
		"board": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.MIRROR,
			Rules.SlotType.PLAIN, Rules.SlotType.PLAIN],
		# Porten har rustning 8 och blockar två rundor: varje enskild tärning
		# studsar. Det enda vettiga är att inte placera – och då dyker Laddning
		# upp med en förklaring spelaren redan efterfrågat med sitt eget spel.
		"dice": [1, 2, 3, 4, 2, 3],
		"enemies": [{"id": "SCRAP_GATE", "hp": 44, "armor": 8, "attack": 6, "name": "Scrap Gate"}],
		"reveal": ["reroll", "charge"],
		"tip": ["TUT_06_CHARGE", "Dice you don't place go in the bank."],
		"point_at": "charge",
		"intents": {
			"1": {"kind": Rules.IntentKind.BLOCK, "value": 4},
			"2": {"kind": Rules.IntentKind.BLOCK, "value": 4},
		},
		"reward": {"key": "TUT_REWARD_ANVIL", "en": "An Anvil on slot 5. It doubles 5 or more."},
	},
	{
		"id": "0.7",
		"idea": "ANVIL_BREAKS_PAIRS",
		"board": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.MIRROR,
			Rules.SlotType.PLAIN, Rules.SlotType.ANVIL],
		# Två sexor i handen: lägger spelaren den ena i Ambossen försvinner
		# paret. Visa fällan innan den smäller, låt spelaren gå i den ändå.
		"dice": [6, 6, 5, 2, 3, 4],
		"enemies": [{"id": "SLAGJAW_RUNT", "hp": 110, "armor": 2, "attack": 6,
			"special": "HARDEN", "name": "Slagjaw's Runt", "boss": true}],
		"reveal": ["anvil"],
		"tip": ["TUT_07_ANVIL", "Anvil doubles 5 or more. A doubled 6 no longer pairs with a 6."],
		"point_at": "slot_4",
		"intents": {},
		"reward": null,
	},
]


static func room_count() -> int:
	return ROOMS.size()


static func room(index: int) -> Dictionary:
	if index < 0 or index >= ROOMS.size():
		return {}
	return ROOMS[index]


## Nodbeskrivningen som [RunFlow] och [CombatScreen] väntar sig. Samma form som
## [method RunGraph.node_at], så att inget i stridsskärmen behöver veta att det
## är en tutorial.
static func node_for(index: int) -> Dictionary:
	var data: Dictionary = room(index)
	var boss: bool = false
	for entry: Variant in data.get("enemies", []) as Array:
		if bool((entry as Dictionary).get("boss", false)):
			boss = true
	return {
		"id": "f0r%d" % (index + 1),
		"floor": 0,
		"room": index + 1,
		"room_in_floor": index + 1,
		"kind": RunGraph.KIND_BOSS if boss else RunGraph.KIND_COMBAT,
		"variant": 0,
		"branch_index": -1,
		"tutorial_room": index,
		"next": [] as Array,
	}


static func enemies_for(index: int) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for entry: Variant in room(index).get("enemies", []) as Array:
		var spec: Dictionary = entry as Dictionary
		var enemy: Enemy = Enemy.new(
			String(spec["id"]),
			int(spec["hp"]),
			int(spec["attack"]),
			String(spec.get("name", spec["id"])),
		)
		enemy.armor = int(spec.get("armor", 0))
		enemy.thorns = int(spec.get("thorns", 0))
		enemy.special = String(spec.get("special", ""))
		result.append(enemy)
	return result


## Bygger rummets tillstånd ur [param carried] (förra rummets tillstånd, eller
## [method Content.smith_state] för 0.1). Brädet, tärningsantalet och de
## uppåtvända värdena kommer ur data; HP och Laddning följer med spelaren.
##
## [param rng] används av [method Resolver.begin_combat] för intents – all
## slump dras alltså fortfarande före bekräftelsen (GAME_DESIGN §6.4).
static func prepare_room(carried: CombatState, index: int, rng: Rng) -> CombatState:
	var data: Dictionary = room(index)
	if data.is_empty():
		return carried
	var state: CombatState = carried.copy()
	state.board = Board.from_types(data["board"] as Array)
	state.enemies = enemies_for(index)
	state.charge = 0
	state.ward = 0
	state.total_damage = 0
	state.player_dead = false
	state.stolen.clear()

	var values: Array = data["dice"] as Array
	while state.dice.size() < values.size():
		state.dice.append(Die.standard("die_%d" % state.dice.size(), Rules.DieMaterial.IRON))
	while state.dice.size() > values.size():
		state.dice.remove_at(state.dice.size() - 1)

	state = Resolver.begin_combat(state, rng)
	force_dice(state, index)
	apply_limits(state, index)
	apply_intents(state, index)
	return state


## Omkastet låses upp av belöningen efter rum 0.5 (§B.2). Fram till dess har
## rummet noll omkast, och då [b]finns[/b] knappen inte – den är inte nedtonad,
## och UI ljuger inte, eftersom det faktiskt inte finns något omkast.
## [method Resolver.advance] delar ut ett nytt omkast varje runda, så gränsen
## måste sättas om efter varje [code]advance[/code].
static func apply_limits(state: CombatState, index: int) -> void:
	state.rerolls_left = 1 if reroll_unlocked(index) else 0


## Rummet där omkastet blir spelbart. Rum 0.5:s belöning ger det, så 0.6 är
## första rummet som har det.
static func reroll_unlocked(index: int) -> bool:
	return index >= 5


## Tvingar de uppåtvända sidorna till rummets fasta värden. Körs EFTER
## [method Resolver.begin_combat] och [method Resolver.advance], som annars
## skulle rulla om dem.
##
## [b]Strömmen rullas inte tillbaka[/b] – kastet har skett, vi skriver bara
## över resultatet. Tutorialen är den enda platsen i spelet där det är tillåtet,
## och den är inte seedberoende eftersom värdena är fasta.
static func force_dice(state: CombatState, index: int) -> void:
	var values: Array = room(index).get("dice", []) as Array
	for i: int in range(mini(state.dice.size(), values.size())):
		var die: Die = state.dice[i]
		var wanted: int = int(values[i])
		for face_index: int in range(die.faces.size()):
			if die.faces[face_index].value == wanted:
				die.showing = face_index
				break


## Tvingar intents för den runda [param state] står på. Utan den kan vi inte
## ge dummyn en tyst första runda eller porten sina två blockrundor, och båda
## skulle kräva en ny special i [Resolver] – alltså en regeländring.
static func apply_intents(state: CombatState, index: int) -> void:
	var table: Dictionary = room(index).get("intents", {}) as Dictionary
	var spec: Dictionary = table.get(str(state.round_number), {}) as Dictionary
	if spec.is_empty():
		return
	for enemy: Enemy in state.enemies:
		if not enemy.is_alive():
			continue
		var intent: Intent = Intent.new(int(spec["kind"]), int(spec["value"]), _note_key(int(spec["kind"])))
		intent.note_args = [int(spec["value"])]
		enemy.intent = intent


static func _note_key(kind: int) -> String:
	match kind:
		Rules.IntentKind.BLOCK:
			return "INTENT_NOTE_HARDEN"
		Rules.IntentKind.SPECIAL:
			return "INTENT_NOTE_GRAB"
	return "INTENT_NOTE_ATTACK"


## Flaggorna rummet tänder. Tomt för ett rum som inte lär ut ett nytt element.
static func reveal_flags(index: int) -> Array[String]:
	var flags: Array[String] = []
	for value: Variant in room(index).get("reveal", []) as Array:
		flags.append(String(value))
	return flags


## Tänder rummets flaggor. Returnerar de som faktiskt ändrades, så att UI kan
## spela kritstreck-animationen bara första gången (§B.2).
static func apply_reveal(reveal: Reveal, index: int) -> Array[String]:
	var fresh: Array[String] = []
	for flag: String in reveal_flags(index):
		if reveal.reveal_flag(flag):
			fresh.append(flag)
	return fresh


## Rummets tooltip: [code]{key, en, point_at}[/code]. Max en per rum, max en
## mening, försvinner vid handling (§B.2).
static func tip_for(index: int) -> Dictionary:
	var data: Dictionary = room(index)
	if data.is_empty():
		return {}
	var tip: Array = data["tip"] as Array
	return {"key": String(tip[0]), "en": String(tip[1]), "point_at": String(data["point_at"])}


## Belöningskortet efter rummet, i [Rewards]-poolens form. Returnerar en tom
## Dictionary när rummet inte ger någon belöning (0.1 och 0.7).
static func reward_for(index: int) -> Dictionary:
	var raw: Variant = room(index).get("reward", null)
	if raw == null:
		return {}
	var spec: Dictionary = raw as Dictionary
	return {
		"id": "TUT_%s" % String(room(index)["id"]),
		"category": Rewards.CATEGORY_TUTORIAL,
		"name": String(spec["en"]),
		"name_key": String(spec["key"]),
		"desc_key": String(spec["key"]),
		"desc_en": String(spec["en"]),
		"rarity": Rules.Rarity.COMMON,
		"data": {},
	}


## Kärrans text när HP nått 0 i våning 0.
static func cart_line() -> Array[String]:
	return [CART_LINE_KEY, CART_LINE_EN]


# ---------------------------------------------------------------------------
# Loot (M5.7)
# ---------------------------------------------------------------------------

## Lämnar rummet ett riktigt val av tre kort efter sitt berättande kort?
static func has_loot(index: int) -> bool:
	return bool(room(index).get("loot", false))


## Rubriken över loot-korten. Egen rad eftersom den säger något annat än
## [code]CORRIDOR_REWARD_TITLE[/code]: det här är ett val, inte en gåva.
static func loot_title() -> Array[String]:
	return [LOOT_TITLE_KEY, LOOT_TITLE_EN]


## Tre sidor ur [param pool], dragna med [param rng] precis som i en run.
## Filtret på [constant Rewards.CATEGORY_FORGE_FACE] är hela skillnaden: korten,
## texterna och sällsynthetsvikterna är desamma som senare.
static func loot_options(pool: Array, rng: Rng) -> Array[Dictionary]:
	var faces: Array = []
	for raw: Variant in pool:
		var entry: Dictionary = raw as Dictionary
		if String(entry.get("category", "")) == Rewards.CATEGORY_FORGE_FACE:
			faces.append(entry)
	return Rewards.generate(faces, rng, 1, LOOT_OPTIONS)


## Sidan som loot-kortet byter ut, för ett val efter rum [param index].
##
## [b]Inte [method RewardApply.default_target].[/b] Den tar sidan med lägst
## värde i hela uppsättningen, och det är tärning 1:s etta – som rum 0.5 och 0.6
## tvingar upp. Byts den bort finns värdet inte längre på tärningen,
## [method force_dice] hittar ingen sida, och rum 0.5:s lektion ("det finns
## inget naturligt par") går sönder utan att något felar. Vi väljer därför den
## lägsta sidan som [b]inget senare rum tvingar upp på just den tärningen[/b].
## Belöningen är fortfarande verklig och permanent; den kan bara inte ljuga om
## vilka tärningar spelaren får se.
static func loot_target(state: CombatState, index: int) -> Dictionary:
	var reserved: Dictionary = {}
	for room_index: int in range(index + 1, ROOM_COUNT):
		var values: Array = room(room_index).get("dice", []) as Array
		for die_index: int in range(values.size()):
			reserved["%d:%d" % [die_index, int(values[die_index])]] = true
	var best_die: int = -1
	var best_face: int = -1
	var best_value: int = 1 << 30
	for d: int in range(state.dice.size()):
		var die: Die = state.dice[d]
		for f: int in range(die.faces.size()):
			var value: int = die.faces[f].value
			if reserved.has("%d:%d" % [d, value]) or value >= best_value:
				continue
			best_value = value
			best_die = d
			best_face = f
	if best_die < 0:
		return {}
	return {"die_index": best_die, "face_index": best_face}


# ---------------------------------------------------------------------------
# Källaren under smedjan (CORRIDOR_DESIGN §5.2)
# ---------------------------------------------------------------------------

## Tutorialvåningen som korridorkarta: sju kammare på rad, två steg emellan, och
## en trappa upp bakom bossen.
##
## [b]Samma presentation som en riktig run[/b] (M5.5). Tutorialen hade en egen
## platt stridsskärm fram till dess; nu finns exakt en stridspresentation, och
## källaren skiljer sig bara i innehåll: fasta tärningar, tvingade intents,
## [Reveal]-flaggor per rum och träningshjulen.
static func corridor_map() -> CorridorMap:
	var ids: Array[String] = []
	for i: int in range(ROOM_COUNT):
		ids.append(String(node_for(i)["id"]))
	return CorridorMap.straight_floor(0, ids, CORRIDOR_STEPS)


## Rumsindex för en kammares nod-id, eller -1. Motsatsen till
## [method node_for]: korridoren talar nod-id, tutorialen talar rumsindex.
static func room_index_for(node_id: String) -> int:
	for i: int in range(ROOM_COUNT):
		if String(node_for(i)["id"]) == node_id:
			return i
	return -1
