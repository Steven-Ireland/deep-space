class_name Deck
extends Node3D
## A deck built from a text layout on the 4 m grid (TECH §3, §5): a floor and ceiling in every
## room cell, a wall on every edge between a room and anything else, doors and windows where
## openings say, corner posts where walls meet or end, and a warm fixture light in each ceiling.
## The LANTERN (lantern.gd) and, later, derelict modules are decks.
##
## Layout rows run fore (top, -Z) to aft; columns port (left, -X) to starboard. Each character is
## a room ('.' is outside). Cell (col, row) of the layout sits at (col - origin.x, row - origin.y)
## on the grid, so `origin` is the layout cell placed at the world origin.

const CELL := 4.0
const SIDES := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const OPPOSITE := {"N": "S", "E": "W", "S": "N", "W": "E"}

## Kit pieces by kind, for each look: the LANTERN's ("lk") and a derelict's ("dk", decayed). Kinds
## a look lacks fall back to the LANTERN's.
const PIECES := {"wall": "wall", "door": "wall_door", "window": "wall_window", "viewport": "wall_viewport",
		"hatch": "wall_hatch", "breach": "wall_breach", "corner": "corner", "floor": "floor", "ceiling": "ceiling"}
const KIT_FOLDERS := {"lk": "station", "dk": "derelict"}

## Hull plating by kind, for each look: the LANTERN's, and a derelict's (art/blender/hull.py: dh_*,
## two plain sides with different wounds, picked by where they stand). Kinds a look lacks fall back
## to the LANTERN's.
const HULLS := {
	"lk": {
		"wall": [preload("res://assets/models/hull/hl_side.glb")],
		"window": [preload("res://assets/models/hull/hl_side_window.glb")],
		"viewport": [preload("res://assets/models/hull/hl_side_viewport.glb")],
		"hatch": [preload("res://assets/models/hull/hl_side_hatch.glb")],
		"corner": [preload("res://assets/models/hull/hl_corner.glb")],
		"roof": [preload("res://assets/models/hull/hl_roof.glb")],
		"belly": [preload("res://assets/models/hull/hl_belly.glb")],
	},
	"dk": {
		"wall": [preload("res://assets/models/hull/dh_side.glb"), preload("res://assets/models/hull/dh_side_b.glb")],
		"window": [preload("res://assets/models/hull/dh_side_window.glb")],
		"hatch": [preload("res://assets/models/hull/dh_side_hatch.glb")],
		"corner": [preload("res://assets/models/hull/dh_corner.glb")],
		"roof": [preload("res://assets/models/hull/dh_roof.glb")],
		"belly": [preload("res://assets/models/hull/dh_belly.glb")],
	},
}
const DOOR := preload("res://game/station/door.tscn")
## Render layer for interiors: the star's light skips it (StarSystem), so it can't leak through
## thin walls; interiors are lit by their own practicals.
const INTERIOR_LAYER := 2
## Render layer for the hull: interior lights skip it, so they don't glow through the walls.
const HULL_LAYER := 4

## Warm sodium-amber practicals (GDD §14).
@export var light_colour := Color(1.0, 0.78, 0.52)
@export var light_energy := 1.35
@export var light_range := 7.0

## Which look the deck is built in: "lk" (the LANTERN) or "dk" (a derelict).
@export var kit := "lk"
## Whether each cell's ceiling fixture is lit (derelicts are dark).
@export var lit := true

## Whether to wrap the deck in hull plating (the LANTERN; derelict modules bring their own).
@export var hull := true
## Rooms open to space (layout characters): their zones hold no air (GDD §9.2).
@export var vacuum := ""
## How high a room's air goes, for its zone.
const ROOM_HEIGHT := 3.0

## Room character at each grid cell.
var cells := {}
## The Door nodes, by "x,z,side" of the edge they're on.
var doors := {}
## The pressure hatches (Hatch), keyed the same way.
var hatches := {}
## Each room cell's air (Zone), by grid cell.
var zones := {}
## The ceiling fixtures' lights, and the ceilings they hang from.
var lights: Array[OmniLight3D] = []
var ceilings: Array[Node3D] = []


