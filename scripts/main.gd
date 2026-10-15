extends Node3D
## Emerald Watch. All meshes, materials, effects, and game rules are generated here.

const TILE := 1.5
const CAMPAIGN_WAVES := [12, 12, 14, 14, 16, 16, 18, 18, 20, 20, 22, 22]
const UPGRADE_DAMAGE := [1.65, 1.8]
const UPGRADE_PRICE := [0.85, 1.6]
const UPGRADE_RANGE := [0.45, 0.55]
const TOWER_DATA := [
	{"name": "脉冲箭塔", "tag": "PULSE", "cost": 80, "range": 4.6, "damage": 24.0, "cooldown": 0.65, "color": Color("63ebba"), "desc": "快速单体 · 克制普通与疾行虫；重甲减伤"},
	{"name": "熔核炮塔", "tag": "EMBER", "cost": 120, "range": 4.0, "damage": 38.0, "cooldown": 1.65, "color": Color("ffba70"), "desc": "范围爆破 · 克制分裂虫与密集虫群"},
	{"name": "霜晶棱塔", "tag": "FROST", "cost": 100, "range": 4.4, "damage": 10.0, "cooldown": 0.8, "color": Color("80cfff"), "desc": "减速 50% · 克制疾行虫；母虫减速效果减半"},
	{"name": "雷链线圈", "tag": "ARC", "cost": 140, "range": 4.5, "damage": 27.0, "cooldown": 1.05, "color": Color("d7a1ff"), "desc": "弹射 3 个目标 · 护盾伤害翻倍"},
	{"name": "穿甲轨炮", "tag": "RAIL", "cost": 150, "range": 6.2, "damage": 100.0, "cooldown": 2.3, "color": Color("ffe89c"), "desc": "无视重甲 · 优先攻击重甲与母虫"},
	{"name": "焰息熔炉", "tag": "BURN", "cost": 130, "range": 3.6, "damage": 17.0, "cooldown": 0.85, "color": Color("ff876c"), "desc": "范围灼烧 · 持续伤害并阻止再生"}
]
var PAD_CELLS := [Vector2i(-5,-1),Vector2i(-3,-1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(3,-1),Vector2i(6,-1),Vector2i(-6,1),Vector2i(-3,1),Vector2i(-1,1),Vector2i(1,1),Vector2i(3,1),Vector2i(5,1),Vector2i(-3,2),Vector2i(-1,2),Vector2i(1,2),Vector2i(3,2)]
var ROUTE := [Vector3(-10.5,0.35,-4.5),Vector3(7.5,0.35,-4.5),Vector3(7.5,0.35,0),Vector3(-7.5,0.35,0),Vector3(-7.5,0.35,4.5),Vector3(9,0.35,4.5)]
var audio: Node
var show_ranges := true
var show_damage_numbers := true
var ability_cooldown := 0.0
var gate_cooldown := 0.0
var gate_mode := 0
var routes: Array = []
var damage_labels: Array[Dictionary] = []
var road_tiles: Dictionary = {}
var selected_enemy: Dictionary = {}
var level_index := 0
var custom_level_data: Dictionary = {}
var hazard_time := 0.0
var hazard_ring: MeshInstance3D
var hazard_data: Dictionary = {}
var levels := [
	{"name":"翡翠哨站", "subtitle":"01 / 云境前哨", "description":"绵长蛇形路线 · 适合熟悉塔的配合", "color":Color("294f4e"), "road":Color("7a8980"), "tree":Color("3d8271"), "gold":360, "difficulty":1.0},
	{"name":"赤岩回廊", "subtitle":"02 / 护盾围城", "description":"螺旋双门 · E 切换下批敌人的入场方向", "color":Color("654c48"), "road":Color("a18d72"), "tree":Color("b37c60"), "gold":420, "difficulty":1.18},
	{"name":"霜岭裂隙", "subtitle":"03 / 最后防线", "description":"双入口交汇 · 两路疾行与重甲混合攻势", "color":Color("3c536b"), "road":Color("8cabb9"), "tree":Color("83b2c2"), "gold":500, "difficulty":1.35}
]
var level_overlay: Control
var preview_ghost: Node3D
var hover_pad := -1
var preview_kind := -1
var ui_refresh_timer := 0.0
var completed_levels: Array[int] = []
var input_hint := ""
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var world: Node3D
var enemies: Array[Dictionary] = []
var towers: Array[Dictionary] = []
var pads: Array[Node3D] = []
var effects: Array[Dictionary] = []
var money := 360
var health := 20
var wave := 0
var kills := 0
var active_wave := false
var remaining := 0
var spawn_timer := 0.0
var spawned := 0
var ended := false
var paused := false
var speed := 1.0
var selected_pad := -1
var selected_kind := 0
var elapsed := 0.0
var toast_time := 0.0
var range_ring: MeshInstance3D
var crystal: MeshInstance3D
var hud: CanvasLayer
var money_label: Label
var hp_label: Label
var wave_label: Label
var phase_label: Label
var info_label: Label
var toast_label: Label
var next_button: Button
var upgrade_button: Button
var sell_button: Button
var build_button: Button
var pause_button: Button
var speed_button: Button
var tower_buttons: Array[Button] = []
var end_panel: PanelContainer
var end_title: Label
var end_desc: Label
var ui_font: Font
var sound_enabled := true
var sounds: Dictionary = {}
var font_color := Color("e3f2ef")
var muted := Color("89aaa9")

func _ready() -> void:
	if bool(get_meta("replay_runner", false)):
		return
	if levels.size() == 3 and ResourceLoader.exists("res://scripts/extra_levels.gd"):
		levels.append_array(load("res://scripts/extra_levels.gd").definitions())
	rng.seed = 42857
	if ResourceLoader.exists("res://assets/ui-font.otf"):
		ui_font = load("res://assets/ui-font.otf")
	configure_level()
	build_world()
	build_sounds()
	build_ui()
	if ResourceLoader.exists("res://scripts/game_settings.gd"):
		load("res://scripts/game_settings.gd").build(self)
	if ResourceLoader.exists("res://scripts/camera_controller.gd"):
		load("res://scripts/camera_controller.gd").install(self)
	refresh_ui()
	show_toast("先选底部塔型，再点基座。右键 / Esc 取消；选塔后可查看升级对比。", 8)
	if "--capture" in OS.get_cmdline_user_args():
		capture_demo.call_deferred()

func mat(color: Color, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.metallic = metallic
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func mesh_node(parent: Node3D, mesh: Mesh, p: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = p
	n.material_override = material
	parent.add_child(n)
	return n

func box(parent: Node3D, p: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, p, mat(color))

func cylinder(parent: Node3D, p: Vector3, radius: float, height: float, color: Color, top: float = -1, sides: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = sides
	return mesh_node(parent, mesh, p, mat(color))

func orb(parent: Node3D, p: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2
	m.radial_segments = 8
	m.rings = 4
	return mesh_node(parent, m, p, mat(color, 0.2, 0.35))

func build_world() -> void:
	world = Node3D.new()
	add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101f2a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8cfd4")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_color = Color("ffe2b3")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.8
	camera.position = Vector3(16,23,25)
	add_child(camera)
	camera.look_at(Vector3(0,0,0))
	camera.current = true
	# Floating archipelago, each column is a distinct low-poly basalt tile.
	for x in range(-7,8):
		for z in range(-4,5):
			var h := rng.randf_range(1.0,2.3)
			var color := Color(current_level().color).lightened(rng.randf_range(-0.06,0.08))
			box(world,Vector3(x*TILE,-h/2-0.14,z*TILE),Vector3(1.46,h,1.46),color.darkened(0.25))
			box(world,Vector3(x*TILE,-0.07,z*TILE),Vector3(1.46,0.25,1.46),color)
	road_tiles.clear()
	# Both entrances are visible; each enemy keeps its own chosen route.
	for road in routes:
		build_road(road)
	for cell in PAD_CELLS:
		var pad := Node3D.new()
		world.add_child(pad)
		pad.position = Vector3(cell.x*TILE,0.26,cell.y*TILE)
		cylinder(pad,Vector3.ZERO,0.65,0.22,Color("182f38"),0.59)
		cylinder(pad,Vector3(0,0.125,0),0.52,0.035,Color("6ba297"))
		box(pad,Vector3(0,0.15,0),Vector3(0.45,0.025,0.08),Color("a9dfca"))
		box(pad,Vector3(0,0.15,0),Vector3(0.08,0.025,0.45),Color("a9dfca"))
		pads.append(pad)
	# Trees and mineral outcrops along the island edge.
	for x in [-6,-4,-2,0,2,4,6]:
		for z in [-4,4]:
			if x > 4 and z == 4: continue
			if road_tiles.has(Vector2i(x * 15, z * 15)) or PAD_CELLS.has(Vector2i(x, z)): continue
			var p := Vector3(x*TILE+rng.randf_range(-0.25,0.25),0.12,z*TILE)
			var tree := Node3D.new()
			world.add_child(tree)
			tree.position = p
			var h := rng.randf_range(0.7,1.3)
			cylinder(tree,Vector3(0,h*0.35,0),0.1,h*0.7,Color("705e45"))
			cylinder(tree,Vector3(0,h*0.8,0),0.49,h,Color(current_level().tree),0,5)
			cylinder(tree,Vector3(0,h*1.2,0),0.34,h*0.7,Color(current_level().tree).lightened(0.2),0,5)
	for p in [Vector3(-9,0.2,3),Vector3(10.5,0.2,-1.5),Vector3(-9,0.2,-1.5)]:
		if road_tiles.has(Vector2i(roundi(p.x * 10), roundi(p.z * 10))) or PAD_CELLS.has(Vector2i(roundi(p.x / TILE), roundi(p.z / TILE))): continue
		for j in range(3):
			var shard := cylinder(world,p+Vector3(j*0.22,0.3+j*0.11,0.12*j),0.18,0.8,Color("6ac6b0"),0,5)
			shard.rotation.z = j*0.2
	build_gate()
	# Arrival portal.
	cylinder(world,ROUTE[0]+Vector3(0,0.03,0),0.65,0.15,Color("533752"))
	for side in [-1,1]:
		var p: Vector3 = ROUTE[0]+Vector3(0,0.6,side*0.48)
		cylinder(world,p,0.18,1.3,Color("715079"),0.09)
		orb(world,p+Vector3(0,0.7,0),0.16,Color("f28aac"))
	for entrance in range(1, routes.size()):
		var p2: Vector3 = routes[entrance][0]
		cylinder(world,p2,0.65,0.15,Color("375f76"))
		for side in [-1,1]:
			cylinder(world,p2+Vector3(0,0.55,side*0.48),0.18,1.3,Color("537ea2"),0.09)
			orb(world,p2+Vector3(0,1.25,side*0.48),0.16,Color("91d7ff"))
	range_ring = make_ring(1.0,Color("6ee5be"))
	world.add_child(range_ring)
	range_ring.visible = false
	build_hazard()

func build_gate() -> void:
	var center: Vector3 = ROUTE[-1]+Vector3(0,-0.15,0)
	cylinder(world,center,1.05,0.35,Color("25414c"),0.9)
	cylinder(world,center+Vector3(0,0.3,0),0.73,0.45,Color("779f98"),0.63)
	crystal = cylinder(world,center+Vector3(0,1.15,0),0.37,1.35,Color("7bffd1"),0,5)
	crystal.material_override = mat(Color("77ffcc"),0.3,1.3)
	for a in range(4):
		var p := center+Vector3(cos(a*PI/2)*0.8,0.45,sin(a*PI/2)*0.8)
		cylinder(world,p,0.17,1.0,Color("3c6967"),0.11)
		orb(world,p+Vector3(0,0.53,0),0.12,Color("afffe0"))

func make_ring(radius: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-0.025
	mesh.outer_radius = radius+0.025
	mesh.rings = 64
	mesh.ring_segments = 6
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat(color,0,0.6)
	return n

func build_tower_model(kind: int, p: Vector3, level: int = 1) -> Node3D:
	var node := Node3D.new()
	world.add_child(node)
	node.position = p
	var color: Color = TOWER_DATA[kind].color
	cylinder(node,Vector3(0,0.16,0),0.43,0.3,Color("233c48"),0.35)
	cylinder(node,Vector3(0,0.46,0),0.28,0.44,Color("719891"),0.23,6)
	cylinder(node,Vector3(0,0.7,0),0.36,0.12,color,0.36,6)
	var turret := Node3D.new()
	turret.name = "Turret"
	node.add_child(turret)
	turret.position.y = 0.85
	if kind == 0:
		box(turret,Vector3.ZERO,Vector3(0.38,0.3,0.48),Color("264f50"))
		for side in [-1,1]:
			box(turret,Vector3(side*0.18,0.04,-0.3),Vector3(0.09,0.12,0.65),color)
		orb(turret,Vector3(0,0.12,0),0.15,color)
	elif kind == 1:
		orb(turret,Vector3.ZERO,0.3,Color("68564b"))
		var barrel := cylinder(turret,Vector3(0,0.12,-0.25),0.2,0.55,Color("343e47"),0.22,8)
		barrel.rotation.x = PI/2-0.3
		orb(turret,Vector3(0,0.2,-0.48),0.15,color)
	elif kind == 2:
		var shard := cylinder(turret,Vector3(0,0.25,0),0.26,0.8,color,0,5)
		shard.material_override = mat(color,0.2,0.8)
		for side in [-1,1]:
			cylinder(turret,Vector3(side*0.3,0.05,0),0.1,0.45,color,0,5)
	elif kind == 3:
		for h in [0.0,0.2,0.4]:
			cylinder(turret,Vector3(0,h,0),0.31,0.07,color,0.31,12)
		orb(turret,Vector3(0,0.6,0),0.2,color)
	elif kind == 4:
		box(turret,Vector3(0,0.1,-0.25),Vector3(0.2,0.16,1.15),Color("42505b"))
		for side in [-1,1]:
			box(turret,Vector3(side*0.13,0.12,-0.3),Vector3(0.06,0.07,1.0),color)
		cylinder(turret,Vector3(0,0,0.2),0.22,0.3,Color("8e8c72"),0.18)
	else:
		cylinder(turret,Vector3(0,0.12,0),0.3,0.45,Color("705747"),0.35)
		for side in [-1,1]:
			var pipe := cylinder(turret,Vector3(side*0.19,0.25,-0.27),0.12,0.4,color,0.16)
			pipe.rotation.x = PI/2
		orb(turret,Vector3(0,0.45,0),0.2,color)
	for i in range(level-1):
		orb(node,Vector3(-0.15+i*0.3,0.4,0.29),0.07,Color("fff0ae"))
	return node

func panel_style(bg: Color, border: Color = Color("294650"), radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func label(text: String, size: int = 18, color: Color = Color("e3f2ef")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	return l

func button(text: String, callback: Callable, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 43
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",panel_style(Color("21524d") if accent else Color("18323d"),Color("438d79") if accent else Color("30505b"),9))
	b.add_theme_stylebox_override("hover",panel_style(Color("315e60"),Color("7ed6bd"),9))
	b.add_theme_stylebox_override("pressed",panel_style(Color("3c796b"),Color("9af0cf"),9))
	b.add_theme_stylebox_override("disabled",panel_style(Color("162b33"),Color("203c44"),9))
	b.add_theme_color_override("font_disabled_color",Color("587476"))
	b.add_theme_font_size_override("font_size",17)
	b.pressed.connect(callback)
	return b

func build_ui() -> void:
	GameUI.build(self)
	if ResourceLoader.exists("res://scripts/game_codex.gd"):
		load("res://scripts/game_codex.gd").build(self)

func tower_at(pad_index: int) -> int:
	for i in range(towers.size()):
		if towers[i].pad == pad_index: return i
	return -1

func select_kind(kind: int) -> void:
	selected_kind = kind
	clear_preview()
	refresh_ui()
	update_range()

func select_pad(index: int) -> void:
	selected_enemy = {}
	selected_pad = index
	clear_preview()
	refresh_ui()
	update_range()

func update_range() -> void:
	if selected_pad < 0:
		range_ring.hide()
		return
	var index := tower_at(selected_pad)
	var r: float = towers[index].range if index >= 0 else TOWER_DATA[selected_kind].range
	range_ring.position = pads[selected_pad].position + Vector3(0,0.025,0)
	range_ring.scale = Vector3(r,1,r)
	range_ring.visible = show_ranges
	if index < 0:
		show_preview(selected_pad)

func build_selected() -> void:
	if selected_pad < 0 or ended or tower_at(selected_pad) >= 0: return
	var data: Dictionary = TOWER_DATA[selected_kind]
	if money < data.cost:
		show_toast("金币不足，击退虫群可获得金币。")
		return
	_replay_record("build", [selected_pad, selected_kind])
	clear_preview()
	money -= data.cost
	play_sound("build")
	var node := build_tower_model(selected_kind,pads[selected_pad].position+Vector3(0,0.14,0))
	towers.append({"pad":selected_pad,"kind":selected_kind,"level":1,"node":node,"damage":data.damage,"range":data.range,"cooldown":0.0,"spent":data.cost})
	show_toast("%s 已部署。" % data.name)
	refresh_ui()
	update_range()

func upgrade_selected() -> void:
	var index := tower_at(selected_pad)
	if index < 0 or ended: return
	var t: Dictionary = towers[index]
	if t.level >= 3: return
	var cost := upgrade_cost(t)
	if money < cost:
		show_toast("金币不足，暂时无法升级。")
		return
	_replay_record("upgrade", [selected_pad])
	money -= cost
	play_sound("upgrade")
	t.spent += cost
	t.level += 1
	t.damage *= UPGRADE_DAMAGE[t.level - 2]
	t.range += UPGRADE_RANGE[t.level - 2]
	var p: Vector3 = t.node.position
	t.node.queue_free()
	t.node = build_tower_model(t.kind,p,t.level)
	refresh_ui()
	update_range()
	show_toast("防御塔已升至 %d 级，伤害与射程提升。" % t.level)

func upgrade_cost(t: Dictionary) -> int:
	return int(TOWER_DATA[t.kind].cost * UPGRADE_PRICE[mini(t.level - 1, 1)])

func sell_selected() -> void:
	var index := tower_at(selected_pad)
	if index < 0 or ended: return
	var t: Dictionary = towers[index]
	var refund := int(t.spent*0.7)
	_replay_record("sell", [selected_pad])
	money += refund
	play_sound("sell")
	t.node.queue_free()
	towers.remove_at(index)
	show_toast("拆除完成，返还 %d 金币。" % refund)
	refresh_ui()
	update_range()

func start_wave() -> void:
	if active_wave or ended or paused: return
	_replay_record("wave", [])
	wave += 1
	play_sound("wave")
	active_wave = true
	remaining = wave_enemy_count()
	spawned = 0
	spawn_timer = 0.0
	show_toast("第 %d 波来袭%s" % [wave,"：巨型母虫接近！" if wave == wave_total() else "，守住防线！"])
	refresh_ui()

func spawn_enemy(kind: int = -1) -> Dictionary:
	var route_index := 0
	if routes.size() > 1: route_index = gate_mode if can_switch_gate() else spawned % routes.size()
	var enemy_route: Array = routes[route_index]
	if kind < 0:
		kind = wave_enemy_kind(spawned)
	var stats := enemy_stats(kind)
	var hp: float = stats.hp
	var movement: float = stats.speed
	var color: Color = stats.color
	var body := Node3D.new()
	world.add_child(body)
	body.position = enemy_route[0]
	var size_mult: float = [1.0,0.7,1.35,2.2,1.1,1.15,1.1][kind]
	body.scale = Vector3.ONE*size_mult
	var carapace := orb(body,Vector3(0,0.27,0),0.28,color)
	carapace.scale = Vector3(0.9,0.8,1.3)
	orb(body,Vector3(0,0.26,-0.3),0.17,color.lightened(0.15))
	for side in [-1,1]:
		orb(body,Vector3(side*0.08,0.3,-0.43),0.045,Color("ffe9ad"))
		for z in [-0.18,0.12]:
			var leg := box(body,Vector3(side*0.29,0.12,z),Vector3(0.32,0.08,0.07),color.darkened(0.28))
			leg.rotation.z = side*0.35
	if kind in [2,3]:
		for z in [-0.15,0.1,0.3]:
			cylinder(body,Vector3(0,0.48,z),0.12,0.26,color.lightened(0.3),0,4)
	if kind == 4:
		var shield := orb(body,Vector3(0,0.28,0),0.43,Color("7ad8ff"))
		var m := mat(Color(0.35,0.78,1.0,0.22),0,0.2)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shield.material_override = m
		shield.name = "Shield"
	elif kind == 5:
		box(body,Vector3(0,0.57,0),Vector3(0.09,0.035,0.38),Color("c1ffb5"))
		box(body,Vector3(0,0.57,0),Vector3(0.38,0.035,0.09),Color("c1ffb5"))
	elif kind == 6:
		for side in [-1,1]:
			orb(body,Vector3(side*0.2,0.4,0.1),0.17,Color("f5cc65"))
	var bar := Node3D.new()
	body.add_child(bar)
	bar.position.y = 0.85
	var back := box(bar,Vector3.ZERO,Vector3(0.7,0.06,0.08),Color("26373e"))
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fill := box(bar,Vector3(0,0.025,0),Vector3(0.7,0.07,0.09),Color("ff9b9e"))
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var e := {"node":body,"hp":hp,"max_hp":hp,"speed":movement,"route":enemy_route,"route_index":route_index,"segment":0,"progress":0.0,"slow":0.0,"kind":kind,"bar":fill,"reward":int([10,11,24,150,19,22,20][kind]),"shield":hp*0.65 if kind == 4 else 0.0,"burn":0.0,"burn_dps":0.0,"regen_timer":0.0,"child":false,"phase":rng.randf()*TAU}
	enemies.append(e)
	return e

func _process(delta: float) -> void:
	if custom_level_data.is_empty():
		elapsed += delta
	crystal.rotation.y += delta*0.7
	crystal.position.y = ROUTE[-1].y+1.0+sin(elapsed*1.7)*0.09
	if toast_time > 0:
		toast_time -= delta
		toast_label.modulate.a = minf(1,toast_time)
	if not paused and not ended:
		if not custom_level_data.is_empty() and ResourceLoader.exists("res://scripts/author_replay.gd"):
			load("res://scripts/author_replay.gd").advance(self, minf(delta, 0.05) * speed)
		else:
			game_tick(minf(delta,0.05)*speed)
	update_effects(delta if not paused else 0)
	update_damage_labels(delta if not paused else 0)
	ui_refresh_timer -= delta
	if ui_refresh_timer <= 0:
		refresh_ui()
		ui_refresh_timer = 0.15

func game_tick(dt: float) -> void:
	hazard_time += dt
	update_hazard(dt)
	ability_cooldown = maxf(0.0,ability_cooldown-dt)
	gate_cooldown = maxf(0.0,gate_cooldown-dt)
	if active_wave and remaining > 0:
		spawn_timer -= dt
		if spawn_timer <= 0:
			spawn_enemy()
			spawned += 1
			remaining -= 1
			spawn_timer = wave_spawn_interval()
	for e in enemies:
		if e.hp <= 0: continue
		if e.burn > 0:
			e.burn -= dt
			damage_enemy(e,e.burn_dps*dt,5)
		if e.hp <= 0: continue
		if e.kind == 5 and e.burn <= 0:
			e.regen_timer -= dt
			if e.regen_timer <= 0:
				e.regen_timer = 1.0
				for ally in enemies:
					if ally.hp > 0 and ally.burn <= 0 and ally.node.position.distance_to(e.node.position)<2.8:
						ally.hp = minf(ally.max_hp,ally.hp+ally.max_hp*0.06)
						ally.bar.scale.x = ally.hp/ally.max_hp
		e.slow = maxf(0,e.slow-dt)
		var distance: float = e.speed * ((0.75 if e.kind == 3 else 0.5) if e.slow > 0 else 1.0) * dt
		e.progress += distance
		var a: Vector3 = e.route[e.segment]
		var b: Vector3 = e.route[e.segment+1]
		while e.progress >= a.distance_to(b):
			e.progress -= a.distance_to(b)
			e.segment += 1
			if e.segment >= e.route.size()-1:
				health -= 5 if e.kind == 3 else 1
				play_sound("leak")
				e.hp = -999
				pulse(ROUTE[-1],Color("ff9c91"),1.0)
				break
			a = e.route[e.segment]
			b = e.route[e.segment+1]
		if e.hp <= 0: continue
		e.node.position = a.move_toward(b,e.progress)
		e.node.position.y += sin(elapsed*14+e.phase)*0.035
		e.node.look_at(e.node.position+(b-a).normalized())
	for t in towers:
		t.cooldown -= dt
		if t.cooldown > 0: continue
		var target: Dictionary = {}
		var best := -1.0
		for e in enemies:
			if e.hp <= 0: continue
			if Vector2(t.node.position.x,t.node.position.z).distance_to(Vector2(e.node.position.x,e.node.position.z)) > t.range: continue
			var score: float = e.segment*100+e.progress
			if t.kind == 4 and e.kind in [2,3]: score += 1000
			if score > best:
				best = score
				target = e
		if target.is_empty(): continue
		fire(t,target)
		t.cooldown = TOWER_DATA[t.kind].cooldown / (1.0+(t.level-1)*0.12)
	for i in range(enemies.size()-1,-1,-1):
		var e: Dictionary = enemies[i]
		if e.hp <= 0:
			if selected_enemy == e: selected_enemy = {}
			if e.hp > -900:
				if e.kind == 6 and not e.child:
					for split in range(2):
						var child := spawn_enemy(1)
						child.child = true
						child.route = e.route
						child.route_index = e.route_index
						child.hp *= 0.5
						child.max_hp = child.hp
						child.reward = 3
						child.segment = e.segment
						child.progress = e.progress + split*0.15
						child.node.position = e.node.position
						child.node.scale *= 0.7
				money += e.reward
				kills += 1
				pulse(e.node.position,Color("f5cc93"),0.4)
			e.node.queue_free()
			enemies.remove_at(i)
	if health <= 0:
		health = 0
		finish(false)
	elif active_wave and remaining == 0 and enemies.is_empty():
		active_wave = false
		if wave >= wave_total():
			finish(true)
		else:
			var bonus := wave_supply()
			money += bonus
			show_toast("第 %d 波已击退！补给 +%d G。调整防线后再出发。" % [wave,bonus],7)
	# HUD refresh is throttled by _process; state changes also refresh immediately.

func fire(t: Dictionary, target: Dictionary) -> void:
	play_sound(["shot","boom","ice","arc","rail","burn"][t.kind])
	var color: Color = TOWER_DATA[t.kind].color
	var end: Vector3 = target.node.position+Vector3(0,0.35,0)
	var origin: Vector3 = t.node.position+Vector3(0,1,0)
	var turret: Node3D = t.node.get_node("Turret")
	var look := Vector3(end.x,turret.global_position.y,end.z)
	if turret.global_position.distance_to(look)>0.01: turret.look_at(look)
	beam(origin,end,color,0.055 if t.kind not in [1,4] else 0.1)
	if t.kind in [1,5]:
		pulse(end,color,1.25)
		for e in enemies:
			if e.hp > 0 and e.node.position.distance_to(target.node.position)<1.6:
				damage_enemy(e,t.damage,t.kind)
				if t.kind == 5:
					e.burn = 3.0
					e.burn_dps = 16.0 * t.level
	elif t.kind == 3:
		damage_enemy(target,t.damage,3)
		var hit: Array = [target]
		var previous: Dictionary = target
		for jump in range(2):
			var nearest: Dictionary = {}
			var dist := 3.2
			for e in enemies:
				if e.hp <= 0 or e in hit: continue
				var d: float = e.node.position.distance_to(previous.node.position)
				if d < dist:
					dist = d
					nearest = e
			if nearest.is_empty(): break
			beam(previous.node.position+Vector3(0,0.4,0),nearest.node.position+Vector3(0,0.4,0),color,0.045)
			damage_enemy(nearest,t.damage*0.85,3)
			hit.append(nearest)
			previous = nearest
	else:
		damage_enemy(target,t.damage,t.kind)
		if t.kind == 2: target.slow = 2.0+t.level*0.35

func damage_enemy(e: Dictionary, amount: float, tower_kind: int = -1) -> void:
	if e.hp <= 0: return
	if e.kind == 2 and tower_kind not in [4,5]: amount *= 0.45
	if e.shield > 0:
		var shield_damage := amount * (2.0 if tower_kind == 3 else 1.0)
		var absorbed: float = minf(e.shield,shield_damage)
		e.shield -= absorbed
		amount = maxf(0.0,amount-absorbed/(2.0 if tower_kind == 3 else 1.0))
		if e.shield <= 0 and e.node.has_node("Shield"): e.node.get_node("Shield").hide()
	e.hp -= amount
	if amount >= 5:
		spawn_damage_label(e.node.position,amount,tower_kind)
		play_sound("hit")
	e.bar.scale.x = maxf(0.01,e.hp/e.max_hp)

func beam(a: Vector3, b: Vector3, color: Color, radius: float) -> void:
	var n := cylinder(world,(a+b)/2,radius,a.distance_to(b),color,radius,6)
	n.material_override = mat(color,0,1.5)
	var direction := b-a
	if absf(direction.normalized().dot(Vector3.UP))<0.99:
		n.look_at(b,Vector3.UP)
		n.rotate_object_local(Vector3.RIGHT,PI/2)
	effects.append({"node":n,"life":0.14,"max":0.14,"ring":false})

func pulse(p: Vector3, color: Color, radius: float) -> void:
	var n := make_ring(radius,color)
	world.add_child(n)
	n.position = p+Vector3(0,0.1,0)
	effects.append({"node":n,"life":0.35,"max":0.35,"ring":true})

func update_effects(dt: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var e: Dictionary = effects[i]
		e.life -= dt
		if e.life<=0:
			e.node.queue_free()
			effects.remove_at(i)
		elif e.ring:
			e.node.scale = Vector3.ONE*(1.4-e.life/e.max)

func refresh_ui() -> void:
	GameUI.refresh(self)

func show_toast(text: String, duration: float = 4.0) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1
	toast_time = duration

func toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	speed_button.text = "%d× 速度" % int(speed)

func toggle_pause() -> void:
	if ended: return
	paused = not paused
	pause_button.text = "继续" if paused else "暂停"
	refresh_ui()

func finish(won: bool) -> void:
	ended = true
	play_sound("win" if won else "loss")
	active_wave = false
	if won and custom_level_data.is_empty() and level_index not in completed_levels: completed_levels.append(level_index)
	end_title.text = "防线屹立 · 胜利！" if won else "核心失守"
	end_desc.text = "%s 通关 · 全部 %d 波\n剩余核心 %d / 20 · 击退 %d 只" % [current_level().name,wave_total(),health,kills] if won else "坚持到第 %d 波 · 击退 %d 只\n试试用霜晶减速配合熔核范围攻击" % [wave,kills]
	end_panel.show()
	refresh_ui()
	if not custom_level_data.is_empty() and ResourceLoader.exists("res://scripts/author_replay.gd"):
		load("res://scripts/author_replay.gd").finished(self, won)

func restart() -> void:
	if ResourceLoader.exists("res://scripts/level_designer.gd"):
		load("res://scripts/level_designer.gd").close(self)
	if ResourceLoader.exists("res://scripts/game_codex.gd"):
		load("res://scripts/game_codex.gd").close(self)
	if ResourceLoader.exists("res://scripts/game_settings.gd"):
		load("res://scripts/game_settings.gd").close(self)
	for item in damage_labels: item.node.queue_free()
	damage_labels.clear()
	hazard_time = 0.0
	ability_cooldown = 0.0
	gate_cooldown = 0.0
	gate_mode = 0
	selected_enemy = {}
	for e in enemies: e.node.queue_free()
	for t in towers: t.node.queue_free()
	for e in effects: e.node.queue_free()
	enemies.clear()
	towers.clear()
	effects.clear()
	money = current_level().gold
	health = 20
	wave = 0
	kills = 0
	active_wave = false
	remaining = 0
	spawned = 0
	spawn_timer = 0
	ended = false
	paused = false
	speed = 1
	clear_preview()
	selected_pad = -1
	selected_kind = 0
	pause_button.text = "暂停"
	speed_button.text = "1× 速度"
	end_panel.hide()
	update_range()
	refresh_ui()
	show_toast("新的防线，新的机会。选择基座开始部署。")
	_reset_camera()
	if not custom_level_data.is_empty() and ResourceLoader.exists("res://scripts/author_replay.gd"):
		load("res://scripts/author_replay.gd").begin(self, custom_level_data)

func _unhandled_input(event: InputEvent) -> void:
	if ResourceLoader.exists("res://scripts/level_designer.gd") and load("res://scripts/level_designer.gd").is_open(self):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			load("res://scripts/level_designer.gd").close(self)
		return
	if ResourceLoader.exists("res://scripts/game_settings.gd") and load("res://scripts/game_settings.gd").is_open(self):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			load("res://scripts/game_settings.gd").close(self)
		return
	if ResourceLoader.exists("res://scripts/game_codex.gd") and load("res://scripts/game_codex.gd").is_open(self):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			load("res://scripts/game_codex.gd").close(self)
		return
	if is_instance_valid(level_overlay) and level_overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			level_overlay.hide()
			paused = bool(get_meta("level_previous_pause",false))
			refresh_ui()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: select_kind(0)
			KEY_2: select_kind(1)
			KEY_3: select_kind(2)
			KEY_4: select_kind(3)
			KEY_5: select_kind(4)
			KEY_6: select_kind(5)
			KEY_U: upgrade_selected()
			KEY_Q: use_ability()
			KEY_E: toggle_gate()
			KEY_O: open_settings()
			KEY_SPACE: start_wave()
			KEY_P: toggle_pause()
			KEY_ESCAPE: select_pad(-1)
			KEY_F12: save_screenshot()
			KEY_M:
				if has_meta("settings_values"):
					var values: Dictionary = get_meta("settings_values")
					load("res://scripts/game_settings.gd")._changed(self,"muted",not values.muted)
					sound_enabled = not get_meta("settings_values").muted
				else:
					sound_enabled = not sound_enabled
					if is_instance_valid(audio): audio.set_muted(not sound_enabled)
				show_toast("声音已开启" if sound_enabled else "声音已静音")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		select_pad(-1)
	if event is InputEventMouseMotion and selected_pad < 0 and not ended:
		var index := pad_from_screen(event.position)
		if index != hover_pad:
			hover_pad = index
			clear_preview()
			if hover_pad >= 0 and tower_at(hover_pad)<0:
				show_preview(hover_pad)
			else:
				range_ring.hide()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not ended:
		var selected: Dictionary = {}
		var nearest := 30.0
		for e in enemies:
			if e.hp <= 0: continue
			var screen := camera.unproject_position(e.node.position+Vector3(0,0.3,0))
			var distance := screen.distance_to(event.position)
			if distance < nearest:
				nearest = distance
				selected = e
		if not selected.is_empty():
			select_pad(-1)
			selected_enemy = selected
			refresh_ui()
			return
		var index := pad_from_screen(event.position)
		select_pad(index)
		if index < 0: show_toast("只能在带 + 标记的基座建造；道路和装饰区域不可建造。",2.5)


func capture_demo() -> void:
	for entry in [[2,0],[4,1],[8,2],[10,0],[13,1]]:
		money = 1000
		select_pad(entry[0])
		select_kind(entry[1])
		build_selected()
	money = 185
	select_pad(4)
	start_wave()
	for i in range(180):
		game_tick(0.1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/emerald-watch.png")
	get_tree().quit()

func save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/emerald-watch.png"
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result == OK:
		show_toast("截图已保存")

# Small synthesized effects: no downloaded recordings, no audio dependencies.
func build_sounds() -> void:
	if ResourceLoader.exists("res://scripts/game_audio.gd"):
		audio = load("res://scripts/game_audio.gd").new()
		add_child(audio)
		return
	for data in [["shot",620.0,0.07,-25.0],["boom",115.0,0.16,-23.0],["build",880.0,0.18,-17.0],["wave",330.0,0.32,-18.0],["win",660.0,0.7,-15.0],["loss",180.0,0.6,-17.0]]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var bytes := PackedByteArray()
		var count := int(22050 * data[2])
		bytes.resize(count*2)
		for i in range(count):
			var t := float(i)/22050.0
			var envelope := pow(1.0-float(i)/count,2.0)
			var frequency: float = data[1]*(1.0-0.25*float(i)/count)
			var value := sin(TAU*frequency*t)*envelope
			bytes.encode_s16(i*2,int(value*24000))
		stream.data = bytes
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = data[3]
		add_child(player)
		sounds[data[0]] = player

func play_sound(key: String) -> void:
	if is_instance_valid(audio):
		audio.play_sfx(key)
		return
	if sound_enabled and sounds.has(key):
		sounds[key].play()

func current_level() -> Dictionary:
	if custom_level_data.is_empty():
		return levels[level_index]
	return {"name": custom_level_data.name, "subtitle": "LOCAL / 本地试打", "description": "本地设计关卡 · 作者须通关后自动回放核验", "color": Color("294f4e"), "road": Color("7a8980"), "tree": Color("3d8271"), "gold": custom_level_data.gold, "difficulty": 1.0}

func wave_total() -> int:
	return int(custom_level_data.waves) if not custom_level_data.is_empty() else CAMPAIGN_WAVES[level_index]

func wave_enemy_count() -> int:
	if custom_level_data.is_empty() and level_index >= 6:
		# A 16-pad defense has finite throughput; grow long campaigns more gently.
		return 8 + mini(wave, 6) * 3 + clampi(wave - 6, 0, 6) * 2 + maxi(wave - 12, 0) + 12 + (level_index - 6)
	return int(custom_level_data.count) if not custom_level_data.is_empty() else 8 + mini(wave, 6) * 3 + maxi(wave - 6, 0) * 2 + level_index * 2

func wave_spawn_interval() -> float:
	if not custom_level_data.is_empty(): return maxf(0.45, 1.05-wave*0.055)
	if level_index >= 6: return maxf(0.58, 1.05-wave*0.025-level_index*0.005)
	# Faster mixed waves create overlap across entrances without runaway HP.
	return maxf(0.38, 1.05-wave*0.045-level_index*0.012)

func wave_supply() -> int:
	# Kill income keeps growing; cap passive supplies to retain upgrade choices.
	return 35 + (wave if not custom_level_data.is_empty() else mini(wave, 8)) * 8

func can_switch_gate() -> bool:
	return custom_level_data.is_empty() and (level_index == 1 or bool(current_level().get("gate", false)))

func configure_level() -> void:
	hazard_data = {}
	if not custom_level_data.is_empty():
		ROUTE = []
		for cell in custom_level_data.route:
			ROUTE.append(Vector3(int(cell[0]) * TILE, 0.35, int(cell[1]) * TILE))
		PAD_CELLS = []
		for cell in custom_level_data.pads:
			PAD_CELLS.append(Vector2i(int(cell[0]), int(cell[1])))
		routes = [ROUTE]
		return
	if level_index >= 3:
		var stage: Dictionary = levels[level_index]
		routes = stage.routes.duplicate(true)
		ROUTE = routes[0]
		PAD_CELLS = stage.pads.duplicate()
		hazard_data = stage.get("hazard", {}).duplicate(true)
		return
	if level_index == 0:
		ROUTE = [Vector3(-10.5,0.35,-4.5),Vector3(7.5,0.35,-4.5),Vector3(7.5,0.35,0),Vector3(-7.5,0.35,0),Vector3(-7.5,0.35,4.5),Vector3(9,0.35,4.5)]
		PAD_CELLS = [Vector2i(-5,-1),Vector2i(-3,-1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(3,-1),Vector2i(6,-1),Vector2i(-6,1),Vector2i(-3,1),Vector2i(-1,1),Vector2i(1,1),Vector2i(3,1),Vector2i(5,1),Vector2i(-3,2),Vector2i(-1,2),Vector2i(1,2),Vector2i(3,2)]
	elif level_index == 1:
		ROUTE = [Vector3(-10.5,0.35,-4.5),Vector3(9,0.35,-4.5),Vector3(9,0.35,4.5),Vector3(-7.5,0.35,4.5),Vector3(-7.5,0.35,-1.5),Vector3(4.5,0.35,-1.5),Vector3(4.5,0.35,1.5),Vector3(0,0.35,1.5)]
		PAD_CELLS = [Vector2i(-6,-2),Vector2i(-3,-2),Vector2i(-1,-2),Vector2i(1,-2),Vector2i(3,-2),Vector2i(5,-2),Vector2i(-4,0),Vector2i(-2,0),Vector2i(0,0),Vector2i(2,0),Vector2i(5,0),Vector2i(-4,2),Vector2i(-2,2),Vector2i(0,2),Vector2i(2,2),Vector2i(4,2)]
	else:
		ROUTE = [Vector3(-10.5,0.35,-4.5),Vector3(-4.5,0.35,-4.5),Vector3(-4.5,0.35,1.5),Vector3(1.5,0.35,1.5),Vector3(1.5,0.35,-3),Vector3(7.5,0.35,-3),Vector3(7.5,0.35,4.5),Vector3(10.5,0.35,4.5)]
		PAD_CELLS = [Vector2i(-6,-2),Vector2i(-4,-2),Vector2i(-2,-2),Vector2i(0,-2),Vector2i(2,-1),Vector2i(4,-1),Vector2i(-4,0),Vector2i(-2,0),Vector2i(0,0),Vector2i(2,1),Vector2i(4,1),Vector2i(6,1),Vector2i(-2,2),Vector2i(0,2),Vector2i(2,3),Vector2i(4,3)]

	routes = [ROUTE]
	if level_index == 1:
		routes.append([Vector3(-10.5,0.35,4.5),Vector3(9,0.35,4.5),Vector3(9,0.35,-4.5),Vector3(-7.5,0.35,-4.5),Vector3(-7.5,0.35,-1.5),Vector3(4.5,0.35,-1.5),Vector3(4.5,0.35,1.5),Vector3(0,0.35,1.5)])
	elif level_index == 2:
		routes.append([Vector3(-10.5,0.35,4.5),Vector3(-4.5,0.35,4.5),Vector3(-4.5,0.35,1.5),Vector3(1.5,0.35,1.5),Vector3(1.5,0.35,-3),Vector3(7.5,0.35,-3),Vector3(7.5,0.35,4.5),Vector3(10.5,0.35,4.5)])

func _rebuild_board() -> void:
	# Keep the HUD and controller; rebuild only the 3D board and lighting.
	for child in get_children():
		if child is Node3D or child is WorldEnvironment:
			remove_child(child)
			child.queue_free()
	pads.clear()
	configure_level()
	build_world()
	if ResourceLoader.exists("res://scripts/game_settings.gd"):
		load("res://scripts/game_settings.gd").apply(self)
	_reset_camera()

func _reset_camera() -> void:
	if has_meta("camera_controller") and is_instance_valid(get_meta("camera_controller")):
		get_meta("camera_controller").reset_view()

func choose_level(index: int) -> void:
	if index < 0 or index >= levels.size(): return
	custom_level_data = {}
	level_index = index
	restart()
	if is_instance_valid(level_overlay): level_overlay.hide()
	_rebuild_board()
	money = current_level().gold
	refresh_ui()
	show_toast("%s：%s" % [current_level().name, current_level().description], 6)

func open_designer() -> void:
	if ResourceLoader.exists("res://scripts/level_designer.gd"):
		load("res://scripts/level_designer.gd").open(self)

func start_custom_level(data: Dictionary) -> void:
	var designer = load("res://scripts/level_designer.gd")
	var errors: Array[String] = designer.validate(data)
	if not errors.is_empty():
		show_toast("关卡无效：" + errors[0], 6)
		return
	custom_level_data = designer.canonical_data(data)
	rng.seed = int(custom_level_data.seed)
	restart()
	if is_instance_valid(level_overlay): level_overlay.hide()
	_rebuild_board()
	money = int(custom_level_data.gold)
	if ResourceLoader.exists("res://scripts/author_replay.gd"):
		load("res://scripts/author_replay.gd").begin(self, custom_level_data)
	refresh_ui()
	show_toast("本地试打：%s。通关后自动回放核验；修改关卡需重新验证。" % custom_level_data.name, 7)

func _replay_record(action: String, args: Array) -> void:
	if not custom_level_data.is_empty() and ResourceLoader.exists("res://scripts/author_replay.gd"):
		load("res://scripts/author_replay.gd").record(self, action, args)

func show_level_select() -> void:
	if is_instance_valid(level_overlay) and level_overlay.visible: return
	set_meta("level_previous_pause",paused)
	paused = true
	pause_button.text = "继续"
	GameUI.show_levels(self)
	refresh_ui()

func next_level() -> void:
	choose_level(0 if not custom_level_data.is_empty() else (level_index+1)%levels.size())

func next_wave_description() -> String:
	var n := mini(wave+1,wave_total()) if not active_wave else wave
	var hint := "普通虫 · 推荐脉冲"
	if n >= 2: hint = "疾行虫 · 推荐霜晶减速"
	if n >= 3: hint = "重甲虫 · 推荐穿甲轨炮"
	if n >= 4: hint = "护盾虫 · 推荐雷链破盾"
	if n >= 5: hint = "再生虫 · 推荐焰息阻止治疗"
	if n >= 6: hint = "分裂虫 · 推荐熔核范围清场"
	if custom_level_data.is_empty() and n >= 8: hint = "精锐混编 · 护盾掩护、再生支援与分裂突击"
	if n == wave_total(): hint = "巨型母虫 + 混编精锐 · 优先升级"
	if custom_level_data.is_empty() and level_index == 1 and n >= 2 and n < 5: hint += " / 额外护盾"
	if custom_level_data.is_empty() and level_index == 2 and n >= 2 and n < 6: hint += " / 重甲加速攻势"
	return "%s第 %d 波：%s" % ["本波 " if active_wave else "下一波 ",n,hint]

func wave_enemy_kind(index: int) -> int:
	if wave == wave_total() and index == wave_enemy_count()-1: return 3
	if custom_level_data.is_empty() and level_index >= 6 and wave >= 4:
		var formation: Array = current_level().formation
		return int(formation[(index + wave) % formation.size()])
	if custom_level_data.is_empty() and wave >= 8:
		# Rotating escorts stop map-specific precedence from suppressing support.
		var formations := [
			[2,4,1,6,0,5,1,4],
			[1,6,4,1,2,5,6,0],
			[4,2,5,1,6,2,4,1]
		]
		return formations[(wave + level_index) % formations.size()][index % 8]
	if custom_level_data.is_empty() and level_index == 1 and wave >= 2 and index % 4 == 1: return 4
	if custom_level_data.is_empty() and level_index == 2 and wave >= 2 and index % 4 == 1: return 2
	if custom_level_data.is_empty() and level_index >= 3:
		if level_index == 3 and wave >= 2 and index % 4 == 1: return 4
		if level_index == 4 and wave >= 2 and index % 4 == 1: return 1
		if level_index == 4 and wave >= 3 and index % 6 == 3: return 2
		if level_index == 5 and wave >= 2 and index % 6 == 1: return 2
		if level_index == 5 and wave >= 3 and index % 6 == 3: return 4
		if level_index == 5 and wave >= 4 and index % 6 == 5: return 5
	if wave >= 6 and index % 7 == 5: return 6
	if wave >= 5 and index % 7 == 3: return 5
	if wave >= 4 and index % 5 == 2: return 4
	if wave >= 3 and index % 5 == 4: return 2
	if wave >= 2 and index % 4 == 2: return 1
	return 0

func pad_from_screen(pos: Vector2) -> int:
	var from := camera.project_ray_origin(pos)
	var direction := camera.project_ray_normal(pos)
	var hit = Plane(Vector3.UP,0.4).intersects_ray(from,direction)
	if hit == null: return -1
	var closest := -1
	var distance := 0.78
	for i in range(pads.size()):
		var d := Vector2(hit.x,hit.z).distance_to(Vector2(pads[i].position.x,pads[i].position.z))
		if d < distance:
			distance = d
			closest = i
	return closest

func clear_preview() -> void:
	if is_instance_valid(preview_ghost):
		preview_ghost.queue_free()
		preview_ghost = null

func show_preview(index: int) -> void:
	clear_preview()
	preview_ghost = build_tower_model(selected_kind,pads[index].position+Vector3(0,0.14,0))
	preview_kind = selected_kind
	var tint: Color = TOWER_DATA[selected_kind].color if money >= TOWER_DATA[selected_kind].cost else Color("f47778")
	for child in preview_ghost.find_children("*","MeshInstance3D",true,false):
		var m := mat(Color(tint.r,tint.g,tint.b,0.38),0,0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		child.material_override = m
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: float = TOWER_DATA[selected_kind].range
	range_ring.position = pads[index].position+Vector3(0,0.025,0)
	range_ring.scale = Vector3(r,1,r)
	range_ring.material_override = mat(tint,0,0.2)
	range_ring.visible = show_ranges

func build_road(road: Array) -> void:
	for i in range(road.size()-1):
		var a: Vector3 = road[i]
		var b: Vector3 = road[i+1]
		var count := maxi(1,int(a.distance_to(b)/TILE))
		for j in range(count+1):
			var p := a.lerp(b,float(j)/count)
			var tile_key := Vector2i(roundi(p.x*10),roundi(p.z*10))
			if road_tiles.has(tile_key): continue
			road_tiles[tile_key] = true
			box(world,Vector3(p.x,0.13,p.z),Vector3(1.38,0.2,1.38),Color(current_level().road).lightened(rng.randf_range(-0.03,0.05)))
			if j % 3 == 1:
				var marker := cylinder(world,Vector3(p.x,0.245,p.z),0.11,0.015,Color("cad5b3"),0.11,3)
				marker.rotation.y = PI/2 if b.x>a.x else -PI/2

func use_ability() -> void:
	if ended or paused or not active_wave: return
	if ability_cooldown > 0:
		show_toast("核心震荡冷却中：%d 秒" % ceili(ability_cooldown),2)
		return
	_replay_record("ability", [])
	ability_cooldown = 35.0
	play_sound("ice")
	for e in enemies:
		if e.hp <= 0: continue
		damage_enemy(e,90.0+wave*8,4)
		e.slow = 3.0
		pulse(e.node.position,Color("b3ecff"),0.65)
	pulse(ROUTE[-1],Color("b3ecff"),4.0)
	show_toast("核心震荡：全场穿甲伤害 + 3 秒减速",3)
	refresh_ui()

func toggle_gate() -> void:
	if not can_switch_gate() or ended or paused: return
	if gate_cooldown > 0:
		show_toast("传送门切换冷却中",2)
		return
	_replay_record("gate", [])
	gate_mode = 1-gate_mode
	gate_cooldown = 12.0
	play_sound("build")
	pulse(routes[gate_mode][0],Color("ace4ff"),1.4)
	show_toast("入口已切换为 %s。新敌人改道，场上敌人保持原路线。" % ["A" if gate_mode == 0 else "B"],4)
	refresh_ui()

func open_settings() -> void:
	if ResourceLoader.exists("res://scripts/game_settings.gd"):
		load("res://scripts/game_settings.gd").open(self)

func spawn_damage_label(p: Vector3, amount: float, kind: int) -> void:
	if not show_damage_numbers or damage_labels.size() >= 18: return
	var n := Label3D.new()
	n.text = str(roundi(amount))
	n.font_size = 34
	n.pixel_size = 0.008
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	n.modulate = TOWER_DATA[kind].color if kind >= 0 else Color("ffddb3")
	n.position = p+Vector3(randf_range(-0.2,0.2),1.1,0)
	world.add_child(n)
	damage_labels.append({"node":n,"life":0.65})

func update_damage_labels(dt: float) -> void:
	for i in range(damage_labels.size()-1,-1,-1):
		var item: Dictionary = damage_labels[i]
		item.life -= dt
		if item.life <= 0:
			item.node.queue_free()
			damage_labels.remove_at(i)
		else:
			item.node.position.y += dt*0.8
			item.node.modulate.a = minf(1.0,item.life*2)

func show_codex() -> void:
	if ResourceLoader.exists("res://scripts/game_codex.gd"):
		load("res://scripts/game_codex.gd").open(self)

func enemy_stats(kind: int, wave_override: int = 0) -> Dictionary:
	var n := maxi(1,wave if wave_override == 0 else wave_override)
	var strength := float(n) if not custom_level_data.is_empty() else float(mini(n, 6)) + maxi(n - 6, 0) * 0.5
	# Longer second-act maps add entrances and formations; avoid runaway healing/HP.
	if custom_level_data.is_empty() and level_index >= 6:
		strength = float(mini(n, 6)) + clampi(n - 6, 0, 6) * 0.5 + maxi(n - 12, 0) * 0.2
	var hp: float = (38.0+strength*12.0)*(1.0+0.12*pow(maxf(strength-2,0),1.4))*current_level().difficulty*[1.0,0.65,2.7,14.0,1.25,1.6,1.45][kind]
	return {"name":["侦察虫","疾行虫","重甲虫","巨型母虫","护盾虫","再生虫","分裂虫"][kind],"hp":hp,"speed":[1.65,2.8,1.1,0.85,1.5,1.45,1.7][kind],"armor":0.55 if kind == 2 else 0.0,"shield":hp*0.65 if kind == 4 else 0.0,"ability":["常规推进，无特殊防御","高速穿越防线","普通攻击受到 55% 减伤","高生命；减速效果减半；漏过扣 5 核心","额外能量护盾吸收伤害","每秒治疗 2.8 范围内队友 6% 最大生命","被击败后分裂为两只小型疾行虫"][kind],"counter":["脉冲箭塔高效处理","霜晶减速配合高频攻击","穿甲轨炮与灼烧无视重甲","轨炮集火、升级与核心震荡","雷链对护盾造成双倍伤害","焰息灼烧期间无法治疗或被治疗","熔核范围攻击清理小虫" ][kind],"color":[Color("bf7192"),Color("edb082"),Color("7887bd"),Color("b46eaf"),Color("80cbe8"),Color("91c481"),Color("e2a453")][kind]}

func build_hazard() -> void:
	hazard_ring = null
	if hazard_data.is_empty():
		return
	var tint := Color("ff9363") if hazard_data.kind == "lava" else Color("9bdcff")
	hazard_ring = make_ring(float(hazard_data.radius), tint)
	world.add_child(hazard_ring)
	hazard_ring.position = hazard_data.center + Vector3(0, 0.01, 0)
	for i in range(8):
		var angle: float = i * TAU / 8.0
		var p: Vector3 = hazard_data.center + Vector3(cos(angle), 0, sin(angle)) * float(hazard_data.radius)
		orb(world, p + Vector3(0, 0.10, 0), 0.11, tint)

func hazard_is_active() -> bool:
	return not hazard_data.is_empty() and fmod(hazard_time, float(hazard_data.cycle)) < float(hazard_data.active)

func update_hazard(dt: float) -> void:
	if hazard_data.is_empty():
		return
	var active := hazard_is_active()
	if is_instance_valid(hazard_ring):
		hazard_ring.scale = Vector3.ONE * (1.0 + sin(hazard_time * 5.0) * 0.035 if active else 1.0)
		hazard_ring.transparency = 0.0 if active else 0.72
	if not active:
		return
	var center: Vector3 = hazard_data.center
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var pos: Vector3 = enemy.node.position
		if Vector2(pos.x, pos.z).distance_to(Vector2(center.x, center.z)) > float(hazard_data.radius):
			continue
		if hazard_data.kind == "frost":
			enemy.slow = maxf(float(enemy.slow), 0.3)
		else:
			damage_enemy(enemy, float(hazard_data.damage) * dt, 5)
