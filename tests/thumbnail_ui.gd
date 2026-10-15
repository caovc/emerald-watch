extends SceneTree
## Logical/model-source regression checks; this is not screenshot or GPU-render QA.
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print(("PASS " if ok else "FAIL ") + message)
func settle() -> void:
	for i in range(4): await process_frame
func signature(node: Node3D) -> Array:
	var result: Array = [node.get_class(),node.transform]
	if node is MeshInstance3D:
		result.append(node.mesh.get_class())
		result.append(node.get_aabb())
		result.append(node.material_override.albedo_color)
	for child in node.get_children():
		if child is Node3D: result.append(signature(child))
	return result
func run() -> void:
	root.size = Vector2i(1440,900)
	var g: Node = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.sound_enabled = false
	g.show_damage_numbers = false
	if is_instance_valid(g.audio): g.audio.set_muted(true)
	await settle()
	var refs: Dictionary = g.get_meta("game_ui")
	expect(refs.dock.size == Vector2(608,70), "compact dock is 608 by70 logical pixels")
	expect(g.tower_buttons.size()==6 and refs.thumbnail_viewports.size()==6, "six models for six tower buttons")
	for i in range(6):
		var vp: SubViewport = refs.thumbnail_viewports[i]
		var model: Node3D = vp.get_child(0).get_node("ExactTowerModel%d" % i)
		var actual: Node3D = g.build_tower_model(i,Vector3.ZERO,1)
		expect(signature(model)==signature(actual), "tower%d thumbnail geometry/materials/transforms exactly match battlefield factory" % i)
		actual.queue_free()
		expect(vp.own_world_3d and vp.size==Vector2i(144,144), "tower%d isolated144px render viewport" % i)
		expect(g.tower_buttons[i].text.is_empty(), "tower%d has no permanent name/description card" % i)
		expect(g.tower_buttons[i].size.x>=44 and g.tower_buttons[i].size.y>=44, "tower%d minimum44px touch target" % i)
		var camera: Camera3D = vp.get_camera_3d()
		expect(camera.projection==Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size,2.10) and camera.position==Vector3(2.8,2.5,-3.7), "tower%d shared presentation angle" % i)
		var fits := true
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for corner in range(8):
				var point: Vector2 = camera.unproject_position(mesh.global_transform * mesh.get_aabb().get_endpoint(corner))
				if not Rect2(0,0,144,144).has_point(point): fits=false
		expect(fits, "tower%d entire model fits thumbnail camera" % i)
	g.money=0
	g.refresh_ui()
	for i in range(6):
		expect(refs.tower_thumbnails[i].modulate.a<1 and g.tower_buttons[i].tooltip_text.contains("还差"), "tower%d clearly unaffordable" % i)
	g.money=1000
	g.select_kind(5)
	expect(g.tower_buttons[5].get_theme_stylebox("normal").border_color==g.TOWER_DATA[5].color, "selected thumbnail uses its tower accent")
	g.show_level_select()
	await settle()
	var grid: GridContainer = g.level_overlay.find_children("*","GridContainer",true,false)[0]
	expect(grid.columns==3 and grid.get_child_count()==12,"twelve levels use three-column scrollable layout")
	var scroll: ScrollContainer = grid.get_parent()
	expect(scroll.get_v_scroll_bar().max_value>scroll.size.y,"twelve levels enable vertical scrolling")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await settle()
	expect(scroll.get_global_rect().intersects(grid.get_child(11).get_global_rect()),"last level is reachable by scrolling")
	GameUI._close_levels(g)
	for stage in range(12):
		g.choose_level(stage)
		await settle()
		expect(is_instance_valid(refs.thumbnail_viewports[0].get_child(0).get_node("ExactTowerModel0")),"stage%d rebuild keeps thumbnail models alive" % (stage+1))
	g.choose_level(11)
	g.next_level()
	expect(g.level_index==0,"next stage wraps from 12 to 1")
	for repeat in range(3):
		g.show_level_select()
		await settle()
		expect(g.level_overlay.find_children("*","GridContainer",true,false)[0].get_child_count()==12,"reopening selector preserves twelve cards")
		GameUI._choose_level(g,11)
		expect(g.level_index==11 and g.wave==0 and g.health==20,"selection safely restarts final level")
	print("THUMBNAIL UI RESULT: %d checks, %d failures" % [checks,failures])
	g.queue_free()
	await settle()
	quit(1 if failures else 0)
