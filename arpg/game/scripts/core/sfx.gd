extends Node
## Plays generated sound effects by id: res://assets/generated/sfx/<id>.wav (variants <id>_1.wav ...).
## Missing sounds are silently ignored so gameplay never depends on audio.

const DIR := "res://assets/generated/sfx/"
const MUSIC_DIR := "res://assets/generated/music/"
var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _music: AudioStreamPlayer
var _last_play := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)

func _variants(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	var out := []
	for suffix in ["", "_1", "_2", "_3", "_4"]:
		var p := DIR + id + suffix + ".wav"
		if ResourceLoader.exists(p):
			out.append(load(p))
	_cache[id] = out
	return out

func play(id: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var v := _variants(id)
	if v.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(id, 0)) < 35:   # avoid stacking the same sound in one frame
		return
	_last_play[id] = now
	for p in _pool:
		if not p.playing:
			p.stream = v[randi() % v.size()]
			p.volume_db = volume_db + linear_to_db(max(0.001, float(Settings.get_value("sfx_volume", 0.9))))
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return

func play_music(id: String) -> void:
	var path := MUSIC_DIR + id + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_DIR + id + ".wav"
		if not ResourceLoader.exists(path):
			return
	var s = load(path)
	if _music.stream == s and _music.playing:
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	_music.stream = s
	_music.volume_db = linear_to_db(max(0.001, float(Settings.get_value("music_volume", 0.7)))) - 6.0
	_music.play()
