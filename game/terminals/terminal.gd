class_name Terminal
extends Node3D
## A live CRT on a console (GDD §10): a small SubViewport running a CrtScreen, shown on the
## console's `screen_*` mesh through the CRT shader, spilling a little of its glow into the room.
## Crew use it by walking up and pressing interact: their camera eases in until the screen fills
## the view, and the mouse drives a cursor on the screen itself. Everyone sees the same contents.
##
## Add as a child of a console model's instance.

const CRT := preload("res://game/terminals/crt.gdshader")

@export var screen_mesh_name := "screen_nav"
@export var screen_script: Script
@export var resolution := Vector2i(320, 240)
@export var glow := Color(0.4, 1.0, 0.5)
@export var verb := "USE"
## Properties set on the screen after it's made, e.g. {"slot": 2} for a vitals tile.
@export var screen_settings := {}

var viewport: SubViewport
var screen: CrtScreen
var mesh: MeshInstance3D

# The screen's plane in the mesh's space: P = _origin + u * _u + v * _v for its UV (u, v).
var _origin: Vector3
var _u: Vector3
var _v: Vector3


func _ready() -> void:
	mesh = get_parent().find_child(screen_mesh_name, true, false) as MeshInstance3D
	if mesh == null:
		push_warning("Terminal: no %s under %s." % [screen_mesh_name, get_parent().name])
		return
	viewport = SubViewport.new()
	viewport.size = resolution
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	add_child(viewport)
	screen = screen_script.new()
	screen.terminal = self
	for key in screen_settings:
		screen.set(key, screen_settings[key])
	screen.size = resolution
	viewport.add_child(screen)

	var material := ShaderMaterial.new()
	material.shader = CRT
	material.set_shader_parameter("screen", viewport.get_texture())
	material.set_shader_parameter("lines", float(resolution.y))
	mesh.material_override = material
	_solve_plane()
	_add_panel()
	_add_glow()


## The camera pose for operating this terminal: square on to the screen, as close as the view
## allows with all of it in frame, so its texels land about one-to-one on the 3D's few pixels
## (the screen's resolution is at most the 3D's 240-270 lines) and every stroke of text survives.
func view_transform(fov_degrees: float) -> Transform3D:
	var centre := mesh.global_transform * (_origin + _u * 0.5 + _v * 0.5)
	var height := (mesh.global_basis * _v).length()
	var width := (mesh.global_basis * _u).length()
	var half_v := deg_to_rad(fov_degrees) * 0.5
	var aspect := float(get_viewport().get_visible_rect().size.aspect())
	var half_h := atan(tan(half_v) * aspect)
	var distance := maxf(height * 0.5 / tan(half_v) / 0.98, width * 0.5 / tan(half_h) / 0.96)
	var normal := _normal()
	var up := -(mesh.global_basis * _v).normalized()
	return Transform3D(Basis.looking_at(-normal, up), centre + normal * distance)


## Where a ray from `from` along `direction` (global) hits the screen, in screen pixels, or
## (-1, -1) if it misses.
func pointer(from: Vector3, direction: Vector3) -> Vector2:
	var inverse := mesh.global_transform.affine_inverse()
	var o := inverse * from
	var d := inverse.basis * direction
	var n := _u.cross(_v)
	var denominator := d.dot(n)
	if absf(denominator) < 1e-6:
		return Vector2(-1, -1)
	var t := (_origin - o).dot(n) / denominator
	var hit := o + d * t - _origin
	# Solve hit = u * _u + v * _v in the plane.
	var uu := _u.dot(_u)
	var uv := _u.dot(_v)
	var vv := _v.dot(_v)
	var hu := hit.dot(_u)
	var hv := hit.dot(_v)
	var det := uu * vv - uv * uv
	var u := (hu * vv - hv * uv) / det
	var v := (hv * uu - hu * uv) / det
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1, -1)
	return Vector2(u, v) * Vector2(resolution)


## Passes an input event to the screen, at `at` screen pixels for mouse events.
func push(event: InputEvent, at: Vector2) -> void:
	if event is InputEventMouse:
		event = event.duplicate()
		event.position = at
		event.global_position = at
	viewport.push_input(event)


func _normal() -> Vector3:
	var n := (mesh.global_basis * _u).cross(mesh.global_basis * _v).normalized()
	# Face the console's operator side (+Z of the console).
	if n.dot(get_parent().global_basis.z) < 0.0:
		n = -n
	return n


## Recovers the screen's plane from its first triangle: three positions and their UVs.
func _solve_plane() -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(positions.size()))
	var best := 0.0
	var tri := [0, 1, 2]
	# The triangle with the widest UV spread gives the best-conditioned solve.
	for i in range(0, indices.size() - 2, 3):
		var a := uvs[indices[i]]
		var area := absf((uvs[indices[i + 1]] - a).cross(uvs[indices[i + 2]] - a))
		if area > best:
			best = area
			tri = [indices[i], indices[i + 1], indices[i + 2]]
	var p0 := positions[tri[0]]
	var e1 := positions[tri[1]] - p0
	var e2 := positions[tri[2]] - p0
	var t1 := uvs[tri[1]] - uvs[tri[0]]
	var t2 := uvs[tri[2]] - uvs[tri[0]]
	var det := t1.x * t2.y - t2.x * t1.y
	_u = (e1 * t2.y - e2 * t1.y) / det
	_v = (e2 * t1.x - e1 * t2.x) / det
	_origin = p0 - _u * uvs[tri[0]].x - _v * uvs[tri[0]].y
	if Args.flag("--debug-terminals"):
		print("Terminal %s: origin %s u %s v %s (uv area %.4f)" % [screen_mesh_name, _origin, _u, _v, best])


func _add_panel() -> void:
	var panel := TerminalPanel.new()
	panel.terminal = self
	panel.verb = verb
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_u.length(), _v.length(), 0.05)
	shape.shape = box
	panel.add_child(shape)
	add_child(panel)
	var centre := mesh.global_transform * (_origin + _u * 0.5 + _v * 0.5)
	var normal := _normal()
	panel.global_transform = Transform3D(Basis.looking_at(-normal, -(mesh.global_basis * _v).normalized()), centre + normal * 0.03)


func _add_glow() -> void:
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = 0.18
	light.omni_range = 1.8
	light.omni_attenuation = 1.6
	light.layers = Deck.INTERIOR_LAYER
	add_child(light)
	var centre := mesh.global_transform * (_origin + _u * 0.5 + _v * 0.5)
	light.global_position = centre + _normal() * 0.35


## The interactable over a terminal's screen: using it is local (the player's camera moves to the
## screen); what they do on the screen goes through the screen's own host requests.
class TerminalPanel:
	extends Interactable

	var terminal: Terminal

	func request_use() -> void:
		var player := get_tree().get_first_node_in_group(&"local_player") as Player
		if player != null:
			player.operate(terminal)
