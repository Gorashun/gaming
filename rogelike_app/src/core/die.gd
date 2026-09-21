class_name Die
extends RefCounted
## En tärning med exakt sex [Face]-sidor. GAME_DESIGN.md §2.1.

## Unikt inom runnen, t.ex. "die_0".
var id: String = ""
## En av [enum Rules.DieMaterial].
var material: int = Rules.DieMaterial.IRON
## EXAKT 6 sidor, index 0..5.
var faces: Array[Face] = []
## Antal sprickor kvar innan tärningen förstörs. -1 = odödlig (IRON/BONE).
var integrity: int = -1
## Antal spruckna sidor hittills.
var cracks: int = 0
## Vilken sida som ligger upp efter kastet, index 0..5.
var showing: int = 0


func _init(p_id: String = "", p_faces: Array[Face] = [], p_material: int = Rules.DieMaterial.IRON) -> void:
	id = p_id
	material = p_material
	faces = p_faces.duplicate()


## Standardtärning med sidorna PIP_1..PIP_6.
static func standard(p_id: String, p_material: int = Rules.DieMaterial.IRON) -> Die:
	var faces: Array[Face] = []
	for v: int in range(1, Rules.FACE_COUNT + 1):
		faces.append(Face.new("PIP_%d" % v, v))
	var die: Die = Die.new(p_id, faces, p_material)
	if p_material == Rules.DieMaterial.GLASS:
		die.integrity = 3
	return die


## Sidan som ligger upp. Aldrig null för en välformad tärning.
func showing_face() -> Face:
	if showing < 0 or showing >= faces.size():
		return null
	return faces[showing]


## Rullar tärningen med den seedade strömmen. Anropas bara av advance(),
## aldrig av resolve() – resolve() är ren och ser ingen RNG (GAME_DESIGN §6.1).
func roll(rng: Rng) -> Face:
	if faces.is_empty():
		return null
	showing = rng.next_int(0, faces.size() - 1)
	return faces[showing]


## Smider om en sida. Returnerar false om indexet ligger utanför tärningen.
func reforge(index: int, face: Face) -> bool:
	if index < 0 or index >= faces.size():
		return false
	faces[index] = face
	return true


func is_destroyed() -> bool:
	return integrity == 0


func copy() -> Die:
	var copied_faces: Array[Face] = []
	for face: Face in faces:
		copied_faces.append(face.copy())
	var other: Die = Die.new(id, copied_faces, material)
	other.integrity = integrity
	other.cracks = cracks
	other.showing = showing
	return other


func to_dict() -> Dictionary:
	var face_data: Array = []
	for face: Face in faces:
		face_data.append(face.to_dict())
	return {
		"id": id,
		"material": material,
		"integrity": integrity,
		"cracks": cracks,
		"showing": showing,
		"faces": face_data,
	}


static func from_dict(data: Dictionary) -> Die:
	var faces: Array[Face] = []
	for entry: Variant in data.get("faces", []) as Array:
		faces.append(Face.from_dict(entry as Dictionary))
	var die: Die = Die.new(
		String(data.get("id", "")),
		faces,
		int(data.get("material", Rules.DieMaterial.IRON)),
	)
	die.integrity = int(data.get("integrity", -1))
	die.cracks = int(data.get("cracks", 0))
	die.showing = int(data.get("showing", 0))
	return die
