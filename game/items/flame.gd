class_name Flame
extends Node3D
## A struck flare's burning end (GDD §9.3): a hot red glow and a flickering red light that throws
## hard shadows, dimming as the flare burns out. It sits at the flare's `SOCKET_flame`, whether
## the flare's in a hand or loose.

const COLOUR := Color(1.0, 0.28, 0.16)
const ENERGY := 4.0
const RANGE := 8.0
## How far past the flare's end the flame burns, so the flare's own tube doesn't shade it.
const LIFT := 0.03

## 0..1: how much of the flare is left to burn. The last of it dims the flame.
var strength := 1.0

var _light := OmniLight3D.new()
var _glow := MeshInstance3D.new()
var _phase := randf() * 100.0


func _ready() -> void:
	position.z += LIFT # the flare points along +Z in Godot (-Y in Blender)
	_light.light_color = COLOUR
	_light.omni_range = RANGE
	_light.omni_attenuation = 0.8
	_light.shadow_enabled = true
	_light.light_cull_mask = ~Deck.HULL_LAYER
	add_child(_light)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.75, 1.0))
	gradient.set_color(1, Color(1.0, 0.2, 0.1, 0.0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	glow.width = 16
	glow.height = 16
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = glow
	material.albedo_color = COLOUR.lightened(0.3)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	_glow.mesh = quad
	_glow.material_override = material
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	var flicker := 0.82 + 0.1 * sin(t * 31.0) + 0.06 * sin(t * 17.3 + 1.0) + randf() * 0.07
	var left := clampf(strength * 10.0, 0.0, 1.0) # the last tenth of the burn dies away
	_light.light_energy = ENERGY * flicker * left
	_glow.scale = Vector3.ONE * (0.75 + 0.35 * flicker) * maxf(left, 0.2)


## A flame on `item` (a flare's model) at its `SOCKET_flame`, or null if it has none.
static func light(item: Node3D) -> Flame:
	var socket := item.find_child("SOCKET_flame", true, false) as Node3D
	if socket == null:
		return null
	var flame := Flame.new()
	socket.add_child(flame)
	return flame
