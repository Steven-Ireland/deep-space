class_name AlarmBeacon
extends Node3D
## An alarm beacon (art/blender/events.py: dk_beacon) on the wall beside a door a security system
## can lock down (GDD §8.3): dead till the alarm sounds, then its dome glows and its light turns,
## sweeping red round the walls, till the lockdown lifts.

const MODEL := preload("res://assets/models/derelict/dk_beacon.glb")
const LAMP_RED := preload("res://assets/materials/lk_lamp_sealed.tres")
const LAMP_DEAD := preload("res://assets/materials/lk_lamp_dead.tres")
## How fast its light turns (radians a second).
const SPIN := 5.5

var on := false:
	set(value):
		on = value
		if is_node_ready():
			_show()

var _lens: MeshInstance3D
var _spin: Node3D
var _beam: SpotLight3D
var _glow: OmniLight3D


func _ready() -> void:
	var model := MODEL.instantiate()
	add_child(model)
	Deck._mark_interior(model)
	_lens = model.find_child("beacon_lens", true, false) as MeshInstance3D
	_spin = Node3D.new()
	# The dome's middle (model space: 9 cm out from the wall, 7 up).
	_spin.position = Vector3(0, 0.07, 0.09)
	add_child(_spin)
	_beam = SpotLight3D.new()
	_beam.light_color = Color(1.0, 0.1, 0.06)
	_beam.spot_range = 7.0
	_beam.spot_angle = 24.0
	_beam.light_energy = 3.0
	_beam.light_cull_mask = ~Deck.HULL_LAYER
	_spin.add_child(_beam)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.12, 0.08)
	_glow.omni_range = 1.6
	_glow.light_energy = 0.6
	_glow.light_cull_mask = ~Deck.HULL_LAYER
	_spin.add_child(_glow)
	_show()


func _process(delta: float) -> void:
	if on:
		_spin.rotate_y(SPIN * delta)


func _show() -> void:
	_beam.visible = on
	_glow.visible = on
	if _lens != null:
		_lens.material_override = LAMP_RED if on else LAMP_DEAD
