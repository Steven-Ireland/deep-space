class_name RoomLayout
extends RefCounted
## A structure's plan (GDD §8.2, TECH §6), grown from its seed out of hand-built rooms, the same on
## every peer: a derelict (DerelictLayout) or a working satellite (SatelliteLayout). Each kind
## brings its own modules (DerelictRooms, SatelliteRooms) and says how big it grows, how it loops,
## which doors start shut, how its rooms are dressed and what's to be found in them.
##   1. From the entry (its hatch to the west, toward the LANTERN), modules are joined at their door
##      sockets, door to door, until the structure has its size. A socket may lead up or down, to a
##      hatchway through the ceiling or the floor, so a structure can stand on several levels.
##      Nothing grows west of the entry, toward the LANTERN.
##   2. The Prize room joins at the open door farthest from the entry.
##   3. A few loops join rooms already side by side (or one over another), where both have a door
##      there and the long way round between them is long, as long as the Prize stays the farthest.
##   4. Walls: doors start open or shut, windows where a room has them and nothing's beyond, some
##      kinds' walls torn open (breaches).
##   5. Dressing and loot, by kind (`_dress`, `loot`).
##
## Rooms sit on a grid of 4 m cells in levels PITCH apart, with the entry's cell at (0, 0, 0): grid
## cell (x, level, z) has its floor's centre at (4x, PITCH·level, 4z) in the structure's space, -Z
## fore, as in a Deck. One Deck is built per level from `rows(level)` and `openings(level)`, with a
## hatchway wherever `hatchways(level)` says one leads up.
##
## A module is authored in its own space, as in DerelictRooms: `cells` its footprint (rows north to
## south, '#' a cell) on one level, or `levels` a list of footprints from its lowest level up; a
## door socket "c,r,S" (level 0) or "c,r,S,l" names cell (c, l, r) and side N, E, S, W, U (up,
## through the ceiling) or D (down, through the floor). Cells of one module stacked one over another
## are joined by a hatchway of their own.

const SIDES := {"N": Vector3i(0, 0, -1), "E": Vector3i(1, 0, 0), "S": Vector3i(0, 0, 1), "W": Vector3i(-1, 0, 0),
		"U": Vector3i(0, 1, 0), "D": Vector3i(0, -1, 0)}
const OPPOSITE := {"N": "S", "E": "W", "S": "N", "W": "E", "U": "D", "D": "U"}
## The sides within a level, in the order walls are walked.
const AROUND: Array[String] = ["N", "E", "S", "W"]
## Metres between levels: a room's 3 m of air, its floor and ceiling, and the hatchway's trunk
## between one level's ceiling and the next one's floor.
const PITCH := 4.0
## Room characters for the Decks, one per room.
const MARKS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

var seed := 0
var sector := 1
## The attempt that grew it (a layout that breaks a rule is grown again from the next).
var attempt := 0
## Each room: {type, at (grid cell of the module's origin), turn (quarter turns), cells (grid)}.
var rooms: Array[Dictionary] = []
## Which room holds each grid cell (Vector3i).
var room_of := {}
## The edges joined, by `edge_key`: {cell, side (from that cell), kind ("door", "open", "hatchway")}.
var joins := {}
## Each room's neighbours through a join.
var links := {}
## The Prize room's index (-1 for none).
var prize := -1
## Doors that start shut (edge keys), windows and breached walls ({key: [cell, side]}).
var shut := {}
var windows := {}
var breaches := {}
## Furniture and fittings: {model, at: Transform3D (the structure's space), rack: kinds}.
var props: Array[Dictionary] = []


# --- What kind of structure it is (each kind says) ------------------------------------------------

## Its modules (DerelictRooms.MODULES, SatelliteRooms.MODULES).
func _modules() -> Dictionary:
	return {}


## How many modules grow from the entry (besides the entry and the Prize), before the sector's.
func _size() -> Vector2i:
	return Vector2i(8, 10)


## How many loops, at least and at most; how far round (rooms) the long way must be for one.
func _loops() -> Vector2i:
	return Vector2i(0, 0)


func _loop_reach() -> int:
	return 3


