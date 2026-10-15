class_name LevelDesigner
extends RefCounted
## Deliberately local-only authoring: one bounded grid, one local file, no sharing.

const SAVE_PATH := "user://custom_level.json"
const PROOF_PATH := "user://author_proof.json"
const INK := Color("e9f5f1")
const MUTED := Color("a4bdba")
const MINT := Color("83ebc0")
const GOLD := Color("ffd397")
const TILE := 1.5
const MAX_FILE_BYTES := 131072
const MAX_PROOF_BYTES := 2097152

class DesignGrid extends Control:
	var owner_game: Node
	var data: Dictionary = {}
	var hover := Vector2i(999, 999)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_exited.connect(func(): hover = Vector2i(999, 999); queue_redraw())

	func cell_at(point: Vector2) -> Vector2i:
		return Vector2i(floori(point.x / (size.x / 15.0)) - 7, floori(point.y / (size.y / 9.0)) - 4)

	func point_at(cell: Array) -> Vector2:
		return Vector2((float(cell[0]) + 7.5) * size.x / 15.0, (float(cell[1]) + 4.5) * size.y / 9.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			hover = cell_at(event.position)
			queue_redraw()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			LevelDesigner._edit_cell(owner_game, cell_at(event.position))
			accept_event()

	func _draw() -> void:
		var cell_size := Vector2(size.x / 15.0, size.y / 9.0)
		for x in range(15):
			for z in range(9):
				var cell := Vector2i(x - 7, z - 4)
				var bg := Color("17373d") if (x + z) % 2 == 0 else Color("153039")
				if cell == hover:
					bg = Color("2e554e")
				draw_rect(Rect2(Vector2(x, z) * cell_size + Vector2.ONE, cell_size - Vector2(2, 2)), bg)
		var route: Array = data.get("route", [])
		if route.size() > 1:
			var points := PackedVector2Array()
			for cell in route:
				points.append(point_at(cell))
			draw_polyline(points, Color("9a9b7b"), cell_size.x * 0.50, true)
			draw_polyline(points, Color("d9dab5"), 2.0, true)
		for i in range(route.size()):
			var p := point_at(route[i])
			if i == 0:
				draw_circle(p, 14, Color("83ebc0"))
				draw_string(ThemeDB.fallback_font, p + Vector2(-5, 5), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("163039"))
			elif i == route.size() - 1:
				draw_circle(p, 14, Color("ffbd83"))
				draw_string(ThemeDB.fallback_font, p + Vector2(-5, 5), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("163039"))
			else:
				draw_circle(p, 4, Color("e8edcb"))
		for cell in data.get("pads", []):
			var p := point_at(cell)
			draw_circle(p, cell_size.x * 0.28, Color("34546a"))
			draw_arc(p, cell_size.x * 0.28, 0, TAU, 24, Color("89d1ed"), 2.0, true)
			draw_line(p - Vector2(6, 0), p + Vector2(6, 0), Color("b4e8f8"), 2.0)
			draw_line(p - Vector2(0, 6), p + Vector2(0, 6), Color("b4e8f8"), 2.0)

static func template_data() -> Dictionary:
	return {
		"schema": 1, "name": "我的翡翠哨站",
		"route": [[-7, -3], [5, -3], [5, 0], [-5, 0], [-5, 3], [6, 3]],
		"pads": [[-5,-1],[-3,-1],[-1,-1],[1,-1],[3,-1],[6,-1],[-6,1],[-3,1],[-1,1],[1,1],[3,1],[5,1],[-3,2],[-1,2],[1,2],[3,2]],
		"waves": 8, "count": 12, "gold": 360, "seed": 42857
	}

static func _integer(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floor(value))

static func _valid_cell(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0]) and _integer(value[1]) and value[0] >= -7 and value[0] <= 7 and value[1] >= -4 and value[1] <= 4

static func _cell_key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]

static func _route_cells(route: Array) -> Array:
	var result: Array = []
	for i in range(route.size()):
		var current := Vector2i(int(route[i][0]), int(route[i][1]))
		if i == 0:
			result.append([current.x, current.y])
			continue
		var previous := Vector2i(int(route[i - 1][0]), int(route[i - 1][1]))
		var direction := Vector2i(signi(current.x - previous.x), signi(current.y - previous.y))
		var steps: int = absi(current.x - previous.x) + absi(current.y - previous.y)
		for step in range(1, steps + 1):
			var cell: Vector2i = previous + direction * step
			result.append([cell.x, cell.y])
	return result

