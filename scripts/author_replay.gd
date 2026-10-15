class_name AuthorReplay
extends RefCounted
## Local reproducibility evidence, not a cryptographic identity/anti-cheat claim.
## A JSON boolean is never trusted: verification executes the current game rules.
const STEP := 1.0 / 60.0
const MAX_TICKS := 216000
const MAX_COMMANDS := 12000
const MAX_BYTES := 2097152
const PATH := "user://author_proof.json"
static var verified: Dictionary = {}
static var busy := false

static func level_hash(data: Dictionary) -> String:
	return JSON.stringify(LevelDesigner.canonical_data(data)).sha256_text()

static func rules_hash() -> String:
	var source := "emerald-fixed60-balance-v2:" + str(Engine.get_version_info().get("string", ""))
	for path in ["res://scripts/main.gd", "res://scripts/author_replay.gd", "res://scripts/level_designer.gd"]:
		var actual_path: String = path
		if not FileAccess.file_exists(actual_path):
			var remap := ConfigFile.new()
			if remap.load(path + ".remap") != OK: return ""
			actual_path = str(remap.get_value("remap", "path", ""))
		var digest := FileAccess.get_sha256(actual_path)
		if digest.is_empty(): return ""
		source += digest
	return source.sha256_text()

static func begin(g: Node, data: Dictionary) -> void:
	g.rng.seed = int(data.seed)
	g.elapsed = 0.0
	g.set_meta("replay_state", {"tick": 0, "accumulator": 0.0, "commands": [], "data": LevelDesigner.canonical_data(data), "rules": rules_hash(), "overflow": false})

static func record(g: Node, command: String, args: Array = []) -> void:
	if g.get_meta("replay_runner", false):
		g.set_meta("replay_accepted", int(g.get_meta("replay_accepted", 0)) + 1)
		return
	if not g.has_meta("replay_state") or g.custom_level_data.is_empty(): return
	var s: Dictionary = g.get_meta("replay_state")
	if s.commands.size() >= MAX_COMMANDS:
		s.overflow = true
		return
	s.commands.append({"tick": s.tick, "command": command, "args": args.duplicate()})

static func advance(g: Node, delta: float) -> void:
	if not g.has_meta("replay_state"): return
	var s: Dictionary = g.get_meta("replay_state")
	s.accumulator += delta
	while s.accumulator >= STEP and not g.ended and not g.paused:
		s.accumulator -= STEP
		s.tick += 1
		if s.tick > MAX_TICKS: s.overflow = true
		g.elapsed = float(s.tick) * STEP
		g.game_tick(STEP)

static func result_hash(g: Node) -> String:
	var tower_state: Array = []
	for tower in g.towers:
		tower_state.append([tower.pad, tower.kind, tower.level, tower.spent, tower.damage, tower.range, tower.cooldown])
	return JSON.stringify([g.health, g.money, g.kills, g.wave, str(g.rng.state), tower_state]).sha256_text()

static func finished(g: Node, won: bool) -> void:
	if g.get_meta("replay_runner", false):
		g.set_meta("replay_won", won)
		return
	if not won or not g.has_meta("replay_state") or g.custom_level_data.is_empty(): return
	var s: Dictionary = g.get_meta("replay_state")
	if s.overflow or s.rules != rules_hash():
		g.show_toast("通关已完成，但本次回放超出限制或规则已改变，仍为未验证", 8)
		return
	var proof := {"schema": 1, "level_hash": level_hash(s.data), "rules_hash": s.rules, "seed": int(s.data.seed), "ticks": s.tick, "result_hash": result_hash(g), "commands": s.commands.duplicate(true)}
	_verify_and_save.call_deferred(g, s.data.duplicate(true), proof)

static func read_verified(data: Dictionary) -> Dictionary:
	if not LevelDesigner.validate(data).is_empty(): return {}
	var key := level_hash(data)
	if not verified.has(key) or not FileAccess.file_exists(PATH): return {}
	var entry: Dictionary = verified[key]
	if entry.rules != rules_hash(): return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {}
	if file.get_as_text().sha256_text() != entry.file_hash: return {}
	return entry.duplicate(true)

static func verify_saved(g: Node, data: Dictionary) -> void:
	if busy:
		g.show_toast("正在核验回放，请稍候", 4)
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		g.show_toast("没有可核验的作者通关回放", 5)
		return
	var proof: Variant = JSON.parse_string(file.get_as_text())
	if not proof is Dictionary:
		g.show_toast("回放文件无效，仍为未验证", 5)
		return
	_verify_and_save(g, data, proof)

static func _integer(v: Variant) -> bool:
	return (v is int) or (v is float and is_finite(v) and v == floor(v))

