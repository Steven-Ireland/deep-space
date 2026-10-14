extends SceneTree
## Relay satellite layouts (GDD §8.1, TECH §6), checked on many seeds independently of the
## generator's own `problems()`: from what the Decks will build (each level's rows and openings, and
## the hatchways between levels), every room can be reached from the entry hatch, nothing lies
## toward the LANTERN or outside its box, it stands on three levels or more, the Prize is a dead end
## far in; windows and the hatch face space. Its solar wings, dish and mast stand clear of its hull.
## The loot holds at most one fuel cell, known items only, and grows with the crew. Each module's
## furniture stays in its own cells, out of its doorways and from under its hatchways. The same seed
## grows the same satellite; others grow others.
##   tools/godot.sh --headless -s tests/test_satellite_layout.gd

const SEEDS := 300
## A door's way (SatelliteRooms): this far either side of its middle, this far into the room; a
## hatchway's, this far round its cell's middle.
const DOOR_HALF := 1.25
const DOOR_DEPTH := 1.2
const HATCHWAY_CLEAR := 1.1
## The grid (Deck, RoomLayout): a cell, a wall's face from its centre, the levels' pitch.
const CELL := 4.0
const HALF_CELL := 2.0
const WALL_FACE := 1.85
const PITCH := 4.0
## The hull round a cell (art/blender/satellite.py): out from its wall lines, below its deck and up
## to its roof's top.
const HULL_OUT := 0.56
const HULL_BOTTOM := -0.5
const HULL_TOP := 3.5
## The hero pieces' reach (art/blender/satellite.py): a solar wing from its mount (its width and
## height, out along +Z: its panels stand on edge), the dish over its mount, the mast.
const WING := Vector3(0.4, 2.9, 11.6)
const DISH := Vector3(4.4, 4.6, 4.4)
const MAST := Vector3(0.6, 3.2, 0.6)
const SIDES := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const OPPOSITE := {"N": "S", "E": "W", "S": "N", "W": "E"}

var failures := 0
var layouts: GDScript
var rooms: GDScript
var items: GDScript


