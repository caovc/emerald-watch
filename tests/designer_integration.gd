extends SceneTree

const Designer = preload("res://scripts/level_designer.gd")
var checks := 0
var failures := 0
var game: Node

func expect(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func button_bounds(node: Node) -> bool:
	if node is BaseButton and node.is_visible_in_tree() and not Rect2(Vector2.ZERO, Vector2(1440, 900)).grow(1).encloses(node.get_global_rect()):
		print("OUTSIDE: ", node.text, " ", node.get_global_rect())
		return false
	for child in node.get_children():
		if not button_bounds(child): return false
	return true

func run() -> void:
	if FileAccess.file_exists(Designer.SAVE_PATH):
		push_error("Use a fresh disposable XDG_DATA_HOME for designer integration")
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.sound_enabled = false
	game.audio.set_muted(true)
	game.show_damage_numbers = false
	await settle()
	expect(game.levels.size() == 6, "all six builtin battlefields registered")
	game.open_designer()
	await settle()
	var refs: Dictionary = game.get_meta("level_designer")
	expect(Designer.is_open(game) and game.paused, "designer opens and pauses battle")
	expect(button_bounds(refs.overlay), "designer buttons stay inside 1440×900 viewport")
	expect(refs.grid.size.x >= 750 and refs.grid.size.y >= 450, "grid touch cells are at least 50px")
	Designer.close(game)
	expect(not game.paused, "closing designer restores unpaused state")
	game.paused = true
	Designer.open(game)
	Designer.close(game)
	expect(game.paused, "closing designer preserves preexisting pause")
	game.paused = false
	Designer.open(game)
	Designer._clear_path(game)
	expect(refs.data.route.is_empty() and refs.play.disabled, "clear path disables playtest")
	Designer._undo(game)
	expect(Designer.validate(refs.data).is_empty(), "undo restores valid route")
	Designer._set_tool(game, "pad")
	var count: int = refs.data.pads.size()
	Designer._edit_cell(game, Vector2i(-7, -4))
	expect(refs.data.pads.size() == count + 1, "pad tool places empty cell")
	Designer._edit_cell(game, Vector2i(-7, -4))
	expect(refs.data.pads.size() == count, "pad tool toggles existing pad")
	Designer._edit_cell(game, Vector2i(-7, -3))
	expect(refs.data.pads.size() == count, "pad tool refuses road cell")
	refs.fields.waves.value = 1
	refs.fields.count.value = 8
	refs.fields.gold.value = 500
	refs.name_edit.text = "本地验证测试"
	Designer._name_changed("本地验证测试", game)
	Designer._save_local(game)
	expect(FileAccess.file_exists(Designer.SAVE_PATH), "local save writes custom_level.json")
	refs.fields.gold.value = 999
	Designer._load_local(game)
	expect(refs.data.gold == 500 and refs.data.waves == 1 and refs.data.count == 8, "load restores bounded wave/count/gold")
	var loaded: Dictionary = refs.data.duplicate(true)
	var corrupt := FileAccess.open(Designer.SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string('{"verified":true}')
	corrupt.close()
	Designer._load_local(game)
	expect(refs.data == loaded, "invalid local file cannot replace editor data")
	Designer._playtest(game)
	expect(not Designer.is_open(game) and not game.paused, "playtest closes designer and resumes battle")
	expect(game.custom_level_data.name == "本地验证测试" and game.wave_total() == 1 and game.money == 500, "custom rules and economy applied")
	game.start_wave()
	expect(game.remaining == 8 and game.wave_enemy_kind(7) == 3, "custom count and final mother composition applied")
	for stage in range(3, 6):
		game.choose_level(stage)
		await settle()
		expect(game.custom_level_data.is_empty() and game.level_index == stage and game.money == game.levels[stage].gold, "builtin stage %d restores normal rules" % (stage + 1))
		expect(game.routes.size() == (4 if stage == 5 else 2), "stage %d has expected independent routes" % (stage + 1))
		var clear := true
		for pad in game.PAD_CELLS:
			if game.road_tiles.has(Vector2i(pad.x * 15, pad.y * 15)): clear = false
		expect(clear and game.pads.size() == 16, "stage %d all sixteen pads clear roads" % (stage + 1))
		var indices: Array = []
		for spawn in range(game.routes.size()):
			game.spawned = spawn
			game.gate_mode = spawn if game.can_switch_gate() else 0
			indices.append(game.spawn_enemy(0).route_index)
		expect(indices == ([0, 1, 2, 3] if stage == 5 else [0, 1]), "stage %d uses every entrance" % (stage + 1))
		var enemy: Dictionary = game.enemies[0]
		enemy.node.position = game.hazard_data.center
		var hp: float = enemy.hp
		game.hazard_time = 0
		game.update_hazard(0.1)
		expect(enemy.slow > 0 if stage == 4 else enemy.hp < hp, "stage %d hazard applies real combat effect" % (stage + 1))
		game.hazard_time = float(game.hazard_data.active) + 1.0
		expect(not game.hazard_is_active(), "stage %d hazard enters inactive cycle" % (stage + 1))
	game.queue_free()
	await settle()
	print("DESIGNER + EXTRA LEVELS: %d checks / %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
