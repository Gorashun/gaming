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
static func default_target(state: CombatState, choice: Dictionary) -> Dictionary:
	var data: Dictionary = choice.get("data", {}) as Dictionary
	match String(choice.get("category", "")):
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


## Svensk mening som beskriver exakt vad valet gör. Visas på belöningskortet.
static func describe(state: CombatState, choice: Dictionary, target: Dictionary) -> String:
	var data: Dictionary = choice.get("data", {}) as Dictionary
	var name: String = String(choice.get("name", choice.get("id", "")))
	match String(choice.get("category", "")):
		Rewards.CATEGORY_FORGE_FACE:
			if target.is_empty():
				return "Smider om en sida till %s." % name
			var die_index: int = int(target.get("die_index", 0))
			var face_index: int = int(target.get("face_index", 0))
			var old_value: int = 0
			if die_index < state.dice.size() and face_index < state.dice[die_index].faces.size():
				old_value = state.dice[die_index].faces[face_index].value
			var face: Face = Content.make_face(String(data.get("face_id", "")))
			return "Tärning %d: sidan %d blir %s (värde %d%s)." % [
				die_index + 1, old_value, name, face.value, _effect_suffix(face),
			]
		Rewards.CATEGORY_RELIC:
			return "Ny relik: %s. Gäller resten av runnen." % name
		Rewards.CATEGORY_SLOT_SWAP:
			var slot_index: int = int(target.get("slot_index", 0))
			var wanted: int = int(data.get("slot_type", Rules.SlotType.PLAIN))
			var before: String = "?"
			if slot_index < state.board.size():
				before = Rules.slot_type_name(state.board.slots[slot_index].type)
			return "Slot %d byter från %s till %s." % [
				slot_index + 1, before, Rules.slot_type_name(wanted),
			]
	return name


static func _effect_suffix(face: Face) -> String:
	if face.effect == Rules.FaceEffectKind.NONE:
		return ""
	if face.magnitude > 0:
		return ", effekt %d" % face.magnitude
	return ", specialeffekt"


## Returnerar en KOPIA av [param state] med belöningen tillämpad.
## Muterar aldrig indata, av samma skäl som [method Resolver.resolve] inte gör det.
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