## Builds the deck. `openings` maps "col,row,side" (layout cell and side N/E/S/W) to "door",
## "window", "viewport", "hatch" or "breach" (or "open", nothing at all); `dark` lists rooms whose
## fixtures start unlit.
func build(rows: PackedStringArray, origin: Vector2i, openings: Dictionary, dark: String = "") -> void:
	for row in rows.size():
		for col in rows[row].length():
			var room := rows[row][col]
			if room != ".":
				cells[Vector2i(col, row) - origin] = room
	var edges := _edges(openings, origin)
	for cell: Vector2i in cells:
		var at := _centre(cell)
		_place("floor", at, 0.0)
		ceilings.append(_place("ceiling", at, 0.0))
		if lit and not dark.contains(cells[cell]):
			_light(at)
		var zone := Zone.make(at + Vector3.UP * ROOM_HEIGHT / 2, Vector3(CELL, ROOM_HEIGHT, CELL), not vacuum.contains(cells[cell]))
		zone.name = "Zone_%d_%d" % [cell.x, cell.y]
		add_child(zone)
		zones[cell] = zone
	var wall_ends := {}
	for key: String in edges:
		var edge: Dictionary = edges[key]
		var kind: String = edge.kind
		if kind == "open":
			continue
		var yaw: float = edge.yaw
		if kind == "breach":
			# Its wound is on one face (toward the cell south or east of it): turned to the room.
			var parts := key.split(",")
			if not cells.has(Vector2i(int(parts[0]), int(parts[1]))):
				yaw += PI
		var piece := _place("door" if kind == "door" else kind, edge.at, yaw)
		piece.name = "%s_%s" % [kind, key.replace(",", "_")]
		if kind == "door":
			var door := DOOR.instantiate()
			door.position = edge.at
			door.rotation.y = edge.yaw
			door.name = "Door_" + key.replace(",", "_")
			door.lamp = piece.find_child("status_lamp", true, false)
			if kit != "lk":
				door.get_node("Leaves").free()
				var leaves := _scene("door_leaves").instantiate()
				leaves.name = "Leaves"
				door.add_child(leaves)
			add_child(door)
			_mark_interior(door)
			doors[key] = door
		elif kind == "hatch":
			# It swings into the room on its side (both, between two rooms: either way).
			var parts := key.split(",")
			hatches[key] = Hatch.fit(piece, 1.0 if cells.has(Vector2i(int(parts[0]), int(parts[1]))) else -1.0)
		for end: Vector2i in edge.ends:
			wall_ends[end] = wall_ends.get(end, []) + [edge.axis]
	for corner: Vector2i in wall_ends:
		var axes: Array = wall_ends[corner]
		var straight: bool = axes.size() == 2 and axes[0] == axes[1]
		if not straight:
			_place("corner", Vector3(corner.x * CELL - CELL / 2, 0, corner.y * CELL - CELL / 2), 0.0)
	if hull:
		_build_hull(edges)


## The world position of a grid cell's centre, on the floor.
static func centre_of(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL)


func _centre(cell: Vector2i) -> Vector3:
	return centre_of(cell)


## Every edge that needs a wall: around each room cell, where the neighbour is another room or
## outside. Each is keyed by its grid position so shared edges get one wall.
func _edges(openings: Dictionary, origin: Vector2i) -> Dictionary:
	var edges := {}
	for cell: Vector2i in cells:
		for side: String in SIDES:
			var other: Vector2i = cell + SIDES[side]
			if cells.get(other, ".") == cells[cell]:
				continue
			var horizontal := side == "N" or side == "S"
			# Normalise to the north or west edge of a cell.
			var owner := cell if side in ["N", "W"] else other
			var axis := "h" if horizontal else "v"
			var key := "%d,%d,%s" % [owner.x, owner.y, axis]
			if edges.has(key):
				continue
			var at: Vector3
			var ends: Array[Vector2i]
			if horizontal:
				at = Vector3(owner.x * CELL, 0, owner.y * CELL - CELL / 2)
				ends = [Vector2i(owner.x, owner.y), Vector2i(owner.x + 1, owner.y)]
			else:
				at = Vector3(owner.x * CELL - CELL / 2, 0, owner.y * CELL)
				ends = [Vector2i(owner.x, owner.y), Vector2i(owner.x, owner.y + 1)]
			# An opening may be named from either side of the edge.
			var here := cell + origin
			var there := other + origin
			var kind: String = openings.get("%d,%d,%s" % [here.x, here.y, side],
					openings.get("%d,%d,%s" % [there.x, there.y, OPPOSITE[side]], "wall"))
			edges[key] = {"at": at, "yaw": 0.0 if horizontal else PI / 2, "kind": kind, "axis": axis, "ends": ends}
	return edges


