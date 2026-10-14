extends CanvasLayer
## The minimal visor HUD (GDD §10): drawn on the same pixel grid as the 3D (rendered small and
## shown big, unsmoothed), in one phosphor colour, and only loud when it has something to say.
##   - Looking at something usable: a small centre dot, and the verb in a box that floats beside the
##     thing, tied to it by a jointed leader line that fades toward it.
##   - The belt (GDD §9.4): four slots in the lower right, the one in hand raised and named (or,
##     carrying something big, its name over the belt). Bright when it changes, then dim.

const COLOUR := Color(0.72, 0.95, 0.78)
const FONT := preload("res://assets/fonts/VT323-Regular.ttf")
const FONT_SIZE := 16
## Belt slots, in HUD pixels.
const SLOT := 22
const SLOT_GAP := 3
const MARGIN := 10
## Seconds the belt stays bright after a change, and how dim it rests.
const BELT_BRIGHT := 2.5
const BELT_REST := 0.35
## 3x5 pixel digits for slot numbers, a row of bits each (top to bottom).
const DIGITS := {1: [2, 6, 2, 2, 7], 2: [6, 1, 2, 4, 7], 3: [6, 1, 2, 1, 6], 4: [5, 5, 7, 1, 1], "E": [7, 4, 6, 4, 7]}

var player: Player

@onready var container: SubViewportContainer = $Screen
@onready var canvas: Control = %Canvas

# The prompt: what it points at, where its box floats, how far it's faded in and drawn out.
var _target: Interactable
var _verb := ""
var _usable := true
var _anchor := Vector2.ZERO
var _box := Vector2.ZERO
var _box_velocity := Vector2.ZERO
var _shown := 0.0
var _drawn := 0.0
var _time := 0.0
var _belt_age := 0.0
var _icons := {}


func _ready() -> void:
	layer = 10
	container.stretch_shrink = Psx.block
	get_window().size_changed.connect(func(): container.stretch_shrink = Psx.block)
	canvas.draw.connect(_draw_hud)
	player.belt_changed.connect(func(): _belt_age = 0.0)


func _process(delta: float) -> void:
	visible = player.operating == null and not Args.flag("--view")
	_time += delta
	_belt_age += delta
	var target := player.aimed_at
	if target != null and target != _target:
		# A new thing: the box starts beside it and the line draws out again.
		_target = target
		_verb = target.prompt(player)
		_drawn = 0.0
		_anchor = _project(target)
		_box = _anchor + _offset(_anchor)
		_box_velocity = Vector2.ZERO
	if target != null:
		_verb = target.prompt(player)
		_usable = target.usable_by(player)
		_anchor = _project(target)
	_shown = move_toward(_shown, 1.0 if target != null else 0.0, delta / (0.12 if target != null else 0.2))
	_drawn = move_toward(_drawn, 1.0, delta / 0.14)
	if _shown <= 0.0:
		_target = null
	# The box floats after its spot on a soft spring, bobbing a pixel.
	var goal := _anchor + _offset(_anchor) + Vector2(0, roundf(sin(_time * 2.4)))
	var pull := (goal - _box) * 140.0 - _box_velocity * 22.0
	_box_velocity += pull * delta
	_box += _box_velocity * delta
	canvas.queue_redraw()


## Where a thing is on the HUD's pixel grid.
func _project(target: Interactable) -> Vector2:
	var at := target.global_position
	for child in target.get_children():
		if child is CollisionShape3D:
			at = child.global_position
			break
	var camera := player.camera
	if camera.is_position_behind(at):
		return _anchor
	return camera.unproject_position(at) / float(container.stretch_shrink)


## Up and to the right of the thing, or to the left near the right edge.
func _offset(anchor: Vector2) -> Vector2:
	var width := _box_width()
	if anchor.x + 30 + width > canvas.size.x - 8:
		return Vector2(-30 - width, -26)
	return Vector2(30, -26)


