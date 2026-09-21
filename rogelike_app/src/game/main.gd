extends Control
## Minimal M0-placeholder. Visar speltiteln så att projektet går att öppna och köra.
## All spellogik bor i src/core/ och får aldrig importeras hit åt andra hållet.

@onready var _title: Label = $Title


func _ready() -> void:
	_title.text = "PIPWRECK"