static func validate_proof(data: Dictionary, proof: Dictionary) -> bool:
	if not LevelDesigner.validate(data).is_empty(): return false
	if rules_hash().is_empty(): return false
	if not proof.get("result_hash") is String or proof.result_hash.length() != 64: return false
	if proof.get("schema") != 1 or proof.get("level_hash") != level_hash(data) or proof.get("rules_hash") != rules_hash() or proof.get("seed") != data.seed: return false
	var ticks: Variant = proof.get("ticks")
	if not _integer(ticks) or ticks < 1 or ticks > MAX_TICKS: return false
	var commands: Variant = proof.get("commands")
	if not commands is Array or commands.size() > MAX_COMMANDS: return false
	var previous := 0
	for command in commands:
		if not command is Dictionary: return false
		var tick: Variant = command.get("tick")
		if not _integer(tick) or tick < previous or tick >= ticks: return false
		previous = int(tick)
		var name: Variant = command.get("command")
		if not name is String or name not in ["build", "upgrade", "sell", "wave", "ability", "gate"]: return false
		var args: Variant = command.get("args")
		if not args is Array: return false
		var required := 2 if name == "build" else (1 if name in ["upgrade", "sell"] else 0)
		if args.size() != required: return false
		for arg in args:
			if not _integer(arg): return false
		if required > 0 and (args[0] < 0 or args[0] >= data.pads.size()): return false
		if required == 2 and (args[1] < 0 or args[1] >= 6): return false
	return true

static func _execute(g: Node, command: Dictionary) -> bool:
	var before := int(g.get_meta("replay_accepted", 0))
	var args: Array = command.args
	if args.size() > 0: g.selected_pad = int(args[0])
	match command.command:
		"build":
			g.selected_kind = int(args[1])
			g.build_selected()
		"upgrade": g.upgrade_selected()
		"sell": g.sell_selected()
		"wave": g.start_wave()
		"ability": g.use_ability()
		"gate": g.toggle_gate()
	return int(g.get_meta("replay_accepted", 0)) == before + 1

static func verify(g: Node, data: Dictionary, proof: Dictionary) -> bool:
	if not validate_proof(data, proof): return false
	# Separate world/UI and RNG; no reused money, towers, enemies or win state.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	g.get_tree().root.add_child(viewport)
	var runner: Node = load("res://scripts/main.gd").new()
	runner.set_meta("replay_runner", true)
	viewport.add_child(runner)
	runner.set_process(false)
	runner.set_process_unhandled_input(false)
	runner.custom_level_data = LevelDesigner.canonical_data(data)
	runner.level_index = 0
	runner.configure_level()
	runner.build_world()
	runner.build_ui()
	runner.sound_enabled = false
	runner.show_damage_numbers = false
	runner.money = int(data.gold)
	begin(runner, data)
	var cursor := 0
	var valid := true
	for tick in range(int(proof.ticks)):
		if runner.ended:
			valid = false
			break
		while cursor < proof.commands.size() and int(proof.commands[cursor].tick) == tick:
			if not _execute(runner, proof.commands[cursor]):
				valid = false
				break
			cursor += 1
		if not valid: break
		runner.elapsed = float(tick + 1) * STEP
		runner.game_tick(STEP)
		runner.update_effects(STEP)
		if tick % 120 == 0: await g.get_tree().process_frame
	valid = valid and result_hash(runner) == proof.result_hash and proof.rules_hash == rules_hash() and cursor == proof.commands.size() and runner.ended and bool(runner.get_meta("replay_won", false)) and runner.health > 0 and runner.wave == runner.wave_total() and runner.remaining == 0 and runner.enemies.is_empty()
	viewport.queue_free()
	return valid

static func _verify_and_save(g: Node, data: Dictionary, proof: Dictionary) -> void:
	if busy: return
	busy = true
	g.show_toast("作者已通关，正在以真实战斗规则核验回放…", 10)
	var passed := await verify(g, data, proof)
	busy = false
	if not passed:
		verified.erase(level_hash(data))
		g.show_toast("回放核验失败：该关卡仍为未验证", 8)
		return
	proof["verified_at"] = Time.get_datetime_string_from_system(true) + ":" + str(Time.get_ticks_usec())
	var text := JSON.stringify(proof)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		g.show_toast("核验通过，但无法保存证明：仍为未验证", 8)
		return
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		g.show_toast("核验通过，但证明保存失败：仍为未验证", 8)
		return
	verified[level_hash(data)] = {"rules": rules_hash(), "file_hash": text.sha256_text(), "level_hash": level_hash(data), "ticks": int(proof.ticks)}
	g.show_toast("已验证：作者通关与真实规则回放均通过", 8)
	if g.has_meta("level_designer"):
		LevelDesigner._refresh_proof(g, true)
