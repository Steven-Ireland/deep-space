class_name SatelliteLayout
extends RoomLayout
## A relay satellite's plan (GDD §8.1, §8.3; TECH §6): an earlier wave's relay in working order,
## grown from its node's seed out of hand-built rooms (SatelliteRooms) by RoomLayout, the same on
## every peer. Smaller than a derelict (a quick EVA, high exposure) and compact like a spacecraft's
## bus: it stands on several levels within a box of cells, joined by hatchways through its floors and
## ceilings, so weightless crew float up and down through it. Unmanned, lit, airless, nothing alive.
##
## Outside, it carries what a relay needs: two solar wings on booms off its north and south faces,
## a dish on its roof farthest from the LANTERN, a mast with a beacon, and thruster clusters at its
## corners (`exterior`, placed where its hull is).

## Modules grown from the entry (besides the entry and the Prize): this many, plus the sector.
const SIZE := Vector2i(9, 12)
const LOOPS := Vector2i(1, 3)
const LOOP_REACH := 3
const PRIZE_DEPTH := 4
## Working doors, some shut.
const SHUT_CHANCE := 0.2
## The box it grows in (grid cells, the entry's at the origin; x away from the LANTERN), and how
## many levels it must use at least.
const BOX := AABB(Vector3(0, -2, -2), Vector3(4, 5, 5))
const MIN_LEVELS := 3
## The loot budget's counts are for a satellite of this many rooms.
const BUDGET_ROOMS := 12.0
## The hull (art/blender/satellite.py): its outer face out from a wall line, its roof's top above
## a level's deck, and where on a level the solar wings' booms come out.
const HULL_OUT := 0.56
const ROOF_TOP := 3.48
const WING_HEIGHT := 1.5

## What's mounted outside: {model, at: Transform3D}, in the satellite's space.
var exterior: Array[Dictionary] = []


## The layout for `seed` (a relay node's own), in `sector`.
static func generate(relay_seed: int, in_sector := 1) -> SatelliteLayout:
	var layout: SatelliteLayout
	for n in 50:
		layout = SatelliteLayout.new()
		if layout.grow(relay_seed, in_sector, n):
			break
	return layout


func _modules() -> Dictionary:
	return SatelliteRooms.MODULES


func _size() -> Vector2i:
	return SIZE


func _loops() -> Vector2i:
	return LOOPS


func _loop_reach() -> int:
	return LOOP_REACH


func _prize_depth() -> int:
	return PRIZE_DEPTH


func _shut_chance() -> float:
	return SHUT_CHANCE


func _label() -> String:
	return "satellite"


func _allowed(cell: Vector3i) -> bool:
	return BOX.has_point(Vector3(cell) + Vector3.ONE * 0.5)


func _more_problems() -> Array[String]:
	var out: Array[String] = []
	if levels().size() < MIN_LEVELS:
		out.append("only %d levels" % levels().size())
	if exterior.filter(func(part: Dictionary) -> bool: return part.model.ends_with("solar_wing")).size() != 2:
		out.append("not two solar wings")
	return out


func _dress(_rng: RandomNumberGenerator) -> void:
	for index in rooms.size():
		_furnish(index)
	_mount()


# --- Outside -----------------------------------------------------------------------------------

## The hero pieces on its hull: the solar wings off the level with the most rooms (its north and
## south faces), the dish on the top level's roof farthest from the LANTERN, the mast on the top
## level's roof nearest it, thruster clusters at the top and bottom levels' outer corners.
func _mount() -> void:
	var counts := {}
	for cell: Vector3i in room_of:
		counts[cell.y] = counts.get(cell.y, 0) + 1
	var main := 0
	for level: int in counts:
		if counts[level] > counts.get(main, 0) or (counts[level] == counts.get(main, 0) and absi(level) < absi(main)):
			main = level
	var middle := float(_bounds().get_center().x)
	for side: int in [-1, 1]:
		# The cell farthest out that way on the main level (nearest the middle, for a tie).
		var best := Vector3i(0, 0, 0)
		var found := false
		for cell: Vector3i in room_of:
			if cell.y != main:
				continue
			if not found or cell.z * side > best.z * side or (cell.z == best.z and absf(cell.x - middle) < absf(best.x - middle)):
				best = cell
				found = true
		var face := centre_of(best) + Vector3(0, WING_HEIGHT, side * (Deck.CELL / 2 + HULL_OUT))
		# Out north or south; the north one rolled over too, so both show their cells to the west.
		var turn := Basis() if side > 0 else Basis(Vector3.UP, PI) * Basis(Vector3.BACK, PI)
		exterior.append({"model": "satellite/sh_solar_wing", "at": Transform3D(turn, face)})
	var top: int = levels().back()
	var roof := room_of.keys().filter(func(cell: Vector3i) -> bool: return cell.y == top)
	roof.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x > b.x or (a.x == b.x and a.z < b.z))
	var dish: Vector3i = roof.front()
	exterior.append({"model": "satellite/sh_dish", "at": Transform3D(Basis(Vector3.UP, -PI / 2), centre_of(dish) + Vector3.UP * ROOF_TOP)})
	var mast: Vector3i = roof.back()
	var mast_at := centre_of(mast) + Vector3.UP * ROOF_TOP
	if mast == dish:
		mast_at += Vector3(-1.3, 0, -1.3)
	exterior.append({"model": "satellite/sh_mast", "at": Transform3D(Basis(), mast_at)})
	for level in [levels().front(), top]:
		for corner in _corners(level).slice(0, 2):
			exterior.append({"model": "satellite/sh_rcs", "at": corner})