func _initialize() -> void:
	layouts = load("res://game/encounter/satellite_layout.gd")
	rooms = load("res://game/encounter/satellite_rooms.gd")
	items = load("res://game/items/items.gd")
	_check_modules()
	var sizes := []
	var types := {}
	var level_counts := []
	var hatchways := 0
	var loops := 0
	var retries := 0
	var finds := [0, 0]
	var fuel := 0
	var prize_depth := 0
	var seen := {}
	for seed in range(1, SEEDS + 1):
		for sector in range(1, 4):
			var layout = layouts.generate(seed, sector)
			var label := "seed %d sector %d" % [seed, sector]
			_check(layout.problems().is_empty(), "%s: %s" % [label, layout.problems()])
			_check(layouts.generate(seed, sector).checksum() == layout.checksum(), "%s: not deterministic" % label)
			_check_structure(layout, label)
			_check_outside(layout, label)
			_check_loot(layout, label)
			seen[layout.checksum()] = true
			sizes.append(layout.rooms.size())
			level_counts.append(layout.levels().size())
			for room: Dictionary in layout.rooms:
				types[room.type] = types.get(room.type, 0) + 1
			for level: int in layout.levels():
				hatchways += layout.hatchways(level).size()
			loops += layout.joins.size() - (layout.rooms.size() - 1)
			retries += layout.attempt
			finds[0] += layout.loot(1).size()
			finds[1] += layout.loot(4).size()
			fuel += 1 if layout.has_fuel() else 0
			prize_depth += layout._depths()[layout.prize]
	var runs := SEEDS * 3
	_check(seen.size() == runs, "%d of %d layouts are repeats" % [runs - seen.size(), runs])
	_check(absf(float(fuel) / runs - 0.5) < 0.1, "a fuel cell in %d%% of satellites, not about half" % (100 * fuel / runs))
	var total: int = sizes.reduce(func(a: int, b: int) -> int: return a + b)
	var shares := []
	for type: StringName in rooms.MODULES:
		shares.append("%s %.1f" % [type, float(types.get(type, 0)) / runs])
	print("Rooms a satellite: %.1f (%d-%d); by type: %s" % [float(total) / runs, sizes.min(), sizes.max(), ", ".join(shares)])
	print("Levels: %.1f (%d-%d); hatchways %.1f; loops %.2f; regrown %d times" % [
			float(level_counts.reduce(func(a: int, b: int) -> int: return a + b)) / runs, level_counts.min(), level_counts.max(),
			float(hatchways) / runs, float(loops) / runs, retries])
	print("Finds: %.1f for one crew, %.1f for four (%.2f a room for one); a fuel cell in %d%%; the Prize %.1f rooms in" % [
			float(finds[0]) / runs, float(finds[1]) / runs, float(finds[0]) / total, 100 * fuel / runs, float(prize_depth) / runs])
	print("test_satellite_layout: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


## From the Decks' own layouts: each level's rooms by character and edges by opening, and the
## hatchways between levels. Walks from the entry; every room's reached, the Prize only through one
## door, far in.
func _check_structure(layout, label: String) -> void:
	var origin: Vector2i = layout.origin()
	var levels: Array = layout.levels()
	_check(levels.size() >= layout.MIN_LEVELS, "%s: only %d levels" % [label, levels.size()])
	var cells := {} # Vector3i (layout col, level, row) -> mark
	var openings := {}
	var up := {} # Vector3i -> true: a hatchway up from this cell
	for level: int in levels:
		var rows: PackedStringArray = layout.rows(level)
		for r in rows.size():
			for c in rows[r].length():
				if rows[r][c] != ".":
					cells[Vector3i(c, level, r)] = rows[r][c]
		var level_openings: Dictionary = layout.openings(level)
		for key: String in level_openings:
			openings["%d:%s" % [level, key]] = level_openings[key]
		for cell: Vector2i in layout.hatchways(level):
			up[Vector3i(cell.x + origin.x, level, cell.y + origin.y)] = true
	var entry := Vector3i(origin.x, 0, origin.y)
	_check(cells.get(entry, ".") == layout.MARKS[0], "%s: the entry isn't at the origin" % label)
	_check(openings.get("0:%d,%d,W" % [entry.x, entry.z]) == "hatch", "%s: no hatch west of the entry" % label)
	for cell: Vector3i in cells:
		var grid := cell - entry
		_check(grid.x >= 0, "%s: a room reaches toward the LANTERN at %s" % [label, grid])
		_check(layout.BOX.has_point(Vector3(grid) + Vector3.ONE * 0.5), "%s: a room outside the box at %s" % [label, grid])
	for key: String in openings:
		var level := int(key.get_slice(":", 0))
		var parts := key.get_slice(":", 1).split(",")
		var cell := Vector3i(int(parts[0]), level, int(parts[1]))
		var flat: Vector2i = SIDES[parts[2]]
		var beyond := cell + Vector3i(flat.x, 0, flat.y)
		var kind: String = openings[key]
		_check(cells.has(cell), "%s: an opening (%s) at %s, outside any room" % [label, kind, key])
		if kind in ["door", "open"]:
			_check(cells.has(beyond) and cells[beyond] != cells.get(cell), "%s: a %s at %s doesn't join two rooms" % [label, kind, key])
		else:
			_check(not cells.has(beyond), "%s: a %s at %s faces a room, not space" % [label, kind, key])
	for cell: Vector3i in up:
		_check(cells.has(cell) and cells.has(cell + Vector3i.UP), "%s: a hatchway at %s leads nowhere" % [label, cell - entry])
	# Walk it: within a room's cells freely, between rooms through doors, open joins and hatchways.
	var depth := {cells[entry]: 0}
	var queue := [entry]
	var reached := {entry: true}
	var prize_mark: String = layout.MARKS[layout.prize]
	var prize_ways := {}
	while not queue.is_empty():
		var at: Vector3i = queue.pop_front()
		var ways := []
		for side: String in SIDES:
			var flat: Vector2i = SIDES[side]
			var next := at + Vector3i(flat.x, 0, flat.y)
			var opening: String = openings.get("%d:%d,%d,%s" % [at.y, at.x, at.z, side],
					openings.get("%d:%d,%d,%s" % [next.y, next.x, next.z, OPPOSITE[side]], "wall"))
			ways.append([next, opening, "%s,%s" % [at, side]])
		ways.append([at + Vector3i.UP, "hatchway" if up.has(at) else "wall", "%s,U" % at])
		ways.append([at + Vector3i.DOWN, "hatchway" if up.has(at + Vector3i.DOWN) else "wall", "%s,U" % (at + Vector3i.DOWN)])
		for way: Array in ways:
			var next: Vector3i = way[0]
			if not cells.has(next) or reached.has(next):
				continue
			var same: bool = cells[next] == cells[at]
			if not same or way[1] == "hatchway":
				if way[1] not in ["door", "open", "hatchway"]:
					continue
				if not same and (cells[next] == prize_mark or cells[at] == prize_mark):
					prize_ways[way[2]] = true
				if not same and not depth.has(cells[next]):
					depth[cells[next]] = depth[cells[at]] + 1
			reached[next] = true
			queue.append(next)
	_check(reached.size() == cells.size(), "%s: %d cells can't be reached from the entry" % [label, cells.size() - reached.size()])
	_check(prize_ways.size() == 1, "%s: the Prize room has %d ways in" % [label, prize_ways.size()])
	_check(depth.get(prize_mark, 0) >= layout.PRIZE_DEPTH, "%s: the Prize is only %d rooms in" % [label, depth.get(prize_mark, 0)])


## The hero pieces outside: two solar wings, a dish and a mast, none of them in the hull, the dish
## and mast on roofs with nothing over them.
func _check_outside(layout, label: String) -> void:
	var hull := []
	for cell: Vector3i in layout.room_of:
		var centre := Vector3(cell.x * CELL, cell.y * PITCH, cell.z * CELL)
		hull.append(AABB(centre + Vector3(-HALF_CELL - HULL_OUT, HULL_BOTTOM, -HALF_CELL - HULL_OUT),
				Vector3(CELL + 2 * HULL_OUT, HULL_TOP - HULL_BOTTOM, CELL + 2 * HULL_OUT)))
	var wings := 0
	for part: Dictionary in layout.exterior:
		var at: Transform3D = part.at
		var box: AABB
		match String(part.model).get_file():
			"sh_solar_wing":
				wings += 1
				box = at * AABB(Vector3(-WING.x / 2, -WING.y / 2, 0.05), WING)
			"sh_dish":
				box = at * AABB(Vector3(-DISH.x / 2, 0.05, -DISH.z / 2), DISH)
			"sh_mast":
				box = at * AABB(Vector3(-MAST.x / 2, 0.05, -MAST.z / 2), MAST)
			"sh_rcs":
				continue
			_:
				_check(false, "%s: an unknown piece outside, %s" % [label, part.model])
				continue
		for cell_box: AABB in hull:
			_check(not cell_box.grow(-0.02).intersects(box), "%s: its %s cuts into the hull" % [label, String(part.model).get_file()])
	_check(wings == 2, "%s: %d solar wings" % [label, wings])


## At most one fuel cell, only things the game knows, inside the rooms, the same for the same crew,
## more for more.
func _check_loot(layout, label: String) -> void:
	var solo: Array = layout.loot(1)
	var four: Array = layout.loot(4)
	_check(solo.filter(func(find: Dictionary) -> bool: return find.kind == &"fuel_cell").size() <= 1, "%s: more than one fuel cell" % label)
	_check(str(solo) == str(layout.loot(1)), "%s: the loot differs for the same crew" % label)
	_check(four.size() > solo.size(), "%s: four crew find no more than one (%d, %d)" % [label, four.size(), solo.size()])
	for find: Dictionary in four:
		_check(items.KINDS.has(find.kind), "%s: an unknown find, %s" % [label, find.kind])
		var spot: Vector3 = find.at.origin
		var cell := Vector3i(roundi(spot.x / CELL), floori(spot.y / PITCH), roundi(spot.z / CELL))
		_check(layout.room_of.has(cell), "%s: a %s outside the rooms at %s" % [label, find.kind, spot])


## Each module as authored: its doors and windows on its own outer edges (or its floor or ceiling
## with nothing of its own beyond), everything it holds inside its cells, nothing standing in a
## door's way or under a hatchway.
func _check_modules() -> void:
	for type: StringName in rooms.MODULES:
		var module: Dictionary = rooms.of(type)
		var cells: Array[Vector3i] = rooms.cells_of(type)
		var ways := []
		for list: String in ["doors", "windows"]:
			for edge: String in module.get(list, []) + ([module.hatch] if module.has("hatch") and list == "doors" else []):
				var parsed: Array = layouts.parse_edge(edge)
				var cell: Vector3i = parsed[0]
				var side: String = parsed[1]
				_check(cell in cells and not (cell + layouts.SIDES[side]) in cells, "%s: %s isn't on its outer face" % [type, edge])
				ways.append(parsed)
		# Its own cells stacked one over another are joined by a hatchway too.
		for cell in cells:
			if (cell + Vector3i.UP) in cells:
				ways.append([cell, "U"])
				ways.append([cell + Vector3i.UP, "D"])
		var things := []
		for prop: Array in module.get("props", []):
			things.append([prop[0], prop[1]])
		for big: Array in module.get("big", []):
			things.append(["big", big[0]])
		for spot: Vector3 in module.get("spots", []):
			things.append(["spot", spot])
		for thing: Array in things:
			var at: Vector3 = thing[1]
			_check(_inside(at, cells), "%s: its %s at %s is outside its cells" % [type, thing[0], at])
			for way: Array in ways:
				_check(not _in_way(at, way[0], way[1]), "%s: its %s at %s stands in the way at %s %s" % [type, thing[0], at, way[0], way[1]])


## Whether a point (module space) is in one of `cells` (by its level), clear of any outer wall.
static func _inside(at: Vector3, cells: Array[Vector3i]) -> bool:
	var level := floori(at.y / PITCH)
	var found := false
	for cell in cells:
		if cell.y != level:
			continue
		var d := Vector2(at.x - cell.x * CELL, at.z - cell.z * CELL)
		if absf(d.x) > HALF_CELL or absf(d.y) > HALF_CELL:
			continue
		found = true
		if absf(d.x) > WALL_FACE and not (cell + Vector3i(signi(roundi(d.x)), 0, 0)) in cells:
			return false
		if absf(d.y) > WALL_FACE and not (cell + Vector3i(0, 0, signi(roundi(d.y)))) in cells:
			return false
	return found


## Whether a point (module space) stands in the way through `side` of `cell`: a door's way, or
## the column under (or over) a hatchway's ring.
static func _in_way(at: Vector3, cell: Vector3i, side: String) -> bool:
	var level := floori(at.y / PITCH)
	if level != cell.y:
		return false
	var centre := Vector2(cell.x, cell.z) * CELL
	if side == "U" or side == "D":
		return Vector2(at.x, at.z).distance_to(centre) < HATCHWAY_CLEAR
	var out := Vector2(SIDES[side])
	var middle := centre + out * HALF_CELL
	var rel := Vector2(at.x, at.z) - middle
	var along := absf(rel.dot(Vector2(-out.y, out.x)))
	var into := -rel.dot(out)
	return along < DOOR_HALF and into >= 0.0 and into < DOOR_DEPTH


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 30:
			printerr("FAIL: " + message)
