class_name ExtraLevels
extends RefCounted
## Nine self-contained battlefield definitions. Coordinates use a 1.5-unit grid.

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
		},
		{
			"name": "苔湾长堤", "subtitle": "07 / 回湾再生",
			"description": "单入口沿海堤折返；再生虫与分裂虫结伴推进。霜场封住中段，利用焰息与熔核清理密集虫群。",
			"color": Color("365a48"), "road": Color("96a981"), "tree": Color("75ac70"),
			"gold": 700, "difficulty": 1.75,
			"routes": [_route([[-7, -4], [7, -4], [7, -1], [-5, -1], [-5, 3], [7, 3], [7, 4]])],
			"pads": _pads([[-5, -2], [6, -2], [-4, 0], [-4, 2], [-6, -1], [5, -3], [-6, 3], [-3, -2], [-4, -3], [6, 0], [6, 2], [-6, 1], [-6, -3], [0, -2], [-1, -3], [1, -3]]), "gate": false,
			"hazard": {"center": _point(-1,0), "radius": 2.8, "cycle": 12.0, "active": 3.0, "kind": "frost", "damage": 10.0},
			"formation": [5, 6, 1, 5, 2, 4, 6, 0], "composition": 6
		},
		{
			"name": "金砂折塔", "subtitle": "08 / 纵深双闸",
			"description": "双闸分别进入纵向折线，切门改变敌人行程。重甲与护盾轮番压近，轨炮应覆盖多段狭道。",
			"color": Color("74613f"), "road": Color("c2ae7d"), "tree": Color("c0a15a"),
			"gold": 730, "difficulty": 1.8,
			"routes": [_route([[-7, -4], [-7, 3], [-3, 3], [-3, -3], [1, -3], [1, 3], [5, 3], [5, -4], [7, -4], [7, 4]]), _route([[-5, -4], [-5, 1], [-1, 1], [-1, -3], [3, -3], [3, 1], [7, 1], [7, 4]])],
			"pads": _pads([[6, 2], [0, -2], [3, 2], [-5, 2], [-2, -2], [2, -2], [6, 0], [4, -3], [-1, 2], [2, 1], [-6, 1], [0, 1], [-2, 0], [-4, 0], [4, 0], [-4, -3]]), "gate": true,
			"hazard": {"center": _point(1,0), "radius": 2.8, "cycle": 12.0, "active": 3.0, "kind": "lava", "damage": 10.0},
			"formation": [2, 4, 2, 1, 5, 4, 6, 0], "composition": 7
		},
		{
			"name": "潮汐三洲", "subtitle": "09 / 三流归港",
			"description": "三路轮流入侵，沿上下海岸汇入右侧港口。疾行虫夹带分裂虫冲线，中央霜场帮助建立交叉火力。",
			"color": Color("315968"), "road": Color("91b8ae"), "tree": Color("63b7b2"),
			"gold": 770, "difficulty": 1.85,
			"routes": [_route([[-7, -4], [5, -4], [5, 0], [-3, 0], [-3, 4], [7, 4]]), _route([[-7, 4], [-7, 2], [3, 2], [3, -2], [-5, -2], [-5, -4], [7, -4], [7, 4]]), _route([[7, 0], [7, -3], [-3, -3], [-3, 1], [5, 1], [5, 4], [7, 4]])],
			"pads": _pads([[-4, -3], [4, 2], [6, 0], [4, -2], [6, -2], [-4, 0], [6, 2], [-2, -1], [3, 3], [2, -1], [-2, 3], [-6, -3], [-4, 3], [-5, -1], [-5, 1], [0, -1]]), "gate": false,
			"hazard": {"center": _point(1,0), "radius": 2.8, "cycle": 12.0, "active": 3.0, "kind": "frost", "damage": 10.0},
			"formation": [1, 6, 1, 4, 2, 6, 5, 0], "composition": 8
		},
		{
			"name": "赤铜盘山", "subtitle": "10 / 熔炉长巡",
			"description": "单路盘旋深入再折返核心；护盾与再生精锐护送重甲。长路便于集中升级，火场只能辅助清群。",
			"color": Color("6c4641"), "road": Color("b68b72"), "tree": Color("cb7759"),
			"gold": 800, "difficulty": 1.9,
			"routes": [_route([[-7, -4], [7, -4], [7, 4], [-7, 4], [-7, -1], [4, -1], [4, 2], [-4, 2]])],
			"pads": _pads([[5, 3], [3, 3], [5, 0], [5, -2], [3, 0], [6, 2], [-6, 3], [3, -2], [-6, -2], [6, -3], [-6, 0], [2, 1], [0, 3], [-2, 3], [4, -3], [6, -1]]), "gate": false,
			"hazard": {"center": _point(0,-1), "radius": 2.8, "cycle": 12.0, "active": 3.0, "kind": "lava", "damage": 10.0},
			"formation": [4, 5, 2, 4, 6, 5, 1, 0], "composition": 9
		},
		{
			"name": "月杉双环", "subtitle": "11 / 双闸夜袭",
			"description": "两座入口通向不同环线，共守左侧林心。霜场减速配合切门争取时间，分裂与重甲考验范围和穿甲配置。",
			"color": Color("414a68"), "road": Color("979ab9"), "tree": Color("9c99ca"),
			"gold": 840, "difficulty": 1.95,
			"routes": [_route([[-7, -4], [7, -4], [7, 3], [-5, 3], [-5, 0], [-7, 0]]), _route([[-7, 4], [5, 4], [5, -2], [-5, -2], [-5, 0], [-7, 0]])],
			"pads": _pads([[-6, -1], [-4, 0], [-6, 1], [-4, 2], [6, -3], [6, 2], [-5, -3], [-6, 3], [4, -3], [6, -1], [-3, -1], [4, 2], [-3, -3], [-3, 1], [0, -3], [2, -3]]), "gate": true,
			"hazard": {"center": _point(0,3), "radius": 2.8, "cycle": 12.0, "active": 3.0, "kind": "frost", "damage": 10.0},
			"formation": [6, 2, 4, 6, 5, 2, 1, 0], "composition": 10
		},
		{
			"name": "星陨终阵", "subtitle": "12 / 四隘决战",
			"description": "四入口交替推进，分别绕行外圈和中央折线后汇入核心。全兵种精锐持续冲击，分区减速并预留母虫火力。",
			"color": Color("4e405f"), "road": Color("aa95ae"), "tree": Color("c78abd"),
			"gold": 900, "difficulty": 2.0,
			"routes": [_route([[-7, -4], [5, -4], [5, 0], [-5, 0], [-5, 4], [7, 4]]), _route([[7, -4], [-5, -4], [-5, -2], [3, -2], [3, 2], [-3, 2], [-3, 4], [7, 4]]), _route([[-7, 4], [-7, -3], [1, -3], [1, 1], [-3, 1], [-3, 4], [7, 4]]), _route([[7, 0], [7, -3], [-3, -3], [-3, -1], [5, -1], [5, 3], [-5, 3], [-5, 4], [7, 4]])],
			"pads": _pads([[-4, 2], [4, -2], [-4, -1], [4, 2], [2, 1], [6, 3], [6, -2], [-6, -2], [-6, 3], [6, 0], [-6, 0], [-4, 1], [-5, -1], [4, 1], [6, -1], [6, 2]]), "gate": false,
			"hazard": {"center": _point(0,0), "radius": 2.8, "cycle": 12.0, "active": 3.0, "kind": "lava", "damage": 10.0},
			"formation": [2, 4, 6, 5, 1, 4, 2, 6, 0, 1, 6, 0, 4, 1, 2, 0], "composition": 11
		}
	]
