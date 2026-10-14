extends SceneTree
## Derelict layouts (GDD §8.2, TECH §6), checked on many seeds independently of the generator's own
## `problems()`: from the walls the Deck will build (its rows and openings), every room can be
## reached from the entry hatch, nothing lies toward the LANTERN, the Prize is a dead end far in;
## windows, breaches and the hatch face space; creatures are few and never by the entry or in the
## Prize room; the loot holds one fuel cell, known items only, and grows with the crew. Each
## module's furniture stays in its own cells and out of its doorways. The same seed grows the same
## derelict; others grow others.
##   tools/godot.sh --headless -s tests/test_derelict_layout.gd

const SEEDS := 300
## A door's way: this far either side of its middle, this far into the room (DerelictRooms).
const DOOR_HALF := 1.25
const DOOR_DEPTH := 1.2
## The grid (Deck): a cell's size, a wall's face from its centre, and a room's height.
const CELL := 4.0
const HALF_CELL := 2.0
const WALL_FACE := 1.85
const ROOM_HEIGHT := 3.0
const SIDES := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const OPPOSITE := {"N": "S", "E": "W", "S": "N", "W": "E"}

var failures := 0
# Loaded now, not named: they reach the game's autoloads, which a test script can't see when it's
# compiled.
var layouts: GDScript
var rooms: GDScript
var items: GDScript


func _initialize() -> void:
	layouts = load("res://game/encounter/derelict_layout.gd")
	rooms = load("res://game/encounter/derelict_rooms.gd")
	items = load("res://game/items/items.gd")
	_check_modules()
	var sizes := []
	var types := {}
	var creatures := [0, 0, 0]
	var loops := 0
	var retries := 0
	var seen := {}
	for seed in range(1, SEEDS + 1):
		for sector in range(1, 4):
			var layout = layouts.generate(seed, sector)
			var label := "seed %d sector %d" % [seed, sector]
			_check(layout.problems().is_empty(), "%s: %s" % [label, layout.problems()])
			_check(layouts.generate(seed, sector).checksum() == layout.checksum(), "%s: not deterministic" % label)
			_check_walls(layout, label)
			_check_creatures(layout, label)
			_check_loot(layout, label)
			seen[layout.checksum()] = true
			sizes.append(layout.rooms.size())
			for room: Dictionary in layout.rooms:
				types[room.type] = types.get(room.type, 0) + 1
			creatures[clampi(layout.creatures.size(), 0, 2)] += 1
			loops += layout.joins.size() - (layout.rooms.size() - 1)
			retries += layout.attempt
	_check(seen.size() == SEEDS * 3, "%d of %d layouts are repeats" % [SEEDS * 3 - seen.size(), SEEDS * 3])
	var total: int = sizes.reduce(func(a: int, b: int) -> int: return a + b)
	var shares := []
	for type: StringName in rooms.MODULES:
		shares.append("%s %.1f" % [type, float(types.get(type, 0)) / (SEEDS * 3)])
	print("Rooms a derelict: %.1f (%d-%d); by type: %s" % [float(total) / sizes.size(), sizes.min(), sizes.max(), ", ".join(shares)])
	print("Creatures: none %d%%, one %d%%, two %d%%; loops %.2f a derelict; regrown %d times" % [
			100 * creatures[0] / (SEEDS * 3), 100 * creatures[1] / (SEEDS * 3), 100 * creatures[2] / (SEEDS * 3),
			float(loops) / (SEEDS * 3), retries])
	print("test_derelict_layout: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


## From the Deck's own layout: rooms by character, edges by opening. Walks from the entry through
## doors and open joins; every room's reached, the Prize only through one door, far in.
func _check_walls(layout, label: String) -> void:
	var rows: PackedStringArray = layout.rows()
	var origin: Vector2i = layout.origin()
	var openings: Dictionary = layout.openings()
	var cells := {}
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] != ".":
				cells[Vector2i(c, r)] = rows[r][c]
	var entry := origin
	_check(cells.get(entry, ".") == layout.MARKS[0], "%s: the entry isn't at the origin" % label)
	_check(openings.get("%d,%d,W" % [entry.x, entry.y]) == "hatch", "%s: no hatch west of the entry" % label)
	for cell: Vector2i in cells:
		_check(cell.x >= entry.x, "%s: a room reaches toward the LANTERN at %s" % [label, cell - origin])
	# Every opening: between two rooms (doors, open joins) or a room and space (the rest).
	for key: String in openings:
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var beyond: Vector2i = cell + SIDES[parts[2]]
		var kind: String = openings[key]
		_check(cells.has(cell), "%s: an opening (%s) at %s, outside any room" % [label, kind, key])
		if kind in ["door", "open"]:
			_check(cells.has(beyond) and cells[beyond] != cells.get(cell), "%s: a %s at %s doesn't join two rooms" % [label, kind, key])
		else:
			_check(not cells.has(beyond), "%s: a %s at %s faces a room, not space" % [label, kind, key])
	# Walk it.
	var depth := {cells[entry]: 0}
	var queue := [entry]
	var reached := {entry: true}
	var prize_mark: String = layout.MARKS[layout.prize]
	var prize_doors := {}
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for side: String in SIDES:
			var next: Vector2i = at + SIDES[side]
			if not cells.has(next) or reached.has(next):
				continue
			var same: bool = cells[next] == cells[at]
			if not same:
				var opening: String = openings.get("%d,%d,%s" % [at.x, at.y, side], openings.get("%d,%d,%s" % [next.x, next.y, OPPOSITE[side]], "wall"))
				if opening not in ["door", "open"]:
					continue
				if cells[next] == prize_mark or cells[at] == prize_mark:
					prize_doors[layouts.edge_key(at, side)] = true
				if not depth.has(cells[next]):
					depth[cells[next]] = depth[cells[at]] + 1
			reached[next] = true
			queue.append(next)
	_check(reached.size() == cells.size(), "%s: %d cells can't be reached from the entry" % [label, cells.size() - reached.size()])
	_check(prize_doors.size() == 1, "%s: the Prize room has %d ways in" % [label, prize_doors.size()])
	_check(depth.get(prize_mark, 0) >= layout.PRIZE_DEPTH, "%s: the Prize is only %d rooms in" % [label, depth.get(prize_mark, 0)])


