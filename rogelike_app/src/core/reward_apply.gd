class_name RewardApply
extends RefCounted
## Tillämpar ett belöningsval på ett [CombatState]. Ren funktion, ingen RNG.
##
## Ligger i core och inte i UI av två skäl: (1) belöningskortet måste kunna visa
## exakt vad som händer INNAN spelaren trycker (samma löfte som den heliga regeln
## i GAME_DESIGN §6 ger striden), och (2) run-simulatorn ska kunna använda samma
## kod när en belöningspolicy byggs i M3.
##
## [b]Målvalet är deterministiskt, inte slumpat.[/b] M1 låter spelaren välja
## belöning men inte var den hamnar; [method default_target] bestämmer platsen
## med de regler som står i varje funktion. En manuell smedja (välj tärning →
## välj sida) är M2, och då skickar UI in ett eget [param target].

## Deterministiskt mål för ett belöningsval.
## [br]• [code]FORGE_FACE[/code] → den sida med LÄGST värde i hela uppsättningen.
##   Lika värde avgörs av lägst tärningsindex, sedan lägst sidindex. Det är
##   alltid ett försvarbart drag och det gör förhandsvisningen exakt.
## [br]• [code]SLOT_SWAP[/code] → den vänstraste sloten som inte redan har den
##   typen, med förtur för [code]PLAIN[/code] (byter hellre bort en tom regel än
##   en spelaren redan bygger på).
## [br]• [code]RELIC[/code] → inget mål behövs.
## [br]• [code]GEAR[/code] (M6) → kortet bär sitt mål själv
##   ([method GearRules.equip_target], satt när dropparna lades bland korten).
static func default_target(state: CombatState, choice: Dictionary) -> Dictionary:
	var data: Dictionary = choice.get("data", {}) as Dictionary
	match String(choice.get("category", "")):
		Rewards.CATEGORY_GEAR:
			return (data.get("target", {}) as Dictionary).duplicate(true)
		Rewards.CATEGORY_FORGE_FACE:
			var best_die: int = -1
			var best_face: int = -1
			var best_value: int = 1 << 30
			for d: int in range(state.dice.size()):
				var die: Die = state.dice[d]
				for f: int in range(die.faces.size()):
					if die.faces[f].value < best_value:
						best_value = die.faces[f].value
						best_die = d
						best_face = f
			if best_die < 0:
				return {}
			return {"die_index": best_die, "face_index": best_face}
		Rewards.CATEGORY_SLOT_SWAP:
			var wanted: int = int(data.get("slot_type", Rules.SlotType.PLAIN))
			var fallback: int = -1
			for i: int in range(state.board.size()):
				var slot: Slot = state.board.slots[i]
				if slot.type == wanted:
					continue
				if slot.type == Rules.SlotType.PLAIN:
					return {"slot_index": i}
				if fallback < 0:
					fallback = i
			if fallback < 0:
				return {}
			return {"slot_index": fallback}
	return {}


## Mening som beskriver exakt vad valet gör, på spelarens språk. Visas på
## belöningskortet. Byggs av översättningsnycklar, se i18n-avsnittet nedan.
static func describe(state: CombatState, choice: Dictionary, target: Dictionary) -> String:
	var data: Dictionary = choice.get("data", {}) as Dictionary
	var name: String = _name_of(choice)
	match String(choice.get("category", "")):
		Rewards.CATEGORY_FORGE_FACE:
			if target.is_empty():
				return _t("REWARD_DESC_FORGE_ANY") % name
			var die_index: int = int(target.get("die_index", 0))
			var face_index: int = int(target.get("face_index", 0))
			var old_value: int = 0
			if die_index < state.dice.size() and face_index < state.dice[die_index].faces.size():
				old_value = state.dice[die_index].faces[face_index].value
			var face: Face = Content.make_face(String(data.get("face_id", "")))
			return _t("REWARD_DESC_FORGE") % [
				die_index + 1, old_value, name, face.value, _effect_suffix(face),
			]
		Rewards.CATEGORY_RELIC:
			return _t("REWARD_DESC_RELIC") % name
		Rewards.CATEGORY_GEAR:
			return describe_gear(choice, target)
		Rewards.CATEGORY_SLOT_SWAP:
			var slot_index: int = int(target.get("slot_index", 0))
			var wanted: int = int(data.get("slot_type", Rules.SlotType.PLAIN))
			var before: String = "?"
			if slot_index < state.board.size():
				before = _slot_label(state.board.slots[slot_index].type)
			return _t("REWARD_DESC_SLOT_SWAP") % [
				slot_index + 1, before, _slot_label(wanted),
			]
	return name


