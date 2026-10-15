class_name GameUI
extends RefCounted
## Compact battlefield HUD. Extra references live in owner metadata.

const INK := Color("e9f5f1")
const MUTED := Color("9cb9b9")
const MINT := Color("83ebc0")
const GOLD := Color("ffd397")
const RED := Color("f1a49c")
const SURFACE := Color("102731")
const BORDER := Color("36535c")

static func _style(bg: Color, border: Color = BORDER, radius: int = 12, padding: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func _panel(parent: Node, rect: Rect2, padding: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = rect.position
	p.size = rect.size
	var s := _style(Color(0.045, 0.105, 0.14, 0.96), BORDER, 14, padding)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

static func _button(g, text: String, action: Callable, accent: bool = false) -> Button:
	var b: Button = g.button(text, action, accent)
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size.y = 40
	b.add_theme_stylebox_override("normal", _style(Color("245546") if accent else Color("18343e"), Color("599b7d") if accent else BORDER, 9, 8))
	b.add_theme_stylebox_override("hover", _style(Color("306152"), MINT, 9, 8))
	b.add_theme_stylebox_override("pressed", _style(Color("397663"), Color("c4ffe4"), 9, 8))
	b.add_theme_stylebox_override("disabled", _style(Color("152b33"), Color("28404a"), 9, 8))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("91a4a5"))
	return b

static func _text(g, text: String, size: int = 16, color: Color = INK) -> Label:
	var l: Label = g.label(text, size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _separator(parent: Node) -> void:
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator", _style(Color("2b4851"), Color("2b4851"), 0, 0))
	line.custom_minimum_size.y = 1
	parent.add_child(line)

static func build(g) -> void:
	g.hud = CanvasLayer.new()
	g.add_child(g.hud)
	var root := Control.new()
	root.name = "BattleHUD"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	if g.ui_font:
		theme.default_font = g.ui_font
	theme.default_font_size = 18
	root.theme = theme
	g.hud.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var refs: Dictionary = {"root": root}
	g.set_meta("game_ui", refs)

	# One slim header; the entire battlefield remains available below it.
	var top := _panel(root, Rect2(16, 14, 1408, 60), 10)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	top.add_child(header)
	var level_title := _text(g, "翡翠哨站", 22)
	level_title.custom_minimum_size.x = 230
	level_title.clip_text = true
	level_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(level_title)
	refs["level_title"] = level_title
	g.money_label = _text(g, "", 20, GOLD)
	g.hp_label = _text(g, "", 20, MINT)
	g.wave_label = _text(g, "", 20)
	for l in [g.money_label, g.hp_label, g.wave_label]:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(l)
	g.money_label.custom_minimum_size.x = 100
	g.hp_label.custom_minimum_size.x = 145
	g.wave_label.custom_minimum_size.x = 135
	g.phase_label = _text(g, "部署阶段", 16, MUTED)
	g.phase_label.custom_minimum_size.x = 84
	g.phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(g.phase_label)
	var codex_button := _button(g, "资料库", g.show_codex)
	codex_button.custom_minimum_size.x = 75
	codex_button.tooltip_text = "查看防御塔与敌人的完整数据"
	header.add_child(codex_button)
	var designer_button := _button(g, "设计", g.open_designer)
	designer_button.custom_minimum_size.x = 65
	designer_button.tooltip_text = "打开本地关卡设计器"
	header.add_child(designer_button)
	var settings_button := _button(g, "设置", g.open_settings)
	settings_button.custom_minimum_size.x = 65
	header.add_child(settings_button)
	var levels_button := _button(g, "关卡", g.show_level_select)
	levels_button.custom_minimum_size.x = 65
	header.add_child(levels_button)
	g.speed_button = _button(g, "1×", g.toggle_speed)
	g.speed_button.custom_minimum_size.x = 54
	g.speed_button.tooltip_text = "切换战斗速度"
	header.add_child(g.speed_button)
	g.pause_button = _button(g, "暂停", g.toggle_pause)
	g.pause_button.custom_minimum_size.x = 65
	g.pause_button.tooltip_text = "P 暂停 / 继续"
	header.add_child(g.pause_button)
	g.next_button = _button(g, "开始第 1 波", g.start_wave, true)
	g.next_button.custom_minimum_size.x = 176
	g.next_button.tooltip_text = "空格 开始下一波"
	header.add_child(g.next_button)
	var preview := _text(g, "", 16, Color("bdd5d0"))
	preview.position = Vector2(30, 84)
	preview.size = Vector2(900, 26)
	preview.clip_text = true
	preview.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	preview.add_theme_constant_override("shadow_offset_x", 1)
	preview.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(preview)
	refs["top"] = top
	refs["header"] = header
	refs["wave_preview"] = preview
	var actions := HBoxContainer.new()
	actions.position = Vector2(934, 84)
	actions.size = Vector2(490, 40)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var ability := _button(g, "Q  核心震荡 · 就绪", g.use_ability)
	ability.custom_minimum_size = Vector2(224, 38)
	ability.tooltip_text = "Q 核心震荡：全场穿甲伤害，并减速 3 秒\n伤害 = 90 + 当前波次 × 8 · 冷却 35 秒"
	actions.add_child(ability)
	var gate := _button(g, "E  切换入口", g.toggle_gate)
	gate.custom_minimum_size = Vector2(244, 38)
	gate.tooltip_text = "E 切换下一只虫群的入口路线\n冷却时间 12 秒"
	actions.add_child(gate)
	refs["actions"] = actions
	refs["ability_button"] = ability
	refs["gate_button"] = gate

	# Compact model thumbnails, rendered from the exact battlefield tower factory.
	var dock := _panel(root, Rect2(416, 814, 608, 70), 8)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	dock.add_child(cards)
	g.tower_buttons.clear()
	var thumbnails: Array[TextureRect] = []
	var prices: Array[Label] = []
	var thumbnail_viewports: Array[SubViewport] = []
	for i in range(g.TOWER_DATA.size()):
		var data: Dictionary = g.TOWER_DATA[i]
		var b := _button(g, "", g.select_kind.bind(i))
		b.custom_minimum_size = Vector2(92, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s\n%s\n伤害 %.0f · 射程 %.1f · 攻击间隔 %.2f 秒\n快捷键 %d：选择，再点击空基座部署" % [data.name, data.desc, data.damage, data.range, data.cooldown, i + 1]
		cards.add_child(b)
		g.tower_buttons.append(b)
		var viewport := _tower_thumbnail(g, b, i)
		thumbnail_viewports.append(viewport)
		var picture := TextureRect.new()
		picture.texture = viewport.get_texture()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(0, -1)
		picture.size = Vector2(58, 55)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(picture)
		thumbnails.append(picture)
		var key := _text(g, str(i + 1), 16, Color("cce0db"))
		key.position = Vector2(68, 1)
		key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		key.add_theme_constant_override("shadow_offset_y", 1)
		b.add_child(key)
		var price_back := PanelContainer.new()
		price_back.position = Vector2(52, 31)
		price_back.size = Vector2(36, 21)
		price_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_back.add_theme_stylebox_override("panel", _style(Color(0.025, 0.065, 0.085, 0.92), Color(0, 0, 0, 0), 5, 0))
		b.add_child(price_back)
		var price := _text(g, str(data.cost), 16, GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_back.add_child(price)
		prices.append(price)
	refs["dock"] = dock
	refs["tower_thumbnails"] = thumbnails
	refs["tower_prices"] = prices
	refs["thumbnail_viewports"] = thumbnail_viewports
	var camera_reset := _button(g, "复位", _reset_view.bind(g))
	camera_reset.position = Vector2(1334, 824)
	camera_reset.size = Vector2(90, 44)
	camera_reset.tooltip_text = "Home 复位视角\n滚轮缩放 · 中键 / Shift+拖动平移\n触屏：拖动平移 · 双指缩放"
	root.add_child(camera_reset)
	var camera_hint := _text(g, "拖动平移 · 双指缩放" if OS.has_feature("mobile") else "滚轮缩放 · 中键拖动平移", 16, MUTED)
	camera_hint.position = Vector2(24, 838)
	root.add_child(camera_hint)
	refs["camera_reset"] = camera_reset
	refs["camera_hint"] = camera_hint

	# Context is hidden until a pad is selected, and placed on the opposite side.
	var context := _panel(root, Rect2(1116, 330, 300, 0), 14)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	context.add_child(col)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	col.add_child(title_row)
	var context_title := _text(g, "", 21)
	context_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(context_title)
	var close := _button(g, "×", g.select_pad.bind(-1))
	close.custom_minimum_size = Vector2(30, 30)
	close.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 3))
	close.tooltip_text = "取消选择 · Esc"
	title_row.add_child(close)
	var context_state := _text(g, "", 16, MINT)
	col.add_child(context_state)
	_separator(col)
	g.info_label = _text(g, "", 16, Color("bfd4d0"))
	g.info_label.custom_minimum_size.x = 270
	g.info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(g.info_label)
	g.build_button = _button(g, "建造", g.build_selected, true)
	col.add_child(g.build_button)
	g.upgrade_button = _button(g, "升级", g.upgrade_selected, true)
	col.add_child(g.upgrade_button)
	g.sell_button = _button(g, "出售", g.sell_selected)
	g.sell_button.add_theme_color_override("font_color", RED)
	g.sell_button.add_theme_stylebox_override("normal", _style(Color("3b3035"), Color("705157"), 9, 8))
	col.add_child(g.sell_button)
	context.hide()
	refs["context"] = context
	refs["context_title"] = context_title
	refs["context_state"] = context_state

	g.toast_label = _text(g, "", 17, Color("e1fff0"))
	g.toast_label.position = Vector2(270, 766)
	g.toast_label.size = Vector2(900, 32)
	g.toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	g.toast_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(g.toast_label)
	_build_end(g, root, refs)
	g.set_meta("game_ui", refs)
	load("res://scripts/responsive_layout.gd").install(g)

static func _tower_thumbnail(g, parent: Control, kind: int) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TowerPreview%d" % kind
	viewport.size = Vector2i(144, 144)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5d7df")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("ffe5c1")
	sun.light_energy = 1.55
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.10
	camera.position = Vector3(2.8, 2.5, -3.7)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.82, 0))
	camera.current = true
	var model: Node3D = g.build_tower_model(kind, Vector3.ZERO, 1)
	model.name = "ExactTowerModel%d" % kind
	model.reparent(stage, false)
	model.position = Vector3.ZERO
	return viewport

