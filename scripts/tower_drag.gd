extends Node
## Dock-origin touch capture. Battlefield gestures remain the camera's responsibility.
const SLOP := 12.0
const Layout = preload("res://scripts/responsive_layout.gd")
var game: Node
var controller: Node
var pointer := -1
var kind := -1
var origin := Vector2.ZERO
var position := Vector2.ZERO
var dragging := false
var captured: Dictionary = {}
var suppress_emulated := false
var ghost: Node3D
var ring: MeshInstance3D
var hint: Label
var source_world: Node3D
var source_camera: Camera3D
var source_safe := Rect2()
var target := -1
var valid_drop := false
var ghost_material: StandardMaterial3D
var ring_material: StandardMaterial3D

static func install(g: Node, camera_controls: Node) -> Node:
	if g.has_meta("tower_drag"):
		return g.get_meta("tower_drag")
	var node = load("res://scripts/tower_drag.gd").new()
	node.name = "TowerDockDrag"
	node.game = g
	node.controller = camera_controls
	g.add_child(node)
	g.set_meta("tower_drag", node)
	return node

func blocked() -> bool:
	return game.ended or game.paused or controller.modal_open()

func dock_kind(point: Vector2) -> int:
	if not Layout.safe_rect(game).has_point(point):
		return -1
	for i in range(game.tower_buttons.size()):
		var button: Button = game.tower_buttons[i]
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return i
	return -1

func handle_input(event: InputEvent) -> bool:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION and suppress_emulated:
		return consume()
	if pointer >= 0 and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		return consume()
	if event is InputEventScreenTouch:
		if event.pressed:
			if not captured.is_empty():
				captured[event.index] = true
				cancel()
				controller.cancel_gesture()
				return consume()
			var chosen := dock_kind(event.position)
			if chosen < 0 or blocked():
				return false
			# Never convert a battlefield pan/pinch into a build gesture.
			if not controller.touches.is_empty():
				return false
			captured[event.index] = true
			suppress_emulated = true
			pointer = event.index
			kind = chosen
			origin = event.position
			position = origin
			source_world = game.world
			source_camera = game.camera
			source_safe = Layout.safe_rect(game)
			return consume()
		elif captured.has(event.index):
			if event.index == pointer:
				var was_dragging := dragging
				var chosen := kind
				if not event.canceled and not interrupted():
					if was_dragging:
						update_preview(event.position)
						var pad := target
						var allowed := valid_drop
						# Clear capture BEFORE the authoritative transaction; one release, one build.
						cancel()
						if allowed:
							game.select_kind(chosen)
							game.select_pad(pad)
							game.build_selected()
					elif origin.distance_to(event.position) < SLOP and dock_kind(event.position) == chosen:
						cancel()
						game.select_kind(chosen)
				cancel()
			captured.erase(event.index)
			return consume()
	elif event is InputEventScreenDrag and captured.has(event.index):
		if event.index == pointer:
			if interrupted():
				cancel()
			elif dragging or origin.distance_to(event.position) >= SLOP:
				if not dragging:
					dragging = true
					game.clear_preview()
					game.range_ring.hide()
					create_preview()
				update_preview(event.position)
		return consume()
	return false

func consume() -> bool:
	get_viewport().set_input_as_handled()
	return true

func interrupted() -> bool:
	return blocked() or not is_instance_valid(source_world) or source_world != game.world or source_camera != game.camera or source_safe != Layout.safe_rect(game)

func _process(_delta: float) -> void:
	if pointer >= 0:
		if interrupted():
			cancel()
		elif dragging:
			update_preview(position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		cancel()

func cancel() -> void:
	pointer = -1
	kind = -1
	dragging = false
	target = -1
	valid_drop = false
	# Keep captured IDs until release so cancellation cannot become a battlefield tap.
	for node in [ghost, ring, hint]:
		if is_instance_valid(node):
			node.queue_free()
	ghost = null
	ring = null
	hint = null

func create_preview() -> void:
	ghost = game.build_tower_model(kind, Vector3.ZERO, 1)
	ghost.name = "DraggedTowerGhost"
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for child in ghost.find_children("*", "MeshInstance3D", true, false):
		child.material_override = ghost_material
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring = game.make_ring(1.0, Color("83ebc0"))
	game.world.add_child(ring)
	ring_material = StandardMaterial3D.new()
	ring.material_override = ring_material
	hint = Label.new()
	hint.name = "TowerDropStatus"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_outline_size", 6)
	game.get_meta("game_ui").root.add_child(hint)

func update_preview(point: Vector2) -> void:
	position = point
	var safe: Rect2 = Layout.safe_rect(game)
	var over_ui: bool = controller.over_ui(point)
	target = game.pad_from_screen(point) if safe.has_point(point) and not over_ui else -1
	var affordable: bool = game.money >= int(game.TOWER_DATA[kind].cost)
	var empty: bool = target >= 0 and game.tower_at(target) < 0
	valid_drop = empty and affordable and not blocked()
	var tint := Color("83ebc0") if valid_drop else Color("f47778")
	var p: Vector3 = game.pads[target].position if target >= 0 else controller.ground_point(point)
	ghost.position = p + Vector3(0, 0.14, 0)
	ghost_material.albedo_color = Color(tint, 0.5)
	var radius: float = game.TOWER_DATA[kind].range
	ring.position = p + Vector3(0, 0.04, 0)
	ring.scale = Vector3(radius, 1, radius)
	ring_material.albedo_color = tint
	ring.visible = true
	hint.text = "松手建造 · %d 金" % game.TOWER_DATA[kind].cost if valid_drop else ("金币不足" if not affordable else ("基座已占用" if target >= 0 and not empty else "拖到空基座 · 松手取消"))
	hint.add_theme_color_override("font_color", tint)
	hint.size = hint.get_minimum_size()
	hint.position = Vector2(clampf(point.x - hint.size.x * 0.5, safe.position.x + 8, maxf(safe.position.x + 8, safe.end.x - hint.size.x - 8)), clampf(point.y - 76, safe.position.y + 8, maxf(safe.position.y + 8, safe.end.y - hint.size.y - 8)))
