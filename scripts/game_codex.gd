class_name GameCodex
extends RefCounted
## On-demand field guide. Opening pauses combat and closing restores its state.

const INK := Color("e9f5f1")
const MUTED := Color("a4bdba")
const MINT := Color("83ebc0")
const GOLD := Color("ffd397")

static func _style(bg: Color, border: Color = Color("36535c"), padding: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func _label(g, text: String, size: int = 17, color: Color = INK) -> Label:
	var l: Label = g.label(text, size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _button(g, text: String, action: Callable) -> Button:
	var b: Button = g.button(text, action)
	b.custom_minimum_size.y = 42
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", _style(Color("18343e"), Color("36535c"), 8))
	b.add_theme_stylebox_override("hover", _style(Color("30594f"), MINT, 8))
	b.add_theme_stylebox_override("pressed", _style(Color("3a6d5c"), MINT, 8))
	return b

static func build(g) -> void:
	if g.has_meta("game_codex"):
		return
	var overlay := Control.new()
	overlay.name = "FieldCodex"
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	if g.ui_font:
		theme.default_font = g.ui_font
	theme.default_font_size = 17
	overlay.theme = theme
	g.hud.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.035, 0.05, 0.91)
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 0) if load("res://scripts/responsive_layout.gd").mobile() else Vector2(1180, 734)
	card.add_theme_stylebox_override("panel", _style(Color("102832"), Color("4b746f"), 26))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	col.add_child(header)
	var title := _label(g, "战地资料库", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button(g, "返回战场  ×", close.bind(g)))
	var note := _label(g, "随时查阅塔型、升级收益与敌人克制关系 · 查阅期间战斗暂停", 17, MUTED)
	col.add_child(note)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	var tower_tab := _button(g, "防御塔  /  6", _set_tab.bind(g, 0))
	tower_tab.custom_minimum_size.x = 176
	tabs.add_child(tower_tab)
	var enemy_tab := _button(g, "敌人  /  7", _set_tab.bind(g, 1))
	enemy_tab.custom_minimum_size.x = 176
	tabs.add_child(enemy_tab)
	var wave_note := _label(g, "", 16, MUTED)
	wave_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(wave_note)
	var body: BoxContainer = VBoxContainer.new() if load("res://scripts/responsive_layout.gd").mobile() else HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.y = 0 if load("res://scripts/responsive_layout.gd").mobile() else 500
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 180 if load("res://scripts/responsive_layout.gd").mobile() else 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _style(Color("16313a"), Color("34535b"), 22))
	body.add_child(detail_panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 14)
	detail_panel.add_child(detail)
	var refs := {"overlay": overlay, "tab": 0, "index": 0, "was_paused": false, "key": "", "list": list, "detail": detail, "tower_tab": tower_tab, "enemy_tab": enemy_tab, "wave_note": wave_note}
	g.set_meta("game_codex", refs)
	overlay.hide()

static func open(g) -> void:
	build(g)
	var refs: Dictionary = g.get_meta("game_codex")
	if not refs.overlay.visible:
		refs.was_paused = g.paused
		if not g.selected_enemy.is_empty():
			refs.tab = 1
			refs.index = int(g.selected_enemy.kind)
		else:
			refs.tab = 0
			refs.index = int(g.selected_kind)
	refs.key = ""
	g.paused = true
	refs.overlay.show()
	refresh(g)
	g.refresh_ui()

static func close(g) -> void:
	if not is_open(g):
		return
	var refs: Dictionary = g.get_meta("game_codex")
	refs.overlay.hide()
	g.paused = bool(refs.was_paused)
	g.refresh_ui()

static func is_open(g) -> bool:
	return g.has_meta("game_codex") and is_instance_valid(g.get_meta("game_codex").overlay) and g.get_meta("game_codex").overlay.visible

static func _set_tab(g, tab: int) -> void:
	var refs: Dictionary = g.get_meta("game_codex")
	refs.tab = tab
	refs.index = 0
	refs.key = ""
	refresh(g)

static func _select(g, index: int) -> void:
	var refs: Dictionary = g.get_meta("game_codex")
	refs.index = index
	refs.key = ""
	refresh(g)

