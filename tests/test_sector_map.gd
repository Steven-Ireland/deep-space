extends SceneTree
## Sector map rules (GDD §6, TECH §8), checked on many seeds by walking every route from the
## departure to the boss, independently of the generator's own checks; and determinism: the same
## seed charts the same sector.
##   tools/godot.sh --headless -s tests/test_sector_map.gd

const SEEDS := 400

var failures := 0


func _init() -> void:
	var types := {}
	var nodes := 0
	var fuel_stops := 0
	var widest_routes := 0
	for run_seed in range(1, SEEDS + 1):
		for sector in range(1, 4):
			var map := SectorMap.generate(run_seed, sector)
			_check(map.problems().is_empty(), "seed %d sector %d: %s" % [run_seed, sector, map.problems()])
			_check_routes(map, "seed %d sector %d" % [run_seed, sector])
			_check(SectorMap.generate(run_seed, sector).checksum() == map.checksum(), "seed %d sector %d: not deterministic" % [run_seed, sector])
			for at in map.nodes():
				var type := map.type_of(at)
				if at.y >= 2 and at.y <= SectorMap.ROWS:
					types[type] = types.get(type, 0) + 1
					nodes += 1
					if SectorMap.info(type).get("refuel", false):
						fuel_stops += 1
			widest_routes = maxi(widest_routes, _routes(map, SectorMap.start()).size())
	_check(SectorMap.generate(1, 1).checksum() != SectorMap.generate(2, 1).checksum(), "different seeds chart the same sector")
	_check(SectorMap.generate(1, 1).checksum() != SectorMap.generate(1, 2).checksum(), "different sectors chart the same")
	var shares := []
	for type: StringName in SectorMap.TYPES:
		shares.append("%s %d%%" % [type, roundi(100.0 * types.get(type, 0) / maxf(nodes, 1))])
	print("Rows 2-7 by type (rolled, then repaired): ", ", ".join(shares))
	print("Fuel stops: %.1f a map; most routes in one map: %d" % [float(fuel_stops) / (SEEDS * 3), widest_routes])
	print("test_sector_map: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


## Every route from the departure to the boss passes fuel and never runs three EVAs; the first row
## is all derelicts; rows are two to four wide; routes never cross.
func _check_routes(map: SectorMap, label: String) -> void:
	_check(map.rows.size() == SectorMap.BOSS_ROW + 1, "%s: %d rows" % [label, map.rows.size()])
	for row in range(1, SectorMap.BOSS_ROW):
		var width: int = map.rows[row].size()
		_check(width >= 2 and width <= 4, "%s: row %d is %d wide" % [label, row, width])
		for i in width:
			if row == 1:
				_check(map.type_of(Vector2i(i, 1)) == &"derelict", "%s: row 1 has a %s" % [label, map.type_of(Vector2i(i, 1))])
	for row in SectorMap.BOSS_ROW:
		var edges := []
		for i in map.rows[row].size():
			for j: int in map.rows[row][i].next:
				edges.append(Vector2i(i, j))
		for a: Vector2i in edges:
			for b: Vector2i in edges:
				_check(not (a.x < b.x and a.y > b.y), "%s: routes %s and %s cross after row %d" % [label, a, b, row])
	for route in _routes(map, SectorMap.start()):
		var fuel := false
		var evas := 0
		for at: Vector2i in route:
			var info := SectorMap.info(map.type_of(at))
			fuel = fuel or info.get("refuel", false)
			evas = evas + 1 if info.get("eva", false) else 0
			_check(evas < 3, "%s: three EVAs in a row on %s" % [label, route])
		_check(fuel, "%s: no fuel on %s" % [label, route])
		_check(route.back() == SectorMap.boss(), "%s: a route ends at %s" % [label, route.back()])


## Every route from `at` to the end of the chart.
func _routes(map: SectorMap, at: Vector2i) -> Array:
	var next := map.next_of(at)
	if next.is_empty():
		return [[at]]
	var out := []
	for to in next:
		for rest: Array in _routes(map, to):
			out.append([at] + rest)
	return out


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 20:
			printerr("FAIL: ", message)
