extends Node
## Keep rendering fullscreen; only interactive content is inset for device cutouts.
var game: Node
var last_size := Vector2.ZERO
var last_safe := Rect2()
var seen_modals: Dictionary = {}

static func mobile() -> bool:
	return OS.has_feature("mobile") or "--mobile-ui" in OS.get_cmdline_user_args()

static func safe_rect(g) -> Rect2:
	var size: Vector2 = g.get_viewport().get_visible_rect().size
	if g.has_meta("test_safe_area"):
		return Rect2(g.get_meta("test_safe_area")).intersection(Rect2(Vector2.ZERO, size))
	if not mobile() or DisplayServer.get_name() == "headless":
		return Rect2(Vector2.ZERO, size)
	var window := Vector2(DisplayServer.window_get_size())
	var area := Rect2(DisplayServer.get_display_safe_area())
	if window.x <= 0 or window.y <= 0 or area.size.x <= 0 or area.size.y <= 0:
		return Rect2(Vector2.ZERO, size)
	var ratio := size / window
	return Rect2(area.position * ratio, area.size * ratio).intersection(Rect2(Vector2.ZERO, size))

static func install(g) -> void:
	var node = load("res://scripts/responsive_layout.gd").new()
	node.game = g
	g.add_child(node)
	g.set_meta("responsive_layout", node)
	if mobile():
		g.get_window().content_scale_size = Vector2i(960, 600)
	g.get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	node.call_deferred("layout")
	if mobile():
		node.call_deferred("show_touch_hint")

func _process(_delta: float) -> void:
	var size: Vector2 = game.get_viewport().get_visible_rect().size
	var safe := safe_rect(game)
	if size != last_size or safe != last_safe:
		layout()
	for key in ["game_codex", "settings_ui", "level_designer"]:
		if game.has_meta(key):
			var overlay: Control = game.get_meta(key).overlay
			if not seen_modals.has(overlay.get_instance_id()):
				adapt_modal(overlay)
			if overlay.visible:
				touch_targets(overlay)
	if is_instance_valid(game.level_overlay) and not seen_modals.has(game.level_overlay.get_instance_id()):
		adapt_modal(game.level_overlay)

func touch_targets(node: Node) -> void:
	if mobile() and (node is Label or node is Button or node is LineEdit):
		if not node.has_meta("mobile_font_applied"):
			node.set_meta("mobile_font_applied", true)
			node.add_theme_font_size_override("font_size", maxi(20, int(node.get_theme_font_size("font_size") * 1.2)))
	if node is BaseButton or node is Slider or node is LineEdit or node is SpinBox:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 72.0 if mobile() else 44.0)
		if node is BaseButton:
			node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, 72.0 if mobile() else 44.0)
	for child in node.get_children():
		touch_targets(child)

func adapt_modal(overlay: Control) -> void:
	seen_modals[overlay.get_instance_id()] = weakref(overlay)
	var center: CenterContainer
	for child in overlay.get_children():
		if child is CenterContainer:
			center = child
	if center == null or center.get_child_count() == 0:
		return
	var card: Control = center.get_child(0)
	center.remove_child(card)
	# Scroll instead of shrinking text or clipping controls on short phone displays.
	var margin := MarginContainer.new()
	margin.name = "SafeModalMargin"
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.name = "SafeModalScroll"
	margin.add_child(scroll)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	holder.add_child(card)
	center.queue_free()
	touch_targets(card)
	if mobile():
		card.custom_minimum_size.x = minf(card.custom_minimum_size.x, 900.0)
	position_modal(overlay)

func position_modal(overlay: Control) -> void:
	var margin := overlay.get_node_or_null("SafeModalMargin") as MarginContainer
	if margin == null:
		return
	var area := safe_rect(game).grow(-12)
	margin.add_theme_constant_override("margin_left", int(area.position.x))
	margin.add_theme_constant_override("margin_top", int(area.position.y))
	margin.add_theme_constant_override("margin_right", int(last_size.x - area.end.x))
	margin.add_theme_constant_override("margin_bottom", int(last_size.y - area.end.y))

