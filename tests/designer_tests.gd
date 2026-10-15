extends SceneTree

const Designer = preload("res://scripts/level_designer.gd")
var checks := 0
var failures := 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var sample := Designer.template_data()
	expect(Designer.validate(sample).is_empty(), "default level is valid")
	var canonical := Designer.canonical_data(sample)
	expect(Designer.canonical_data(JSON.parse_string(JSON.stringify(sample))) == canonical, "canonical JSON roundtrip stays identical")
	var redundant := sample.duplicate(true)
	redundant.route.insert(1, [-2, -3])
	redundant.pads.reverse()
	expect(Designer.canonical_data(redundant) == canonical, "pad order and redundant straight waypoint are canonicalized")
	for invalid in [null, [], {}, {"schema": 1}]:
		expect(not Designer.validate(invalid).is_empty(), "malformed data rejected safely: " + str(invalid))
	for key in ["waves", "count", "gold", "seed"]:
		var invalid := sample.duplicate(true)
		invalid[key] = 1.25
		expect(not Designer.validate(invalid).is_empty(), key + " rejects fractional value")
	var bad_route := sample.duplicate(true)
	bad_route.route = [[-7, -3], [5, 0]]
	expect(not Designer.validate(bad_route).is_empty(), "diagonal road rejected")
	bad_route.route = [[-7, -3], [-7, -3], [5, -3]]
	expect(not Designer.validate(bad_route).is_empty(), "zero-length segment rejected")
	bad_route.route = [[-7, -3], [5, -3], [5, 2], [-4, 2], [-4, -4]]
	expect(not Designer.validate(bad_route).is_empty(), "self-intersecting route rejected")
	bad_route.route = [[-7, -3], [5, -3], [1, -3]]
	expect(not Designer.validate(bad_route).is_empty(), "route backtracking rejected")
	bad_route.route = [[-7, -3], [-6, -3]]
	expect(not Designer.validate(bad_route).is_empty(), "short route rejected")
	bad_route.route = [[-8, -3], [5, -3]]
	expect(not Designer.validate(bad_route).is_empty(), "out-of-grid route rejected")
	var bad_pad := sample.duplicate(true)
	bad_pad.pads[0] = [-7, -3]
	expect(not Designer.validate(bad_pad).is_empty(), "on-road pad rejected")
	bad_pad = sample.duplicate(true)
	bad_pad.pads[0] = bad_pad.pads[1]
	expect(not Designer.validate(bad_pad).is_empty(), "duplicate pad rejected")
	bad_pad = sample.duplicate(true)
	bad_pad.pads = bad_pad.pads.slice(0, 3)
	expect(not Designer.validate(bad_pad).is_empty(), "too few pads rejected")
	print("DESIGNER VALIDATION: %d checks / %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
