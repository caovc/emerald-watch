extends SceneTree
var game: Node
var control: Node
var dragger: Node
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
func touch(id: int, pos: Vector2, pressed: bool, canceled: bool = false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = id
	e.position = pos
	e.pressed = pressed
	e.canceled = canceled
	root.push_input(e, true)
func move(id: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = id
	e.position = pos
	root.push_input(e, true)
func dock(k: int = 0) -> Vector2:
	return game.tower_buttons[k].get_global_rect().get_center()
func pad(index: int) -> Vector2:
	return game.camera.unproject_position(game.pads[index].position + Vector3(0, 0.4, 0))
func gesture(target: Vector2, canceled: bool = false) -> void:
	touch(0, dock(), true)
	move(0, target)
	touch(0, target, false, canceled)
func run() -> void:
	root.size = Vector2i(844,390) if "--mobile-ui" in OS.get_cmdline_user_args() else Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	control = load("res://scripts/camera_controller.gd").install(game)
	dragger = load("res://scripts/tower_drag.gd").install(game, control)
	game.select_pad(-1)
	var cash: int = game.money
	touch(0,dock(1),true)
	touch(0,dock(1),false)
	expect(game.selected_kind == 1 and game.towers.is_empty(), "Dock tap preserves kind selection without building")
	touch(0,dock(),true)
	move(0,pad(0))
	expect(dragger.dragging and dragger.valid_drop and is_instance_valid(dragger.ghost) and dragger.ring.visible, "Touch drag shows actual model ghost, range and valid state without hover")
	expect(control.offset == Vector3.ZERO, "Dock drag never pans battlefield")
	touch(0,pad(0),false)
	expect(game.towers.size() == 1 and game.money == cash - int(game.TOWER_DATA[0].cost), "Valid drop creates exactly one tower and deducts exactly one cost")
	cash = game.money
	touch(0,pad(0),false)
	expect(game.towers.size() == 1 and game.money == cash, "Duplicate release cannot build twice")
	game.select_pad(-1)
	gesture(pad(0))
	expect(game.money == cash and game.towers.size() == 1, "Occupied pad drop is free and rejected")
	gesture(Vector2(10,10))
	expect(game.money == cash, "UI/invalid drop is free")
	gesture(dock() + Vector2(20,0))
	expect(game.money == cash, "Return-to-dock drop cancels")
	gesture(pad(1),true)
	expect(game.money == cash and game.tower_at(1) < 0, "Canceled touch never builds")
	touch(0,dock(),true)
	move(0,pad(1))
	touch(1,pad(2),true)
	touch(0,pad(1),false)
	touch(1,pad(2),false)
	expect(game.money == cash and game.tower_at(1) < 0 and control.touches.is_empty(), "Second finger cancels capture and both releases safely")
	touch(0,dock(),true)
	move(0,pad(1))
	dragger._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(0,pad(1),false)
	expect(game.money == cash and game.tower_at(1) < 0, "Focus interruption cancels drop")
	touch(0,dock(),true)
	move(0,pad(1))
	game.paused = true
	touch(0,pad(1),false)
	game.paused = false
	expect(game.money == cash and game.tower_at(1) < 0, "Pause interruption cancels drop")
	game.money = 0
	touch(0,dock(),true)
	move(0,pad(1))
	expect(not dragger.valid_drop and is_instance_valid(dragger.hint) and dragger.hint.text == "金币不足", "Unaffordable preview explicitly reports insufficient funds")
	touch(0,pad(1),false)
	expect(game.money == 0 and game.tower_at(1) < 0, "Unaffordable release never charges or builds")
	game.money = cash
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = pad(1)
	root.push_input(emulated, true)
	expect(game.selected_pad == -1, "Emulated mouse following touch cannot select accidentally")
	touch(0,pad(1),true)
	touch(0,pad(1),false)
	expect(game.selected_pad == 1, "Battlefield tap remains available after drag")
	game.select_pad(-1)
	var middle: Vector2 = root.get_visible_rect().get_center()
	touch(0,middle,true)
	move(0,middle + Vector2(60,0))
	touch(0,middle + Vector2(60,0),false)
	expect(control.offset.length() > 0.1, "Battlefield pan remains available after drag")
	control.reset_view()
	touch(0,dock(),true)
	move(0,pad(1))
	game.set_meta("test_safe_area", root.get_visible_rect().grow(-24))
	touch(0,pad(1),false)
	expect(game.money == cash and game.tower_at(1) < 0, "Safe-area/orientation change cancels captured build")
	game.remove_meta("test_safe_area")
	game.queue_free()
	await process_frame
	print("TOWER DRAG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