## How many rooms in the Prize must be, at least.
func _prize_depth() -> int:
	return 1


## Whether a module may stand in `cell`: never west of the entry, toward the LANTERN.
func _allowed(cell: Vector3i) -> bool:
	return cell.x >= 0


## The chance a door starts shut, and that a room's outer wall is torn open.
func _shut_chance() -> float:
	return 0.0


func _breach_chance() -> float:
	return 0.0


## The label its rng is drawn from, attempt by attempt.
func _label() -> String:
	return "layout"


## Rules its own kind adds (`problems`).
func _more_problems() -> Array[String]:
	return []


## Dresses the rooms (furniture, lights, decay, what lives there).
func _dress(rng: RandomNumberGenerator) -> void:
	for index in rooms.size():
		_furnish(index)


# --- Growing ---------------------------------------------------------------------------------

## Grows it from `seed_` in `sector_`, as attempt `attempt_`: whether it grew, and breaks no rule.
func grow(seed_: int, sector_: int, attempt_: int) -> bool:
	seed = seed_
	sector = sector_
	attempt = attempt_
	return _grow(Seeds.rng(seed_, "%s/%d" % [_label(), attempt_])) and problems().is_empty()


func _grow(rng: RandomNumberGenerator) -> bool:
	_place(&"entry", Vector3i.ZERO, 0)
	var size := rng.randi_range(_size().x, _size().y) + sector
	var tries := 0
	while rooms.size() - 1 < size and tries < 300:
		tries += 1
		var open := _open_doors()
		if open.is_empty():
			break
		var door: Array = open[rng.randi() % open.size()]
		var type := _pick(rng, rooms[door[0]].type)
		if type != &"":
			_attach(rng, type, door)
	if rooms.size() - 1 < _size().x:
		return false
	# The Prize at the open door farthest in (by rooms, then by metres).
	var depth := _depths()
	var ends := _open_doors()
	ends.sort_custom(func(a: Array, b: Array) -> bool:
		if depth[a[0]] != depth[b[0]]:
			return depth[a[0]] > depth[b[0]]
		return Vector3(a[1]).length() > Vector3(b[1]).length())
	for door: Array in ends:
		if _attach(rng, &"prize", door):
			prize = rooms.size() - 1
			break
	if prize < 0:
		return false
	_loop(rng)
	_walls(rng)
	_dress(rng)
	return true


## The key for the edge on `side` of `cell`: horizontal edges by the cell south or east of them and
## their axis ("h" or "v"), as a Deck keys them on its level; a hatchway by the cell under it ("u").
static func edge_key(cell: Vector3i, side: String) -> String:
	var owner: Vector3i
	var axis: String
	match side:
		"N", "W":
			owner = cell
			axis = "h" if side == "N" else "v"
		"S", "E":
			owner = cell + SIDES[side]
			axis = "h" if side == "S" else "v"
		"U":
			owner = cell
			axis = "u"
		_:
			owner = cell + SIDES["D"]
			axis = "u"
	return "%d,%d,%d,%s" % [owner.x, owner.y, owner.z, axis]


## A horizontal edge's key as its level's Deck has it ("x,z,axis"), and that level.
static func deck_key(key: String) -> String:
	var parts := key.split(",")
	return "%s,%s,%s" % [parts[0], parts[2], parts[3]]


static func level_of(key: String) -> int:
	return int(key.split(",")[1])


## Every free door: [room, cell, side] where the cell beyond is empty, and may hold a room.
func _open_doors() -> Array:
	var out := []
	for index in rooms.size():
		for door: Array in _doors_of(index):
			var beyond: Vector3i = door[0] + SIDES[door[1]]
			if not room_of.has(beyond) and _allowed(beyond) and not joins.has(edge_key(door[0], door[1])):
				out.append([index, door[0], door[1]])
	return out


