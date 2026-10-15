extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func run() -> void:
	var g: Node = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.sound_enabled = false
	g.show_damage_numbers = true
	var data := LevelDesigner.template_data()
	data.waves = 1
	data.count = 8
	data.gold = 2000
	data = LevelDesigner.canonical_data(data)
	g.start_custom_level(data)
	AuthorReplay.busy = true
	for i in range(6):
		g.selected_pad = i
		g.selected_kind = i
		g.build_selected()
	g.selected_pad = 0
	g.upgrade_selected()
	g.selected_pad = 1
	g.sell_selected()
	g.start_wave()
	for frame in range(60):
		AuthorReplay.advance(g, AuthorReplay.STEP / 2.0)
		g.update_effects(AuthorReplay.STEP / 2.0)
	g.use_ability()
	var count := 0
	while not g.ended and count < 24000:
		AuthorReplay.advance(g, AuthorReplay.STEP)
		g.update_effects(AuthorReplay.STEP)
		count += 1
		if count % 120 == 0: await process_frame
	await process_frame
	expect(g.ended and g.health > 0, "recorded custom level actually wins with real towers/combat")
	var s: Dictionary = g.get_meta("replay_state")
	var proof := {"schema": 1, "level_hash": AuthorReplay.level_hash(data), "rules_hash": AuthorReplay.rules_hash(), "seed": data.seed, "ticks": s.tick, "result_hash": AuthorReplay.result_hash(g), "commands": s.commands.duplicate(true)}
	expect(proof.commands.size() == 10, "successful build upgrade sell wave ability commands recorded")
	expect(await AuthorReplay.verify(g, data, proof), "legal replay wins in a fresh real simulation")
	expect(await AuthorReplay.verify(g, data, JSON.parse_string(JSON.stringify(proof))), "JSON round trip replay deterministically wins again")
	var changed := data.duplicate(true)
	changed.gold += 1
	expect(not AuthorReplay.validate_proof(changed, proof), "level edit invalidates proof")
	changed = data.duplicate(true)
	changed.seed += 1
	expect(not AuthorReplay.validate_proof(changed, proof), "seed edit invalidates proof")
	var bad := proof.duplicate(true)
	bad.rules_hash = "old rules"
	expect(not AuthorReplay.validate_proof(data, bad), "rules mismatch rejects")
	bad = proof.duplicate(true)
	bad.commands = []
	bad.verified = true
	expect(not await AuthorReplay.verify(g, data, bad), "forged verified flag without commands cannot win")
	bad = proof.duplicate(true)
	bad.commands[0].args[0] = 999
	expect(not AuthorReplay.validate_proof(data, bad), "out of bounds command rejects")
	bad = proof.duplicate(true)
	bad.commands[0].tick = -1
	expect(not AuthorReplay.validate_proof(data, bad), "negative tick rejects")
	bad = proof.duplicate(true)
	bad.commands.insert(1, bad.commands[0].duplicate(true))
	expect(not await AuthorReplay.verify(g, data, bad), "illegal duplicate build rejects instead of silently skipping")
	bad = proof.duplicate(true)
	bad.commands.insert(10, bad.commands[9].duplicate(true))
	expect(not await AuthorReplay.verify(g, data, bad), "ability cooldown bypass rejects")
	bad = proof.duplicate(true)
	bad.commands.insert(9, bad.commands[8].duplicate(true))
	expect(not await AuthorReplay.verify(g, data, bad), "wave already active rejects duplicate wave")
	var poor := data.duplicate(true)
	poor.gold = 100
	bad = proof.duplicate(true)
	bad.level_hash = AuthorReplay.level_hash(poor)
	expect(not await AuthorReplay.verify(g, poor, bad), "insufficient gold rejects command under actual economy")
	bad = proof.duplicate(true)
	bad.ticks += 1
	expect(not await AuthorReplay.verify(g, data, bad), "terminal tick must match actual victory")
	AuthorReplay.verified.clear()
	expect(AuthorReplay.read_verified(data).is_empty(), "disk proof alone cannot grant verified status")
	AuthorReplay.busy = false
	await AuthorReplay._verify_and_save(g, data, proof)
	expect(not AuthorReplay.read_verified(data).is_empty(), "verified proof saved and trusted after successful real rerun")
	var file := FileAccess.open(AuthorReplay.PATH, FileAccess.WRITE)
	file.store_string('{"verified":true}')
	file.close()
	expect(AuthorReplay.read_verified(data).is_empty(), "tampered proof invalidates cached verification")
	g.queue_free()
	await process_frame
	print("REPLAY RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
