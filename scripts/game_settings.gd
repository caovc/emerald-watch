class_name GameSettings
extends RefCounted
## Persistent, immediately applied settings. State and UI references stay on the owner.

const SAVE_PATH := "user://settings.cfg"
const SECTION := "game"
const DEFAULTS := {
	"music_volume": 0.55,
	"sfx_volume": 0.75,
	"muted": false,
	"fullscreen": false,
	"quality": "high",
	"fps_cap": 60,
	"camera_zoom": 22.8,
	"show_ranges": true,
	"show_damage_numbers": true,
}
const INK := Color("e9f5f1")
const MUTED := Color("9cb9b9")
const MINT := Color("83ebc0")
const BORDER := Color("36535c")

static func build(g) -> void:
	if g.has_meta("settings_ui"):
		var previous: Dictionary = g.get_meta("settings_ui")
		if is_instance_valid(previous.get("overlay")):
			apply(g)
			return
	if not g.has_meta("settings_values"):
		g.set_meta("settings_values", _load_values())
	else:
		g.set_meta("settings_values", _sanitize(g.get_meta("settings_values")))

	var overlay := PanelContainer.new()
	overlay.name = "SettingsModal"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_theme_stylebox_override("panel", _style(Color(0.015, 0.035, 0.05, 0.88), Color.TRANSPARENT, 0, 0))
	var theme := Theme.new()
	if g.ui_font:
		theme.default_font = g.ui_font
	theme.default_font_size = 16
	overlay.theme = theme
	g.hud.add_child(overlay)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 700
	var card_style := _style(Color("102731"), Color("50776f"), 18, 26)
	card_style.shadow_color = Color(0, 0, 0, 0.4)
	card_style.shadow_size = 22
	card_style.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	card.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	header.add_child(title_col)
	title_col.add_child(_text(g, "翡翠哨站  /  SETTINGS", 13, MINT))
	title_col.add_child(_text(g, "游戏设置", 28))
	var close_button := _button(g, "×", func(): close(g))
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.tooltip_text = "返回战场 · Esc"
	header.add_child(close_button)
	column.add_child(_text(g, "调整即时生效 · 关闭后恢复进入设置前的暂停状态", 14, MUTED))
	_separator(column)

	var refs: Dictionary = {"overlay": overlay, "close_button": close_button}
	var columns: BoxContainer = VBoxContainer.new() if load("res://scripts/responsive_layout.gd").mobile() else HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	column.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 306
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 306
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)

	left.add_child(_text(g, "声音", 18, MINT))
	_add_slider(g, left, refs, "music_volume", "背景音乐", 0.0, 1.0, 0.01)
	_add_slider(g, left, refs, "sfx_volume", "战斗音效", 0.0, 1.0, 0.01)
	_add_toggle(g, left, refs, "muted", "全部静音", "保留音乐与音效的音量设置")
	_separator(left)
	left.add_child(_text(g, "战场显示", 18, MINT))
	_add_slider(g, left, refs, "camera_zoom", "镜头距离", 18.0, 28.0, 0.2)
	_add_toggle(g, left, refs, "show_ranges", "显示射程圈", "选择防御塔或预览部署时显示射程")
	_add_toggle(g, left, refs, "show_damage_numbers", "显示伤害数字", "在命中目标上方显示实际伤害")

	right.add_child(_text(g, "画面", 18, MINT))
	_add_toggle(g, right, refs, "fullscreen", "全屏模式", "关闭后返回窗口模式")
	_add_options(g, right, refs, "quality", "画质", [["高 · 抗锯齿 + 阴影", "high"], ["低 · 更轻量", "low"]])
	_add_options(g, right, refs, "fps_cap", "帧率上限", [["30 FPS", 30], ["60 FPS", 60], ["120 FPS", 120], ["无限制", 0]])
	var quality_help := _text(g, "低画质关闭 3D 抗锯齿与动态阴影", 13, MUTED)
	right.add_child(quality_help)
	_separator(right)
	right.add_child(_text(g, "操作提示", 18, MINT))
	var help := _text(g, "1–6  选择塔型\n左键  选择基座 / 防御塔\n空格  开始下一波\nP  暂停 / 继续\n右键 / Esc  取消选择\nEsc  关闭设置", 14, MUTED)
	help.add_theme_constant_override("line_spacing", 5)
	right.add_child(help)

	_separator(column)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	var reset_button := _button(g, "恢复默认", func(): reset_defaults(g))
	reset_button.custom_minimum_size.x = 120
	footer.add_child(reset_button)
	var status := _text(g, "设置会自动保存", 13, MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(status)
	refs["status"] = status
	var return_button := _button(g, "返回战场", func(): close(g), true)
	return_button.custom_minimum_size.x = 140
	footer.add_child(return_button)
	g.set_meta("settings_ui", refs)
	overlay.hide()
	_sync_ui(g)
	apply(g)

static func open(g) -> void:
	var existing: Dictionary = g.get_meta("settings_ui", {})
	if not is_instance_valid(existing.get("overlay")):
		build(g)
	if is_open(g):
		return
	var refs: Dictionary = g.get_meta("settings_ui")
	g.set_meta("settings_pause_before", g.paused)
	var focus: Control = g.get_viewport().gui_get_focus_owner()
	g.set_meta("settings_focus_before", weakref(focus) if is_instance_valid(focus) else false)
	g.paused = true
	_sync_ui(g)
	refs.overlay.show()
	refs.overlay.move_to_front()
	g.refresh_ui()

static func close(g) -> void:
	# In particular, a restart calling close() on a closed menu must not restore
	# a stale pause state from a previous visit to settings.
	if not is_open(g):
		return
	var refs: Dictionary = g.get_meta("settings_ui")
	refs.overlay.hide()
	g.paused = bool(g.get_meta("settings_pause_before", false))
	g.remove_meta("settings_pause_before")
	var previous_focus: Variant = g.get_meta("settings_focus_before", false)
	if previous_focus is WeakRef:
		var control: Control = previous_focus.get_ref()
		if is_instance_valid(control) and control.is_visible_in_tree():
			control.grab_focus()
	g.remove_meta("settings_focus_before")
	g.refresh_ui()

static func is_open(g) -> bool:
	if not g.has_meta("settings_ui"):
		return false
	var refs: Dictionary = g.get_meta("settings_ui")
	return is_instance_valid(refs.get("overlay")) and refs.overlay.visible

static func apply(g) -> void:
	if not g.has_meta("settings_values"):
		return
	var values: Dictionary = _sanitize(g.get_meta("settings_values"))
	g.set_meta("settings_values", values)
	if is_instance_valid(g.audio):
		g.audio.set_music_volume(values.music_volume)
		g.audio.set_sfx_volume(values.sfx_volume)
		g.audio.set_muted(values.muted)
	if is_instance_valid(g.camera):
		if g.has_meta("camera_controller"):
			g.get_meta("camera_controller").set_logical_zoom(values.camera_zoom)
		else:
			g.camera.size = values.camera_zoom
	g.show_ranges = values.show_ranges
	g.show_damage_numbers = values.show_damage_numbers
	if is_instance_valid(g.range_ring):
		if not g.show_ranges:
			g.range_ring.hide()
		elif g.has_method("update_range"):
			g.update_range()
	Engine.max_fps = values.fps_cap
	var viewport: Viewport = g.get_viewport()
	if is_instance_valid(viewport):
		viewport.msaa_3d = Viewport.MSAA_4X if values.quality == "high" else Viewport.MSAA_DISABLED
	for light in g.find_children("*", "DirectionalLight3D", true, false):
		light.shadow_enabled = values.quality == "high"
	# Headless CI has no native window; never ask its dummy display to change mode.
	if DisplayServer.get_name() != "headless" and not OS.has_feature("mobile"):
		var mode := DisplayServer.window_get_mode()
		var currently_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if values.fullscreen != currently_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

static func reset_defaults(g) -> void:
	g.set_meta("settings_values", DEFAULTS.duplicate(true))
	_sync_ui(g)
	apply(g)
	_save(g)
	g.show_toast("已恢复默认设置")

static func _changed(g, key: String, value: Variant) -> void:
	var values: Dictionary = g.get_meta("settings_values", DEFAULTS.duplicate(true))
	values[key] = value
	g.set_meta("settings_values", _sanitize(values))
	_sync_ui(g)
	apply(g)
	_save(g)

static func _load_values() -> Dictionary:
	var config := ConfigFile.new()
	var result := config.load(SAVE_PATH)
	var values: Dictionary = DEFAULTS.duplicate(true)
	if result == OK:
		for key in DEFAULTS:
			values[key] = config.get_value(SECTION, key, DEFAULTS[key])
	elif result != ERR_FILE_NOT_FOUND:
		push_warning("Cannot read settings.cfg; using defaults (error %d)." % result)
	return _sanitize(values)

static func _save(g) -> void:
	var config := ConfigFile.new()
	var values: Dictionary = g.get_meta("settings_values")
	for key in DEFAULTS:
		config.set_value(SECTION, key, values[key])
	var result := config.save(SAVE_PATH)
	if g.has_meta("settings_ui"):
		var refs: Dictionary = g.get_meta("settings_ui")
		if is_instance_valid(refs.get("status")):
			refs.status.text = "已自动保存" if result == OK else "保存失败 · 本次仍然生效"
			refs.status.add_theme_color_override("font_color", MUTED if result == OK else Color("f1a49c"))
	if result != OK:
		push_warning("Cannot save settings.cfg (error %d)." % result)

static func _sanitize(raw: Dictionary) -> Dictionary:
	var values: Dictionary = DEFAULTS.duplicate(true)
	values.music_volume = _number(raw.get("music_volume"), 0.55, 0.0, 1.0)
	values.sfx_volume = _number(raw.get("sfx_volume"), 0.75, 0.0, 1.0)
	values.camera_zoom = _number(raw.get("camera_zoom"), 22.8, 18.0, 28.0)
	for key in ["muted", "fullscreen", "show_ranges", "show_damage_numbers"]:
		if typeof(raw.get(key)) == TYPE_BOOL:
			values[key] = raw[key]
	if raw.get("quality") in ["low", "high"]:
		values.quality = raw.quality
	if raw.get("fps_cap") in [0, 30, 60, 120]:
		values.fps_cap = int(raw.fps_cap)
	return values

static func _number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var number := float(value)
	return clampf(number, minimum, maximum) if is_finite(number) else fallback

static func _sync_ui(g) -> void:
	if not g.has_meta("settings_ui"):
		return
	var refs: Dictionary = g.get_meta("settings_ui")
	var values: Dictionary = g.get_meta("settings_values")
	for key in ["music_volume", "sfx_volume", "camera_zoom"]:
		var slider: HSlider = refs[key]
		slider.set_value_no_signal(values[key])
		var readout: Label = refs[key + "_readout"]
		readout.text = "%.1f" % values[key] if key == "camera_zoom" else "%d%%" % roundi(values[key] * 100.0)
	for key in ["muted", "fullscreen", "show_ranges", "show_damage_numbers"]:
		var toggle: CheckButton = refs[key]
		toggle.set_pressed_no_signal(values[key])
	for key in ["quality", "fps_cap"]:
		var options: OptionButton = refs[key]
		for index in range(options.item_count):
			if options.get_item_metadata(index) == values[key]:
				options.select(index)
				break

static func _add_slider(g, parent: Node, refs: Dictionary, key: String, title: String, minimum: float, maximum: float, step: float) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 0)
	parent.add_child(group)
	var row := HBoxContainer.new()
	group.add_child(row)
	var title_label := _text(g, title, 15)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var readout := _text(g, "", 14, MINT)
	readout.custom_minimum_size.x = 52
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(0, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_stylebox_override("slider", _style(Color("203f49"), Color("375b60"), 3, 3))
	slider.add_theme_stylebox_override("grabber_area", _style(Color("438a75"), Color("438a75"), 3, 3))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style(MINT, MINT, 3, 3))
	slider.value_changed.connect(func(value: float): _changed(g, key, value))
	slider.tooltip_text = "数值越小，视角越近" if key == "camera_zoom" else "拖动调整音量，0% 为静音"
	group.add_child(slider)
	refs[key] = slider
	refs[key + "_readout"] = readout