## A module type to join to a room of type `from`, weighted: rooms open off corridors, corridors
## off rooms; fewer of a type the more there are; none past its `most`.
func _pick(rng: RandomNumberGenerator, from: StringName) -> StringName:
	var corridor_from: bool = module(from).kind != "room"
	var table := {}
	var total := 0.0
	for type: StringName in _modules():
		var spec := module(type)
		if spec.kind in ["entry", "prize"] or not spec.has("weight"):
			continue
		var count := count_of(type)
		if count >= spec.most:
			continue
		var weight: float = spec.weight / (1.0 + count)
		if spec.kind == "room":
			weight *= 2.0 if corridor_from else 0.25
		else:
			weight *= 0.8 if corridor_from else 1.6
		table[type] = weight
		total += weight
	var roll := rng.randf() * total
	for type: StringName in table:
		roll -= table[type]
		if roll <= 0.0:
			return type
	return &""


func count_of(type: StringName) -> int:
	return rooms.filter(func(room: Dictionary) -> bool: return room.type == type).size()


## Joins a `type` module at `door` ([room, cell, side]) if it fits any way round.
func _attach(rng: RandomNumberGenerator, type: StringName, door: Array) -> bool:
	var target: Vector3i = door[1] + SIDES[door[2]]
	var need: String = OPPOSITE[door[2]]
	var fits := []
	for turn in 4:
		for socket: Array in _sockets(type, turn):
			if socket[1] != need:
				continue
			var at: Vector3i = target - socket[0]
			if _fits(type, at, turn):
				fits.append([at, turn])
	if fits.is_empty():
		return false
	var pick: Array = fits[rng.randi() % fits.size()]
	var index := _place(type, pick[0], pick[1])
	_join(door[0], index, door[1], door[2])
	return true


func _fits(type: StringName, at: Vector3i, turn: int) -> bool:
	for cell in cells_of(type):
		var spot := at + turn_cell(cell, turn)
		if room_of.has(spot) or not _allowed(spot):
			return false
	return true


func _place(type: StringName, at: Vector3i, turn: int) -> int:
	var index := rooms.size()
	var cells: Array[Vector3i] = []
	for cell in cells_of(type):
		var spot := at + turn_cell(cell, turn)
		cells.append(spot)
		room_of[spot] = index
	rooms.append({"type": type, "at": at, "turn": turn, "cells": cells})
	links[index] = []
	return index


## Joins rooms `a` and `b` at `side` of `cell` (in `a`): through the floor or ceiling, a hatchway;
## between two corridors, open; otherwise a door.
func _join(a: int, b: int, cell: Vector3i, side: String) -> void:
	var kind := "door"
	if side == "U" or side == "D":
		kind = "hatchway"
	elif module(rooms[a].type).kind == "corridor" and module(rooms[b].type).kind == "corridor":
		kind = "open"
	joins[edge_key(cell, side)] = {"cell": cell, "side": side, "kind": kind}
	links[a].append(b)
	links[b].append(a)


func _unjoin(a: int, b: int, cell: Vector3i, side: String) -> void:
	joins.erase(edge_key(cell, side))
	links[a].erase(b)
	links[b].erase(a)


## Takes back the last room placed (`index`), joined at `door` ([room, cell, side]) to the room it
## grew from.
func _unplace(index: int, door: Array) -> void:
	_unjoin(door[0], index, door[1], door[2])
	for cell: Vector3i in rooms[index].cells:
		room_of.erase(cell)
	links.erase(index)
	rooms.remove_at(index)


## A room's door sockets on the grid: [cell, side].
func _doors_of(index: int) -> Array:
	var room := rooms[index]
	return _sockets(room.type, room.turn).map(func(socket: Array) -> Array: return [room.at + socket[0], socket[1]])


## A module's door sockets turned `turn` quarter turns: [cell (module space, turned), side].
func _sockets(type: StringName, turn: int) -> Array:
	return module(type).doors.map(func(door: String) -> Array: return turn_edge(door, turn))


# --- Modules -----------------------------------------------------------------------------------

func module(type: StringName) -> Dictionary:
	return _modules()[type]


func cells_of(type: StringName) -> Array[Vector3i]:
	return cells_in(module(type))