func _box_width() -> float:
	return FONT.get_string_size(_verb, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + (23 if _usable else 12)


func _draw_hud() -> void:
	if _shown > 0.0:
		_draw_prompt(_shown)
	_draw_belt()


func _draw_prompt(alpha: float) -> void:
	var centre := (canvas.size / 2).floor()
	canvas.draw_rect(Rect2(centre - Vector2(1, 1), Vector2(2, 2)), Color(COLOUR, 0.85 * alpha))
	var box := _box.round()
	var width := _box_width()
	var height := 15.0
	var left := box.x <= _anchor.x
	var mid_y := box.y + height / 2.0
	var join := Vector2(box.x + width if left else box.x, mid_y)
	# The jointed leader: a 45° run up from the thing, then level into the box.
	var anchor := _anchor.round()
	var rise := absf(anchor.y - mid_y)
	var elbow := Vector2(anchor.x + (rise if join.x > anchor.x else -rise), mid_y)
	if (join.x - elbow.x) * (join.x - anchor.x) < 0.0:
		elbow = Vector2(join.x, mid_y)
	var start := anchor + (elbow - anchor).normalized() * 3.0
	var points := PackedVector2Array([start, elbow, join])
	var length := start.distance_to(elbow) + elbow.distance_to(join)
	var shown := _drawn * length
	# Drawn out from the thing toward the box, faint at the thing and solid at the box.
	var line := PackedVector2Array([start])
	var colours := PackedColorArray([Color(COLOUR, 0.1 * alpha)])
	var run := 0.0
	for i in range(1, points.size()):
		var segment := points[i - 1].distance_to(points[i])
		var t := clampf((shown - run) / maxf(segment, 0.001), 0.0, 1.0)
		var end := points[i - 1].lerp(points[i], t)
		line.append(end)
		colours.append(Color(COLOUR, lerpf(0.1, 0.9, (run + segment * t) / length) * alpha))
		run += segment
		if t < 1.0:
			break
	canvas.draw_polyline_colors(line, colours, 1.0)
	canvas.draw_rect(Rect2(anchor - Vector2(1, 1), Vector2(3, 3)), Color(COLOUR, 0.35 * alpha), false, 1.0)
	if _drawn < 1.0:
		return
	# The box: a dark pane with a thin border, a key cap, the verb. What can't be done now is dim,
	# with no key.
	var rect := Rect2(box, Vector2(width, height))
	var text := alpha * (1.0 if _usable else 0.5)
	canvas.draw_rect(rect, Color(0.02, 0.05, 0.03, 0.55 * alpha))
	canvas.draw_rect(rect.grow(-0.5), Color(COLOUR, 0.75 * text), false, 1.0)
	if _usable:
		var key := Rect2(rect.position + Vector2(4, 3), Vector2(9, 9))
		canvas.draw_rect(key, Color(COLOUR, 0.85 * alpha))
		_draw_digit("E", key.position + Vector2(3, 2), Color(0.02, 0.05, 0.03, alpha))
	canvas.draw_string(FONT, rect.position + Vector2(17 if _usable else 6, 12), _verb, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(COLOUR, text))


func _draw_belt() -> void:
	var bright := clampf(1.0 - (_belt_age - BELT_BRIGHT) / 0.6, 0.0, 1.0)
	var alpha := lerpf(BELT_REST, 1.0, bright)
	var count := player.belt.size()
	var origin := Vector2(canvas.size.x - MARGIN - count * SLOT - (count - 1) * SLOT_GAP, canvas.size.y - MARGIN - SLOT).floor()
	# Carrying something big, no slot is drawn: the belt waits, dimmed, under its name.
	var carrying := not player.carrying.is_empty()
	for i in count:
		var kind := Items.kind_of(player.belt[i])
		var selected := i == player.slot and not carrying
		var rect := Rect2(origin + Vector2(i * (SLOT + SLOT_GAP), -3 if selected else 0), Vector2(SLOT, SLOT))
		canvas.draw_rect(rect, Color(0.02, 0.05, 0.03, (0.5 if selected else 0.3) * alpha))
		canvas.draw_rect(rect.grow(-0.5), Color(COLOUR, (0.9 if selected else 0.4) * alpha), false, 1.0)
		var icon := _icon(kind)
		if icon != null:
			var size := Vector2(icon.get_size())
			canvas.draw_texture(icon, (rect.position + (rect.size - size) / 2).floor() + Vector2(2, 2), Color(COLOUR, (1.0 if selected else 0.6) * alpha))
		_draw_digit(i + 1, rect.position + Vector2(2, 2), Color(COLOUR, (0.9 if selected else 0.5) * alpha))
	var name := Items.display_name(player.held)
	if name != "":
		var right := origin.x + count * SLOT + (count - 1) * SLOT_GAP
		canvas.draw_string(FONT, Vector2(right - 200, origin.y - 7), name, HORIZONTAL_ALIGNMENT_RIGHT, 200, FONT_SIZE, Color(COLOUR, alpha))


## A 3x5 pixel glyph (DIGITS), crisp at any size the HUD is shown.
func _draw_digit(digit: Variant, at: Vector2, colour: Color) -> void:
	var rows: Array = DIGITS.get(digit, [])
	for y in rows.size():
		for x in 3:
			if int(rows[y]) & (4 >> x):
				canvas.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), colour)


func _icon(kind: StringName) -> Texture2D:
	if not _icons.has(kind):
		_icons[kind] = Items.icon(kind)
	return _icons[kind]
