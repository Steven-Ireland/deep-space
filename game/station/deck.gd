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

const KIT := {
	"wall": preload("res://assets/models/station/lk_wall.glb"),
	"door": preload("res://assets/models/station/lk_wall_door.glb"),
	"window": preload("res://assets/models/station/lk_wall_window.glb"),
	"viewport": preload("res://assets/models/station/lk_wall_viewport.glb"),
	"corner": preload("res://assets/models/station/lk_corner.glb"),
	"floor": preload("res://assets/models/station/lk_floor.glb"),
	"ceiling": preload("res://assets/models/station/lk_ceiling.glb"),
}
const DOOR := preload("res://game/station/door.tscn")

## Warm sodium-amber practicals (GDD §14).
@export var light_colour := Color(1.0, 0.78, 0.52)
@export var light_energy := 0.9
@export var light_range := 6.5

## Room character at each grid cell.
var cells := {}
## The Door nodes, by "x,z,side" of the edge they're on.
var doors := {}


## Builds the deck. `openings` maps "col,row,side" (layout cell and side N/E/S/W) to "door",
## "window" or "viewport"; `dark` lists rooms whose fixtures start unlit.
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
		_place("ceiling", at, 0.0)
		if not dark.contains(cells[cell]):
			_light(at)
	var wall_ends := {}
	for key: String in edges:
		var edge: Dictionary = edges[key]
		var kind: String = edge.kind
		var piece := _place("door" if kind == "door" else kind, edge.at, edge.yaw)
		piece.name = "%s_%s" % [kind, key.replace(",", "_")]
		if kind == "door":
			var door := DOOR.instantiate()
			door.position = edge.at
			door.rotation.y = edge.yaw
			door.name = "Door_" + key.replace(",", "_")
			door.lamp = piece.find_child("status_lamp", true, false)
			add_child(door)
			doors[key] = door
		for end: Vector2i in edge.ends:
			wall_ends[end] = wall_ends.get(end, []) + [edge.axis]
	for corner: Vector2i in wall_ends:
		var axes: Array = wall_ends[corner]
		var straight: bool = axes.size() == 2 and axes[0] == axes[1]
		if not straight:
			_place("corner", Vector3(corner.x * CELL - CELL / 2, 0, corner.y * CELL - CELL / 2), 0.0)


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
	var piece: Node3D = KIT[kind].instantiate()
	piece.position = at
	piece.rotation.y = yaw
	add_child(piece)
	return piece


func _light(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 2.8, 0)
	light.light_color = light_colour
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	add_child(light)
