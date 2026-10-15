class_name ChargeLamps
extends Node3D
## A shock prod's charge lamps (GDD §13: a weapon shows its charge on itself): the three lamps on
## its battery pod (art/blender/items.py: shock_prod), green for each jolt left and dark for each
## spent, laid over the model's own (baked lit). Spent from the tip end first.

## Where they sit on the prod (its own space: the pod's top, toward the grip), and their size.
const FIRST := Vector3(0.0, 0.0472, 0.17)
const GAP := Vector3(0.0, 0.0, -0.02)
const SIZE := Vector3(0.011, 0.003, 0.009)
const SHADER := preload("res://game/rendering/psx_unlit.gdshader")
const LIT := Color(0.35, 1.0, 0.45)
const OUT := Color(0.05, 0.08, 0.05)

## How many are lit.
var lit := 3:
	set(value):
		lit = value
		_show()

var _lamps: Array[MeshInstance3D] = []
var _on: ShaderMaterial
var _off: ShaderMaterial


## Lamps on `item` (a prod's model) showing `charge` of `charges`.
static func fit(item: Node3D, charge: int, charges: int) -> ChargeLamps:
	var lamps := ChargeLamps.new()
	lamps.name = "ChargeLamps"
	lamps._make(charges)
	lamps.lit = charge
	item.add_child(lamps)
	return lamps


func _make(count: int) -> void:
	_on = ShaderMaterial.new()
	_on.shader = SHADER
	_on.set_shader_parameter("albedo", LIT)
	_off = ShaderMaterial.new()
	_off.shader = SHADER
	_off.set_shader_parameter("albedo", OUT)
	var box := BoxMesh.new()
	box.size = SIZE
	for i in count:
		var lamp := MeshInstance3D.new()
		lamp.mesh = box
		lamp.position = FIRST + GAP * i
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps.append(lamp)


func _show() -> void:
	for i in _lamps.size():
		# The one nearest the tip goes out first: lamp i is lit while more than (count - 1 - i) remain.
		_lamps[i].material_override = _on if lit > _lamps.size() - 1 - i else _off
