extends Node
## Plays generated sound effects by id: res://assets/generated/sfx/<id>.wav (variants <id>_1.wav ...).
## Missing sounds are silently ignored so gameplay never depends on audio.

const DIR := "res://assets/generated/sfx/"
const MUSIC_DIR := "res://assets/generated/music/"
var _cache = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _music: AudioStreamPlayer
var _last_play = {}
# Ambience: two looping players that crossfade (see play_ambience).
var _amb: Array[AudioStreamPlayer] = []
var _amb_cur := 0
var _amb_id := ""
var _amb_tweens: Array = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for i in 2:
		var a = AudioStreamPlayer.new()
		a.bus = "Master"
		add_child(a)
		_amb.append(a)

func _variants(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	var out = []
	for suffix in ["", "_1", "_2", "_3", "_4"]:
		var p = DIR + id + suffix + ".wav"
		if ResourceLoader.exists(p):
			out.append(load(p))
	_cache[id] = out
	return out

func play(id: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var v = _variants(id)
	if v.is_empty():
		return
	var now = Time.get_ticks_msec()
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
	var path = MUSIC_DIR + id + ".ogg"
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

func _load_loop(id: String) -> AudioStream:
	var path = MUSIC_DIR + id + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_DIR + id + ".wav"
		if not ResourceLoader.exists(path):
			return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s

func _ambience_db() -> float:
	var v = float(Settings.get_value("ambience_volume", Settings.get_value("music_volume", 0.7)))
	return linear_to_db(max(0.001, v)) - 8.0

func _fade_amb(i: int, to_db: float, secs: float, stop_after: bool) -> void:
	if _amb_tweens[i] != null and _amb_tweens[i].is_valid():
		_amb_tweens[i].kill()
	var t = create_tween()
	t.tween_property(_amb[i], "volume_db", to_db, max(0.01, secs))
	if stop_after:
		t.tween_callback(_amb[i].stop)
	_amb_tweens[i] = t

## Loop an ambience bed (res://assets/generated/music/<id>.ogg, e.g. "amb_bog") under the music,
## crossfading from the previous one over `fade` seconds. "" or a missing id fades ambience out.
func play_ambience(id: String, fade := 2.0) -> void:
	if id == _amb_id and _amb[_amb_cur].playing:
		return
	var s = _load_loop(id) if id != "" else null
	var old = _amb_cur
	if _amb[old].playing:
		_fade_amb(old, -60.0, fade, true)
	_amb_id = id if s != null else ""
	if s == null:
		return
	_amb_cur = 1 - old
	var p = _amb[_amb_cur]
	p.stream = s
	p.volume_db = -60.0
	p.play()
	_fade_amb(_amb_cur, _ambience_db(), fade, false)

func stop_ambience(fade := 2.0) -> void:
	play_ambience("", fade)