static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func refresh(g) -> void:
	if not is_open(g):
		return
	var refs: Dictionary = g.get_meta("game_codex")
	var current_wave: int = maxi(1, g.wave)
	var key := "%d:%d:%d:%d" % [refs.tab, refs.index, current_wave, g.level_index]
	if refs.key == key:
		return
	refs.key = key
	refs.wave_note.text = "当前关卡 · 第 %d 波属性" % current_wave if refs.tab == 1 else "实战数值 · 3 个升级等级"
	for i in range(2):
		var b: Button = refs.tower_tab if i == 0 else refs.enemy_tab
		b.add_theme_stylebox_override("normal", _style(Color("285349") if i == refs.tab else Color("18343e"), MINT if i == refs.tab else Color("36535c"), 8))
	_clear(refs.list)
	_clear(refs.detail)
	var count: int = g.TOWER_DATA.size() if refs.tab == 0 else 7
	refs.index = clampi(int(refs.index), 0, count - 1)
	for i in range(count):
		var data: Dictionary = g.TOWER_DATA[i] if refs.tab == 0 else g.enemy_stats(i, current_wave)
		var accent: Color = data.color
		var b := _button(g, "%02d   %s" % [i + 1, data.name], _select.bind(g, i))
		b.custom_minimum_size = Vector2(260, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", INK if i == refs.index else accent.lightened(0.15))
		b.add_theme_stylebox_override("normal", _style(Color("2a4e46") if i == refs.index else Color("142c36"), accent if i == refs.index else Color("2d4852"), 12))
		refs.list.add_child(b)
	if refs.tab == 0:
		_tower_detail(g, refs.detail, g.TOWER_DATA[refs.index])
	else:
		_enemy_detail(g, refs.detail, g.enemy_stats(refs.index, current_wave), current_wave)

static func _identity(g, parent: VBoxContainer, title: String, category: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(74, 74)
	chip.add_theme_stylebox_override("panel", _style(color.darkened(0.76), color, 6))
	row.add_child(chip)
	var mark := _label(g, "◆", 36, color)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(mark)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	names.add_child(_label(g, category, 16, color))
	names.add_child(_label(g, title, 30))

static func _paragraph(g, parent: VBoxContainer, text: String, color: Color = MUTED) -> Label:
	var l := _label(g, text, 17, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 720
	parent.add_child(l)
	return l

static func _table_cell(g, grid: GridContainer, text: String, color: Color = INK, heading: bool = false) -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(174, 44)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _style(Color("24453f") if heading else Color("122b34"), Color("35534f") if heading else Color("203e47"), 8))
	grid.add_child(box)
	var label := _label(g, text, 17, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

static func _tower_detail(g, parent: VBoxContainer, d: Dictionary) -> void:
	_identity(g, parent, d.name, "防御设施  /  %s" % d.tag, d.color)
	_paragraph(g, parent, d.desc)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for text in ["升级数据", "等级 1", "等级 2", "等级 3"]:
		_table_cell(g, grid, text, MINT, true)
	var rows := [
		["建造 / 升级", "%d 金" % d.cost, "%d 金" % int(d.cost * g.UPGRADE_PRICE[0]), "%d 金" % int(d.cost * g.UPGRADE_PRICE[1])],
		["攻击伤害", "%.1f" % d.damage, "%.1f" % (d.damage * g.UPGRADE_DAMAGE[0]), "%.1f" % (d.damage * g.UPGRADE_DAMAGE[0] * g.UPGRADE_DAMAGE[1])],
		["攻击射程", "%.2f" % d.range, "%.2f" % (d.range + g.UPGRADE_RANGE[0]), "%.2f" % (d.range + g.UPGRADE_RANGE[0] + g.UPGRADE_RANGE[1])],
		["攻击间隔", "%.2f 秒" % d.cooldown, "%.2f 秒" % (d.cooldown / 1.12), "%.2f 秒" % (d.cooldown / 1.24)]
	]
	for row in rows:
		for i in range(row.size()):
			_table_cell(g, grid, row[i], MUTED if i == 0 else INK)
	_paragraph(g, parent, "等级 1 为建造价；等级 2、3 为该次升级费用。二级伤害 ×1.65、射程 +0.45；三级伤害 ×1.8、射程 +0.55。", MUTED)
	_paragraph(g, parent, "出售返还累计投入的 70%。点击已建造的塔，可查看当前属性与下一等级的变化。", GOLD)

static func _enemy_detail(g, parent: VBoxContainer, d: Dictionary, current_wave: int) -> void:
	_identity(g, parent, d.name, "敌军档案  /  第 %d 波" % current_wave, d.color)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for text in ["最大生命", "移动速度", "护甲减伤", "初始护盾"]:
		_table_cell(g, grid, text, MUTED, true)
	for text in ["%.0f" % d.hp, "%.2f / 秒" % d.speed, "%.0f%%" % (float(d.armor) * 100.0), "%.0f" % d.shield]:
		_table_cell(g, grid, text, INK)
	parent.add_child(_label(g, "特殊能力", 18, d.color))
	_paragraph(g, parent, d.ability, INK)
	parent.add_child(_label(g, "推荐应对", 18, MINT))
	_paragraph(g, parent, d.counter, INK)
	_paragraph(g, parent, "数值按当前关卡第 %d 波计算；敌人生命会随波次增长。点击战场上的敌人，可查看实时生命、护盾与减速、灼烧状态。" % current_wave, MUTED)