static func _compact_route(route: Array) -> Array:
	var result: Array = []
	for value in route:
		var cell := [int(value[0]), int(value[1])]
		if result.size() >= 2:
			var a: Array = result[result.size() - 2]
			var b: Array = result[result.size() - 1]
			var first := Vector2i(b[0] - a[0], b[1] - a[1])
			var next := Vector2i(cell[0] - b[0], cell[1] - b[1])
			if (first.x == 0 and next.x == 0 and signi(first.y) == signi(next.y)) or (first.y == 0 and next.y == 0 and signi(first.x) == signi(next.x)):
				result.pop_back()
		result.append(cell)
	return result

static func canonical_data(data: Dictionary) -> Dictionary:
	# Call validate first for untrusted input. Fixed key order and pad sorting make
	# hashes stable through JSON's integer-to-float load conversion.
	var route: Array = _compact_route(data.get("route", []))
	var sorted_pads: Array = []
	for cell in data.get("pads", []):
		sorted_pads.append([int(cell[0]), int(cell[1])])
	sorted_pads.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return {"schema": 1, "name": str(data.get("name", "我的关卡")).strip_edges(), "route": route, "pads": sorted_pads, "waves": int(data.get("waves", 8)), "count": int(data.get("count", 12)), "gold": int(data.get("gold", 360)), "seed": int(data.get("seed", 42857))}

static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary:
		errors.append("关卡文件必须是对象")
		return errors
	if not _integer(data.get("schema")) or data.get("schema") != 1:
		errors.append("仅支持 schema 1 的本地关卡")
	var name_value: Variant = data.get("name")
	if not name_value is String or name_value.strip_edges().is_empty() or name_value.length() > 32:
		errors.append("关卡名称需为 1–32 个字符")
	for field in [["waves", 1, 12, "波数"], ["count", 8, 40, "每波敌人数"], ["gold", 100, 2000, "初始金币"], ["seed", 0, 2147483647, "随机种子"]]:
		var value: Variant = data.get(field[0])
		if not _integer(value) or value < field[1] or value > field[2]:
			errors.append("%s必须是 %d–%d 的整数" % [field[3], field[1], field[2]])
	var route_value: Variant = data.get("route")
	var route_ok := route_value is Array
	if not route_ok or route_value.size() < 2 or route_value.size() > 135:
		errors.append("路径需要 2–135 个有序格点")
		route_ok = false
	if route_ok:
		for cell in route_value:
			if not _valid_cell(cell):
				errors.append("路径格点必须位于 15×9 网格内，且坐标为整数")
				route_ok = false
				break
	if route_ok:
		for i in range(1, route_value.size()):
			var a: Array = route_value[i - 1]
			var b: Array = route_value[i]
			if a == b or (a[0] != b[0] and a[1] != b[1]):
				errors.append("路径只能水平或垂直连接，不可有重复的相邻格点")
				route_ok = false
				break
	var road: Dictionary = {}
	if route_ok:
		var cells: Array = _route_cells(route_value)
		if (cells.size() - 1) * TILE < 18.0:
			errors.append("路径至少需要 12 格步长（18 世界单位）")
		for cell in cells:
			var key := _cell_key(cell)
			if road.has(key):
				errors.append("路径不可自交、折返或重复经过同一格")
				break
			road[key] = true
	var pads_value: Variant = data.get("pads")
	if not pads_value is Array or pads_value.size() < 4 or pads_value.size() > 24:
		errors.append("需要 4–24 个防御塔基座")
	if pads_value is Array:
		var occupied: Dictionary = {}
		for cell in pads_value:
			if not _valid_cell(cell):
				errors.append("基座格点必须位于 15×9 网格内，且坐标为整数")
				break
			var key := _cell_key(cell)
			if occupied.has(key):
				errors.append("基座不可重复放置")
				break
			if road.has(key):
				errors.append("基座不可放在路径上")
				break
			occupied[key] = true
	return errors

