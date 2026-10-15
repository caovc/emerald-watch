extends Node
## Orthographic ground-plane camera controls. HUD remains in its CanvasLayer.
const MIN_SIZE := 18.0
const MAX_SIZE := 28.0
const DEFAULT_SIZE := 22.8
const TAP_SLOP := 12.0
var game: Node
var camera: Camera3D
var home_position := Vector3.ZERO
var offset := Vector3.ZERO
var dragging := false
var drag_button := 0
var touches: Dictionary = {}
var touch_origin := Vector2.ZERO
var touch_moved := false
var suppress_emulated := false

static func install(owner_node: Node) -> Node:
	if owner_node.has_meta("camera_controller"):
		return owner_node.get_meta("camera_controller")
	var controller = load("res://scripts/camera_controller.gd").new()
	controller.name = "BattlefieldCameraControls"
	controller.game = owner_node
	controller.camera = owner_node.camera
	controller.home_position = owner_node.camera.position
	owner_node.set_meta("camera_controller", controller)
	owner_node.add_child(controller)
	return controller

func modal_open() -> bool:
	for key in ["settings_ui", "game_codex", "level_designer"]:
		if game.has_meta(key):
			var overlay = game.get_meta(key).get("overlay")
			if is_instance_valid(overlay) and overlay.visible:
				return true
	return (is_instance_valid(game.level_overlay) and game.level_overlay.visible) or (is_instance_valid(game.end_panel) and game.end_panel.visible)

func _process(_delta: float) -> void:
	if modal_open():
		cancel_gesture()

func cancel_gesture() -> void:
	dragging = false
	touches.clear()
	touch_moved = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_gesture()

func over_ui(pos: Vector2, node: Node = null) -> bool:
	if node == null:
		node = game.hud
	if node is Control:
		if not node.is_visible_in_tree():
			return false
		if node.mouse_filter == Control.MOUSE_FILTER_STOP and node.get_global_rect().has_point(pos):
			return true
	for child in node.get_children():
		if over_ui(pos, child):
			return true
	return false

func ground_point(pos: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(pos)
	var direction := camera.project_ray_normal(pos)
	if absf(direction.y) < 0.0001:
		return origin
	return origin + direction * (-origin.y / direction.y)

func pan_between(previous: Vector2, current: Vector2) -> void:
	offset += ground_point(previous) - ground_point(current)
	apply_bounds()

func apply_bounds() -> void:
	offset.x = clampf(offset.x, -8.0, 8.0)
	offset.y = 0.0
	offset.z = clampf(offset.z, -6.0, 6.0)
	camera.position = home_position + offset

func zoom_at(factor: float, pos: Vector2) -> void:
	var before := ground_point(pos)
	camera.size = clampf(camera.size * factor, MIN_SIZE, MAX_SIZE)
	offset += before - ground_point(pos)
	apply_bounds()
	sync_settings()

func sync_settings() -> void:
	# Keep settings application from reverting a live zoom on unrelated changes.
	if game.has_meta("settings_values"):
		var values: Dictionary = game.get_meta("settings_values")
		values.camera_zoom = camera.size
		game.set_meta("settings_values", values)

func reset_view() -> void:
	if camera != game.camera or not is_instance_valid(camera):
		camera = game.camera
		home_position = camera.position
	cancel_gesture()
	offset = Vector3.ZERO
	camera.size = DEFAULT_SIZE
	apply_bounds()
	sync_settings()

func _input(event: InputEvent) -> void:
	# Release capture even when the pointer has crossed a HUD panel.
	if event is InputEventMouseButton and not event.pressed and event.button_index == drag_button:
		dragging = false
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION and suppress_emulated:
			get_viewport().set_input_as_handled()
		return
	if modal_open():
		cancel_gesture()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if touches.is_empty():
				suppress_emulated = not over_ui(event.position)
			if over_ui(event.position):
				return
			if touches.is_empty():
				touch_origin = event.position
				touch_moved = false
			touches[event.index] = event.position
			if touches.size() > 1:
				touch_moved = true
		elif touches.has(event.index):
			var is_tap: bool = touches.size() == 1 and not touch_moved and not event.canceled and touch_origin.distance_to(event.position) < TAP_SLOP
			touches.erase(event.index)
			if is_tap and not over_ui(event.position):
				var click := InputEventMouseButton.new()
				click.position = event.position
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				game._unhandled_input(click)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touches.has(event.index):
		var previous: Vector2 = touches[event.index]
		if touches.size() == 1:
			if touch_origin.distance_to(event.position) >= TAP_SLOP:
				touch_moved = true
			if touch_moved and not over_ui(event.position):
				pan_between(previous, event.position)
			touches[event.index] = event.position
		else:
			var ids := touches.keys()
			var old_center: Vector2 = (touches[ids[0]] + touches[ids[1]]) * 0.5
			var old_distance: float = touches[ids[0]].distance_to(touches[ids[1]])
			touches[event.index] = event.position
			var center: Vector2 = (touches[ids[0]] + touches[ids[1]]) * 0.5
			var distance: float = touches[ids[0]].distance_to(touches[ids[1]])
			if distance > 1.0 and old_distance > 1.0 and not over_ui(event.position):
				pan_between(old_center, center)
				zoom_at(old_distance / distance, center)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if modal_open():
		cancel_gesture()
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventGesture) and over_ui(event.position):
		return
	var handled := false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(pow(0.9, maxf(event.factor, 1.0) * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)), event.position)
			handled = true
		elif event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed):
			dragging = true
			drag_button = event.button_index
			handled = true
	elif event is InputEventMouseMotion and dragging:
		pan_between(event.position - event.relative, event.position)
		handled = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_HOME:
		reset_view()
		handled = true
	elif event is InputEventMagnifyGesture:
		zoom_at(1.0 / maxf(event.factor, 0.01), event.position)
		handled = true
	elif event is InputEventPanGesture:
		pan_between(event.position, event.position - event.delta * 12.0)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()
