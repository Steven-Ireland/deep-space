class_name DerelictLayout
extends RefCounted
## A derelict's plan (GDD §8.2, TECH §6), grown from its seed out of hand-built rooms
## (DerelictRooms), the same on every peer:
##   1. From the entry (its hatch to the west, where the LANTERN's collar docks), modules are joined
##      at their door sockets, door to door, until the derelict has its size. Nothing grows west of
##      the entry, toward the LANTERN.
##   2. The Prize room joins at the open door farthest from the entry.
##   3. A few loops join rooms already side by side, where both have a door there and the long way
##      round between them is long, as long as the Prize stays the farthest room.
##   4. Walls: doors start open or shut, windows where a room has them and nothing's beyond, a few
##      walls torn open (breaches).
##   5. Dressing: each room's furniture, the scatter of decay, which strobes still flash, and what
##      lives here (often one thing, sometimes none, rarely two). Loot is spent from a budget that
##      grows with the crew and the derelict's size (`loot`).
## Every derelict is vacuum throughout for now (GDD §17, 13); power zones come later.
##
## Rooms sit on the grid with the entry's cell at (0, 0): grid cell (x, z) has its centre at
## (4x, 0, 4z) in the derelict's space, -Z fore, as in a Deck.

const SIDES := Deck.SIDES
const OPPOSITE := Deck.OPPOSITE
## Modules grown from the entry (besides the entry and the Prize): this many, plus the sector. Big
## enough that one tank of O2 won't see all of it, and the crew have to find their way back.
const SIZE := Vector2i(26, 34)
## How many loops, at most, and how far round (rooms) the long way must be for one.
const LOOPS := Vector2i(2, 5)
const LOOP_REACH := 3
## The Prize must be at least this many rooms in.
const PRIZE_DEPTH := 6
## Chances: a door starts shut; an outer wall is torn open.
const SHUT_CHANCE := 0.25
const BREACH_CHANCE := 0.1
## How many creatures (GDD §8.3: often one, sometimes none, rarely two): weights for 0, 1 and 2.
const CREATURES := [2, 7, 1]
## The loot budget's counts are for a derelict of this many rooms; a bigger one has more in
## proportion, so finds are as thin on the ground in any of them.
const BUDGET_ROOMS := 14.0
## Room characters for the Deck, one per room.
const MARKS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

var seed := 0
var sector := 1
## The attempt that grew it (a layout that breaks a rule is grown again from the next).
var attempt := 0
## Each room: {type, at (grid cell of the module's origin), turn (quarter turns), cells (grid)}.
var rooms: Array[Dictionary] = []
## Which room holds each grid cell.
var room_of := {}
## The edges joined, by Deck's edge key: {cell, side (from that cell), kind ("door", "open")}.
var joins := {}
## Each room's neighbours through a join.
var links := {}
## The Prize room's index (-1 for none).
var prize := -1
## Doors that start shut (edge keys), windows and breached walls ({key: [cell, side]}).
var shut := {}
var windows := {}
var breaches := {}
## The dressing: props ({model, at: Transform3D, rack: kinds}), strobes ({at, failing}) and
## creatures ({kind, at}), in the derelict's space.
var props: Array[Dictionary] = []
var strobes: Array[Dictionary] = []
var creatures: Array[Dictionary] = []


## The layout for `seed` (a derelict node's own), in `sector`.
static func generate(derelict_seed: int, in_sector := 1) -> DerelictLayout:
	var layout: DerelictLayout
	for n in 50:
		layout = DerelictLayout.new()
		layout.seed = derelict_seed
		layout.sector = in_sector
		layout.attempt = n
		if layout._grow(Seeds.rng(derelict_seed, "layout/%d" % n)) and layout.problems().is_empty():
			break
	return layout


## Deck's key for the edge on `side` of `cell`: by the cell south or east of it, and its axis.
static func edge_key(cell: Vector2i, side: String) -> String:
	var owner: Vector2i = cell if side in ["N", "W"] else cell + SIDES[side]
	return "%d,%d,%s" % [owner.x, owner.y, "h" if side in ["N", "S"] else "v"]


# --- Growing -----------------------------------------------------------------------------------

