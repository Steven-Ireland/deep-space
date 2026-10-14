class_name Hatch
extends Node3D
## A round pressure hatch (GDD §5, §8) in a hatch wall (lk_wall_hatch, dk_wall_hatch): its door
## swings on a hinge at its edge into the room it serves, and while it's anywhere near shut the
## opening is solid. Whatever drives it (the collar's airlock, the docking collar) sets `open` on
## every peer from state they share; it swings, heard from where it is (Sound.hatch). The wall's
## status lamp shows green open, amber shut, red while `locked`.

## How far it swings open (radians), and how fast.
const SWING := deg_to_rad(105.0)
const SPEED := 1.3
## The swing counts as open, and the opening unblocked, past this.
const CLEAR := deg_to_rad(40.0)
## The door's radius and its centre above the deck (art/blender/station_kit.py: wall_hatch); the
## hinge stands just past its edge.
const RADIUS := 0.8
const CENTRE := 1.15
const HINGE := RADIUS + 0.06
## The square opening in the wall that the seal closes.
const OPENING := Vector3(2.2, 2.25, 0.3)

const LAMP_OPEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_SHUT := preload("res://assets/materials/lk_lamp_shut.tres")
const LAMP_SEALED := preload("res://assets/materials/lk_lamp_sealed.tres")

@export var open := false:
	set(value):
		if value != open and _live:
			Sound.hatch(self, value)
		open = value
@export var locked := false

## Which side of the wall the room it serves is on: +1 the piece's +Z, -1 its -Z. It swings that way.
var inward := 1.0
var lamp: MeshInstance3D
var _pivot: Node3D
var _seal: CollisionShape3D
var _angle := 0.0
## Whether it's had a frame yet: until then it's being built and starts as it's set, at once and
## silently.
var _live := false


## Fits a hatch to the wall `piece` (a hatch wall a Deck placed), its room on the `inward` side.
static func fit(piece: Node3D, inward: float) -> Hatch:
	var hatch := Hatch.new()
	hatch.name = "Hatch"
	hatch.inward = inward
	piece.add_child(hatch)
	return hatch


func _ready() -> void:
	var piece := get_parent()
	lamp = piece.find_child("status_lamp", true, false) as MeshInstance3D
	var door := piece.find_child("hatch_door", true, false) as Node3D
	if door != null:
		_pivot = Node3D.new()
		_pivot.name = "Hinge"
		add_child(_pivot)
		_pivot.position = Vector3(HINGE, 0, 0)
		var at := door.global_transform
		door.get_parent().remove_child(door)
		_pivot.add_child(door)
		door.global_transform = at
	var seal := StaticBody3D.new()
	seal.name = "Seal"
	_seal = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = OPENING
	_seal.shape = box
	_seal.position = Vector3(0, OPENING.y / 2, 0)
	seal.add_child(_seal)
	add_child(seal)


func _process(delta: float) -> void:
	var target := SWING if open else 0.0
	_angle = move_toward(_angle, target, SPEED * delta if _live else SWING)
	_live = true
	if _pivot != null:
		_pivot.rotation.y = inward * _angle
	_seal.disabled = _angle > CLEAR
	if lamp != null:
		lamp.material_override = LAMP_SEALED if locked else (LAMP_OPEN if _angle > CLEAR else LAMP_SHUT)


## Whether it stands open enough to pass.
func passable() -> bool:
	return _angle > CLEAR


## The middle of the hatch, in the world: where it's heard from.
func centre() -> Vector3:
	return global_transform * Vector3(0, CENTRE, 0)
