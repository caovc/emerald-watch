extends SceneTree
const Audio = preload("res://scripts/game_audio.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var audio = Audio.new()
	audio.set_music_volume(.37)
	audio.set_sfx_volume(.61)
	root.add_child(audio)
	await process_frame
	check(audio._initialized, "GameAudio initializes")
	check(AudioServer.get_bus_index(&"Music") >= 0, "Music bus exists")
	check(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus exists")
	check(audio._music_player.playing, "Soundtrack autostarts")
	check(audio._music_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music loops")
	check(audio._music_player.stream.loop_end == 940800, "Music exact frame count")
	check(audio._music_player.stream.mix_rate == 22050, "Music sample rate")
	check(audio._music_player.stream.stereo, "Music stereo")
	check(is_equal_approx(audio.get_music_volume(), .37), "Pre-ready music volume retained")
	check(is_equal_approx(audio.get_sfx_volume(), .61), "Pre-ready SFX volume retained")
	check(audio._combat_players.size() == 6 and audio._event_players.size() == 3, "Fixed voice pools")
	check(Audio.SOUNDS.size() == 14, "Fourteen distinct effects")
	for key in Audio.SOUNDS:
		var effect: AudioStreamWAV = Audio.SOUNDS[key]
		check(effect.data.size() > 100, "Loaded effect " + key)
		check(effect.get_length() > .05 and effect.get_length() < 2, "Finite effect " + key)
		audio._last_combat_ms = -100000
		audio.play_sfx(key)
		check(audio._last_play_ms.has(key), "Effect dispatched " + key)
		for voice in audio._combat_players + audio._event_players:
			voice.stop()
	audio._last_play_ms.clear()
	audio._last_combat_ms = -100000
	for i in 100:
		audio.play_sfx("shot")
	var active: int = 0
	for voice in audio._combat_players:
		if voice.playing:
			active += 1
	check(active == 1, "Hundred-shot burst is rate limited")
	audio.set_music_volume(2)
	audio.set_sfx_volume(-1)
	check(audio.get_music_volume() == 1 and audio.get_sfx_volume() == 0, "Volume values clamp")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Zero SFX volume is muted")
	audio.set_sfx_volume(.61)
	audio.set_muted(true)
	check(audio.is_muted(), "Mute flag")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Music bus mutes")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "SFX bus mutes")
	audio.set_muted(false)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Music restores")
	check(is_equal_approx(audio.get_sfx_volume(), .61), "Mute preserves volume")
	audio.set_music_volume(NAN)
	check(audio.get_music_volume() == 0, "Non-finite volume is safe")
	audio.play_sfx("unknown")
	paused = true
	await create_timer(.08, true).timeout
	check(audio._music_player.playing, "Music survives pause")
	paused = false
	audio.set_music_volume(1.0)
	audio._music_player.seek(42.60)
	await create_timer(.20).timeout
	check(audio._music_player.get_playback_position() < .4, "Playback crosses exact loop seam")
	var bus_count: int = AudioServer.bus_count
	var effect_count: int = AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"SFX"))
	audio.queue_free()
	await process_frame
	var second = Audio.new()
	root.add_child(second)
	await process_frame
	check(AudioServer.bus_count == bus_count, "Reinstantiation does not duplicate buses")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"SFX")) == effect_count, "No duplicate limiter")
	# Capture actual mixed PCM in Godot's headless audio driver: nine simultaneous
	# explosions at maximum sliders stress the limiter beyond normal dispatch.
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	var capture_slot: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	second.set_music_volume(1.0)
	second.set_sfx_volume(1.0)
	await create_timer(1.3).timeout
	capture.clear_buffer()
	for voice in second._combat_players + second._event_players:
		voice.stream = Audio.SOUNDS["boom"]
		voice.volume_db = -8.0
		voice.play()
	await create_timer(.7).timeout
	var frames: int = capture.get_frames_available()
	var samples: PackedVector2Array = capture.get_buffer(frames)
	var peak: float = 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(frames > 0 and peak > .001 and peak < 1.0, "Stress mix is non-silent and unclipped")
	print("MIX_CAPTURE frames=", frames, " peak=", peak)
	AudioServer.remove_bus_effect(0, capture_slot)
	second.queue_free()
	await create_timer(.12).timeout
	print("AUDIO_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
