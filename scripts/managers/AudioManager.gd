extends Node
## AudioManager.gd - all audio is generated in-project at runtime (safe,
## no external assets). Provides subtle UI feedback tones and a low
## ambient loop. Volumes follow SettingsManager.

const MIX_RATE := 22050

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _tones: Dictionary = {}
var _next_player: int = 0


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_build_tones()
	_build_ambient()
	SettingsManager.settings_changed.connect(_apply_volumes)
	_apply_volumes()
	_music_player.play()


func _apply_volumes() -> void:
	var sfx_db := linear_to_db(clampf(SettingsManager.sfx_volume, 0.0001, 1.0))
	for p in _sfx_players:
		p.volume_db = sfx_db - 6.0
	_music_player.volume_db = linear_to_db(clampf(SettingsManager.music_volume, 0.0001, 1.0)) - 14.0
	if SettingsManager.music_volume <= 0.001:
		if _music_player.playing:
			_music_player.stop()
	elif not _music_player.playing:
		_music_player.play()


# ---------- Public API (UI hooks) ----------
func play_click() -> void: _play("click")
func play_confirm() -> void: _play("confirm")
func play_success() -> void: _play("success")
func play_fail() -> void: _play("fail")
func play_event() -> void: _play("event")
func play_alarm() -> void: _play("alarm")


func _play(id: String) -> void:
	if SettingsManager.sfx_volume <= 0.001:
		return
	var p := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	p.stream = _tones[id]
	p.play()


# ---------- Tone synthesis ----------
func _build_tones() -> void:
	_tones["click"] = _tone([[880.0, 1.0]], 0.05, 0.3)
	_tones["confirm"] = _tone([[660.0, 1.0], [990.0, 0.4]], 0.09, 0.25)
	_tones["success"] = _two_step(523.25, 784.0, 0.09, 0.14)
	_tones["fail"] = _two_step(300.0, 180.0, 0.10, 0.18)
	_tones["event"] = _tone([[392.0, 1.0], [466.16, 0.7]], 0.22, 0.4)
	_tones["alarm"] = _two_step(440.0, 415.3, 0.16, 0.16)


func _tone(partials: Array, duration: float, attack_ratio: float) -> AudioStreamWAV:
	var frames := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := _envelope(float(i) / frames, attack_ratio)
		var sample := 0.0
		for part in partials:
			sample += sin(TAU * part[0] * t) * part[1]
		var v := int(clampf(sample * env * 0.4, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	return _wav(data)


func _two_step(freq_a: float, freq_b: float, dur_a: float, dur_b: float) -> AudioStreamWAV:
	var frames_a := int(MIX_RATE * dur_a)
	var frames_b := int(MIX_RATE * dur_b)
	var total := frames_a + frames_b
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / MIX_RATE
		var freq := freq_a if i < frames_a else freq_b
		var env := _envelope(float(i) / total, 0.15)
		var v := int(clampf(sin(TAU * freq * t) * env * 0.4, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	return _wav(data)


func _build_ambient() -> void:
	# Quiet layered drone: two low sines with slow amplitude drift.
	var duration := 12.0
	var frames := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / MIX_RATE
		var lfo_a := 0.5 + 0.5 * sin(TAU * t / duration)
		var lfo_b := 0.5 + 0.5 * sin(TAU * t / duration * 2.0 + 1.3)
		var sample := sin(TAU * 55.0 * t) * 0.35 * lfo_a \
			+ sin(TAU * 82.4 * t) * 0.25 * lfo_b \
			+ sin(TAU * 660.0 * t) * 0.02 * lfo_a * lfo_b
		var v := int(clampf(sample * 0.5, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := _wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	_music_player.stream = wav


func _envelope(progress: float, attack_ratio: float) -> float:
	if progress < attack_ratio:
		return progress / attack_ratio
	return 1.0 - (progress - attack_ratio) / (1.0 - attack_ratio)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
