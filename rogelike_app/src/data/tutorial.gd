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
## HP spelaren står kvar med när kärran kommer (§B.2).
const REVIVE_HP: int = 1

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
		"point_at": "routes",
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
