class_name LampBeam
extends Node3D
## A teammate's helmet lamp as you see it from outside (GDD §9.3, §9.4, §14): a faint cone of lit
## air from the lens to where the light lands, and the lens's glare, which flares across your view
## when the beam points at you. It rides their SpotLight3D (Player keeps that at the lamp's lens,
## pointing -Z), so it shows when the light does. Only other people's lamps get one: you never
## see your own from outside.

const BEAM_SHADER := preload("res://game/rendering/lamp_beam.gdshader")
const FLARE_SHADER := preload("res://game/rendering/lamp_flare.gdshader")
## Metres the cone shows before it fades (the light itself reaches further).
const BEAM_RANGE := 7.0
## Bodies and walls that stop the beam.
const SOLID := 1 | 2

## The crew member holding the light, which doesn't stop its own beam.
var holder: CollisionObject3D

var _light: SpotLight3D
var _energy := 1.0
var _cone := MeshInstance3D.new()
var _flare := MeshInstance3D.new()


func _ready() -> void:
	_light = get_parent() as SpotLight3D
	_energy = _light.light_energy
	var beam := ShaderMaterial.new()
	beam.shader = BEAM_SHADER
	beam.set_shader_parameter("colour", _light.light_color)
	beam.set_shader_parameter("spread", tan(deg_to_rad(_light.spot_angle)) * 0.8)
	beam.set_shader_parameter("range", BEAM_RANGE)
	_cone.mesh = _tube(24)
	_cone.material_override = beam
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.custom_aabb = AABB(Vector3(-BEAM_RANGE, -BEAM_RANGE, -BEAM_RANGE - 1.0), Vector3(2.0 * BEAM_RANGE, 2.0 * BEAM_RANGE, BEAM_RANGE + 2.0))
	add_child(_cone)
	var flare := ShaderMaterial.new()
	flare.shader = FLARE_SHADER
	flare.set_shader_parameter("colour", _light.light_color)
	_flare.mesh = QuadMesh.new()
	_flare.material_override = flare
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flare.custom_aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	add_child(_flare)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var space := get_world_3d().direct_space_state
	var lens := global_position
	var forward := -global_basis.z
	var power := _light.light_energy / _energy
	var exclude: Array[RID] = []
	if holder != null:
		exclude.append(holder.get_rid())
	# The cone runs to whatever the light lands on.
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(lens, lens + forward * BEAM_RANGE, SOLID, exclude))
	_cone.set_instance_shader_parameter(&"reach", lens.distance_to(hit.position) if not hit.is_empty() else BEAM_RANGE)
	_cone.set_instance_shader_parameter(&"power", power)
	# The glare: how squarely the lens faces this eye. (The flare hides itself behind whatever's
	# drawn in front of the lens.)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var distance := eye.distance_to(lens)
	var facing := forward.dot((eye - lens) / maxf(distance, 0.001))
	var edge := cos(deg_to_rad(_light.spot_angle))
	var glare := clampf((facing - edge) / (1.0 - edge), 0.0, 1.0)
	_flare.set_instance_shader_parameter(&"glow", smoothstep(-0.2, 0.6, facing) * minf(power, 1.0))
	_flare.set_instance_shader_parameter(&"glare", glare * glare * power / (1.0 + distance * 0.06))


## An open tube `sides` round: unit directions in xy, z 0 at one end and -1 at the other. The beam
## shader shapes it into the cone.
static func _tube(sides: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in sides + 1:
		var angle := TAU * i / sides
		var ring := Vector3(cos(angle), sin(angle), 0.0)
		vertices.append(ring)
		vertices.append(ring + Vector3(0, 0, -1))
	for i in sides:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 2, a + 1, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