func _grow(rng: RandomNumberGenerator) -> bool:
	_place(&"entry", Vector2i.ZERO, 0)
	var size := rng.randi_range(SIZE.x, SIZE.y) + sector
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
	if rooms.size() - 1 < SIZE.x:
		return false
	# The Prize at the open door farthest in (by rooms, then by metres).
	var depth := _depths()
	var ends := _open_doors()
	ends.sort_custom(func(a: Array, b: Array) -> bool:
		if depth[a[0]] != depth[b[0]]:
			return depth[a[0]] > depth[b[0]]
		return Vector2(a[1]).length() > Vector2(b[1]).length())
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


## Every free door: [room, cell, side] where the cell beyond is empty and not toward the LANTERN.
func _open_doors() -> Array:
	var out := []
	for index in rooms.size():
		for door: Array in _doors_of(index):
			var beyond: Vector2i = door[0] + SIDES[door[1]]
			if not room_of.has(beyond) and beyond.x >= 0 and not joins.has(edge_key(door[0], door[1])):
				out.append([index, door[0], door[1]])
	return out


## A module type to join to a room of type `from`, weighted: rooms open off corridors, corridors
## off rooms; fewer of a type the more there are; none past its `most`.
func _pick(rng: RandomNumberGenerator, from: StringName) -> StringName:
	var corridor_from: bool = DerelictRooms.of(from).kind != "room"
	var table := {}
	var total := 0.0
	for type: StringName in DerelictRooms.MODULES:
		var module := DerelictRooms.of(type)
		if module.kind in ["entry", "prize"]:
			continue
		var count := _count(type)
		if count >= module.most:
			continue
		var weight: float = module.weight / (1.0 + count)
		if module.kind == "room":
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


func _count(type: StringName) -> int:
	return rooms.filter(func(room: Dictionary) -> bool: return room.type == type).size()


## Joins a `type` module at `door` ([room, cell, side]) if it fits any way round.
func _attach(rng: RandomNumberGenerator, type: StringName, door: Array) -> bool:
	var target: Vector2i = door[1] + SIDES[door[2]]
	var need: String = OPPOSITE[door[2]]
	var fits := []
	for turn in 4:
		for socket: Array in _sockets(type, turn):
			if socket[1] != need:
				continue
			var at: Vector2i = target - socket[0]
			if _fits(type, at, turn):
				fits.append([at, turn])
	if fits.is_empty():
		return false
	var pick: Array = fits[rng.randi() % fits.size()]
	var index := _place(type, pick[0], pick[1])
	_join(door[0], index, door[1], door[2])
	return true


func _fits(type: StringName, at: Vector2i, turn: int) -> bool:
	for cell in DerelictRooms.cells_of(type):
		var spot := at + _turn_cell(cell, turn)
		if room_of.has(spot) or spot.x < 0:
			return false
	return true


func _place(type: StringName, at: Vector2i, turn: int) -> int:
	var index := rooms.size()
	var cells: Array[Vector2i] = []
	for cell in DerelictRooms.cells_of(type):
		var spot := at + _turn_cell(cell, turn)
		cells.append(spot)
		room_of[spot] = index
	rooms.append({"type": type, "at": at, "turn": turn, "cells": cells})
	links[index] = []
	return index


func _join(a: int, b: int, cell: Vector2i, side: String) -> void:
	var corridors: bool = DerelictRooms.of(rooms[a].type).kind == "corridor" and DerelictRooms.of(rooms[b].type).kind == "corridor"
	joins[edge_key(cell, side)] = {"cell": cell, "side": side, "kind": "open" if corridors else "door"}
	links[a].append(b)
	links[b].append(a)


## A room's door sockets on the grid: [cell, side].
func _doors_of(index: int) -> Array:
	var room := rooms[index]
	return _sockets(room.type, room.turn).map(func(socket: Array) -> Array: return [room.at + socket[0], socket[1]])


## A module's door sockets turned `turn` quarter turns: [cell (module space, turned), side].
static func _sockets(type: StringName, turn: int) -> Array:
	return DerelictRooms.of(type).doors.map(func(door: String) -> Array: return _turn_edge(door, turn))


## "c,r,S" turned: [cell, side].
static func _turn_edge(edge: String, turn: int) -> Array:
	var parts := edge.split(",")
	return [_turn_cell(Vector2i(int(parts[0]), int(parts[1])), turn), _turn_side(parts[2], turn)]


## A cell of a module turned `turn` quarter turns about its origin (as Basis(UP, turn·90°) turns
## a point: east goes north).
static func _turn_cell(cell: Vector2i, turn: int) -> Vector2i:
	var out := cell
	for i in turn:
		out = Vector2i(out.y, -out.x)
	return out