static func _style(bg: Color, border: Color = Color("36535c"), padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func _label(g, text: String, size: int = 17, color: Color = INK) -> Label:
	var result: Label = g.label(text, size, color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func _button(g, text: String, callback: Callable) -> Button:
	var result: Button = g.button(text, callback)
	result.custom_minimum_size.y = 46
	result.add_theme_font_size_override("font_size", 17)
	return result

static func build(g) -> void:
	if g.has_meta("level_designer"):
		return
	var overlay := Control.new()
	overlay.name = "LocalLevelDesigner"
	overlay.z_index = 110
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	if g.ui_font:
		theme.default_font = g.ui_font
	theme.default_font_size = 17
	overlay.theme = theme
	g.hud.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.05, 0.94)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 0) if load("res://scripts/responsive_layout.gd").mobile() else Vector2(1210, 784)
	card.add_theme_stylebox_override("panel", _style(Color("102832"), Color("4b746f"), 24))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	col.add_child(header)
	var title := _label(g, "本地关卡设计器", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button(g, "返回战场  ×", close.bind(g)))
	col.add_child(_label(g, "仅保存在此设备 · 15×9 网格 · S 为入口，E 为终点 · 编辑期间战斗暂停", 17, MUTED))
	var body: BoxContainer = VBoxContainer.new() if load("res://scripts/responsive_layout.gd").mobile() else HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	col.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 8)
	left.add_child(tools_row)
	var tool_buttons: Array[Button] = []
	for tool in [["路径", "path"], ["基座", "pad"], ["擦除", "erase"]]:
		var b := _button(g, tool[0], _set_tool.bind(g, tool[1]))
		b.custom_minimum_size.x = 115
		tools_row.add_child(b)
		tool_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_row.add_child(spacer)
	tools_row.add_child(_button(g, "撤回一步", _undo.bind(g)))
	tools_row.add_child(_button(g, "清空路径", _clear_path.bind(g)))
	var grid := DesignGrid.new()
	grid.owner_game = g
	grid.custom_minimum_size = Vector2(1080, 648) if load("res://scripts/responsive_layout.gd").mobile() else Vector2(750, 450)
	left.add_child(grid)
	var hint := _label(g, "路径：依次点同一行或列的格子添加路段，可在末端转弯", 16, MUTED)
	left.add_child(hint)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	right.add_child(_label(g, "关卡设置", 21))
	var name_edit := LineEdit.new()
	name_edit.custom_minimum_size.y = 46
	name_edit.max_length = 32
	name_edit.placeholder_text = "关卡名称"
	right.add_child(name_edit)
	var fields: Dictionary = {}
	for config in [["waves", "波数", 1, 12], ["count", "每波敌人数", 8, 40], ["gold", "初始金币", 100, 2000]]:
		var row := HBoxContainer.new()
		var caption := _label(g, config[1])
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var spin := SpinBox.new()
		spin.min_value = config[2]
		spin.max_value = config[3]
		spin.step = 1
		spin.custom_minimum_size = Vector2(142, 48)
		spin.value_changed.connect(_setting_changed.bind(g, config[0]))
		row.add_child(spin)
		right.add_child(row)
		fields[config[0]] = spin
	var explanation := _label(g, "敌人随波次逐渐增强，使用固定混合编队。\n至少 4 个基座；路径至少 12 格步长。\n\n作者须通关，随后自动回放核验，才显示已验证", 17, MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size.x = 310
	right.add_child(explanation)
	var proof := _label(g, "尚未验证 · 完成试打后开始核验", 17, GOLD)
	proof.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	proof.custom_minimum_size.x = 310
	right.add_child(proof)
	right.add_child(_button(g, "重新核验已存回放", _verify_saved.bind(g)))
	var status := _label(g, "", 17, MINT)
	status.custom_minimum_size = Vector2(700 if load("res://scripts/responsive_layout.gd").mobile() else 1100, 48)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	for config in [["恢复示例", _reset.bind(g)], ["载入本地", _load_local.bind(g)], ["保存本地", _save_local.bind(g)]]:
		var b := _button(g, config[0], config[1])
		b.custom_minimum_size.x = 180
		actions.add_child(b)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	var play := _button(g, "开始试打  ▶", _playtest.bind(g))
	play.custom_minimum_size.x = 230
	play.add_theme_stylebox_override("normal", _style(Color("285349"), MINT))
	actions.add_child(play)
	var refs := {"overlay": overlay, "data": template_data(), "was_paused": false, "tool": "path", "grid": grid, "hint": hint, "status": status, "proof": proof, "name_edit": name_edit, "fields": fields, "tool_buttons": tool_buttons, "play": play, "syncing": false, "dirty": false, "invalidated_proof": "", "history": []}
	g.set_meta("level_designer", refs)
	name_edit.text_changed.connect(_name_changed.bind(g))
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close(g)
			overlay.accept_event()
	)
	_sync_controls(g)
	overlay.hide()