func _place(kind: String, at: Vector3, yaw: float) -> Node3D:
	var piece: Node3D = _scene(kind).instantiate()
	piece.position = at
	piece.rotation.y = yaw
	add_child(piece)
	_mark_interior(piece)
	return piece


## The kit piece for `kind` in this deck's look (falling back to the LANTERN's).
func _scene(kind: String) -> PackedScene:
	var piece: String = "door" if kind == "door_leaves" else PIECES[kind]
	for look: String in [kit, "lk"]:
		var path := "res://assets/models/%s/%s_%s.glb" % [KIT_FOLDERS[look], look, piece]
		if ResourceLoader.exists(path):
			return load(path)
	push_error("Deck: no kit piece for %s." % kind)
	return null


## Stocks the deck with a loose `kind` (Items) at `at`, turned `yaw` degrees: a marker the host
## puts the real thing out at when a crew starts (LooseItems).
func stock(kind: StringName, at: Vector3, yaw := 0.0) -> void:
	var spot := Marker3D.new()
	spot.name = "Stock_%s" % kind
	spot.position = at
	spot.rotation.y = deg_to_rad(yaw)
	spot.set_meta(&"kind", kind)
	spot.add_to_group(&"loot")
	add_child(spot)


## Racks a loose `kind` at `where`: held there (not falling) until someone takes it.
func rack(kind: StringName, where: Transform3D) -> void:
	var spot := Marker3D.new()
	spot.name = "Rack_%s" % kind
	add_child(spot)
	spot.global_transform = where
	spot.set_meta(&"kind", kind)
	spot.set_meta(&"racked", true)
	spot.add_to_group(&"loot")


static func _mark_interior(node: Node) -> void:
	for mesh: VisualInstance3D in node.find_children("*", "VisualInstance3D", true, false):
		mesh.layers = INTERIOR_LAYER


## Hull plating outside every exterior edge (matching its opening), outer corner posts, and roof
## and belly plates over every cell.
func _build_hull(edges: Dictionary) -> void:
	var outer := {}
	for key: String in edges:
		var edge: Dictionary = edges[key]
		var parts := key.split(",")
		var owner := Vector2i(int(parts[0]), int(parts[1]))
		var horizontal: bool = parts[2] == "h"
		# The two cells either side: the owner (south or east of the edge) and its neighbour.
		var other := owner + (Vector2i(0, -1) if horizontal else Vector2i(-1, 0))
		var room_owner := cells.has(owner)
		if room_owner == cells.has(other):
			continue # between two rooms: no hull
		var outward: Vector2i = (Vector2i(0, -1) if horizontal else Vector2i(-1, 0)) if room_owner else (Vector2i(0, 1) if horizontal else Vector2i(1, 0))
		if edge.kind == "open":
			continue # docked to something: no plating over the join
		var kind: String = edge.kind if edge.kind in HULLS["lk"] else "wall"
		var yaw := atan2(float(outward.x), float(outward.y))
		_place_hull(kind, edge.at, yaw)
		for end: Vector2i in edge.ends:
			outer[end] = outer.get(end, Vector2i.ZERO) + outward
	for vertex: Vector2i in outer:
		var around := 0
		for offset in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			if cells.has(vertex + offset):
				around += 1
		if around == 1: # a convex corner of the deck
			var out: Vector2i = outer[vertex]
			_place_hull("corner", Vector3(vertex.x * CELL - CELL / 2 + out.x * 0.2, 0, vertex.y * CELL - CELL / 2 + out.y * 0.2), 0.0)
	for cell: Vector2i in cells:
		_place_hull("roof", centre_of(cell), 0.0)
		_place_hull("belly", centre_of(cell), 0.0)


func _place_hull(kind: String, at: Vector3, yaw: float) -> Node3D:
	var looks: Array = HULLS.get(kit, HULLS["lk"]).get(kind, HULLS["lk"][kind])
	var piece: Node3D = (looks[absi(hash(at)) % looks.size()] as PackedScene).instantiate()
	piece.position = at
	piece.rotation.y = yaw
	add_child(piece)
	for mesh: VisualInstance3D in piece.find_children("*", "VisualInstance3D", true, false):
		mesh.layers = HULL_LAYER
	return piece


func _light(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 2.8, 0)
	light.light_color = light_colour
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.light_cull_mask = ~HULL_LAYER
	add_child(light)
	lights.append(light)
