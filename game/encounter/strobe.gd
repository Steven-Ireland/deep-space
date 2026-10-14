class_name Strobe
extends Node3D
## An emergency strobe (dk_strobe): a red lens on a wall that pulses a hard red light, a derelict's
## only light in most rooms (GDD §14). Some are failing and stutter.

@export var period := 1.6
@export var failing := false

var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	var model: Node3D = preload("res://assets/models/derelict/dk_strobe.glb").instantiate()
	add_child(model)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.16, 0.08)
	_light.omni_range = 6.0
	_light.omni_attenuation = 1.2
	_light.position = Vector3(0, 0, 0.15)
	_light.light_cull_mask = ~Deck.HULL_LAYER # not through the walls onto the hull
	add_child(_light)
	_time = randf() * period


func _process(delta: float) -> void:
	_time += delta
	var phase := fmod(_time, period) / period
	var on := phase < 0.35
	if failing and fmod(_time * 7.3, 1.0) < 0.3:
		on = not on
	_light.light_energy = 2.2 if on else 0.15