static func open(g) -> void:
	build(g)
	var refs: Dictionary = g.get_meta("level_designer")
	if not refs.overlay.visible:
		refs.was_paused = g.paused
	g.paused = true
	refs.overlay.show()
	refresh(g)
	g.refresh_ui()

static func close(g) -> void:
	if not is_open(g):
		return
	var refs: Dictionary = g.get_meta("level_designer")
	refs.overlay.hide()
	g.paused = bool(refs.was_paused)
	g.refresh_ui()

static func is_open(g) -> bool:
	return g.has_meta("level_designer") and is_instance_valid(g.get_meta("level_designer").overlay) and g.get_meta("level_designer").overlay.visible

static func _proof_snapshot() -> String:
	if not FileAccess.file_exists(PROOF_PATH):
		return ""
	var file := FileAccess.open(PROOF_PATH, FileAccess.READ)
	if file == null or file.get_length() > MAX_PROOF_BYTES:
		return ""
	return file.get_as_text().sha256_text()

static func _mark_changed(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	refs.dirty = true
	refs.invalidated_proof = _proof_snapshot()
	refresh(g)

static func _remember(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	refs.history.append(refs.data.duplicate(true))
	if refs.history.size() > 80:
		refs.history.pop_front()

static func _sync_controls(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	refs.syncing = true
	refs.name_edit.text = refs.data.name
	for key in refs.fields:
		refs.fields[key].value = refs.data[key]
	refs.syncing = false
	refresh(g)

static func _name_changed(value: String, g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	if refs.syncing:
		return
	refs.data.name = value
	_mark_changed(g)

static func _setting_changed(value: float, g, key: String) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	if refs.syncing:
		return
	refs.data[key] = int(value)
	_mark_changed(g)

static func _set_tool(g, tool: String) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	refs.tool = tool
	refresh(g)

static func _edit_cell(g, cell: Vector2i) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	var value := [cell.x, cell.y]
	if not _valid_cell(value):
		return
	var route: Array = refs.data.route
	var pads: Array = refs.data.pads
	var cells: Array = _route_cells(route)
	if refs.tool == "path":
		if not route.is_empty():
			var last: Array = route.back()
			if last == value:
				return
			if last[0] != cell.x and last[1] != cell.y:
				_feedback(g, "请点与路径末端同一行或列的格子；转弯时分两次点击")
				return
			var extension := _route_cells([last, value])
			extension.pop_front()
			for added in extension:
				if cells.has(added) or pads.has(added):
					_feedback(g, "新路段不能穿过已有路径或基座，请先擦除冲突的基座")
					return
		elif pads.has(value):
			_feedback(g, "入口不能放在基座上，请先擦除该基座")
			return
		_remember(g)
		route.append(value)
	elif refs.tool == "pad":
		if pads.has(value):
			_remember(g)
			pads.erase(value)
		elif cells.has(value):
			_feedback(g, "基座不能放在路径上")
			return
		elif pads.size() >= 24:
			_feedback(g, "最多可设置 24 个基座")
			return
		else:
			_remember(g)
			pads.append(value)
	else:
		if pads.has(value):
			_remember(g)
			pads.erase(value)
		elif cells.has(value):
			_remember(g)
			refs.data.route = _compact_route(cells.slice(0, cells.find(value)))
		else:
			return
	_mark_changed(g)

static func _feedback(g, message: String) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	refs.status.text = message
	refs.status.add_theme_color_override("font_color", GOLD)

static func _undo(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	if refs.history.is_empty():
		_feedback(g, "暂无可撤回的网格操作")
		return
	refs.data = refs.history.pop_back()
	_sync_controls(g)
	_mark_changed(g)

static func _clear_path(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	if refs.data.route.is_empty():
		return
	_remember(g)
	refs.data.route = []
	_mark_changed(g)

static func _reset(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	_remember(g)
	refs.data = template_data()
	_sync_controls(g)
	_mark_changed(g)

static func _save_local(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	var errors := validate(refs.data)
	if not errors.is_empty():
		_feedback(g, "无法保存：" + errors[0])
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_feedback(g, "本地保存失败（错误 %d），请检查设备可用空间" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(canonical_data(refs.data), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		_feedback(g, "本地保存失败（错误 %d），原存档可能未完整写入" % error)
		return
	_mark_changed(g)
	refs.dirty = false
	_feedback(g, "已保存到此设备；重新完成试打与自动回放后显示验证状态")

static func _load_local(g) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_feedback(g, "此设备还没有本地关卡，先编辑并保存一份")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		_feedback(g, "本地关卡无法读取，或文件超过安全大小限制")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var errors := validate(parsed)
	if not errors.is_empty():
		_feedback(g, "本地关卡无效：" + errors[0])
		return
	var refs: Dictionary = g.get_meta("level_designer")
	_remember(g)
	refs.data = canonical_data(parsed)
	refs.dirty = false
	refs.invalidated_proof = ""
	_sync_controls(g)
	_feedback(g, "已载入此设备的关卡，可继续编辑或试打")

static func _verify_saved(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	var errors := validate(refs.data)
	if not errors.is_empty():
		_feedback(g, "无法核验：" + errors[0])
		return
	if not ResourceLoader.exists("res://scripts/author_replay.gd"):
		_feedback(g, "当前版本尚无可用的回放核验器")
		return
	load("res://scripts/author_replay.gd").verify_saved(g, canonical_data(refs.data))

static func _playtest(g) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	var errors := validate(refs.data)
	if not errors.is_empty():
		_feedback(g, "无法试打：" + errors[0])
		return
	var data := canonical_data(refs.data)
	close(g)
	g.start_custom_level(data)

static func refresh(g) -> void:
	if not g.has_meta("level_designer"):
		return
	var refs: Dictionary = g.get_meta("level_designer")
	refs.grid.data = refs.data
	refs.grid.queue_redraw()
	var errors := validate(refs.data)
	refs.play.disabled = not errors.is_empty()
	var route: Array = refs.data.route
	var length := 0.0
	for i in range(1, route.size()):
		length += (absf(route[i][0] - route[i - 1][0]) + absf(route[i][1] - route[i - 1][1])) * TILE
	refs.status.text = "路径 %.1f 单位 · %d 个基座 · %d 波 × %d 敌人 · 可开始试打" % [length, refs.data.pads.size(), refs.data.waves, refs.data.count] if errors.is_empty() else "请调整：" + "；".join(errors.slice(0, 2))
	refs.status.add_theme_color_override("font_color", MINT if errors.is_empty() else GOLD)
	var names := ["path", "pad", "erase"]
	for i in range(names.size()):
		refs.tool_buttons[i].add_theme_stylebox_override("normal", _style(Color("285349") if refs.tool == names[i] else Color("18343e"), MINT if refs.tool == names[i] else Color("36535c"), 8))
	refs.hint.text = {"path": "路径：依次点同一行或列的格子添加路段，可在末端转弯", "pad": "基座：点击空格放置；再次点击移除（最多 24 个）", "erase": "擦除：点击移除基座；点击道路将从该格起截断后续路径"}[refs.tool]
	_refresh_proof(g, errors.is_empty())

static func _refresh_proof(g, valid: bool) -> void:
	var refs: Dictionary = g.get_meta("level_designer")
	refs.proof.text = "尚未验证 · 完成试打后开始核验"
	refs.proof.add_theme_color_override("font_color", GOLD)
	if not valid:
		refs.proof.text = "尚未验证 · 请先完成关卡设置"
		return
	var snapshot := _proof_snapshot()
	if snapshot.is_empty() or (not refs.invalidated_proof.is_empty() and snapshot == refs.invalidated_proof):
		return
	# The replay subsystem supplies the only trusted proof reader. No victory flag
	# in this editor can mark a level verified.
	if not ResourceLoader.exists("res://scripts/author_replay.gd"):
		return
	var verifier = load("res://scripts/author_replay.gd")
	if not verifier.has_method("read_verified"):
		return
	var proof: Variant = verifier.read_verified(canonical_data(refs.data))
	if proof is Dictionary and not proof.is_empty():
		refs.proof.text = "已验证 · 作者通关与自动回放均通过"
		refs.proof.add_theme_color_override("font_color", MINT)
