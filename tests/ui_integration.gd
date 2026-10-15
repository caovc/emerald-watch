extends SceneTree
## Actual-scene input, state, content, and logical-layout checks (not visual QA).
## Run with an empty disposable XDG_DATA_HOME; this test changes saved settings.

const Settings = preload("res://scripts/game_settings.gd")
const Codex = preload("res://scripts/game_codex.gd")
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)

func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.button_index = button
	event.pressed = true
	game._unhandled_input(event)

func text_in(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += node.text + "\n"
	for child in node.get_children():
		result += text_in(child)
	return result

func visible_buttons(node: Node) -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	if node is BaseButton and node.is_visible_in_tree():
		var clipped := false
		var ancestor := node.get_parent()
		while ancestor:
			if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().intersects(node.get_global_rect()):
				clipped = true
			ancestor = ancestor.get_parent()
		if not clipped: result.append(node)
	for child in node.get_children():
		result.append_array(visible_buttons(child))
	return result

func inside(rect: Rect2, bounds: Rect2, tolerance: float = 1.0) -> bool:
	return bounds.grow(tolerance).encloses(rect)

func check_buttons(node: Node, scope: String) -> void:
	var outside: Array[String] = []
	var zero_size: Array[String] = []
	var logical: Rect2 = root.get_visible_rect()
	for button in visible_buttons(node):
		if not inside(button.get_global_rect(), logical):
			outside.append("%s %s" % [button.text.replace("\n", "/"), str(button.get_global_rect())])
		if button.size.x < 12 or button.size.y < 12:
			zero_size.append(button.text)
	expect(outside.is_empty(), scope + " visible buttons remain within logical viewport: " + str(outside))
	expect(zero_size.is_empty(), scope + " visible buttons have usable nonzero hit boxes")

func run() -> void:
	if FileAccess.file_exists(Settings.SAVE_PATH):
		push_error("Use an empty disposable XDG_DATA_HOME; refusing to overwrite player settings")
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await settle()
	await test_codex()
	await test_context_and_selection()
	await test_settings()
	await test_layouts()
	print("UI INTEGRATION SUMMARY: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await settle()
	game = null
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.SAVE_PATH))
	quit(1 if failures else 0)

func test_codex() -> void:
	expect(not Codex.is_open(game), "codex starts closed")
	game.start_wave()
	game.show_codex()
	expect(Codex.is_open(game) and game.paused, "codex opens and pauses a running wave")
	var refs: Dictionary = game.get_meta("game_codex")
	var child_count: int = game.hud.get_child_count()
	game.show_codex()
	Codex.close(game)
	expect(not game.paused and not Codex.is_open(game), "repeated codex open preserves the original running state")
	game.paused = true
	game.show_codex()
	Codex.close(game)
	expect(game.paused, "codex restores an already paused game")
	game.paused = false
	game.show_codex()
	expect(game.hud.get_child_count() == child_count, "reopening codex reuses the existing overlay")
	key(KEY_ESCAPE)
	expect(not Codex.is_open(game) and not game.paused, "Escape closes codex and restores running state")
	game.restart()
	for kind in range(6):
		game.select_kind(kind)
		game.show_codex()
		var d: Dictionary = game.TOWER_DATA[kind]
		var text := text_in(refs.detail)
		expect(refs.tab == 0 and refs.index == kind and refs.list.get_child_count() == 6, "codex selects tower %d and lists all six tower types" % kind)
		expect(d.name in text and d.desc in text and ("%d 金" % d.cost) in text and ("%.1f" % d.damage) in text and ("%.2f" % (d.range + game.UPGRADE_RANGE[0] + game.UPGRADE_RANGE[1])) in text and ("%.2f 秒" % (d.cooldown / 1.24)) in text, "tower %d codex contains live cost, damage, range, and upgraded cooldown" % kind)
		Codex.close(game)
	for stage in range(3):
		game.choose_level(stage)
		game.wave = 6
		for kind in range(7):
			var enemy: Dictionary = game.spawn_enemy(kind)
			var stats: Dictionary = game.enemy_stats(kind, 6)
			expect(is_equal_approx(enemy.max_hp, stats.hp) and is_equal_approx(enemy.speed, stats.speed) and is_equal_approx(enemy.shield, stats.shield), "level %d enemy %d codex stats match actual spawned enemy" % [stage + 1, kind])
			game.selected_enemy = enemy
			game.show_codex()
			var text := text_in(refs.detail)
			expect(refs.tab == 1 and refs.index == kind and refs.list.get_child_count() == 7 and stats.name in text and stats.ability in text and stats.counter in text and ("%.0f" % stats.hp) in text, "level %d enemy %d codex shows correct live-wave identity and counters" % [stage + 1, kind])
			Codex.close(game)
	game.choose_level(0)
	game.show_codex()
	game.restart()
	expect(not Codex.is_open(game) and not game.paused, "restart dismisses codex and restores deployment input")
	# Close explicitly so subsequent checks can continue even if this regression fails.
	Codex.close(game)
	game.restart()
	await settle()