## Few creatures, each in its own room, none by the entry or with the Prize.
func _check_creatures(layout, label: String) -> void:
	_check(layout.creatures.size() <= 2, "%s: %d creatures" % [label, layout.creatures.size()])
	var dens := {}
	for creature: Dictionary in layout.creatures:
		var spot: Vector3 = creature.at.origin
		var cell := Vector2i(roundi(spot.x / CELL), roundi(spot.z / CELL))
		var room: int = layout.room_of.get(cell, -1)
		_check(room > 0 and room != layout.prize, "%s: a %s in room %d" % [label, creature.kind, room])
		_check(not dens.has(room), "%s: two creatures in room %d" % [label, room])
		dens[room] = true
		if creature.kind == &"hanger":
			_check(is_equal_approx(spot.y, ROOM_HEIGHT), "%s: a Hanger off the ceiling" % label)


## One fuel cell, only things the game knows, the same for the same crew, more for more.
func _check_loot(layout, label: String) -> void:
	var solo: Array = layout.loot(1)
	var four: Array = layout.loot(4)
	_check(solo.filter(func(find: Dictionary) -> bool: return find.kind == &"fuel_cell").size() == 1, "%s: not one fuel cell" % label)
	_check(str(solo) == str(layout.loot(1)), "%s: the loot differs for the same crew" % label)
	_check(four.size() > solo.size(), "%s: four crew find no more than one (%d, %d)" % [label, four.size(), solo.size()])
	for find: Dictionary in four:
		_check(items.KINDS.has(find.kind), "%s: an unknown find, %s" % [label, find.kind])
		if find.has("rack"):
			_check(find.rack < layout.props.size() and find.kind in layout.props[find.rack].rack, "%s: a %s on no rack" % [label, find.kind])
		else:
			var spot: Vector3 = find.at.origin
			_check(layout.room_of.has(Vector2i(roundi(spot.x / CELL), roundi(spot.z / CELL))), "%s: a %s outside the rooms" % [label, find.kind])


## Each module as authored: its doors and windows on its own outer edges, everything it holds
## inside its cells and on the deck, and nothing standing in a door's way (cables hang overhead).
func _check_modules() -> void:
	for type: StringName in rooms.MODULES:
		var module: Dictionary = rooms.of(type)
		var cells: Array[Vector2i] = rooms.cells_of(type)
		for list: String in ["doors", "windows"]:
			for edge: String in module.get(list, []) + ([module.hatch] if module.has("hatch") and list == "doors" else []):
				var parts := edge.split(",")
				var cell := Vector2i(int(parts[0]), int(parts[1]))
				_check(cell in cells and not (cell + SIDES[parts[2]]) in cells, "%s: %s isn't on its outer wall" % [type, edge])
		var things := []
		for prop: Array in module.get("props", []):
			things.append([prop[0], prop[1]])
		for bit: Array in module.get("scatter", []):
			things.append([bit[0], bit[1]])
		for big: Array in module.get("big", []):
			things.append(["big", big[0]])
		for spot: Vector3 in module.get("open", []):
			things.append(["open floor", spot])
		for spot: Vector3 in module.get("spots", []):
			things.append(["spot", spot])
		for strobe: Array in module.get("strobes", []):
			things.append(["strobe", strobe[0]])
		for thing: Array in things:
			var at: Vector3 = thing[1]
			_check(_inside(at, cells), "%s: its %s at %s is outside its cells" % [type, thing[0], at])
			if thing[0] in ["cables", "strobe", "spot"] or at.y >= 2.5:
				continue
			for edge: String in module.doors:
				_check(not _in_way(at, edge), "%s: its %s at %s stands in the door at %s" % [type, thing[0], at, edge])


## Whether a point (module space) is in one of `cells`, and clear of any outer wall's face.
static func _inside(at: Vector3, cells: Array[Vector2i]) -> bool:
	var found := false
	for cell in cells:
		var d := Vector2(at.x, at.z) - Vector2(cell) * CELL
		if absf(d.x) > HALF_CELL or absf(d.y) > HALF_CELL:
			continue
		found = true
		if absf(d.x) > WALL_FACE and not (cell + Vector2i(signi(roundi(d.x)), 0)) in cells:
			return false
		if absf(d.y) > WALL_FACE and not (cell + Vector2i(0, signi(roundi(d.y)))) in cells:
			return false
	return found


## Whether a point (module space) stands in the way of the door on `edge`.
static func _in_way(at: Vector3, edge: String) -> bool:
	var parts := edge.split(",")
	var centre := Vector2(int(parts[0]), int(parts[1])) * CELL
	var out := Vector2(SIDES[parts[2]])
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
