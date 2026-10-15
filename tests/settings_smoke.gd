extends SceneTree
## Isolated checks; run with a disposable XDG_DATA_HOME to protect player settings.
const Settings = preload("res://scripts/game_settings.gd")

class StubAudio extends RefCounted:
	var music := -1.0
	var sfx := -1.0
	var muted := false
	func set_music_volume(value: float) -> void: music = value
	func set_sfx_volume(value: float) -> void: sfx = value
	func set_muted(value: bool) -> void: muted = value

class StubGame extends Node3D:
	var camera: Camera3D
	var hud: CanvasLayer
	var ui_font: Font
	var paused := false
	var ended := false
	var audio := StubAudio.new()
	var range_ring: MeshInstance3D
	var show_ranges := true
	var show_damage_numbers := true
	var refreshes := 0
	var toast := ""
	func _init() -> void:
		if ResourceLoader.exists("res://assets/ui-font.otf"):
			ui_font = load("res://assets/ui-font.otf")
		camera = Camera3D.new()
		add_child(camera)
		hud = CanvasLayer.new()
		add_child(hud)
		range_ring = MeshInstance3D.new()
		add_child(range_ring)
		add_child(DirectionalLight3D.new())
	func label(value: String, font_size: int, color: Color) -> Label:
		var result := Label.new()
		result.text = value
		result.add_theme_font_size_override("font_size", font_size)
		result.add_theme_color_override("font_color", color)
		return result
	func button(value: String, callback: Callable, _accent: bool = false) -> Button:
		var result := Button.new()
		result.text = value
		result.pressed.connect(callback)
		return result
	func refresh_ui() -> void: refreshes += 1
	func show_toast(value: String) -> void: toast = value
	func update_range() -> void: range_ring.visible = show_ranges

var count := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	count += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	var file := ProjectSettings.globalize_path(Settings.SAVE_PATH)
	if FileAccess.file_exists(file):
		push_error("Use a disposable, empty XDG_DATA_HOME; refusing to overwrite existing settings.")
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	var game := StubGame.new()
	root.add_child(game)
	Settings.build(game)
	await process_frame
	var refs: Dictionary = game.get_meta("settings_ui")
	expect(not Settings.is_open(game), "settings start closed")
	expect(game.get_meta("settings_values") == Settings.DEFAULTS, "missing file uses all defaults")
	expect(is_equal_approx(game.audio.music, 0.55) and is_equal_approx(game.audio.sfx, 0.75), "default audio levels applied")
	expect(is_equal_approx(game.camera.size, 22.8) and Engine.max_fps == 60, "camera and FPS defaults applied")
	expect(root.msaa_3d == Viewport.MSAA_4X and game.find_children("*", "DirectionalLight3D", true, false)[0].shadow_enabled, "high quality enables MSAA and shadows")
	Settings.open(game)
	await process_frame
	expect(Settings.is_open(game) and game.paused, "opening displays modal and pauses game")
	expect(refs.overlay.size == Vector2(1440, 900) and refs.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "modal covers viewport and absorbs clicks")
	var card: Control = refs.overlay.get_child(0).get_child(0)
	expect(card.size.x <= 740 and card.size.y < 800, "settings card fits 1440 by 900 display")
	print("Settings card size: ", card.size)
	Settings.open(game)
	Settings.close(game)
	expect(not game.paused and not Settings.is_open(game), "repeated open preserves original unpaused state")
	game.paused = true
	Settings.close(game)
	expect(game.paused, "close on an already closed menu leaves pause unchanged")
	Settings.open(game)
	Settings.close(game)
	expect(game.paused, "opening while paused restores paused state")
	game.paused = false
	Settings.open(game)
	refs.music_volume.value = 0.2
	refs.sfx_volume.value = 0.4
	refs.muted.button_pressed = true
	refs.camera_zoom.value = 26.4
	refs.show_ranges.button_pressed = false
	refs.show_damage_numbers.button_pressed = false
	refs.quality.item_selected.emit(1)
	refs.fps_cap.item_selected.emit(2)
	expect(is_equal_approx(game.audio.music, 0.2) and is_equal_approx(game.audio.sfx, 0.4) and game.audio.muted, "audio controls apply immediately")
	expect(is_equal_approx(game.camera.size, 26.4), "zoom slider changes actual orthographic camera")
	expect(not game.show_ranges and not game.range_ring.visible and not game.show_damage_numbers, "visibility controls affect actual owner state")
	expect(root.msaa_3d == Viewport.MSAA_DISABLED and not game.find_children("*", "DirectionalLight3D", true, false)[0].shadow_enabled, "low quality disables MSAA and shadows")
	expect(Engine.max_fps == 120, "FPS selection updates Engine.max_fps")
	refs.fps_cap.item_selected.emit(3)
	expect(Engine.max_fps == 0, "unlimited FPS sets Engine.max_fps to zero")
	refs.fullscreen.button_pressed = true
	expect(game.get_meta("settings_values").fullscreen, "fullscreen preference can be changed headlessly without native display calls")
	var config := ConfigFile.new()
	expect(config.load(Settings.SAVE_PATH) == OK and is_equal_approx(config.get_value("game", "music_volume"), 0.2), "changes are persisted to settings.cfg")
	Settings.close(game)
	var game2 := StubGame.new()
	root.add_child(game2)
	Settings.build(game2)
	expect(game2.audio.muted and is_equal_approx(game2.camera.size, 26.4) and not game2.show_ranges, "new game owner reloads persisted preferences")
	var extra_light := DirectionalLight3D.new()
	extra_light.shadow_enabled = true
	game2.add_child(extra_light)
	game2.camera.size = 22.8
	Settings.apply(game2)
	expect(not extra_light.shadow_enabled and is_equal_approx(game2.camera.size, 26.4), "apply restores settings to rebuilt camera and new directional lights")
	var child_count := game2.hud.get_child_count()
	Settings.build(game2)
	expect(game2.hud.get_child_count() == child_count, "repeated build does not duplicate modal")
	Settings.reset_defaults(game2)
	expect(game2.get_meta("settings_values") == Settings.DEFAULTS and not game2.audio.muted, "reset restores all default values and applies them")
	config.load(Settings.SAVE_PATH)
	expect(config.get_value("game", "fps_cap") == 60 and config.get_value("game", "quality") == "high", "reset defaults is persistent")
	var sanitized := Settings._sanitize({"music_volume": -5.0, "sfx_volume": 10.0, "camera_zoom": NAN, "muted": "bad", "quality": "bad", "fps_cap": -9})
	expect(sanitized.music_volume == 0.0 and sanitized.sfx_volume == 1.0 and sanitized.camera_zoom == 22.8 and not sanitized.muted and sanitized.quality == "high" and sanitized.fps_cap == 60, "invalid settings are clamped or replaced with safe defaults")
	game.free()
	game2.free()
	DirAccess.remove_absolute(file)
	Engine.max_fps = 0
	print("SETTINGS SUMMARY: %d checks, %d failures" % [count, failures])
	quit(1 if failures else 0)
