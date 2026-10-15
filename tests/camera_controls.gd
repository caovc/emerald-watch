extends SceneTree
const Controller = preload("res://scripts/camera_controller.gd")
var game: Node
var control: Node
var failures := 0
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)
func mouse(button: int, pos: Vector2, pressed: bool = true, shift: bool = false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = pos
	e.pressed = pressed
	e.shift_pressed = shift
	return e
func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	control._input(e)
func drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	control._input(e)
func run() -> void:
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	control = Controller.install(game)
	var point := Vector2(720,430)
	control.reset_view()
	var before: Vector3 = control.ground_point(point)
	root.push_input(mouse(MOUSE_BUTTON_WHEEL_UP, point))
	expect(game.camera.size < 22.8, "Actual viewport wheel zoom reaches controller")
	expect(control.ground_point(point).distance_to(before) < 0.001, "Zoom preserves ground point under pointer")
	for i in 50:
		control.zoom_at(0.8,point)
	expect(is_equal_approx(game.camera.size,18.0), "Near zoom bound")
	for i in 50:
		control.zoom_at(1.2,point)
	expect(is_equal_approx(game.camera.size,28.0), "Far zoom bound")
	control.reset_view()
	game.select_pad(-1)
	root.push_input(mouse(MOUSE_BUTTON_LEFT,point,true,true))
	expect(control.dragging and game.selected_pad == -1, "Shift click captures pan without selecting pad")
	var move := InputEventMouseMotion.new()
	move.position = point + Vector2(100,0)
	move.relative = Vector2(100,0)
	root.push_input(move)
	expect(control.offset.length() > 0.1, "Captured mouse drag pans actual camera")
	control._input(mouse(MOUSE_BUTTON_LEFT,Vector2(30,30),false))
	expect(not control.dragging, "Release over HUD stops drag")
	control.pan_between(Vector2(-100000,-100000),Vector2(100000,100000))
	expect(absf(control.offset.x) <= 8 and absf(control.offset.z) <= 6, "Pan bounded to battlefield")
	control.reset_view()
	root.push_input(mouse(MOUSE_BUTTON_WHEEL_UP,Vector2(60,30)))
	expect(is_equal_approx(game.camera.size,22.8), "HUD wheel does not zoom map")
	load("res://scripts/game_settings.gd").open(game)
	control._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_UP,point))
	expect(is_equal_approx(game.camera.size,22.8), "Settings modal blocks zoom")
	load("res://scripts/game_settings.gd").close(game)
	touch(0,point,true)
	drag(0,point+Vector2(70,0))
	touch(0,point+Vector2(70,0),false)
	expect(control.offset.length() > 0.1 and game.selected_pad == -1, "Single touch drag pans without placement")
	control.reset_view()
	touch(0,point-Vector2(60,0),true)
	touch(1,point+Vector2(60,0),true)
	drag(1,point+Vector2(100,0))
	expect(game.camera.size < 22.8, "Two finger pinch zooms")
	touch(1,point+Vector2(100,0),false)
	touch(0,point-Vector2(60,0),false)
	expect(game.selected_pad == -1, "Pinch release does not select")
	control.reset_view()
	var home := InputEventKey.new()
	home.keycode = KEY_HOME
	home.pressed = true
	control.zoom_at(0.8,point)
	root.push_input(home)
	expect(is_equal_approx(game.camera.size,22.8) and control.offset == Vector3.ZERO, "Home resets position and zoom")
	var tap_point: Vector2 = game.camera.unproject_position(game.pads[0].position)
	touch(0,tap_point,true)
	touch(0,tap_point,false)
	expect(game.selected_pad == 0, "Touch tap still selects a build pad")
	control.reset_view()
	for meta_key in ["game_codex", "level_designer"]:
		var overlay := Control.new()
		root.add_child(overlay)
		var original = game.get_meta(meta_key) if game.has_meta(meta_key) else null
		game.set_meta(meta_key, {"overlay":overlay})
		control._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_UP,point))
		expect(is_equal_approx(game.camera.size,22.8), meta_key + " modal blocks zoom")
		if original != null:
			game.set_meta(meta_key, original)
		else:
			game.remove_meta(meta_key)
		overlay.queue_free()
	touch(0,point,true)
	control.cancel_gesture()
	touch(0,point,false)
	expect(control.touches.is_empty() and not control.dragging, "Interrupted touch leaves no stale gesture")
	control.zoom_at(0.9,point)
	var zoom: float = game.camera.size
	load("res://scripts/game_settings.gd").apply(game)
	expect(is_equal_approx(game.camera.size,zoom), "Settings retain live camera zoom")
	game._rebuild_board()
	control.reset_view()
	control.zoom_at(0.9, point)
	expect(control.camera == game.camera and is_equal_approx(game.camera.size, 22.8 * 0.9), "Rebuilt level rebinds camera controls")
	game.queue_free()
	await process_frame
	print("CAMERA: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
