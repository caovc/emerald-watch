class_name GameAudio
extends Node
## Original baked synthesis: inexpensive playback, separate Music/SFX controls.
## Instantiate once and add_child(). Music starts automatically, even while paused.
## Volume methods accept normalized 0..1 values; muting preserves both volumes.

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const COMBAT_VOICES: int = 6
const EVENT_VOICES: int = 3
const COMBAT_INTERVAL_MS: int = 45
const MUSIC_LEVEL_DB: float = -5.0
const MUSIC_TRACK: AudioStreamWAV = preload("res://assets/audio/emerald_drift.wav")
const SOUNDS: Dictionary = {
	"build": preload("res://assets/audio/build.wav"),
	"upgrade": preload("res://assets/audio/upgrade.wav"),
	"shot": preload("res://assets/audio/shot.wav"),
	"boom": preload("res://assets/audio/boom.wav"),
	"ice": preload("res://assets/audio/ice.wav"),
	"arc": preload("res://assets/audio/arc.wav"),
	"rail": preload("res://assets/audio/rail.wav"),
	"burn": preload("res://assets/audio/burn.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"leak": preload("res://assets/audio/leak.wav"),
	"wave": preload("res://assets/audio/wave.wav"),
	"win": preload("res://assets/audio/win.wav"),
	"loss": preload("res://assets/audio/loss.wav"),
	"sell": preload("res://assets/audio/sell.wav"),
}
# Millisecond cooldowns use real time, so 2x game speed cannot double sound density.
const COOLDOWN_MS: Dictionary = {
	"build": 70, "upgrade": 150, "sell": 100,
	"shot": 90, "boom": 220, "ice": 150, "arc": 160,
	"rail": 220, "burn": 200, "hit": 180,
	"leak": 260, "wave": 1000, "win": 2000, "loss": 2000,
}
const COMBAT_KEYS: Array[String] = ["shot", "boom", "ice", "arc", "rail", "burn", "hit"]
const LEVEL_DB: Dictionary = {
	"shot": -11.0, "boom": -8.0, "ice": -10.0, "arc": -11.0,
	"rail": -9.0, "burn": -12.0, "hit": -16.0,
	"build": -6.0, "upgrade": -6.0, "sell": -7.0,
	"leak": -6.0, "wave": -6.0, "win": -5.0, "loss": -6.0,
}

var music_volume: float = 0.42
var sfx_volume: float = 0.65
var muted: bool = false
var _music_player: AudioStreamPlayer
var _combat_players: Array[AudioStreamPlayer] = []
var _event_players: Array[AudioStreamPlayer] = []
var _last_play_ms: Dictionary = {}
var _last_combat_ms: int = -100000
var _event_cursor: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_add_sfx_limiter()
	for index in COMBAT_VOICES:
		_combat_players.append(_make_player("CombatVoice%d" % index, SFX_BUS))
	for index in EVENT_VOICES:
		_event_players.append(_make_player("EventVoice%d" % index, SFX_BUS))
	_music_player = _make_player("OriginalSoundtrack", MUSIC_BUS)
	var loop: AudioStreamWAV = MUSIC_TRACK.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	# Use sample frames, independent of the editor's PCM/QOA import setting.
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	_music_player.stream = loop
	_music_player.volume_db = -60.0
	_initialized = true
	_apply_mix()
	_music_player.play()
	var fade: Tween = create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_music_player, "volume_db", MUSIC_LEVEL_DB, 1.25)


func play_sfx(key: String) -> void:
	if not _initialized or muted or sfx_volume <= 0.0 or not SOUNDS.has(key):
		return
	var now: int = Time.get_ticks_msec()
	var cooldown: int = int(COOLDOWN_MS.get(key, 100))
	if now - int(_last_play_ms.get(key, -100000)) < cooldown:
		return
	var is_combat: bool = key in COMBAT_KEYS
	if is_combat and now - _last_combat_ms < COMBAT_INTERVAL_MS:
		return
	var pool: Array[AudioStreamPlayer] = _combat_players if is_combat else _event_players
	var voice: AudioStreamPlayer = null
	for candidate in pool:
		if not candidate.playing:
			voice = candidate
			break
	# Dense combat drops extra notes. Important UI cues have a separate voice pool.
	if voice == null:
		if is_combat:
			return
		voice = _event_players[_event_cursor]
		_event_cursor = (_event_cursor + 1) % EVENT_VOICES
		voice.stop()
	voice.stream = SOUNDS[key] as AudioStream
	voice.volume_db = float(LEVEL_DB.get(key, -8.0))
	# Keep melodic event cues in tune; tiny combat variation prevents machine-gun sameness.
	voice.pitch_scale = _rng.randf_range(0.97, 1.03) if is_combat else 1.0
	voice.play()
	_last_play_ms[key] = now
	if is_combat:
		_last_combat_ms = now


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	_apply_mix()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	_apply_mix()


func set_muted(value: bool) -> void:
	muted = value
	_apply_mix()


func get_music_volume() -> float:
	return music_volume


func get_sfx_volume() -> float:
	return sfx_volume


func is_muted() -> bool:
	return muted


func _apply_mix() -> void:
	if not _initialized:
		return
	var music_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_index: int = AudioServer.get_bus_index(SFX_BUS)
	AudioServer.set_bus_volume_db(music_index, linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(sfx_index, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(music_index, muted or music_volume <= 0.0)
	AudioServer.set_bus_mute(sfx_index, muted or sfx_volume <= 0.0)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _add_sfx_limiter() -> void:
	var index: int = AudioServer.get_bus_index(SFX_BUS)
	for effect_index in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect_index) is AudioEffectLimiter:
			return
	var limiter: AudioEffectLimiter = AudioEffectLimiter.new()
	limiter.resource_name = "EmeraldWatchSFXLimiter"
	limiter.ceiling_db = -6.0
	limiter.threshold_db = -2.0
	limiter.soft_clip_db = 2.0
	AudioServer.add_bus_effect(index, limiter)


func _make_player(player_name: String, bus_name: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	player.max_polyphony = 1
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _exit_tree() -> void:
	# Explicitly detach streams on shutdown/redeployment, including paused audio.
	_initialized = false
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	for player in _combat_players + _event_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	# Playback stop commands are consumed by the audio thread on its next mix.
	# Let that cycle finish before the SceneTree tears down the audio server.
	OS.delay_msec(ceili(clampf(AudioServer.get_time_to_next_mix(), 0.0, 0.05) * 1000.0) + 30)