func test_context_and_selection() -> void:
	game.choose_level(0)
	var refs: Dictionary = game.get_meta("game_ui")
	expect(not refs.context.visible, "context panel is hidden with no selection")
	game.select_kind(4)
	game.select_pad(2)
	await settle()
	expect(refs.context.visible and game.build_button.visible and not game.upgrade_button.visible and not game.sell_button.visible, "empty-pad context exposes build and hides upgrade/sell")
	expect("150" in game.build_button.text and "100" in game.info_label.text, "empty-pad context displays selected tower's real price and damage")
	game.build_selected()
	await settle()
	expect(refs.context.visible and not game.build_button.visible and game.upgrade_button.visible and game.sell_button.visible, "occupied-pad context exposes upgrade and sell")
	expect("100" in game.info_label.text and "165" in game.info_label.text, "occupied-pad context shows current and next-level damage")
	click(Vector2.ZERO, MOUSE_BUTTON_RIGHT)
	expect(game.selected_pad == -1 and not refs.context.visible, "right click clears selection and context")
	var screen: Vector2 = game.camera.unproject_position(game.pads[3].global_position + Vector3(0, 0.14, 0))
	expect(game.pad_from_screen(screen) == 3, "screen-to-pad helper resolves the actual selected build pad")
	click(screen)
	expect(game.selected_pad == 3, "actual mouse event selects a build pad")
	expect(game.pad_from_screen(Vector2(-1000, -1000)) == -1, "out-of-board click helper returns no pad")
	click(Vector2(-1000, -1000))
	expect(game.selected_pad == -1 and "只能" in game.toast_label.text and not refs.context.visible, "invalid click clears selection and explains valid placement")
	game.wave = 4
	var enemy: Dictionary = game.spawn_enemy(4)
	enemy.node.position = Vector3(0, 0.35, 0)
	enemy.hp = 33.0
	enemy.shield = 17.0
	enemy.slow = 1.5
	enemy.burn = 2.0
	screen = game.camera.unproject_position(enemy.node.position + Vector3(0, 0.3, 0))
	click(screen)
	expect(game.selected_enemy == enemy and game.selected_pad == -1 and refs.context.visible, "actual enemy click opens its live context")
	expect("33" in game.info_label.text and "17" in game.info_label.text and "1.5" in game.info_label.text and "2.0" in game.info_label.text, "enemy context shows current HP, shield, slow, and burn")
	expect(not game.build_button.visible and not game.upgrade_button.visible and not game.sell_button.visible, "enemy context hides tower mutation buttons")
	game.damage_enemy(enemy, 100.0, 4)
	game.game_tick(0.01)
	game.refresh_ui()
	expect(game.selected_enemy.is_empty() and not refs.context.visible, "enemy death clears selected enemy and context")
	var next_enemy: Dictionary = game.spawn_enemy(0)
	game.selected_enemy = next_enemy
	game.restart()
	expect(game.selected_enemy.is_empty() and game.selected_pad == -1 and not refs.context.visible, "restart clears both enemy and tower selections")
	await settle()