static func _turn_side(side: String, turn: int) -> String:
	var v: Vector2i = SIDES[side]
	for i in turn:
		v = Vector2i(v.y, -v.x)
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


## Loops: doors between rooms side by side that both have a door there, the long way round
## between them at least LOOP_REACH rooms, not through the entry or the Prize; and only while the
## Prize stays the farthest room in (but one).
func _loop(rng: RandomNumberGenerator) -> void:
	var candidates := []
	for index in rooms.size():
		if index == 0 or index == prize:
			continue
		for door: Array in _doors_of(index):
			var beyond: Vector2i = door[0] + SIDES[door[1]]
			var other: int = room_of.get(beyond, -1)
			if other <= index or other == prize or joins.has(edge_key(door[0], door[1])):
				continue
			if _doors_of(other).any(func(d: Array) -> bool: return d[0] == beyond and d[1] == OPPOSITE[door[1]]):
				candidates.append([index, other, door[0], door[1]])
	var wanted := rng.randi_range(LOOPS.x, LOOPS.y)
	while wanted > 0 and not candidates.is_empty():
		var pick: Array = candidates.pop_at(rng.randi() % candidates.size())
		if links[pick[0]].has(pick[1]) or _apart(pick[0], pick[1]) < LOOP_REACH:
			continue
		_join(pick[0], pick[1], pick[2], pick[3])
		if _prize_far():
			wanted -= 1
		else:
			_unjoin(pick[0], pick[1], pick[2], pick[3])


func _unjoin(a: int, b: int, cell: Vector2i, side: String) -> void:
	joins.erase(edge_key(cell, side))
	links[a].erase(b)
	links[b].erase(a)


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


## Whether the Prize is at least PRIZE_DEPTH rooms in, and as far in as any room but by one.
func _prize_far() -> bool:
	var depth := _depths()
	var deepest := 0
	for index: int in depth:
		if index != prize:
			deepest = maxi(deepest, depth[index])
	return depth.get(prize, 0) >= PRIZE_DEPTH and depth[prize] >= deepest - 1


## Doors open or shut, windows and breaches on the outer walls.
func _walls(rng: RandomNumberGenerator) -> void:
	for key: String in joins:
		if joins[key].kind == "door" and rng.randf() < SHUT_CHANCE:
			shut[key] = true
	for index in rooms.size():
		var room := rooms[index]
		var module := DerelictRooms.of(room.type)
		for edge: String in module.get("windows", []):
			var turned := _turn_edge(edge, room.turn)
			var cell: Vector2i = room.at + turned[0]
			if not room_of.has(cell + SIDES[turned[1]]):
				windows[edge_key(cell, turned[1])] = [cell, turned[1]]
		if module.kind != "room":
			continue
		for cell: Vector2i in room.cells:
			for side: String in SIDES:
				var key := edge_key(cell, side)
				if not room_of.has(cell + SIDES[side]) and not windows.has(key) and rng.randf() < BREACH_CHANCE:
					breaches[key] = [cell, side]


# --- Dressing ----------------------------------------------------------------------------------

## The transform of a room's own space in the derelict's.
func frame_of(index: int) -> Transform3D:
	var room := rooms[index]
	return Transform3D(Basis(Vector3.UP, room.turn * PI / 2), Deck.centre_of(room.at))


static func _local(at: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)


func _dress(rng: RandomNumberGenerator) -> void:
	for index in rooms.size():
		var module := DerelictRooms.of(rooms[index].type)
		var frame := frame_of(index)
		for prop: Array in module.get("props", []):
			props.append({"model": prop[0], "at": frame * _local(prop[1], prop[2]), "rack": prop[3] if prop.size() > 3 else []})
		for strobe: Array in module.get("strobes", []):
			if index == prize or rng.randf() < DerelictRooms.STROBE_CHANCE:
				strobes.append({"at": frame * _local(strobe[0], strobe[1]), "failing": rng.randf() < DerelictRooms.FAILING_CHANCE, "room": index})
		for bit: Array in module.get("scatter", []):
			if rng.randf() < DerelictRooms.SCATTER_CHANCE[bit[0]]:
				props.append({"model": DerelictRooms.SCATTER[bit[0]], "at": frame * _local(bit[1], bit[2]), "rack": [],
						"pose": ["death", 1.4] if bit[0] == "corpse" else []})
	_creatures(rng)


