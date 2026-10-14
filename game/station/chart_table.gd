class_name ChartTable
extends Node3D
## The chart table's hologram (GDD §5, §6), on its lens (`SOCKET_holo`): the sector chart the Nav
## Chart shows, floating over the glass for the whole crew to stand round. The departure is at the
## aft end and the boss at the fore, the rows rising toward it, so it reads like the way ahead
## through the viewport. Charted systems are their type's mark; routes join them, the way taken
## bright and the route plotted brighter; where the LANTERN is blinks. It's unsteady, as
## holograms are, and shakes up in a jump. Display only: routes are plotted at the helm.

const HOLOGRAM := preload("res://game/rendering/hologram.gdshader")
const FONT := preload("res://assets/fonts/VT323-Regular.ttf")
## The chart's footprint over the glass (x across, z departure to boss), and its height: from
## LOW at the departure to HIGH at the boss.
const SPAN := Vector2(1.1, 1.0)
const LOW := 0.3
const HIGH := 0.52
const GREEN := CrtScreen.GREEN
const DIM := Color(0.12, 0.34, 0.18)
const WHITE := CrtScreen.WHITE
const RED := CrtScreen.RED
const AMBER := CrtScreen.AMBER

var _lines := MeshInstance3D.new()
var _mesh := ImmediateMesh.new()
var _material := ShaderMaterial.new()
var _beam := MeshInstance3D.new()
var _beam_material := ShaderMaterial.new()
var _light := OmniLight3D.new()
var _marks := {} # node -> Label3D
var _title: Label3D
var _strength := 1.0
var _dropout := 0.0
var _chart := -1 # the chart shown (its checksum)


func _ready() -> void:
	_material.shader = HOLOGRAM
	_material.set_shader_parameter("energy", 1.6)
	_lines.mesh = _mesh
	_lines.material_override = _material
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	# The beam from the lens up to the chart: a faint cone, fading as it rises.
	var cone := CylinderMesh.new()
	cone.bottom_radius = 0.07
	cone.top_radius = 0.5
	cone.height = LOW
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	_beam.mesh = cone
	_beam_material.shader = HOLOGRAM
	_beam_material.set_shader_parameter("energy", 0.18)
	_beam_material.set_shader_parameter("tint", GREEN)
	_beam_material.set_shader_parameter("fade_height", LOW)
	_beam.material_override = _beam_material
	_beam.position.y = LOW / 2
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_light.light_color = GREEN
	_light.light_energy = 0.5
	_light.omni_range = 2.6
	_light.omni_attenuation = 1.5
	_light.position.y = 0.35
	_light.layers = Deck.INTERIOR_LAYER
	add_child(_light)
	_title = _label(Vector3(0, HIGH + 0.14, -SPAN.y / 2), "", 0.002)
	for node in [_lines, _beam]:
		node.layers = Deck.INTERIOR_LAYER


func _process(delta: float) -> void:
	var run := Run.of(self)
	if run == null or run.map == null:
		visible = false
		return
	visible = true
	if run.map.checksum() != _chart:
		_chart = run.map.checksum()
		for mark: Label3D in _marks.values():
			mark.queue_free()
		_marks.clear()
	_flicker(run, delta)
	_draw_routes(run)
	_draw_marks(run)
	_title.text = "SECTOR %d" % run.sector
	_title.modulate = Color(AMBER, _strength)


## Unsteady: a little shimmer always, a dropout now and then, and a hard judder in a jump.
func _flicker(run: Run, delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_dropout = maxf(0.0, _dropout - delta)
	if _dropout <= 0.0 and randf() < delta * 0.15:
		_dropout = randf_range(0.04, 0.12)
	var shake := run.shake()
	_strength = (0.82 + 0.1 * sin(t * 13.0) + 0.08 * randf()) * (0.15 if _dropout > 0.0 else 1.0)
	if shake > 0.0:
		_strength *= 0.6 + 0.4 * randf()
		position.x = randf_range(-1.0, 1.0) * 0.012 * shake
	else:
		position.x = 0.0
	_material.set_shader_parameter("strength", _strength)
	_beam_material.set_shader_parameter("strength", _strength)
	_light.light_energy = 0.5 * _strength


func _draw_routes(run: Run) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var map := run.map
	# A dotted rail across every row, charted or not.
	for row in SectorMap.BOSS_ROW + 1:
		for i in 12:
			var x := lerpf(-SPAN.x / 2, SPAN.x / 2, (i + 0.3) / 12.0)
			_line(_at(x, row), _at(x + SPAN.x / 12.0 * 0.2, row), Color(DIM, 0.3))
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3
	for from in run.charted:
		for to in map.next_of(from):
			if to not in run.charted:
				continue
			var colour := DIM
			if from in run.visited and to in run.visited:
				colour = GREEN
			elif from == run.at and (to == run.route or to == run.jump_to):
				colour = WHITE if blink else GREEN
			elif from == run.at:
				colour = Color(GREEN, 0.5)
			_line(_point(map, from), _point(map, to), colour)
	# Where the LANTERN is: a ring on the chart under its mark.
	var here := _point(map, run.at)
	for i in 12:
		var a := TAU * i / 12.0
		var b := TAU * (i + 1) / 12.0
		var ring := WHITE if blink else GREEN
		_line(here + Vector3(cos(a), 0, sin(a)) * 0.05, here + Vector3(cos(b), 0, sin(b)) * 0.05, ring)
	_mesh.surface_end()


func _draw_marks(run: Run) -> void:
	var map := run.map
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5
	for node in run.charted:
		if not _marks.has(node):
			_marks[node] = _label(_point(map, node) + Vector3.UP * 0.045, SectorMap.info(map.type_of(node)).mark, 0.0032)
		var colour := DIM
		if node == run.at:
			colour = WHITE if blink else GREEN
		elif node in run.jumps():
			colour = GREEN
		elif node in run.visited:
			colour = Color(GREEN, 0.7)
		if map.type_of(node) == &"boss":
			colour = RED if node != run.at else colour
		if node == run.route or node == run.jump_to:
			colour = WHITE
		(_marks[node] as Label3D).modulate = Color(colour, colour.a * _strength)


## A mark floating over the chart: a pixel glyph that always faces the viewer.
func _label(at: Vector3, value: String, size: float) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font = FONT
	label.font_size = 32
	label.outline_size = 0
	label.pixel_size = size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.double_sided = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.layers = Deck.INTERIOR_LAYER
	label.position = at
	add_child(label)
	return label


func _line(a: Vector3, b: Vector3, colour: Color) -> void:
	var c := Color(colour.r * colour.a, colour.g * colour.a, colour.b * colour.a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)


## Where `node` floats.
func _point(map: SectorMap, node: Vector2i) -> Vector3:
	var x: float = map.node(node).get("x", 0.5)
	return Vector3((x - 0.5) * SPAN.x, 0, 0) + _at(0, node.y)


## The chart's centre line at `row`, offset `x` across.
func _at(x: float, row: int) -> Vector3:
	var along := float(row) / SectorMap.BOSS_ROW
	return Vector3(x, lerpf(LOW, HIGH, along), lerpf(SPAN.y / 2, -SPAN.y / 2, along))