## Gear-kortets mening: effekten, sedan var plagget hamnar. Exakt vad som händer
## när spelaren trycker – på kroppen (och vad det ersätter) eller i packningen.
static func describe_gear(choice: Dictionary, target: Dictionary) -> String:
	var data: Dictionary = choice.get("data", {}) as Dictionary
	var item_data: Dictionary = data.get("item", {}) as Dictionary
	var id: String = String(item_data.get("id", ""))
	var summary: String = _t(Content.gear_desc_key(id))
	var slot: String = _t(Content.sheet_slot_key(String(target.get("slot", item_data.get("slot", "")))))
	var where: String = ""
	if bool(target.get("to_pack", false)):
		where = _t("GEAR_TARGET_PACK") % [slot, int(target.get("unlock_level", 0))]
	elif String(target.get("replaces", "")) != "":
		where = _t("GEAR_TARGET_REPLACES") % [slot, _t(String(target.get("replaces_key", "")))]
	else:
		where = _t("GEAR_TARGET_EQUIP") % slot
	return "%s %s" % [summary, where]


static func _effect_suffix(face: Face) -> String:
	if face.effect == Rules.FaceEffectKind.NONE:
		return ""
	if face.magnitude > 0:
		return _t("REWARD_EFFECT_MAGNITUDE") % face.magnitude
	return _t("REWARD_EFFECT_SPECIAL")


# --- i18n ------------------------------------------------------------------
# describe() är den enda funktionen i src/core/ som producerar spelartext.
# Den bygger den av ÖVERSÄTTNINGSNYCKLAR, aldrig av prosa (CLAUDE.md): strängen
# slås upp i assets/i18n/translations.csv. TranslationServer är en Engine-
# singleton, inte en Node, så lagerregeln i ARCHITECTURE.md håller.

static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func _slot_label(slot_type: int) -> String:
	return _t("SLOT_%s" % Rules.slot_type_name(slot_type))


## Belöningens namn på spelarens språk. [code]name_key[/code] sätts av
## [method Content.reward_pool]; saknas den faller vi tillbaka på källnamnet.
static func _name_of(choice: Dictionary) -> String:
	var fallback: String = String(choice.get("name", choice.get("id", "")))
	var key: String = String(choice.get("name_key", ""))
	if key == "":
		return fallback
	var value: String = _t(key)
	return fallback if value == key else value


## Tillämpar ett val på hela runnen. Gear hamnar på hjälten eller i packningen
## ([method GearRules.take_item]); allt annat går till [method apply].
## [b]Muterar [param run][/b] – runnen är controllerns arbetsobjekt, inte ett
## förhandsvisat tillstånd.
static func apply_to_run(run: RunState, choice: Dictionary, target: Dictionary = {}) -> void:
	if run == null or choice.is_empty():
		return
	if String(choice.get("category", "")) == Rewards.CATEGORY_GEAR:
		var data: Dictionary = choice.get("data", {}) as Dictionary
		GearRules.take_item(run, Item.from_dict(data.get("item", {}) as Dictionary))
		return
	run.combat = apply(run.combat, choice, target)


## Returnerar en KOPIA av [param state] med belöningen tillämpad.
## Muterar aldrig indata, av samma skäl som [method Resolver.resolve] inte gör det.
## GEAR ändrar inte stridstillståndet här – det sitter på hjälten, se
## [method apply_to_run].
static func apply(state: CombatState, choice: Dictionary, target: Dictionary = {}) -> CombatState:
	var next: CombatState = state.copy()
	var data: Dictionary = choice.get("data", {}) as Dictionary
	var where: Dictionary = target if not target.is_empty() else default_target(state, choice)
	match String(choice.get("category", "")):
		Rewards.CATEGORY_FORGE_FACE:
			var die_index: int = int(where.get("die_index", -1))
			var face_index: int = int(where.get("face_index", -1))
			if die_index >= 0 and die_index < next.dice.size():
				next.dice[die_index].reforge(face_index, Content.make_face(String(data.get("face_id", ""))))
		Rewards.CATEGORY_RELIC:
			var relic_id: String = String(data.get("relic_id", ""))
			if relic_id != "" and not Relic.has_relic(next.relics, relic_id):
				next.relics.append(Content.make_relic(relic_id))
		Rewards.CATEGORY_SLOT_SWAP:
			var slot_index: int = int(where.get("slot_index", -1))
			if slot_index >= 0 and slot_index < next.board.size():
				next.board.slots[slot_index].type = int(data.get("slot_type", Rules.SlotType.PLAIN))
	return next