## What lives here: in rooms at least two in from the entry (never the Prize room), on open floor.
## A Hanger hangs from the ceiling in the dark, its growth on the deck below; a Crawler waits.
func _creatures(rng: RandomNumberGenerator) -> void:
	var count := 0
	var roll := rng.randi_range(1, CREATURES.reduce(func(a: int, b: int) -> int: return a + b))
	while roll > CREATURES[count]:
		roll -= CREATURES[count]
		count += 1
	var depth := _depths()
	var dens := []
	for index in rooms.size():
		if index != prize and depth.get(index, 0) >= 2:
			for spot: Vector3 in DerelictRooms.of(rooms[index].type).get("open", []):
				dens.append([index, frame_of(index) * spot])
	var kinds := [&"crawler", &"hanger"]
	if rng.randf() < 0.5:
		kinds.reverse()
	var used := {}
	for i in count:
		var choices := dens.filter(func(den: Array) -> bool: return not used.has(den[0]))
		if choices.is_empty():
			return
		var den: Array = choices[rng.randi() % choices.size()]
		used[den[0]] = true
		var yaw := rng.randf() * TAU
		if kinds[i] == &"hanger":
			creatures.append({"kind": &"hanger", "at": Transform3D(Basis(Vector3.UP, yaw), den[1] + Vector3.UP * Deck.ROOM_HEIGHT)})
			props.append({"model": "derelict/dk_growth", "at": Transform3D(Basis(Vector3.UP, yaw), den[1]), "rack": []})
		else:
			creatures.append({"kind": &"crawler", "at": Transform3D(Basis(Vector3.UP, yaw), den[1])})


## The loot (GDD §8.2): a fuel cell, and finds from a budget that grows with the crew, each in a
## room that suits it: [{kind, at}] in the derelict's space, or {kind, rack} hung on the kit rack
## that's `props[rack]`. The same for the same crew.
func loot(crew: int) -> Array[Dictionary]:
	var rng := Seeds.rng(seed, "loot/%d/%d" % [attempt, crew])
	var out: Array[Dictionary] = []
	for type in DerelictRooms.FUEL_ROOMS:
		var index := _first(type)
		if index >= 0:
			var big: Array = DerelictRooms.of(type).big[0]
			out.append({"kind": &"fuel_cell", "at": frame_of(index) * _local(big[0], big[1])})
			break
	var spots := []
	for index in rooms.size():
		for spot: Vector3 in DerelictRooms.of(rooms[index].type).get("spots", []):
			spots.append([index, frame_of(index) * _local(spot, rng.randf() * 360.0)])
	for find: StringName in _budget(rng, crew):
		if spots.is_empty():
			break
		var weights := spots.map(func(spot: Array) -> float: return DerelictRooms.of(rooms[spot[0]].type).get("finds", {}).get(find, 1.0))
		var spot: Array = spots.pop_at(_weighted(rng, weights))
		out.append({"kind": _roll(rng, DerelictRooms.FINDS[find]), "at": spot[1]})
	# A kit rack keeps a flare now and then: {kind, rack (the prop's index)}.
	for i in props.size():
		for kind: StringName in props[i].rack:
			if rng.randf() < 0.5:
				out.append({"kind": kind, "rack": i})
	return out


## What's to be found, kind by kind (GDD §8.2: it grows with the crew), scaled to the derelict's
## size (a part of one rolled).
func _budget(rng: RandomNumberGenerator, crew: int) -> Array[StringName]:
	var counts := {&"salvage": 3.0 + crew, &"supplies": 1.0 + crew, &"lore": 1.5, &"power": 1.0, &"ammo": 0.5, &"tools": 1.5}
	var share := rooms.size() / BUDGET_ROOMS
	var out: Array[StringName] = []
	for find: StringName in counts:
		var many: float = counts[find] * share
		for i in floori(many) + (1 if rng.randf() < many - floorf(many) else 0):
			out.append(find)
	return out


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


# --- For the Deck, and checking ----------------------------------------------------------------

## The Deck's layout: rows of room characters (one per room), the layout cell at the grid's
## origin, and the openings by layout cell and side.
func rows() -> PackedStringArray:
	var bounds := _bounds()
	var out := PackedStringArray()
	for z in range(bounds.position.y, bounds.end.y):
		var row := ""
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, z)
			row += MARKS[room_of[cell]] if room_of.has(cell) else "."
		out.append(row)
	return out


