extends SceneTree
var checks := 0
func verify(condition: bool, message: String):
	checks += 1
	assert(condition, message)
func _initialize():
	var stages: Array = load("res://scripts/extra_levels.gd").definitions()
	verify(stages.size() == 3, "three additional stages")
	for stage in stages:
		verify(stage.routes.size() >= 1 and stage.routes.size() <= 4, "route count")
		verify(stage.pads.size() == 16, "16 pads")
		var seen: Dictionary = {}
		for pad in stage.pads:
			verify(not seen.has(pad), "unique pad")
			seen[pad] = true
			verify(abs(pad.x) <= 7 and abs(pad.y) <= 4, "pad within board")
		var endpoint: Vector3 = stage.routes[0][-1]
		var starts: Dictionary = {}
		var lengths: Array[float] = []
		var nearest := INF
		for path in stage.routes:
			verify(path[-1].is_equal_approx(endpoint), "shared goal")
			verify(not starts.has(path[0]), "distinct entrances")
			starts[path[0]] = true
			var length := 0.0
			for point in path:
				verify(abs(point.x) <= 10.5 and abs(point.z) <= 6.0, "road within board")
				verify(is_equal_approx(point.x / 1.5, round(point.x / 1.5)) and is_equal_approx(point.z / 1.5, round(point.z / 1.5)), "1.5 grid")
			for segment in range(path.size() - 1):
				var a: Vector3 = path[segment]
				var b: Vector3 = path[segment + 1]
				verify((is_equal_approx(a.x,b.x) or is_equal_approx(a.z,b.z)) and not a.is_equal_approx(b), "axis aligned nonzero segment")
				length += a.distance_to(b)
				var av := Vector2(a.x,a.z)
				var bv := Vector2(b.x,b.z)
				for pad in stage.pads:
					var point := Vector2(pad.x*1.5,pad.y*1.5)
					var distance: float = point.distance_to(Geometry2D.get_closest_point_to_segment(point,av,bv))
					nearest = minf(nearest,distance)
					verify(distance >= 1.499, "pad-road clearance")
				for other in range(segment+2,path.size()-1):
					var c: Vector3 = path[other]
					var d: Vector3 = path[other+1]
					verify(Geometry2D.segment_intersects_segment(av,bv,Vector2(c.x,c.z),Vector2(d.x,d.z)) == null, "no route self-crossings")
			verify(length >= 40.0, "minimum travel distance")
			lengths.append(length)
		verify(stage.hazard.active > 0.0 and stage.hazard.active < stage.hazard.cycle, "hazard duty cycle")
		verify(stage.hazard.kind in ["lava","frost"], "hazard kind")
		verify(not stage.gate or stage.routes.size() >= 2, "gate supports multiple routes")
		print(stage.name, " lengths=",lengths," pads=",stage.pads.size()," min_clearance=",nearest," hazard=",stage.hazard.kind)
	print("PASS ",checks," geometry and schema checks")
	quit()
