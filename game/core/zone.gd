class_name Zone
extends Area3D
## A volume of the world with its own air and gravity (TECH §3): one room cell of a deck, floor to
## ceiling (or a hatchway's trunk between levels). Crew in a zone that isn't pressurized breathe
## from their suit's O2 (GDD §9.2); outside every zone is space, airless and weightless. Gravity is
## its `weight`, a share of a standard g, straight down: the LANTERN's plating and a derelict's give
## 1, a working relay satellite has none (GDD §9.1). Power will live here too.

## The physics layer zones are on ("zones"). Nothing collides with them; crew look them up.
const LAYER := 1 << 5

@export var pressurized := true
## How heavy things are here, in g (0 weightless .. 1 the LANTERN's).
@export var weight := 1.0


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


## A zone `size` big, centred on `at`.
static func make(at: Vector3, size: Vector3, has_air: bool, g := 1.0) -> Zone:
	var zone := Zone.new()
	zone.position = at
	zone.pressurized = has_air
	zone.weight = g
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	return zone


## The zone holding `point`, or null in open space.
static func at(world: World3D, point: Vector3) -> Zone:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in world.direct_space_state.intersect_point(query, 4):
		if hit.collider is Zone:
			return hit.collider
	return null


## Whether there's air to breathe at `point`.
static func has_air(world: World3D, point: Vector3) -> bool:
	var zone := at(world, point)
	return zone != null and zone.pressurized


## How heavy things are at `point`, in g: weightless out in space.
static func weight_at(world: World3D, point: Vector3) -> float:
	var zone := at(world, point)
	return zone.weight if zone != null else 0.0
