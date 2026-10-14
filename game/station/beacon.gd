class_name Beacon
extends Node3D
## A rotating warning beacon (GDD §14): a spot of amber light sweeping round, for airlocks and
## anywhere the crew should know something dangerous can happen. In an `alarm` (the collar's undock
## countdown) it turns red and sweeps faster.

@export var colour := Color(1.0, 0.6, 0.15)
@export var speed := 4.0 # radians per second
@export var on := true
@export var alarm := false
const ALARM := Color(1.0, 0.15, 0.08)

var _light: SpotLight3D


func _ready() -> void:
	_light = SpotLight3D.new()
	_light.light_color = colour
	_light.light_energy = 3.0
	_light.spot_range = 7.0
	_light.spot_angle = 30.0
	_light.rotation_degrees = Vector3(-25, 0, 0)
	add_child(_light)


func _process(delta: float) -> void:
	_light.visible = on
	_light.light_color = ALARM if alarm else colour
	rotation.y += speed * delta * (2.2 if alarm else 1.0)
