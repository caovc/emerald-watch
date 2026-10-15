extends SceneTree
## Headless integration tests. Run with:
## godot --headless --path . --script res://tests/integration.gd

var game: Node
var checks := 0
var failures := 0
var balance_reports: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func build(pad: int, kind: int) -> void:
	game.select_pad(pad)
	game.select_kind(kind)
	game.build_selected()

func clear_enemies() -> void:
	for e in game.enemies:
		e.node.queue_free()
	game.enemies.clear()

func place_enemy(e: Dictionary, segment: int, progress: float) -> void:
	e.segment = segment
	e.progress = progress
	e.node.position = e.route[segment].move_toward(e.route[segment + 1], progress)

func run() -> void:
	var scene = load("res://main.tscn")
	if scene == null or not scene.can_instantiate():
		push_error("Main scene could not load")
		quit(1)
		return
	game = scene.instantiate()
	scene = null
	root.add_child(game)
	game.set_process(false)
	game.show_ranges = true
	game.show_damage_numbers = false
	game.sound_enabled = false
	if is_instance_valid(game.audio): game.audio.set_muted(true)
	expect(game.pads.size() == 16 and game.towers.is_empty(), "actual scene initializes 16 empty build pads")
	expect(game.money == 360 and game.health == 20 and game.wave == 0, "initial economy, health, and wave")
	expect(not game.end_panel.visible and not game.range_ring.visible, "initial overlays are hidden")
	await test_economy()
	await test_combat()
	await test_flow()
	await test_controls()
	await test_new_combat()
	await test_maps_and_routes()
	await test_ability()
	for stage in range(game.levels.size()):
		await simulate_mixed_six_strategy(stage)
		await simulate_stage_undefended(stage)
	print("\n=== BALANCE REPORT ===")
	for report in balance_reports:
		print(report)
	print("\nINTEGRATION SUMMARY: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	game = null
	await process_frame
	# Audio playback teardown reaches the mixer asynchronously.
	await create_timer(0.15).timeout
	quit(1 if failures else 0)

func test_economy() -> void:
	game.restart()
	game.build_selected()
	expect(game.towers.is_empty() and game.money == 360, "cannot build without selecting a pad")
	build(2, 0)
	expect(game.towers.size() == 1 and game.money == 280, "building a pulse tower deducts 80 gold")
	expect(game.tower_at(2) == 0 and game.range_ring.visible, "built tower is registered at selected pad")
	game.build_selected()
	expect(game.towers.size() == 1 and game.money == 280, "cannot build duplicate towers on one pad")
	game.money = 79
	build(3, 0)
	expect(game.towers.size() == 1 and game.money == 79, "insufficient build money leaves state unchanged")
	game.select_pad(2)
	game.money = 67
	game.upgrade_selected()
	expect(game.towers[0].level == 1 and game.money == 67, "insufficient upgrade money leaves state unchanged")
	game.money = 1000
	game.upgrade_selected()
	expect(game.towers[0].level == 2 and game.money == 932, "level 2 upgrade costs 68 gold")
	expect(is_equal_approx(game.towers[0].damage, 39.6) and is_equal_approx(game.towers[0].range, 5.05), "upgrade increases damage and range")
	game.upgrade_selected()
	expect(game.towers[0].level == 3 and game.money == 832 and game.towers[0].spent == 248, "level 3 upgrade costs 100 gold and tracks investment")
	game.upgrade_selected()
	expect(game.towers[0].level == 3 and game.money == 832, "level 3 is the upgrade cap")
	expect(game.upgrade_button.disabled, "max-level upgrade button is disabled")
	game.sell_selected()
	expect(game.towers.is_empty() and game.money == 1005, "selling refunds floor(70 percent of total investment), 173 gold")
	game.sell_selected()
	expect(game.money == 1005, "selling an empty pad does not create money")
	await process_frame

func test_combat() -> void:
	game.restart()
	game.wave = 1
	build(2, 2)
	var frost: Dictionary = game.towers[0]
	var victim: Dictionary = game.spawn_enemy(0)
	place_enemy(victim, 0, 9.0)
	game.fire(frost, victim)
	expect(is_equal_approx(victim.hp, 40.0), "frost applies its 10 direct damage")
	expect(is_equal_approx(victim.slow, 2.35), "frost applies a 2.35-second level-1 slow")
	frost.cooldown = 1000.0
	var before: float = victim.progress
	game.game_tick(0.1)
	expect(is_equal_approx(victim.progress - before, 1.65 * 0.5 * 0.1), "frost halves actual enemy movement speed")
	victim.slow = 0.01
	before = victim.progress
	game.game_tick(0.1)
	expect(is_equal_approx(victim.progress - before, 1.65 * 0.1), "enemy resumes full movement after slow expires")
	game.restart()
	game.wave = 3
	build(2, 1)
	var cannon: Dictionary = game.towers[0]
	var target: Dictionary = game.spawn_enemy(2)
	var nearby: Dictionary = game.spawn_enemy(2)
	var distant: Dictionary = game.spawn_enemy(2)
	place_enemy(target, 0, 9.0)
	place_enemy(nearby, 0, 10.0)
	place_enemy(distant, 0, 11.0)
	var hp: float = target.hp
	game.fire(cannon, target)
	expect(is_equal_approx(target.hp, hp - 38.0 * 0.45) and is_equal_approx(nearby.hp, hp - 38.0 * 0.45), "ember splash damages both armored enemies with armor mitigation")
	expect(distant.hp == hp, "ember splash does not damage an enemy outside 1.6 units")
	game.restart()
	game.wave = 1
	build(2, 0)
	var rear: Dictionary = game.spawn_enemy(0)
	var front: Dictionary = game.spawn_enemy(0)
	place_enemy(rear, 0, 8.0)
	place_enemy(front, 0, 9.0)
	game.game_tick(0.01)
	expect(front.hp == 26.0 and rear.hp == 50.0, "tower selects the furthest-progressed in-range enemy")
	game.towers[0].cooldown = 1000.0
	var gold_before: int = game.money
	game.damage_enemy(front, 100.0)
	game.game_tick(0.01)
	expect(game.kills == 1 and game.money == gold_before + 10 and game.enemies.size() == 1, "defeated enemy gives exactly one kill and its gold reward")
	game.game_tick(0.01)
	expect(game.money == gold_before + 10 and game.kills == 1, "dead enemies cannot pay rewards twice")
	await process_frame

func test_flow() -> void:
	game.restart()
	game.wave = 1
	var leaking: Dictionary = game.spawn_enemy(0)
	place_enemy(leaking, game.ROUTE.size() - 2, 16.499)
	game.game_tick(0.01)
	expect(game.health == 19 and game.enemies.is_empty(), "ordinary enemy leak removes one core health")
	expect(game.money == 360 and game.kills == 0, "leaks give neither reward nor kills")
	var boss: Dictionary = game.spawn_enemy(3)
	place_enemy(boss, game.ROUTE.size() - 2, 16.499)
	game.game_tick(0.01)
	expect(game.health == 14, "boss leak removes five core health")
	game.restart()
	game.start_wave()
	expect(game.wave == 1 and game.remaining == 11 and game.active_wave, "wave 1 starts with 11 queued enemies")
	game.start_wave()
	expect(game.wave == 1, "cannot start another wave while active")
	game.game_tick(0.01)
	expect(game.enemies.size() == 1 and game.remaining == 10 and game.spawned == 1, "game_tick spawns and tracks queued enemies")
	clear_enemies()
	game.remaining = 0
	game.game_tick(0.01)
	expect(not game.active_wave and game.money == 403 and not game.ended, "completed nonfinal wave awards 43 gold and returns to deployment")
	game.game_tick(0.01)
	expect(game.money == 403, "wave bonus is only awarded once")
	game.start_wave()
	expect(game.wave == 2 and game.remaining == 14, "next wave advances and increases enemy count")
	game.restart()
	game.wave = 8
	game.spawned = 31
	var final_boss: Dictionary = game.spawn_enemy()
	var expected_boss_hp := 1876.0 * (1.0 + 0.12 * pow(6.0, 1.4))
	expect(final_boss.kind == 3 and is_equal_approx(final_boss.max_hp, expected_boss_hp), "last enemy of wave 8 is the boss with late-wave HP scaling")
	clear_enemies()
	game.active_wave = true
	game.remaining = 0
	game.game_tick(0.01)
	expect(game.ended and not game.active_wave and game.end_panel.visible, "clearing wave 8 ends the game and shows result overlay")
	expect("胜利" in game.end_title.text, "successful final wave shows victory")
	var tower_count: int = game.towers.size()
	build(0, 0)
	game.start_wave()
	expect(game.towers.size() == tower_count and game.wave == 8, "no construction or extra waves after game ends")
	game.restart()
	game.health = 1
	game.wave = 2
	var fatal: Dictionary = game.spawn_enemy(0)
	place_enemy(fatal, game.ROUTE.size() - 2, 16.499)
	game.game_tick(0.01)
	expect(game.health == 0 and game.ended and "失守" in game.end_title.text, "fatal leak clamps health and displays defeat")
	game.restart()
	expect(game.money == 360 and game.health == 20 and game.wave == 0 and game.kills == 0, "restart restores initial game counters")
	expect(not game.ended and not game.active_wave and game.enemies.is_empty() and game.towers.is_empty() and game.effects.is_empty(), "restart clears game entities and end state")
	expect(not game.end_panel.visible and not game.range_ring.visible and game.selected_pad == -1, "restart resets overlay and selection")
	await process_frame

func test_controls() -> void:
	game.restart()
	game.toggle_pause()
	game.start_wave()
	expect(game.paused and game.wave == 0 and game.next_button.disabled, "pause prevents starting waves and disables the start button")
	game.toggle_pause()
	game.wave = 1
	var e: Dictionary = game.spawn_enemy(0)
	var before: float = e.progress
	game._process(0.05)
	var normal_distance: float = e.progress - before
	game.toggle_speed()
	before = e.progress
	game._process(0.05)
	expect(game.speed == 2.0 and is_equal_approx(e.progress - before, normal_distance * 2.0), "2x speed doubles simulation movement through actual _process")
	game.toggle_pause()
	before = e.progress
	game._process(0.05)
	expect(is_equal_approx(e.progress, before), "paused _process does not advance enemy movement")
	game.toggle_pause()
	game.toggle_speed()
	expect(game.speed == 1.0 and not game.paused, "speed and pause toggle back normally")
	game.toggle_pause()
	game.toggle_speed()
	game.restart()
	expect(not game.paused and game.speed == 1.0 and game.pause_button.text == "暂停" and game.speed_button.text.begins_with("1×"), "restart resets speed and pause buttons")
	await process_frame

func run_wave() -> float:
	game.start_wave()
	var simulation_time := 0.0
	while game.active_wave and not game.ended and simulation_time < 180.0:
		game.game_tick(0.05)
		game.update_effects(0.05)
		game.update_damage_labels(0.05)
		simulation_time += 0.05
		if int(simulation_time * 20.0) % 200 == 0:
			await process_frame
	expect(not game.active_wave or game.ended, "normal-economy wave %d terminates within 180 seconds" % game.wave)
	await process_frame
	return simulation_time

func test_new_combat() -> void:
	game.choose_level(0)
	game.wave = 3
	var armor: Dictionary = game.spawn_enemy(2)
	var before: float = armor.hp
	game.damage_enemy(armor, 24.0, 0)
	expect(is_equal_approx(armor.hp, before - 10.8), "heavy armor mitigates 55 percent of pulse damage")
	before = armor.hp
	game.damage_enemy(armor, 100.0, 4)
	expect(is_equal_approx(armor.hp, before - 100.0), "rail damage bypasses armor")
	before = armor.hp
	game.damage_enemy(armor, 17.0, 5)
	expect(is_equal_approx(armor.hp, before - 17.0), "burn damage bypasses armor")
	clear_enemies()
	var shield: Dictionary = game.spawn_enemy(4)
	var shield_before: float = shield.shield
	before = shield.hp
	game.damage_enemy(shield, 10.0, 0)
	expect(shield.hp == before and is_equal_approx(shield.shield, shield_before - 10.0), "shield absorbs ordinary damage before health")
	shield_before = shield.shield
	game.damage_enemy(shield, 10.0, 3)
	expect(shield.hp == before and is_equal_approx(shield.shield, shield_before - 20.0), "arc does double damage to shields")
	shield.shield = 10.0
	game.damage_enemy(shield, 20.0, 3)
	expect(shield.shield == 0.0 and is_equal_approx(shield.hp, before - 15.0), "arc shield overflow applies correct remaining health damage")
	expect(not shield.node.get_node("Shield").visible, "depleted shield visual is hidden")
	game.restart()
	game.wave = 3
	build(2, 3)
	var chain: Array[Dictionary] = []
	for progress in [7.0, 9.0, 11.0, 13.0]:
		var e: Dictionary = game.spawn_enemy(0)
		place_enemy(e, 0, progress)
		chain.append(e)
	before = chain[0].hp
	game.fire(game.towers[0], chain[0])
	expect(is_equal_approx(chain[0].hp, before - 27.0), "arc primary hit deals full damage")
	expect(is_equal_approx(chain[1].hp, before - 22.95) and is_equal_approx(chain[2].hp, before - 22.95), "arc jumps to two nearby enemies at 85 percent damage")
	expect(chain[3].hp == before, "arc chain is capped at three distinct targets")
	game.restart()
	game.wave = 3
	build(2, 4)
	var ahead: Dictionary = game.spawn_enemy(0)
	var armored: Dictionary = game.spawn_enemy(2)
	place_enemy(ahead, 0, 10.0)
	place_enemy(armored, 0, 9.0)
	before = armored.hp
	game.game_tick(0.01)
	expect(is_equal_approx(armored.hp, before - 100.0) and ahead.hp == ahead.max_hp, "rail prioritizes a heavy enemy over a more advanced normal enemy")
	game.restart()
	game.wave = 1
	var healer: Dictionary = game.spawn_enemy(5)
	var ally: Dictionary = game.spawn_enemy(0)
	place_enemy(healer, 0, 9.0)
	place_enemy(ally, 0, 10.0)
	ally.hp = 25.0
	game.game_tick(0.01)
	expect(is_equal_approx(ally.hp, 28.0), "healer restores 6 percent max HP to a nearby ally")
	healer.regen_timer = 0.0
	ally.hp = 49.0
	game.game_tick(0.01)
	expect(ally.hp == ally.max_hp, "healing is capped at max HP")
	healer.regen_timer = 0.0
	healer.burn = 2.0
	healer.burn_dps = 0.0
	ally.hp = 25.0
	game.game_tick(0.01)
	expect(ally.hp == 25.0, "burning healer cannot heal allies")
	healer.burn = 0.0
	healer.regen_timer = 0.0
	ally.burn = 2.0
	ally.burn_dps = 0.0
	game.game_tick(0.01)
	expect(ally.hp == 25.0, "burning ally cannot receive healing")
	game.restart()
	game.wave = 1
	build(2, 5)
	var burn_target: Dictionary = game.spawn_enemy(0)
	var burn_nearby: Dictionary = game.spawn_enemy(0)
	place_enemy(burn_target, 0, 9.0)
	place_enemy(burn_nearby, 0, 10.0)
	game.fire(game.towers[0], burn_target)
	expect(burn_target.hp == 33.0 and burn_nearby.hp == 33.0 and burn_target.burn == 3.0 and burn_nearby.burn == 3.0, "burn tower damages and ignites its splash targets")
	game.towers[0].cooldown = 1000.0
	game.game_tick(0.1)
	expect(is_equal_approx(burn_target.hp, 31.4), "burn applies its ongoing 16 DPS through game_tick")
	game.restart()
	game.wave = 1
	var terminal_burn: Dictionary = game.spawn_enemy(0)
	terminal_burn.hp = 1.0
	terminal_burn.burn = 2.0
	terminal_burn.burn_dps = 16.0
	place_enemy(terminal_burn, terminal_burn.route.size() - 2, 16.499)
	game.game_tick(0.1)
	expect(game.health == 20 and game.kills == 1 and game.money == 370, "lethal burn is resolved before an enemy can leak at the exit")
	game.restart()
	game.wave = 3
	var boss: Dictionary = game.spawn_enemy(3)
	boss.slow = 3.0
	before = boss.progress
	game.game_tick(0.1)
	expect(is_equal_approx(boss.progress - before, boss.speed * 0.75 * 0.1), "boss resists frost and moves at 75 percent speed")
	game.restart()
	game.wave = 6
	var splitter: Dictionary = game.spawn_enemy(6)
	place_enemy(splitter, 1, 2.0)
	var parent_route: Array = splitter.route
	game.damage_enemy(splitter, splitter.hp + 1.0, 4)
	game.game_tick(0.01)
	expect(game.enemies.size() == 2 and game.kills == 1 and game.money == 380, "killed splitter rewards once and spawns two children")
	var split_valid := true
	for child in game.enemies:
		split_valid = split_valid and child.child and child.kind == 1 and child.route == parent_route and child.segment == 1 and child.reward == 3
	expect(split_valid, "split children inherit route, segment, and reduced reward")
	for child in game.enemies:
		game.damage_enemy(child, child.hp + 1.0, 4)
	game.game_tick(0.01)
	expect(game.enemies.is_empty() and game.kills == 3 and game.money == 386, "split children give small rewards without recursively splitting")
	await process_frame

func test_maps_and_routes() -> void:
	var map_routes: Array = []
	for stage in range(3):
		game.choose_level(stage)
		map_routes.append(game.ROUTE.duplicate())
		expect(game.money == game.levels[stage].gold and game.wave == 0 and game.health == 20, "level %d initializes its own economy and counters" % (stage + 1))
		expect(game.routes.size() == (1 if stage == 0 else 2), "level %d exposes correct entrance count" % (stage + 1))
		var overlaps: Array[int] = []
		for pad_index in range(game.pads.size()):
			var p := Vector2(game.pads[pad_index].position.x, game.pads[pad_index].position.z)
			var nearest := INF
			for road in game.routes:
				for i in range(road.size() - 1):
					var a := Vector2(road[i].x, road[i].z)
					var b := Vector2(road[i + 1].x, road[i + 1].z)
					nearest = minf(nearest, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
			if nearest < 1.3:
				overlaps.append(pad_index)
		expect(overlaps.is_empty(), "level %d has no build-pad/road overlap; overlapping pads: %s" % [stage + 1, str(overlaps)])
		await process_frame
	expect(map_routes[0] != map_routes[1] and map_routes[1] != map_routes[2] and map_routes[0] != map_routes[2], "all three maps have distinct route geometry")
	game.choose_level(1)
	game.wave = 2
	var north: Dictionary = game.spawn_enemy(0)
	var north_route: Array = north.route.duplicate()
	game.toggle_gate()
	expect(game.gate_mode == 1 and game.gate_cooldown == 12.0, "gate switches entrance and starts its 12-second cooldown")
	var south: Dictionary = game.spawn_enemy(0)
	expect(north.route_index == 0 and south.route_index == 1 and north.route == north_route and north.route != south.route, "new enemy takes switched entrance while existing enemy keeps original route")
	game.toggle_gate()
	expect(game.gate_mode == 1, "gate cooldown prevents rapid switching")
	game.game_tick(0.1)
	expect(is_equal_approx(game.gate_cooldown, 11.9), "gate cooldown counts down in simulation time")
	game.gate_cooldown = 0.0
	game.toggle_gate()
	expect(game.gate_mode == 0, "gate can switch back after cooldown")
	game.restart()
	expect(game.gate_mode == 0 and game.gate_cooldown == 0.0, "restart resets gate state")
	game.choose_level(2)
	game.wave = 2
	game.spawned = 0
	var first: Dictionary = game.spawn_enemy(0)
	game.spawned = 1
	var second: Dictionary = game.spawn_enemy(0)
	expect(first.route_index == 0 and second.route_index == 1 and first.route != second.route, "final level alternates enemy entrance routes")
	game.toggle_gate()
	expect(game.gate_mode == 0 and game.gate_cooldown == 0, "manual gate switching is unavailable outside level 2")
	game.choose_level(0)
	await process_frame

func test_ability() -> void:
	game.choose_level(0)
	game.use_ability()
	expect(game.ability_cooldown == 0.0, "core ability is unavailable during deployment")
	game.wave = 8
	game.active_wave = true
	game.remaining = 0
	var armored: Dictionary = game.spawn_enemy(2)
	var normal: Dictionary = game.spawn_enemy(0)
	var armor_before: float = armored.hp
	var normal_before: float = normal.hp
	game.paused = true
	game.use_ability()
	expect(game.ability_cooldown == 0 and armored.hp == armor_before, "core ability cannot fire while paused")
	game.paused = false
	game.use_ability()
	expect(is_equal_approx(armored.hp, armor_before - 154.0) and is_equal_approx(normal.hp, normal_before - 154.0), "core ability damages all enemies and bypasses armor")
	expect(armored.slow == 3.0 and normal.slow == 3.0 and game.ability_cooldown == 35.0, "core ability applies slow and starts 35-second cooldown")
	var after: float = armored.hp
	game.use_ability()
	expect(armored.hp == after, "cooldown prevents repeated core ability damage")
	game.game_tick(0.1)
	expect(is_equal_approx(game.ability_cooldown, 34.9), "ability cooldown decreases in game_tick")
	game.restart()
	expect(game.ability_cooldown == 0 and game.enemies.is_empty(), "restart clears ability cooldown and targets")
	await process_frame

func simulate_mixed_six_strategy(stage: int) -> void:
	game.choose_level(stage)
	# All builds use earned money. Expansion/upgrades happen only between waves.
	# Pads are chosen to cover each map's middle lanes and shared choke points.
	var placements: Array = [
		[[1, 0], [3, 1], [2, 2], [4, 4], [0, 3], [5, 5], [8, 4], [9, 1], [7, 3], [10, 5]],
		[[2, 0], [8, 1], [3, 2], [4, 3], [7, 4], [9, 5], [1, 3], [12, 4], [13, 1], [14, 5]],
		[[7, 0], [8, 1], [6, 2], [3, 4], [9, 3], [2, 5], [4, 4], [10, 1], [13, 3], [5, 5]],
		[[7, 0], [8, 1], [6, 2], [9, 4], [10, 3], [13, 5], [2, 4], [4, 1], [14, 3], [15, 5]],
		[[9, 0], [10, 1], [8, 2], [6, 4], [7, 3], [11, 5], [5, 4], [13, 1], [14, 3], [2, 5]],
		[[8, 0], [9, 1], [7, 2], [10, 4], [11, 3], [6, 5], [2, 4], [12, 1], [14, 3], [4, 5]]
	][stage]
	var next_build := 0
	for opening in range(3):
		build(placements[next_build][0], placements[next_build][1])
		next_build += 1
	var results: Array[String] = []
	var ability_uses := 0
	for wave_index in range(game.wave_total()):
		# Get all six tower types on the board before optimizing upgrades.
		if next_build < 6:
			while next_build < 6 and game.money >= game.TOWER_DATA[placements[next_build][1]].cost:
				build(placements[next_build][0], placements[next_build][1])
				next_build += 1
		if next_build >= 6:
			for desired_level in [2, 3]:
				for t in game.towers:
					if t.level < desired_level and game.money >= game.upgrade_cost(t):
						game.select_pad(t.pad)
						game.upgrade_selected()
			var all_maxed := true
			for t in game.towers:
				if t.level < 3: all_maxed = false
			if all_maxed:
				while next_build < placements.size() and game.money >= game.TOWER_DATA[placements[next_build][1]].cost:
					build(placements[next_build][0], placements[next_build][1])
					next_build += 1
		game.start_wave()
		var duration := 0.0
		var tick := 0
		while game.active_wave and not game.ended and duration < 240.0:
			game.game_tick(0.05)
			game.update_effects(0.05)
			game.update_damage_labels(0.05)
			# One intuitive emergency rule: use Q on a crowd or lone boss.
			var boss_present := false
			for e in game.enemies:
				if e.kind == 3: boss_present = true
			if game.ability_cooldown <= 0 and (game.enemies.size() >= 8 or boss_present):
				game.use_ability()
				ability_uses += 1
			duration += 0.05
			tick += 1
			if tick % 200 == 0: await process_frame
		expect(not game.active_wave or game.ended, "level %d wave %d resolves within 240 seconds" % [stage + 1, game.wave])
		results.append("wave %d: HP %d, gold %d, towers %d, kills %d, %.1fs" % [game.wave, game.health, game.money, game.towers.size(), game.kills, duration])
		await process_frame
		if game.ended: break
	var won: bool = game.ended and game.health > 0 and game.wave == game.wave_total()
	expect(won, "level %d normal-economy six-tower strategy wins" % (stage + 1))
	if won:
		expect(stage in game.completed_levels, "level %d victory records completion" % (stage + 1))
	var report := "LEVEL %d MIXED SIX-TOWER STRATEGY: %s; Q uses %d\n%s" % [stage + 1, "VICTORY" if won else "DEFEAT", ability_uses, "\n".join(results)]
	balance_reports.append(report)
	print(report)

func simulate_stage_undefended(stage: int) -> void:
	game.choose_level(stage)
	for wave_index in range(3):
		await run_wave()
		if game.ended: break
	var losing_wave := 1 if stage == 5 else 2
	expect(game.ended and game.health == 0 and game.wave == losing_wave, "level %d undefended game loses in wave %d" % [stage + 1, losing_wave])
	game.restart()
	expect(game.money == game.levels[stage].gold and game.health == 20 and game.wave == 0 and not game.ended and game.enemies.is_empty(), "level %d restart after defeat restores its starting state" % (stage + 1))
	balance_reports.append("LEVEL %d UNDEFENDED: defeat in wave %d; restart verified" % [stage + 1, losing_wave])
	await process_frame
