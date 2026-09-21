class_name Die
extends RefCounted
## En tärning: sex [Face]-sidor plus material. Tärningarna ÄR spelarens build.

enum DieMaterial {
	BONE, ## Billig, neutral. Startmaterial för Spelaren.
	GLASS, ## Hög risk: kan spricka, men sidorna reagerar på varandra.
	IRON, ## Tålig och tung. Färre tärningar, större värden.
}

const FACE_COUNT: int = 6

var id: String = ""
var material: int = DieMaterial.BONE
var faces: Array[Face] = []
## Hur många sprickor tärningen tål innan den går sönder. -1 = odödlig.
var durability: int = -1
## Senast rullade sidans index, eller -1 om tärningen inte rullats denna runda.
var rolled_index: int = -1


func _init(p_id: String = "", p_faces: Array[Face] = [], p_material: int = DieMaterial.BONE) -> void:
	id = p_id
	material = p_material
	faces = p_faces.duplicate()


## Standardtärning 1–6, för tester och startutrustning.
static func standard(p_id: String, p_material: int = DieMaterial.BONE) -> Die:
	var faces: Array[Face] = []
	for pips: int in range(1, FACE_COUNT + 1):
		faces.append(Face.new("pip_%d" % pips, pips, Face.Kind.PIP))
	return Die.new(p_id, faces, p_material)


## Rullar tärningen med den seedade strömmen och returnerar den valda sidan.
## Sätter även [member rolled_index] så att UI kan visa vilken sida som kom upp.
func roll(rng: Rng) -> Face:
	if faces.is_empty():
		rolled_index = -1
		return null
	rolled_index = rng.next_int(0, faces.size() - 1)
	return faces[rolled_index]


func rolled_face() -> Face:
	if rolled_index < 0 or rolled_index >= faces.size():
		return null
	return faces[rolled_index]


## Smider om en sida. Returnerar false om indexet ligger utanför tärningen.
func reforge(index: int, face: Face) -> bool:
	if index < 0 or index >= faces.size():
		return false
	faces[index] = face
	return true


func is_broken() -> bool:
	return durability == 0


func to_dict() -> Dictionary:
	var face_data: Array = []
	for face: Face in faces:
		face_data.append(face.to_dict())
	return {
		"id": id,
		"material": int(material),
		"durability": durability,
		"rolled_index": rolled_index,
		"faces": face_data,
	}


static func from_dict(data: Dictionary) -> Die:
	var faces: Array[Face] = []
	for entry: Variant in data.get("faces", []) as Array:
		faces.append(Face.from_dict(entry as Dictionary))
	var die: Die = Die.new(
		String(data.get("id", "")),
		faces,
		int(data.get("material", DieMaterial.BONE)),
	)
	die.durability = int(data.get("durability", -1))
	die.rolled_index = int(data.get("rolled_index", -1))
	return die