func origin() -> Vector2i:
	return -_bounds().position


## Openings for Deck.build: "col,row,side" of a layout cell to the edge's kind.
func openings() -> Dictionary:
	var out := {}
	var shift := origin()
	var add := func(cell: Vector2i, side: String, kind: String) -> void:
		out["%d,%d,%s" % [cell.x + shift.x, cell.y + shift.y, side]] = kind
	add.call(Vector2i.ZERO, "W", "hatch")
	for key: String in joins:
		add.call(joins[key].cell, joins[key].side, joins[key].kind)
	for key: String in windows:
		add.call(windows[key][0], windows[key][1], "window")
	for key: String in breaches:
		add.call(breaches[key][0], breaches[key][1], "breach")
	return out


## The entry hatch's opening, as Derelict wants it.
func entry_opening() -> String:
	var shift := origin()
	return "%d,%d,W" % [shift.x, shift.y]


func _bounds() -> Rect2i:
	var box := Rect2i(Vector2i.ZERO, Vector2i.ONE)
	for cell: Vector2i in room_of:
		box = box.expand(cell).expand(cell + Vector2i.ONE)
	return box


func checksum() -> int:
	var plan := rooms.map(func(room: Dictionary) -> Array: return [room.type, room.at, room.turn])
	var edges := joins.keys()
	edges.sort()
	var dressing := props.map(func(prop: Dictionary) -> Array: return [prop.model, prop.at.origin.snapped(Vector3.ONE * 0.01)])
	return hash([seed, attempt, plan, edges, shut.keys(), windows.keys(), breaches.keys(), dressing, creatures.size()])


## Every rule the layout breaks (none, for a good one).
func problems() -> Array[String]:
	var out: Array[String] = []
	if rooms.is_empty() or rooms[0].type != &"entry" or rooms[0].at != Vector2i.ZERO:
		out.append("the entry isn't at the origin")
		return out
	if room_of.has(Vector2i(-1, 0)):
		out.append("something stands in the collar's way")
	var cells := 0
	for index in rooms.size():
		var room := rooms[index]
		cells += room.cells.size()
		for cell: Vector2i in room.cells:
			if cell.x < 0:
				out.append("room %d reaches toward the LANTERN" % index)
			if room_of.get(cell, -1) != index:
				out.append("room %d overlaps another" % index)
	if cells != room_of.size():
		out.append("rooms overlap")
	var grown := rooms.size() - 2
	if grown < SIZE.x or grown > SIZE.y + sector:
		out.append("%d rooms grown" % grown)
	for type: StringName in DerelictRooms.MODULES:
		var module := DerelictRooms.of(type)
		if module.has("most") and _count(type) > module.most:
			out.append("%d %s" % [_count(type), type])
	if prize < 0 or rooms[prize].type != &"prize" or _count(&"prize") != 1:
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
		if DerelictRooms.of(room.type).kind == "room":
			kinds[room.type] = true
	if kinds.size() < 3:
		out.append("only %d kinds of room" % kinds.size())
	if creatures.size() > 2:
		out.append("%d creatures" % creatures.size())
	return out


## The plan as text, for the log: the rooms by character, where each one lies docked (the entry's
## cell is at (20, 0, 0) docked) and what lives in it.
func describe() -> String:
	var lines := ["Derelict %d (attempt %d), %d rooms:" % [seed, attempt, rooms.size()]]
	lines.append_array(rows())
	var living := {}
	for creature in creatures:
		var cell := Vector2i(roundi(creature.at.origin.x / Deck.CELL), roundi(creature.at.origin.z / Deck.CELL))
		living[room_of.get(cell, -1)] = living.get(room_of.get(cell, -1), []) + [creature.kind]
	for index in rooms.size():
		var centre := Vector3.ZERO
		for cell: Vector2i in rooms[index].cells:
			centre += Deck.centre_of(cell)
		centre = centre / rooms[index].cells.size() + Vector3(20, 0, 0)
		var who := ", ".join(living.get(index, [])) if living.has(index) else ""
		lines.append("  %s %-13s docked at %s %s" % [MARKS[index], DerelictRooms.of(rooms[index].type).name, centre, who])
	return "\n".join(lines)