func layout() -> void:
	if not game.has_meta("game_ui"):
		return
	last_size = game.get_viewport().get_visible_rect().size
	last_safe = safe_rect(game)
	var a := last_safe.grow(-12)
	var r: Dictionary = game.get_meta("game_ui")
	var compact := mobile() or a.size.x < 1380
	var top: PanelContainer = r.top
	var header: HBoxContainer = r.header
	if compact and not r.has("status_row"):
		var column := VBoxContainer.new()
		top.remove_child(header)
		top.add_child(column)
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 16)
		column.add_child(stats)
		for item in [r.level_title, game.money_label, game.hp_label, game.wave_label, game.phase_label]:
			header.remove_child(item)
			stats.add_child(item)
		column.add_child(header)
		r.status_row = stats
		game.set_meta("game_ui", r)
	elif not compact and r.has("status_row"):
		var stats: HBoxContainer = r.status_row
		var column: VBoxContainer = header.get_parent()
		column.remove_child(header)
		top.remove_child(column)
		top.add_child(header)
		var index := 0
		for item in stats.get_children():
			stats.remove_child(item)
			header.add_child(item)
			header.move_child(item, index)
			index += 1
		column.queue_free()
		r.erase("status_row")
		game.set_meta("game_ui", r)
	if mobile() and not r.has("mobile_actions"):
		for button in [r.ability_button, r.gate_button]:
			r.actions.remove_child(button)
			r.root.add_child(button)
			button.clip_text = true
			button.custom_minimum_size = Vector2(72, 72)
		r.root.remove_child(r.camera_reset)
		header.add_child(r.camera_reset)
		r.camera_reset.custom_minimum_size = Vector2(72, 72)
		r.actions.hide()
		r.mobile_actions = true
		game.set_meta("game_ui", r)
	if mobile() and not r.has("context_scroll"):
		var context: PanelContainer = r.context
		var content: Control = context.get_child(0)
		context.remove_child(content)
		var context_scroll := ScrollContainer.new()
		context_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		context_scroll.custom_minimum_size = Vector2(290, 270)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		context.add_child(context_scroll)
		context_scroll.add_child(content)
		r.context_scroll = context_scroll
		game.set_meta("game_ui", r)
	touch_targets(r.root)
	r.level_title.custom_minimum_size.x = 100 if compact else 230
	top.position = a.position
	top.size = Vector2(a.size.x, 0)
	var header_height: float = top.get_combined_minimum_size().y
	var dock: PanelContainer = r.dock
	dock.size = Vector2(608, 0)
	dock.position = Vector2(a.get_center().x - dock.size.x / 2, a.end.y - dock.get_combined_minimum_size().y)
	if not mobile():
		r.camera_reset.size.y = 44
		r.camera_reset.position = Vector2(a.end.x - 90, a.end.y - r.camera_reset.size.y)
	else:
		var side_width: float = maxf(72, (a.size.x - dock.size.x) / 2 - 8)
		r.ability_button.position = Vector2(a.position.x, dock.position.y + 8)
		r.ability_button.size = Vector2(side_width, 72)
		r.gate_button.position = Vector2(a.end.x - side_width, dock.position.y + 8)
		r.gate_button.size = Vector2(side_width, 72)
	r.camera_hint.visible = not compact
	r.camera_hint.position = Vector2(a.position.x, a.end.y - 32)
	r.wave_preview.visible = not compact
	r.wave_preview.position = Vector2(a.position.x + 10, a.position.y + header_height + 8)
	r.wave_preview.size.x = maxf(100, a.size.x - 510)
	var action_width: float = maxf(490.0, r.actions.get_combined_minimum_size().x)
	r.actions.position = Vector2(a.end.x - action_width, a.position.y + header_height + 8)
	r.actions.size = Vector2(action_width, 0)
	game.toast_label.position = Vector2(a.position.x, dock.position.y - 36)
	game.toast_label.size.x = a.size.x
	for id in seen_modals:
		var overlay = seen_modals[id].get_ref()
		if is_instance_valid(overlay):
			position_modal(overlay)
	if not seen_modals.has(game.end_panel.get_instance_id()):
		adapt_modal(game.end_panel)

func show_touch_hint() -> void:
	game.show_toast("从底部拖动塔到基座，或点选塔再点基座", 8)
