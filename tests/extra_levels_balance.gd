extends SceneTree
## Actual-combat checks for the three additional built-in maps. No economy cheats.
var game: Node
var checks := 0
var failures := 0
var report: Array[Dictionary] = []
func _initialize() -> void:
	run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print(("PASS " if ok else "FAIL ") + message)
func build(pad: int, kind: int) -> void:
	game.select_pad(pad)
	game.select_kind(kind)
	game.build_selected()
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.sound_enabled = false
	game.show_damage_numbers = false
	if is_instance_valid(game.audio): game.audio.set_muted(true)
	expect(game.levels.size() == 6, "all six built-in stages available")
	for stage in range(3,6):
		await simulate(stage, true)
		await simulate(stage, false)
	var output := FileAccess.open("res://tests/extra-level-balance-results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":report}, "  "))
	output.close()
	print("EXTRA LEVEL BALANCE: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
func simulate(stage: int, defended: bool) -> void:
	game.choose_level(stage)
	var placements: Array = [
		[[7,0],[9,1],[8,2],[4,3],[10,4],[6,5],[11,4],[13,1],[3,3],[14,5]],
		[[10,0],[9,1],[8,2],[7,4],[11,3],[5,5],[14,4],[13,1],[4,3],[15,5]],
		[[9,0],[10,1],[8,2],[11,4],[7,3],[6,5],[14,4],[15,1],[2,3],[10,5]]
	][stage-3]
	var next_build := 0
	var wave_results: Array[Dictionary] = []
	var ability_uses := 0
	var gate_uses := 0
	for wave_index in range(game.wave_total()):
		if defended:
			while next_build < 6 and game.money >= game.TOWER_DATA[placements[next_build][1]].cost:
				build(placements[next_build][0],placements[next_build][1])
				next_build += 1
			if next_build >= 6:
				for desired in [2,3]:
					for tower in game.towers:
						if tower.level < desired and game.money >= game.upgrade_cost(tower):
							game.select_pad(tower.pad)
							game.upgrade_selected()
				var all_maxed := true
				for tower in game.towers:
					if tower.level < 3: all_maxed = false
				if all_maxed:
					while next_build < placements.size() and game.money >= game.TOWER_DATA[placements[next_build][1]].cost:
						if game.tower_at(placements[next_build][0]) < 0:
							build(placements[next_build][0],placements[next_build][1])
						next_build += 1
			if game.can_switch_gate() and wave_index % 2 == 1 and game.gate_cooldown <= 0:
				game.toggle_gate()
				gate_uses += 1
		game.start_wave()
		var duration := 0.0
		var tick := 0
		while game.active_wave and not game.ended and duration < 240.0:
			game.game_tick(0.05)
			game.update_effects(0.05)
			game.update_damage_labels(0.05)
			if defended:
				var boss := false
				for enemy in game.enemies:
					if enemy.kind == 3: boss = true
				if game.ability_cooldown <= 0 and (game.enemies.size() >= 8 or boss):
					game.use_ability()
					ability_uses += 1
			duration += 0.05
			tick += 1
			if tick % 160 == 0: await process_frame
		expect(not game.active_wave or game.ended, "stage %d wave %d resolves (%s)" % [stage+1,game.wave,"defended" if defended else "undefended"])
		wave_results.append({"wave":game.wave,"health":game.health,"gold":game.money,"towers":game.towers.size(),"kills":game.kills,"seconds":snappedf(duration,0.05)})
		print("WAVE ",stage+1," defended=",defended," ",wave_results[-1])
		await process_frame
		if game.ended: break
	var won: bool = game.ended and game.health > 0 and game.wave == game.wave_total()
	expect(won if defended else game.ended and game.health <= 0, "stage %d %s" % [stage+1,"normal-economy mixed defense wins" if defended else "undefended game loses"])
	report.append({"stage":stage+1,"name":game.current_level().name,"defended":defended,"won":won,"health":game.health,"q_uses":ability_uses,"gate_uses":gate_uses,"placements":placements if defended else [],"waves":wave_results})
	print("STAGE RESULT ",stage+1," defended=",defended," won=",won," health=",game.health)
