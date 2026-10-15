class_name ExtraLevels
extends RefCounted
## Three self-contained battlefield definitions. Coordinates use a 1.5-unit grid.

static func _point(x: int, z: int) -> Vector3:
	return Vector3(x * 1.5, 0.35, z * 1.5)

static func _route(cells: Array) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for cell in cells:
		points.append(_point(int(cell[0]), int(cell[1])))
	return points

static func _pads(cells: Array) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for cell in cells:
		points.append(Vector2i(int(cell[0]), int(cell[1])))
	return points

static func definitions() -> Array:
	return [
		{
			"name": "熔脉岔口",
			"subtitle": "04 / 双闸熔流",
			"description": "切换双入口，引导虫群绕行熔脉。熔岩每 12 秒喷发 4 秒，对经过的敌人持续造成伤害。",
			"color": Color("60463e"),
			"road": Color("a58b71"),
			"tree": Color("bc7952"),
			"gold": 550,
			"difficulty": 1.40,
			"routes": [
				_route([[-7,-4],[5,-4],[5,-1],[-5,-1],[-5,2],[7,2],[7,4]]),
				_route([[-7,4],[3,4],[3,1],[-7,1],[-7,-2],[7,-2],[7,4]])
			],
			"pads": _pads([[-6,-3],[-4,-3],[-2,-3],[0,-3],[2,-3],[4,-3],[-4,0],[-2,0],[0,0],[2,0],[4,0],[6,0],[-4,3],[-2,3],[0,3],[5,3]]),
			"gate": true,
			"hazard": {"center": _point(0,-1), "radius": 2.6, "cycle": 12.0, "active": 4.0, "kind": "lava", "damage": 10.0},
			"composition": 3
		},
		{
			"name": "霜镜交汇",
			"subtitle": "05 / 双线寒潮",
			"description": "两支虫群交替从双入口进攻。中央霜场每 10 秒苏醒 3.5 秒，减缓经过的敌人，把握集火时机。",
			"color": Color("3b5968"),
			"road": Color("97b7bf"),
			"tree": Color("a7cbd8"),
			"gold": 600,
			"difficulty": 1.55,
			"routes": [
				_route([[-7,-4],[5,-4],[5,0],[-5,0],[-5,4],[7,4]]),
				_route([[-7,4],[-7,2],[3,2],[3,-2],[-5,-2],[-5,-4],[7,-4],[7,4]])
			],
			"pads": _pads([[-4,-3],[0,-3],[4,-3],[6,-3],[-6,-1],[-2,-1],[0,-1],[4,-1],[-4,1],[-2,1],[0,1],[4,1],[-4,3],[0,3],[4,3],[6,3]]),
			"gate": false,
			"hazard": {"center": _point(-1,0), "radius": 3.4, "cycle": 10.0, "active": 3.5, "kind": "frost", "damage": 0.0},
			"composition": 4
		},
		{
			"name": "裂隙围城",
			"subtitle": "06 / 四面合围",
			"description": "四处裂隙轮流涌出混编精锐，长短攻势交错汇向核心。中央熔池每 11 秒喷发 3 秒，兼顾四路并利用火场清群。",
			"color": Color("4b455a"),
			"road": Color("97919d"),
			"tree": Color("9f80b4"),
			"gold": 650,
			"difficulty": 1.70,
			"routes": [
				_route([[-7,-4],[5,-4],[5,0],[-5,0],[-5,4],[7,4]]),
				_route([[7,-4],[-5,-4],[-5,-1],[5,-1],[5,2],[-3,2],[-3,4],[7,4]]),
				_route([[-7,4],[-7,-2],[3,-2],[3,2],[-3,2],[-3,4],[7,4]]),
				_route([[7,0],[7,-3],[-3,-3],[-3,0],[3,0],[3,3],[-5,3],[-5,4],[7,4]])
			],
			"pads": _pads([[-6,-3],[-4,-3],[4,-2],[6,-2],[-6,-1],[6,-1],[-6,1],[-4,1],[-2,1],[0,1],[2,1],[4,1],[6,1],[-6,3],[4,3],[6,3]]),
			"gate": false,
			"hazard": {"center": _point(0,0), "radius": 2.8, "cycle": 11.0, "active": 3.0, "kind": "lava", "damage": 12.0},
			"composition": 5
		}
	]