static func _reset_view(g) -> void:
	if g.has_meta("camera_controller"):
		g.get_meta("camera_controller").reset_view()

static func _overlay(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_theme_stylebox_override("panel", _style(Color(0.015, 0.035, 0.05, 0.86), Color(0, 0, 0, 0), 0, 0))
	return p

static func _build_end(g, root: Control, refs: Dictionary) -> void:
	g.end_panel = _overlay(root)
	var center := CenterContainer.new()
	g.end_panel.add_child(center)
	var card := _panel(center, Rect2(0, 0, 610, 0), 30)
	card.custom_minimum_size.x = 610
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	var eyebrow := _text(g, "翡翠哨站  /  战场报告", 16, MINT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(eyebrow)
	g.end_title = _text(g, "", 34)
	g.end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(g.end_title)
	g.end_desc = _text(g, "", 19, MUTED)
	g.end_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.end_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.end_desc.custom_minimum_size = Vector2(550, 78)
	col.add_child(g.end_desc)
	_separator(col)
	var next_level_button := _button(g, "继续下一关  →", g.next_level, true)
	col.add_child(next_level_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var retry := _button(g, "重新挑战", g.restart)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(retry)
	var choose := _button(g, "选择其他关卡", g.show_level_select)
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choose)
	refs["next_level_button"] = next_level_button
	g.end_panel.hide()

static func refresh(g) -> void:
	if not g.has_meta("game_ui") or not is_instance_valid(g.money_label):
		return
	var refs: Dictionary = g.get_meta("game_ui")
	var stage: Dictionary = g.current_level()
	var custom: bool = not g.custom_level_data.is_empty()
	refs.level_title.text = "自制  /  %s" % stage.name if custom else "%02d  /  %s" % [g.level_index + 1, stage.name]
	refs.level_title.tooltip_text = "%s\n%s\n%s" % [stage.name, stage.subtitle, stage.description]
	g.money_label.text = "金币  %d" % g.money
	g.hp_label.text = "核心  %d / 20" % g.health
	g.hp_label.add_theme_color_override("font_color", RED if g.health <= 5 else MINT)
	g.wave_label.text = "波次  %02d / %02d" % [g.wave, g.wave_total()]
	g.phase_label.text = "战斗结束" if g.ended else ("已暂停" if g.paused else ("防守中" if g.active_wave else "部署阶段"))
	g.phase_label.add_theme_color_override("font_color", GOLD if g.paused else MUTED)
	g.pause_button.text = "继续" if g.paused else "暂停"
	g.pause_button.disabled = g.ended
	g.speed_button.text = "%d×" % int(g.speed)
	g.speed_button.disabled = g.ended
	g.next_button.disabled = g.active_wave or g.ended or g.paused
	g.next_button.text = "战斗进行中" if g.active_wave else ("已完成防守" if g.ended else "开始第 %d 波  →" % mini(g.wave + 1, g.wave_total()))
	if g.active_wave:
		refs.wave_preview.text = "战场情报  /  场上 %d  ·  待入场 %d  ·  %s" % [g.enemies.size(), g.remaining, String(g.next_wave_description()).replace("\n", "  ")]
	else:
		refs.wave_preview.text = "下一波  /  %s" % String(g.next_wave_description()).replace("\n", "  ")
	refs.wave_preview.visible = not g.ended and not load("res://scripts/responsive_layout.gd").mobile()
	refs.ability_button.text = "Q  核心震荡 · %ds" % ceili(g.ability_cooldown) if g.ability_cooldown > 0 else "Q  核心震荡 · 就绪"
	refs.ability_button.tooltip_text = "Q 核心震荡：对全场敌人造成 %d 穿甲伤害，并减速 3 秒\n伤害 = 90 + 当前波次 × 8 · 冷却 35 秒" % (90 + g.wave * 8)
	refs.ability_button.disabled = g.ended or g.paused or not g.active_wave or g.ability_cooldown > 0
	refs.gate_button.visible = g.can_switch_gate()
	refs.gate_button.text = "E  入口 %s · %ds" % ["A" if g.gate_mode == 0 else "B", ceili(g.gate_cooldown)] if g.gate_cooldown > 0 else "E  切换入口 %s → %s" % ["A" if g.gate_mode == 0 else "B", "B" if g.gate_mode == 0 else "A"]
	refs.gate_button.disabled = g.ended or g.paused or g.gate_cooldown > 0
	if load("res://scripts/responsive_layout.gd").mobile():
		refs.ability_button.text = "震荡 %ds" % ceili(g.ability_cooldown) if g.ability_cooldown > 0 else "核心震荡"
		refs.gate_button.text = "入口 %s" % ("A" if g.gate_mode == 0 else "B")
	refs.camera_reset.visible = g.has_meta("camera_controller")
	refs.camera_hint.visible = g.has_meta("camera_controller") and not load("res://scripts/responsive_layout.gd").mobile()

	for i in range(g.tower_buttons.size()):
		var b: Button = g.tower_buttons[i]
		var d: Dictionary = g.TOWER_DATA[i]
		var chosen: bool = i == g.selected_kind
		var color: Color = d.color
		b.text = ""
		b.disabled = g.ended
		var affordable: bool = g.money >= int(d.cost)
		refs.tower_prices[i].text = str(d.cost)
		refs.tower_prices[i].add_theme_color_override("font_color", GOLD if affordable else RED)
		refs.tower_thumbnails[i].modulate = Color.WHITE if affordable else Color(0.47, 0.52, 0.55, 0.78)
		b.tooltip_text = "%s · %d 金%s\n%s\n伤害 %.0f · 射程 %.1f · 攻击间隔 %.2f 秒\n快捷键 %d：选择，再点击空基座部署" % [d.name, d.cost, " · 还差 %d 金" % (int(d.cost) - g.money) if not affordable else "", d.desc, d.damage, d.range, d.cooldown, i + 1]
		b.add_theme_color_override("font_color", INK if chosen else color.lightened(0.15))
		b.add_theme_stylebox_override("normal", _style(Color("274d45") if chosen else Color("142c36"), color if chosen else Color("304a54"), 9, 3))
		b.add_theme_stylebox_override("hover", _style(Color("30564d"), color, 9, 3))
		b.add_theme_stylebox_override("pressed", _style(Color("3b6c58"), color.lightened(0.25), 9, 3))
		b.add_theme_stylebox_override("disabled", _style(Color("152b33"), Color("28404a"), 9, 3))

	var index: int = g.tower_at(g.selected_pad)
	var occupied: bool = index >= 0
	var live_enemy: bool = not g.selected_enemy.is_empty() and float(g.selected_enemy.get("hp", 0.0)) > 0.0
	var context: PanelContainer = refs.context
	context.visible = (g.selected_pad >= 0 or live_enemy) and not g.ended
	g.build_button.visible = not occupied and not live_enemy
	g.upgrade_button.visible = occupied and not live_enemy
	g.sell_button.visible = occupied and not live_enemy
	if live_enemy:
		var e: Dictionary = g.selected_enemy
		var stats: Dictionary = g.enemy_stats(int(e.kind), maxi(1, g.wave))
		refs.context_title.text = stats.name
		refs.context_title.add_theme_color_override("font_color", stats.color)
		refs.context_state.text = "敌军情报  ·  实时状态"
		refs.context_state.add_theme_color_override("font_color", GOLD)
		g.info_label.text = "生命  %.0f / %.0f\n护盾  %.0f\n减速  %.1f 秒  ·  灼烧  %.1f 秒\n\n%s" % [maxf(0.0, float(e.hp)), e.max_hp, maxf(0.0, float(e.get("shield", 0.0))), maxf(0.0, float(e.get("slow", 0.0))), maxf(0.0, float(e.get("burn", 0.0))), stats.counter]
	elif occupied:
		var t: Dictionary = g.towers[index]
		var data: Dictionary = g.TOWER_DATA[t.kind]
		var maxed: bool = int(t.level) >= 3
		var cost: int = g.upgrade_cost(t)
		refs.context_title.text = data.name
		refs.context_title.add_theme_color_override("font_color", data.color)
		refs.context_state.text = "等级 %d / 3  ·  已达最高等级" % t.level if maxed else "等级 %d / 3  →  等级 %d" % [t.level, t.level + 1]
		refs.context_state.add_theme_color_override("font_color", MINT)
		if maxed:
			g.info_label.text = "%s\n伤害  %.0f    射程  %.1f\n已完成全部升级" % [data.desc, t.damage, t.range]
		else:
			g.info_label.text = "%s\n伤害  %.0f  →  %.0f\n射程  %.1f  →  %.1f" % [data.desc, t.damage, t.damage * g.UPGRADE_DAMAGE[t.level - 1], t.range, t.range + g.UPGRADE_RANGE[t.level - 1]]
		g.upgrade_button.disabled = maxed or g.money < cost or g.ended
		g.upgrade_button.text = "最高等级 · 无需升级" if maxed else ("升级 %d 金 · 还差 %d 金" % [cost, cost - g.money] if g.money < cost else "升级至 %d 级  ·  %d 金" % [t.level + 1, cost])
		g.upgrade_button.tooltip_text = "已达最高等级" if maxed else "升级价格 %d 金 · 快捷键 U" % cost
		g.sell_button.text = "出售防御塔  ·  返还 %d 金" % int(t.spent * 0.7)
		g.sell_button.disabled = g.ended
	else:
		var data: Dictionary = g.TOWER_DATA[g.selected_kind]
		var cost: int = data.cost
		refs.context_title.text = data.name
		refs.context_title.add_theme_color_override("font_color", data.color)
		refs.context_state.text = "空基座  ·  可以部署"
		refs.context_state.add_theme_color_override("font_color", MINT)
		g.info_label.text = "%s\n伤害  %.0f    射程  %.1f\n攻击间隔  %.2f 秒" % [data.desc, data.damage, data.range, data.cooldown]
		g.build_button.disabled = g.selected_pad < 0 or g.money < cost or g.ended
		g.build_button.text = "建造 %d 金 · 还差 %d 金" % [cost, cost - g.money] if g.money < cost else "在此建造  ·  %d 金" % cost
		g.build_button.tooltip_text = "建造价格 %d 金" % cost
	if context.visible:
		_place_context(g, context)
	var last_level: bool = not custom and g.level_index >= g.levels.size() - 1
	refs.next_level_button.disabled = last_level
	refs.next_level_button.text = "返回第一关  →" if custom else ("已到达最终关卡" if last_level else "继续下一关  →")

static func _place_context(g, panel: PanelContainer) -> void:
	var safe: Rect2 = load("res://scripts/responsive_layout.gd").safe_rect(g).grow(-12)
	var point := safe.get_center()
	if not g.selected_enemy.is_empty() and is_instance_valid(g.selected_enemy.get("node")):
		point = g.camera.unproject_position(g.selected_enemy.node.global_position)
	elif g.selected_pad >= 0 and g.selected_pad < g.pads.size():
		point = g.camera.unproject_position(g.pads[g.selected_pad].global_position)
	var panel_height: float = maxf(panel.get_combined_minimum_size().y, 275.0)
	panel.size.y = panel_height
	var top: float = safe.position.y + 140.0
	panel.position = Vector2(safe.end.x - panel.size.x if point.x < safe.get_center().x else safe.position.x, clampf(point.y - 130.0, top, maxf(top, safe.end.y - 100.0 - panel_height)))

static func show_levels(g) -> void:
	if not g.has_meta("game_ui"):
		return
	var refs: Dictionary = g.get_meta("game_ui")
	if is_instance_valid(g.level_overlay):
		g.level_overlay.queue_free()
	g.level_overlay = _overlay(refs.root)
	var center := CenterContainer.new()
	g.level_overlay.add_child(center)
	var outer := _panel(center, Rect2(0, 0, 1180, 0), 28)
	outer.custom_minimum_size.x = 850 if load("res://scripts/responsive_layout.gd").mobile() else 1180
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	outer.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := _text(g, "选择战场", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var back := _button(g, "返回战场  ×", _close_levels.bind(g))
	title_row.add_child(back)
	column.add_child(_text(g, "%d 处战场，不同的路线与机制。所有关卡均可直接挑战。" % g.levels.size(), 18, MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(794, 300) if load("res://scripts/responsive_layout.gd").mobile() else Vector2(1124, 550)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2 if load("res://scripts/responsive_layout.gd").mobile() else 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var colors := [Color("86e1ba"), Color("f2c18c"), Color("9ecff1"), Color("ffac83"), Color("ace0f5"), Color("c9a9f0")]
	for i in range(g.levels.size()):
		var stage: Dictionary = g.levels[i]
		var accent: Color = colors[i % colors.size()]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(360, 260)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("18333b"), accent if i == g.level_index else BORDER, 14, 14))
		grid.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 10)
		card.add_child(content)
		content.add_child(_text(g, "%02d  %s" % [i + 1, stage.name], 22))
		var subtitle := _text(g, "%s · %d 波 · %d G" % [stage.subtitle, g.CAMPAIGN_WAVES[i], stage.gold], 16, accent)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(subtitle)
		var desc := _text(g, stage.description, 16, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(320, 76)
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(desc)
		var deploy := _button(g, "当前关卡 · 重新部署" if i == g.level_index else "部署此战场  →", _choose_level.bind(g, i), true)
		content.add_child(deploy)
	g.level_overlay.show()

static func _close_levels(g) -> void:
	if is_instance_valid(g.level_overlay):
		g.level_overlay.hide()
	if g.has_meta("level_previous_pause"):
		g.paused = bool(g.get_meta("level_previous_pause"))
	g.refresh_ui()

static func _choose_level(g, index: int) -> void:
	_close_levels(g)
	g.choose_level(index)