## A level's outer corners (where only one of the four cells round a grid vertex is there), farthest
## from the satellite's middle first: a thruster cluster's place, its back to the corner post,
## facing out between the two walls.
func _corners(level: int) -> Array[Transform3D]:
	var centre := Vector3(_bounds().get_center().x, 0, _bounds().get_center().y) * Deck.CELL
	var out: Array[Transform3D] = []
	var seen := {}
	for cell: Vector3i in room_of:
		if cell.y != level:
			continue
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var vertex := Vector2i(cell.x, cell.z) + corner
			if seen.has(vertex):
				continue
			seen[vertex] = true
			var around := []
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				var other := vertex + offset
				if room_of.has(Vector3i(other.x, level, other.y)):
					around.append(offset)
			if around.size() != 1:
				continue
			# Out from the corner, away from the one cell that's there.
			var inward := Vector2(around[0]) + Vector2(0.5, 0.5)
			var out_dir := -inward.normalized()
			var at := Vector3((vertex.x - 0.5) * Deck.CELL, level * PITCH + 1.5, (vertex.y - 0.5) * Deck.CELL)
			at += Vector3(out_dir.x, 0, out_dir.y) * HULL_OUT * sqrt(2.0)
			out.append(Transform3D(Basis(Vector3.UP, atan2(out_dir.x, out_dir.y)), at))
	out.sort_custom(func(a: Transform3D, b: Transform3D) -> bool:
		var da := Vector2(a.origin.x - centre.x, a.origin.z - centre.z).length_squared()
		var db := Vector2(b.origin.x - centre.x, b.origin.z - centre.z).length_squared()
		return da > db + 0.001 or (absf(da - db) <= 0.001 and a.origin.x + a.origin.z < b.origin.x + b.origin.z))
	return out


# --- Loot --------------------------------------------------------------------------------------

## The loot (GDD §8.1: quick loot): half the time a fuel cell, and finds from a budget that grows
## with the crew, each in a room that suits it: [{kind, at}] in the satellite's space. Weightless,
## each hangs where it's put. The same for the same crew.
func loot(crew: int) -> Array[Dictionary]:
	var rng := Seeds.rng(seed, "satellite_loot/%d/%d" % [attempt, crew])
	var out: Array[Dictionary] = []
	if Seeds.rng(seed, "satellite_fuel/%d" % attempt).randf() < SatelliteRooms.FUEL_CHANCE:
		for type in SatelliteRooms.FUEL_ROOMS:
			var index := _first(type)
			if index >= 0:
				var big: Array = module(type).big[0]
				out.append({"kind": &"fuel_cell", "at": frame_of(index) * _local(big[0], big[1])})
				break
	var spots := []
	for index in rooms.size():
		for spot: Vector3 in module(rooms[index].type).get("spots", []):
			var turn := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
			spots.append([index, frame_of(index) * Transform3D(turn, spot)])
	for find: StringName in _budget(rng, crew):
		if spots.is_empty():
			break
		var weights := spots.map(func(spot: Array) -> float: return module(rooms[spot[0]].type).get("finds", {}).get(find, 1.0))
		var spot: Array = spots.pop_at(_weighted(rng, weights))
		out.append({"kind": _roll(rng, SatelliteRooms.FINDS[find]), "at": spot[1]})
	return out


## Whether it has a fuel cell aboard.
func has_fuel() -> bool:
	return loot(1).any(func(find: Dictionary) -> bool: return find.kind == &"fuel_cell")


func _budget(rng: RandomNumberGenerator, crew: int) -> Array[StringName]:
	var counts := {&"salvage": 2.5 + crew, &"supplies": 1.0 + crew, &"lore": 2.0, &"power": 1.5, &"ammo": 0.3, &"tools": 0.5}
	var share := rooms.size() / BUDGET_ROOMS
	var out: Array[StringName] = []
	for find: StringName in counts:
		var many: float = counts[find] * share
		for i in floori(many) + (1 if rng.randf() < many - floorf(many) else 0):
			out.append(find)
	return out


func checksum() -> int:
	return hash([super.checksum(), exterior.map(func(part: Dictionary) -> Array: return [part.model, part.at.origin.snapped(Vector3.ONE * 0.01)])])