func test_settings() -> void:
	game.restart()
	game.open_settings()
	var refs: Dictionary = game.get_meta("settings_ui")
	expect(Settings.is_open(game) and game.paused, "settings opens and pauses the actual game")
	game.open_settings()
	Settings.close(game)
	expect(not Settings.is_open(game) and not game.paused, "repeated settings open preserves running-state restoration")
	game.paused = true
	game.open_settings()
	Settings.close(game)
	expect(game.paused, "settings restores previously paused state")
	game.paused = false
	game.open_settings()
	refs.muted.button_pressed = true
	expect(game.get_meta("settings_values").muted and game.audio.is_muted(), "settings mute updates saved preference and actual audio")
	game.restart()
	expect(not Settings.is_open(game) and not game.paused and game.audio.is_muted() and game.get_meta("settings_values").muted, "restart closes settings while preserving mute")
	game.open_settings()
	expect(refs.muted.button_pressed, "reopened settings show the persisted mute value")
	key(KEY_ESCAPE)
	expect(not Settings.is_open(game) and not game.paused, "Escape closes settings and restores prior running state")
	key(KEY_M)
	expect(not game.get_meta("settings_values").muted and not game.audio.is_muted() and game.sound_enabled, "M unmutes both saved preference and actual audio")
	game.open_settings()
	expect(not refs.muted.button_pressed, "settings checkbox stays synchronized with M shortcut")
	Settings.close(game)
	var cfg := ConfigFile.new()
	expect(cfg.load(Settings.SAVE_PATH) == OK and not cfg.get_value("game", "muted", true), "M shortcut persists the new mute preference")
	Settings._changed(game, "muted", true)
	game.choose_level(1)
	expect(game.audio.is_muted() and game.get_meta("settings_values").muted, "changing map keeps saved mute applied to actual audio")
	game.choose_level(0)
	await settle()

func test_layouts() -> void:
	for physical in [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(960, 600)]:
		root.size = physical
		await settle()
		var logical: Rect2 = root.get_visible_rect()
		print("LAYOUT viewport=%s logical=%s content_scale=%s mode=%s" % [str(physical), str(logical), str(root.content_scale_size), str(root.content_scale_mode)])
		expect(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and logical.size.x >= 1440 and logical.size.y >= 900, "%s uses project logical canvas scaling" % str(physical))
		game.restart()
		await settle()
		check_buttons(game.get_meta("game_ui").root, "%s HUD" % str(physical))
		for pad in range(game.pads.size()):
			game.select_pad(pad)
			await settle()
			expect(inside(game.get_meta("game_ui").context.get_global_rect(), logical), "%s pad %d context remains inside viewport" % [str(physical), pad])
		game.select_pad(-1)
		game.show_codex()
		await settle()
		var codex: Dictionary = game.get_meta("game_codex")
		expect(inside(codex.overlay.get_global_rect(), logical), "%s codex blocker fits logical viewport" % str(physical))
		check_buttons(codex.overlay, "%s codex" % str(physical))
		var card: Control = codex.overlay.get_child(1).get_child(0)
		expect(inside(card.get_global_rect(), logical), "%s codex card fits logical viewport: %s" % [str(physical), str(card.get_global_rect())])
		Codex._set_tab(game, 1)
		Codex._select(game, 6)
		await settle()
		check_buttons(codex.overlay, "%s enemy codex" % str(physical))
		Codex.close(game)
		game.open_settings()
		await settle()
		var settings: Dictionary = game.get_meta("settings_ui")
		expect(inside(settings.overlay.get_global_rect(), logical), "%s settings blocker fits logical viewport" % str(physical))
		card = settings.overlay.get_child(0).get_child(0)
		expect(inside(card.get_global_rect(), logical), "%s settings card fits logical viewport: %s" % [str(physical), str(card.get_global_rect())])
		check_buttons(settings.overlay, "%s settings" % str(physical))
		Settings.close(game)
		game.show_level_select()
		await settle()
		check_buttons(game.level_overlay, "%s level chooser" % str(physical))
		key(KEY_ESCAPE)
		expect(not game.level_overlay.visible and not game.paused, "%s Escape closes level chooser and restores gameplay" % str(physical))
		game.finish(true)
		await settle()
		check_buttons(game.end_panel, "%s result overlay" % str(physical))
		game.restart()
	root.size = Vector2i(1440, 900)
