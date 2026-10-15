extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	print(('PASS ' if ok else 'FAIL ') + message)
	if not ok:
		failures += 1
func run() -> void:
	# Desktop window minimums must not clamp synthetic phone capture sizes.
	root.min_size = Vector2i.ZERO
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	for dimensions in [Vector2i(1440,900), Vector2i(1920,1080), Vector2i(1024,768), Vector2i(844,390), Vector2i(667,375), Vector2i(1366,1024)]:
		root.size = dimensions
		for i in 8:
			await process_frame
		var r: Dictionary = game.get_meta('game_ui')
		if dimensions == Vector2i(1440,900):
			check(('从底部拖动塔' in game.toast_label.text) if '--mobile-ui' in OS.get_cmdline_user_args() else ('右键 / Esc' in game.toast_label.text), 'Platform-specific initial instruction')
		var size := root.get_visible_rect().size
		print('VIEW ', dimensions, ' logical ', size, ' header ', r.top.get_global_rect(), ' dock ', r.dock.get_global_rect())
		check(Rect2(Vector2.ZERO, size).encloses(r.top.get_global_rect()), 'Header fits '+str(dimensions))
		check(Rect2(Vector2.ZERO, size).encloses(r.dock.get_global_rect()), 'Dock fits '+str(dimensions))
		check(Rect2(Vector2.ZERO, size).encloses(r.actions.get_global_rect()), 'Abilities fit '+str(dimensions))
		for b in game.tower_buttons:
			check(b.size.y >= (72 if '--mobile-ui' in OS.get_cmdline_user_args() else 44), 'Tower target height')
		var point := size * 0.5
		var c = game.get_meta('camera_controller')
		var world: Vector3 = c.ground_point(point)
		check(game.camera.unproject_position(world).distance_to(point) < 0.1, 'Picking round trip')
		var battlefield := Rect2(12, r.top.get_global_rect().end.y + 8, size.x - 24, r.dock.position.y - r.top.get_global_rect().end.y - 16)
		for route in game.routes:
			for waypoint in route:
				check(battlefield.has_point(game.camera.unproject_position(waypoint)), 'Route visible between HUD and dock')
		if DisplayServer.get_name() != 'headless' and '--capture-layouts' in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var variant := 'mobile' if '--mobile-ui' in OS.get_cmdline_user_args() else 'desktop'
			root.get_texture().get_image().save_png('res://screenshots/responsive-%s-%dx%d.png' % [variant, dimensions.x, dimensions.y])
	var size := root.get_visible_rect().size
	game.set_meta('test_safe_area', Rect2(70, 0, size.x-140, size.y-34))
	for i in 4:
		await process_frame
	var r: Dictionary = game.get_meta('game_ui')
	var safe: Rect2 = game.get_meta('test_safe_area')
	check(safe.encloses(r.top.get_global_rect()), 'Notch-safe header')
	check(safe.encloses(r.dock.get_global_rect()), 'Home-indicator-safe dock')
	game.select_pad(0)
	for i in 4:
		await process_frame
	check(safe.encloses(r.context.get_global_rect()), 'Context stays inside safe area')
	game.show_codex()
	await process_frame
	await process_frame
	check(game.get_meta('game_codex').overlay.has_node('SafeModalMargin'), 'Codex scroll safe wrapper')
	game.get_meta('game_codex').overlay.hide()
	game.open_designer()
	await process_frame
	await process_frame
	check(game.get_meta('level_designer').overlay.has_node('SafeModalMargin'), 'Designer scroll safe wrapper')
	print('RESPONSIVE FAILURES ', failures)
	quit(1 if failures else 0)