static func _add_toggle(g, parent: Node, refs: Dictionary, key: String, title: String, tooltip: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.tooltip_text = tooltip
	toggle.custom_minimum_size.y = 34
	toggle.add_theme_color_override("font_color", INK)
	toggle.add_theme_color_override("font_hover_color", MINT)
	toggle.add_theme_font_size_override("font_size", 15)
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.toggled.connect(func(value: bool): _changed(g, key, value))
	parent.add_child(toggle)
	refs[key] = toggle

static func _add_options(g, parent: Node, refs: Dictionary, key: String, title: String, items: Array) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	parent.add_child(group)
	group.add_child(_text(g, title, 15))
	var options := OptionButton.new()
	options.custom_minimum_size.y = 36
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	options.add_theme_stylebox_override("normal", _style(Color("18343e"), BORDER, 8, 8))
	options.add_theme_stylebox_override("hover", _style(Color("244b4b"), MINT, 8, 8))
	options.add_theme_stylebox_override("pressed", _style(Color("306152"), MINT, 8, 8))
	options.add_theme_color_override("font_color", INK)
	options.add_theme_font_size_override("font_size", 15)
	for item in items:
		options.add_item(item[0])
		options.set_item_metadata(options.item_count - 1, item[1])
	options.item_selected.connect(func(index: int): _changed(g, key, options.get_item_metadata(index)))
	parent.add_child(options)
	refs[key] = options

static func _style(bg: Color, border: Color = BORDER, radius: int = 10, padding: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func _button(g, title: String, callback: Callable, accent: bool = false) -> Button:
	var result: Button = g.button(title, callback, accent)
	result.custom_minimum_size.y = 40
	result.add_theme_font_size_override("font_size", 15)
	result.add_theme_stylebox_override("normal", _style(Color("245546") if accent else Color("18343e"), Color("599b7d") if accent else BORDER, 9, 8))
	result.add_theme_stylebox_override("hover", _style(Color("306152"), MINT, 9, 8))
	result.add_theme_stylebox_override("pressed", _style(Color("397663"), Color("c4ffe4"), 9, 8))
	result.add_theme_color_override("font_color", INK)
	return result

static func _text(g, value: String, size: int = 16, color: Color = INK) -> Label:
	var result: Label = g.label(value, size, color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func _separator(parent: Node) -> void:
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _style(Color("2b4851"), Color("2b4851"), 0, 0))
	separator.custom_minimum_size.y = 1
	parent.add_child(separator)