## A module's cells in its own space: (c, level, r).
static func cells_in(spec: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var levels: Array = spec.get("levels", [spec.get("cells", [])])
	for level in levels.size():
		var rows: Array = levels[level]
		for r in rows.size():
			for c in rows[r].length():
				if rows[r][c] == "#":
					out.append(Vector3i(c, level, r))
	return out


## "c,r,S" (level 0) or "c,r,S,l": [cell (c, l, r), side].
static func parse_edge(edge: String) -> Array:
	var parts := edge.split(",")
	var level := int(parts[3]) if parts.size() > 3 else 0
	return [Vector3i(int(parts[0]), level, int(parts[1])), parts[2]]


## An edge turned `turn` quarter turns: [cell, side].
static func turn_edge(edge: String, turn: int) -> Array:
	var parsed := parse_edge(edge)
	return [turn_cell(parsed[0], turn), turn_side(parsed[1], turn)]


## A cell of a module turned `turn` quarter turns about its origin (as Basis(UP, turn·90°) turns
## a point: east goes north). Its level doesn't change.
static func turn_cell(cell: Vector3i, turn: int) -> Vector3i:
	var out := cell
	for i in turn:
		out = Vector3i(out.z, out.y, -out.x)
	return out


static func turn_side(side: String, turn: int) -> String:
	if side == "U" or side == "D":
		return side
	var v: Vector3i = SIDES[side]
	for i in turn:
		v = Vector3i(v.z, 0, -v.x)
	return SIDES.find_key(v)


## How many rooms in each room is from the entry, through the joins.
func _depths() -> Dictionary:
	var depth := {0: 0}
	var queue := [0]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for next: int in links[at]:
			if not depth.has(next):
				depth[next] = depth[at] + 1
				queue.append(next)
	return depth


## Loops: doors between rooms side by side (or one over another) that both have a door there, the
## long way round between them at least `_loop_reach()` rooms, not through the entry or the Prize;
## and only while the Prize stays the farthest room in (but one).
func _loop(rng: RandomNumberGenerator) -> void:
	var candidates := []
	for index in rooms.size():
		if index == 0 or index == prize:
			continue
		for door: Array in _doors_of(index):
			var beyond: Vector3i = door[0] + SIDES[door[1]]
			var other: int = room_of.get(beyond, -1)
			if other <= index or other == prize or joins.has(edge_key(door[0], door[1])):
				continue
			if _doors_of(other).any(func(d: Array) -> bool: return d[0] == beyond and d[1] == OPPOSITE[door[1]]):
				candidates.append([index, other, door[0], door[1]])
	var wanted := rng.randi_range(_loops().x, _loops().y)
	while wanted > 0 and not candidates.is_empty():
		var pick: Array = candidates.pop_at(rng.randi() % candidates.size())
		if links[pick[0]].has(pick[1]) or _apart(pick[0], pick[1]) < _loop_reach():
			continue
		_join(pick[0], pick[1], pick[2], pick[3])
		if _prize_far():
			wanted -= 1
		else:
			_unjoin(pick[0], pick[1], pick[2], pick[3])


## How many rooms apart two rooms are, through the joins.
func _apart(a: int, b: int) -> int:
	var depth := {a: 0}
	var queue := [a]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == b:
			return depth[at]
		for next: int in links[at]:
			if not depth.has(next):
				depth[next] = depth[at] + 1
				queue.append(next)
	return 1 << 20


## Whether the Prize is at least `_prize_depth()` rooms in, and as far in as any room but by one.
func _prize_far() -> bool:
	var depth := _depths()
	var deepest := 0
	for index: int in depth:
		if index != prize:
			deepest = maxi(deepest, depth[index])
	return depth.get(prize, 0) >= _prize_depth() and depth[prize] >= deepest - 1


## Doors open or shut, windows and breaches on the outer walls.
func _walls(rng: RandomNumberGenerator) -> void:
	for key: String in joins:
		if joins[key].kind == "door" and rng.randf() < _shut_chance():
			shut[key] = true
	for index in rooms.size():
		var room := rooms[index]
		var spec := module(room.type)
		for edge: String in spec.get("windows", []):
			var turned := turn_edge(edge, room.turn)
			var cell: Vector3i = room.at + turned[0]
			if not room_of.has(cell + SIDES[turned[1]]):
				windows[edge_key(cell, turned[1])] = [cell, turned[1]]
		if spec.kind != "room" or _breach_chance() <= 0.0:
			continue
		for cell: Vector3i in room.cells:
			for side: String in AROUND:
				var key := edge_key(cell, side)
				if not room_of.has(cell + SIDES[side]) and not windows.has(key) and rng.randf() < _breach_chance():
					breaches[key] = [cell, side]


# --- Dressing ----------------------------------------------------------------------------------

## The floor's centre of a grid cell, in the structure's space.
static func centre_of(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * Deck.CELL, cell.y * PITCH, cell.z * Deck.CELL)


## The transform of a room's own space in the structure's.
func frame_of(index: int) -> Transform3D:
	var room := rooms[index]
	return Transform3D(Basis(Vector3.UP, room.turn * PI / 2), centre_of(room.at))


static func _local(at: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)


## A room's furniture, from its module.
func _furnish(index: int) -> void:
	var frame := frame_of(index)
	for prop: Array in module(rooms[index].type).get("props", []):
		props.append({"model": prop[0], "at": frame * _local(prop[1], prop[2]), "rack": prop[3] if prop.size() > 3 else [], "room": index})


static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = weights.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


static func _roll(rng: RandomNumberGenerator, table: Dictionary) -> StringName:
	var keys := table.keys()
	return keys[_weighted(rng, keys.map(func(key: StringName) -> float: return float(table[key])))]


func _first(type: StringName) -> int:
	for index in rooms.size():
		if rooms[index].type == type:
			return index
	return -1


# --- For the Decks, and checking ---------------------------------------------------------------

## The levels it stands on, lowest first.
func levels() -> Array[int]:
	var out: Array[int] = []
	for cell: Vector3i in room_of:
		if not out.has(cell.y):
			out.append(cell.y)
	out.sort()
	return out


## A level's Deck layout: rows of room characters (one per room), every level on the same columns.
func rows(level := 0) -> PackedStringArray:
	var bounds := _bounds()
	var out := PackedStringArray()
	for z in range(bounds.position.y, bounds.end.y):
		var row := ""
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector3i(x, level, z)
			row += MARKS[room_of[cell]] if room_of.has(cell) else "."
		out.append(row)
	return out


## The layout cell at the grid's origin, the same on every level.
func origin() -> Vector2i:
	return -_bounds().position


## Openings for a level's Deck.build: "col,row,side" of a layout cell to the edge's kind.
func openings(level := 0) -> Dictionary:
	var out := {}
	var shift := origin()
	var add := func(cell: Vector3i, side: String, kind: String) -> void:
		if cell.y == level:
			out["%d,%d,%s" % [cell.x + shift.x, cell.z + shift.y, side]] = kind
	add.call(Vector3i.ZERO, "W", "hatch")
	for key: String in joins:
		if joins[key].kind != "hatchway":
			add.call(joins[key].cell, joins[key].side, joins[key].kind)
	for key: String in windows:
		add.call(windows[key][0], windows[key][1], "window")
	for key: String in breaches:
		add.call(breaches[key][0], breaches[key][1], "breach")
	return out


## The grid cells (x, z) on `level` with a hatchway up through their ceiling to the level above:
## where two rooms join through it, and where one module stands on both.
func hatchways(level: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: String in joins:
		if joins[key].kind == "hatchway":
			var parts := key.split(",")
			if int(parts[1]) == level:
				out.append(Vector2i(int(parts[0]), int(parts[2])))
	for room in rooms:
		for cell: Vector3i in room.cells:
			if cell.y == level and (cell + SIDES["U"]) in room.cells:
				out.append(Vector2i(cell.x, cell.z))
	return out


## The doors on `level` that start shut, by their Deck's keys.
func shut_on(level := 0) -> Dictionary:
	var out := {}
	for key: String in shut:
		if level_of(key) == level:
			out[deck_key(key)] = true
	return out


## The entry hatch's opening on level 0, as its Deck has it.
func entry_opening() -> String:
	var shift := origin()
	return "%d,%d,W" % [shift.x, shift.y]


## The footprint's bounds across every level, in (x, z).
func _bounds() -> Rect2i:
	var box := Rect2i(Vector2i.ZERO, Vector2i.ONE)
	for cell: Vector3i in room_of:
		var flat := Vector2i(cell.x, cell.z)
		box = box.expand(flat).expand(flat + Vector2i.ONE)
	return box


func checksum() -> int:
	var plan := rooms.map(func(room: Dictionary) -> Array: return [room.type, room.at, room.turn])
	var edges := joins.keys()
	edges.sort()
	var dressing := props.map(func(prop: Dictionary) -> Array: return [prop.model, prop.at.origin.snapped(Vector3.ONE * 0.01)])
	return hash([seed, attempt, plan, edges, shut.keys(), windows.keys(), breaches.keys(), dressing])


## Every rule the layout breaks (none, for a good one).
func problems() -> Array[String]:
	var out: Array[String] = []
	if rooms.is_empty() or rooms[0].type != &"entry" or rooms[0].at != Vector3i.ZERO:
		out.append("the entry isn't at the origin")
		return out
	if room_of.has(Vector3i(-1, 0, 0)):
		out.append("something stands in the way of the entry's hatch")
	var cells := 0
	for index in rooms.size():
		var room := rooms[index]
		cells += room.cells.size()
		for cell: Vector3i in room.cells:
			if not _allowed(cell):
				out.append("room %d stands where none may (%s)" % [index, cell])
			if room_of.get(cell, -1) != index:
				out.append("room %d overlaps another" % index)
	if cells != room_of.size():
		out.append("rooms overlap")
	var grown := rooms.size() - 2 - count_of(&"vault")
	if grown < _size().x or grown > _size().y + sector:
		out.append("%d rooms grown" % grown)
	for type: StringName in _modules():
		var spec := module(type)
		if spec.has("most") and count_of(type) > spec.most:
			out.append("%d %s" % [count_of(type), type])
	if prize < 0 or rooms[prize].type != &"prize" or count_of(&"prize") != 1:
		out.append("no Prize room")
	elif links[prize].size() != 1:
		out.append("the Prize room has %d doors" % links[prize].size())
	elif not _prize_far():
		out.append("the Prize isn't far in")
	var depth := _depths()
	if depth.size() != rooms.size():
		out.append("%d rooms can't be reached" % (rooms.size() - depth.size()))
	for key: String in joins:
		var join: Dictionary = joins[key]
		var a: int = room_of.get(join.cell, -1)
		var b: int = room_of.get(join.cell + SIDES[join.side], -1)
		if a < 0 or b < 0 or a == b:
			out.append("a door at %s leads nowhere" % key)
		elif not _doors_of(a).any(func(d: Array) -> bool: return d[0] == join.cell and d[1] == join.side):
			out.append("a door at %s where room %d has none" % [key, a])
		elif not _doors_of(b).any(func(d: Array) -> bool: return d[0] == join.cell + SIDES[join.side] and d[1] == OPPOSITE[join.side]):
			out.append("a door at %s where room %d has none" % [key, b])
	var kinds := {}
	for room in rooms:
		if module(room.type).kind == "room":
			kinds[room.type] = true
	if kinds.size() < 3:
		out.append("only %d kinds of room" % kinds.size())
	out.append_array(_more_problems())
	return out


## The plan as text, for the log: each level's rooms by character, and where each room lies in the
## world once the structure stands at `placed` (a room's middle, on its floor).
func describe(title: String, placed: Transform3D) -> String:
	var lines := ["%s %d (attempt %d), %d rooms:" % [title, seed, attempt, rooms.size()]]
	for level in levels():
		if levels().size() > 1:
			lines.append(" level %d" % level)
		lines.append_array(rows(level))
	for index in rooms.size():
		var centre := Vector3.ZERO
		for cell: Vector3i in rooms[index].cells:
			centre += centre_of(cell)
		centre = placed * (centre / rooms[index].cells.size())
		lines.append("  %s %-13s at %s%s" % [MARKS[index], module(rooms[index].type).name, centre.snapped(Vector3.ONE * 0.1), _who(index)])
	return "\n".join(lines)


## What else `describe` says of a room (what lives there).
func _who(_index: int) -> String:
	return ""
