extends CanvasLayer
## The visor HUD (GDD §10): drawn on the same pixel grid as the 3D (rendered small and shown big,
## unsmoothed), in the suit's phosphor colour, amber for a warning and red for danger, and only
## loud when it has something to say.
##   - Looking at something usable: a small centre dot, and the verb in a box that floats beside the
##     thing, tied to it by a jointed leader line that fades toward it. A thing that takes a hold
##     has a gauge under its box that fills as it's held.
##   - The belt (GDD §9.4): four slots in the lower right, the one in hand raised and named (or,
##     carrying something big, its name over the belt). Bright when it changes, then dim.
##   - Gauges in the upper left, each while it matters and a few seconds after: O2 (breathing from
##     the suit, or low), SUIT (worn, or breached: BREACH blinking), RCS (the EVA harness's
##     propellant, worn weightless or low; its label bright while the jets fire), RAD (the
##     dosimeter, in a field); VITALS blinking under them when health is critical.
##   - Notices, top centre: what the suit picks up (POWER RESTORED, LOCKDOWN), typed out, held,
##     faded; amber or red when they're a warning.
##   - The communicator (GDD §10): lower left, who's on the channel (TX, sending; or the crew
##     member heard) and a few bars of what's on it.
##   - Struck (GDD §10): the readouts flicker and jump for a moment, and blood spatters the glass at
##     an edge of the visor, fading. Breached out of the air, frost creeps in from the visor's
##     edges; nearly out of O2, the glass fogs. Near a leaking core, radiation specks the sensors.

const COLOUR := Color(0.72, 0.95, 0.78)
const AMBER := Color(1.0, 0.74, 0.3)
const RED := Color(1.0, 0.32, 0.22)
const DARK := Color(0.02, 0.05, 0.03)
const FONT := preload("res://assets/fonts/VT323-Regular.ttf")
const FONT_SIZE := 16
## Struck: seconds the readouts flicker, and the blood on the glass takes to fade.
const STRUCK_FLICKER := 1.2
const SPATTER := 9.0
const BLOOD := Color(0.42, 0.03, 0.02)
## Belt slots, in HUD pixels.
const SLOT := 22
const SLOT_GAP := 3
const MARGIN := 10
## Where a gauge's cells start, past its label, and the rows between gauges.
const GAUGE_CELLS := 24
const GAUGE_ROW := 13
## Seconds the belt stays bright after a change, and how dim it rests.
const BELT_BRIGHT := 2.5
const BELT_REST := 0.35
## Notices: characters typed a second, seconds held once typed, seconds fading; at most this many
## stacked.
const TYPE_RATE := 45.0
const NOTICE_HOLD := 3.2
const NOTICE_FADE := 0.6
const NOTICES := 3
## Frost: seconds a leak takes to frost the visor's edges over, and to clear once it's sealed.
const FROST_GROW := 8.0
const FROST_CLEAR := 3.0
## 3x5 pixel glyphs for slot numbers and key caps, a row of bits each (top to bottom).
const DIGITS := {1: [2, 6, 2, 2, 7], 2: [6, 1, 2, 4, 7], 3: [6, 1, 2, 1, 6], 4: [5, 5, 7, 1, 1], "E": [7, 4, 6, 4, 7],
		"V": [5, 5, 5, 5, 2]}

var player: Player

@onready var container: SubViewportContainer = $Screen
@onready var canvas: Control = %Canvas

# The prompt: what it points at, where its box floats, how far it's faded in and drawn out.
## The finest step its box's spring is followed in (s).
const SPRING_STEP := 1.0 / 120.0
## Specks of radiation static on the visor for each unit of dose a second.
const STATIC_SPECKS := 9000.0
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
## Each gauge: how far it's shown (0..1) and seconds since it last mattered.
var _gauges := {&"o2": [0.0, 99.0], &"suit": [0.0, 99.0], &"rcs": [0.0, 99.0], &"rad": [0.0, 99.0]}
var _last_o2 := 0.0
var _last_integrity := 1.0
## Blood on the glass: blobs [centre, radius] on the HUD's pixel grid, and how long since.
var _spatter: Array = []
var _hurt_seen := 99.0
## Notices on the glass: [text, level, age].
var _notices: Array = []
## Frost over the visor (0 clear .. 1 its edges iced) and fog on it, drawn by the glass's shader.
var _frost := 0.0
var _fog := 0.0
var _glass: ShaderMaterial


func _ready() -> void:
	layer = 10
	container.stretch_shrink = Psx.block
	get_window().size_changed.connect(func(): container.stretch_shrink = Psx.block)
	canvas.draw.connect(_draw_hud)
	# The glass itself, under the readouts: frost and fog (visor_frost.gdshader).
	var glass := ColorRect.new()
	glass.name = "Glass"
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass = ShaderMaterial.new()
	_glass.shader = preload("res://game/rendering/visor_frost.gdshader")
	glass.material = _glass
	canvas.get_parent().add_child(glass)
	canvas.get_parent().move_child(glass, 0)
	player.belt_changed.connect(func(): _belt_age = 0.0)
	player.notice.connect(post)
	_last_o2 = player.o2


## Puts `text` up among the notices (`level` 0 news, 1 warning, 2 danger); the same text again
## only starts it over.
func post(text: String, level := 0) -> void:
	for notice in _notices:
		if notice[0] == text:
			notice[2] = minf(notice[2], text.length() / TYPE_RATE)
			notice[1] = level
			return
	_notices.append([text, level, 0.0])
	if _notices.size() > NOTICES:
		_notices.pop_front()


func _process(delta: float) -> void:
	visible = player.operating == null and not player.dead and not Args.flag("--view")
	_time += delta
	_belt_age += delta
	if player.since_hurt < _hurt_seen:
		_splash()
	_hurt_seen = player.since_hurt
	_follow_gauges(delta)
	for notice in _notices:
		notice[2] += delta
	_notices = _notices.filter(func(notice: Array) -> bool: return notice[2] < _notice_life(notice))
	if player.leaking():
		_frost = minf(1.0, _frost + delta / FROST_GROW)
	else:
		_frost = maxf(0.0, _frost - delta / FROST_CLEAR)
	var fogged := player.in_vacuum and player.o2 < Player.O2_CAPACITY * 0.1
	_fog = move_toward(_fog, 1.0 if fogged else 0.0, delta / 2.0)
	_glass.set_shader_parameter("frost", _frost)
	_glass.set_shader_parameter("fog", _fog)
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
	# The box floats after its spot on a soft spring, bobbing a pixel: stepped finely, so a slow
	# frame or a hitch can't fling it off the visor.
	var goal := _anchor + _offset(_anchor) + Vector2(0, roundf(sin(_time * 2.4)))
	var left := minf(delta, 0.25)
	while left > 0.0:
		var step := minf(left, SPRING_STEP)
		_box_velocity += ((goal - _box) * 140.0 - _box_velocity * 22.0) * step
		_box += _box_velocity * step
		left -= step
	canvas.queue_redraw()


## Each gauge shows while it matters, and for a few seconds after: O2 out of the air or low (or
## being topped up), the suit worn or breached, the harness's propellant weightless or low, any
## dose at all.
func _follow_gauges(delta: float) -> void:
	var matters := {
		&"o2": player.in_vacuum or player.o2 < Player.O2_CAPACITY * 0.25 or player.health < 0.3 or player.o2 > _last_o2 + 1.0,
		&"suit": player.breached or player.integrity < _last_integrity - 0.001,
		&"rcs": player.harness and (player.floating or player.rcs < Player.RCS_FUEL * 0.25),
		&"rad": player.radiation > 0.0,
	}
	_last_o2 = player.o2
	_last_integrity = player.integrity
	for gauge: StringName in _gauges:
		var state: Array = _gauges[gauge]
		state[1] = 0.0 if matters[gauge] else state[1] + delta
		state[0] = move_toward(state[0], 1.0 if state[1] < 3.0 else 0.0, delta / 0.4)


func _notice_life(notice: Array) -> float:
	return String(notice[0]).length() / TYPE_RATE + NOTICE_HOLD + NOTICE_FADE


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
	_draw_spatter()
	if player.panel != null and player.panel.visible:
		# The suit panel shows all of it: only the notices stay, under the panel.
		_draw_notices(SuitPanel.FRAME.end.y + 4.0)
		return
	if player.since_hurt < STRUCK_FLICKER:
		# Struck: the readouts drop out and jump about, settling.
		var shaken := 1.0 - player.since_hurt / STRUCK_FLICKER
		if randf() < 0.35 * shaken:
			return
		canvas.draw_set_transform(Vector2(randi_range(-2, 2), randi_range(-1, 1)) * ceilf(shaken * 2.0))
	_draw_static()
	if _shown > 0.0:
		_draw_prompt(_shown)
	_draw_belt()
	_draw_gauges()
	_draw_notices()
	_draw_comms()
	canvas.draw_set_transform(Vector2.ZERO)


## Radiation striking the visor's sensors (a leaking core near: Hazards): white specks flicking on
## and off across it, more the stronger the dose.
func _draw_static() -> void:
	var specks := mini(160, roundi(player.exposure * STATIC_SPECKS))
	for i in specks:
		var at := Vector2(randf() * canvas.size.x, randf() * canvas.size.y).floor()
		canvas.draw_rect(Rect2(at, Vector2(1, 1)), Color(1, 1, 1, randf_range(0.3, 0.9)))


# --- Gauges ------------------------------------------------------------------------------------

## The gauges stacked down the upper left, each sliding into the row under the last one shown.
func _draw_gauges() -> void:
	var y := float(MARGIN)
	for gauge: StringName in _gauges:
		var alpha: float = _gauges[gauge][0]
		if alpha <= 0.0:
			continue
		var at := Vector2(MARGIN, y).floor()
		match gauge:
			&"o2":
				var fraction := player.o2 / Player.O2_CAPACITY
				var left := ceili(player.o2)
				var colour := COLOUR if fraction > 0.25 else (AMBER if fraction > 0.1 else RED)
				_gauge(at, "O2", fraction, "%d:%02d" % [left / 60, left % 60], colour, alpha, fraction < 0.1)
			&"suit":
				var leak := player.leaking()
				var text := "BREACH" if player.breached else "%d%%" % roundi(player.integrity * 100.0)
				var colour := RED if player.breached else (COLOUR if player.integrity > 0.5 else AMBER)
				_gauge(at, "SUIT", player.integrity, text, colour, alpha, leak)
			&"rcs":
				var fraction := player.rcs / Player.RCS_FUEL
				var firing := player.thrust.length() > 0.05
				_gauge(at, "RCS", fraction, "%d%%" % ceili(fraction * 100.0), COLOUR if fraction > 0.25 else AMBER,
						alpha, fraction < 0.1, 1.0 if firing else 0.7)
			&"rad":
				var rate := player.radiation
				var colour := COLOUR if rate < 0.25 else (AMBER if rate < 0.6 else RED)
				_gauge(at, "RAD", rate, "%.1f" % (rate * 10.0), colour, alpha, rate > 0.6)
		y += GAUGE_ROW * alpha
	if player.health < 0.3 and fmod(_time, 0.8) < 0.5:
		canvas.draw_string(FONT, Vector2(MARGIN, y + 11).floor(), "VITALS", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, RED)


## One gauge at `at`: its label, ten cells filled to `fraction`, a reading; blinking if `urgent`.
func _gauge(at: Vector2, label: String, fraction: float, reading: String, colour: Color, alpha: float, urgent := false,
		label_alpha := 1.0) -> void:
	if urgent and fmod(_time, 0.5) > 0.3:
		alpha *= 0.3
	canvas.draw_string(FONT, at + Vector2(0, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(colour, alpha * label_alpha))
	_draw_cells(at + Vector2(GAUGE_CELLS, 3), fraction, alpha, colour)
	canvas.draw_string(FONT, at + Vector2(GAUGE_CELLS + 54, 11), reading, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(colour, alpha))


## A gauge's ten cells from `at`, filled to `fraction`.
func _draw_cells(at: Vector2, fraction: float, alpha: float, colour := COLOUR) -> void:
	for i in 10:
		var cell := Rect2(at + Vector2(i * 5, 0), Vector2(4, 8))
		if fraction > i / 10.0:
			canvas.draw_rect(cell, Color(colour, 0.9 * alpha))
		else:
			canvas.draw_rect(cell.grow(-0.5), Color(colour, 0.35 * alpha), false, 1.0)


# --- Notices -----------------------------------------------------------------------------------

## The notices down from the top centre, newest lowest: typed out with a cursor, held, faded; a
## warning in amber, danger in red and blinking while it types.
func _draw_notices(top := float(MARGIN)) -> void:
	var y := top
	for notice in _notices:
		var text: String = notice[0]
		var level: int = notice[1]
		var age: float = notice[2]
		var typed := mini(text.length(), int(age * TYPE_RATE))
		var life := _notice_life(notice)
		var alpha := clampf((life - age) / NOTICE_FADE, 0.0, 1.0)
		var colour: Color = [COLOUR, AMBER, RED][clampi(level, 0, 2)]
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var at := Vector2((canvas.size.x - width) / 2.0, y).floor()
		var pane := Rect2(at - Vector2(5, 1), Vector2(width + 10, 14))
		canvas.draw_rect(pane, Color(DARK, 0.5 * alpha))
		if level > 0:
			canvas.draw_rect(Rect2(pane.position, Vector2(2, pane.size.y)), Color(colour, 0.9 * alpha))
			canvas.draw_rect(Rect2(pane.end - Vector2(2, pane.size.y), Vector2(2, pane.size.y)), Color(colour, 0.9 * alpha))
		var shown := text.substr(0, typed)
		if typed < text.length() and fmod(_time, 0.2) < 0.1:
			shown += "_"
		canvas.draw_string(FONT, at + Vector2(0, 11), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(colour, alpha))
		y += 16


# --- The communicator --------------------------------------------------------------------------

## Who's on the channel, lower left over the belt's line: TX while they send (with the talk key's
## cap), otherwise the crew member heard, and a few bars of the channel's spectrum beside it.
func _draw_comms() -> void:
	var talking := Sound.talking()
	if talking.is_empty():
		return
	var sending := talking.has(player)
	var label := "TX" if sending else (talking[0] as Player).crew_name()
	var at := Vector2(MARGIN, canvas.size.y - MARGIN - 12).floor()
	var colour := AMBER if sending else COLOUR
	var dot := fmod(_time, 0.6) < 0.4
	if dot:
		canvas.draw_rect(Rect2(at + Vector2(0, 4), Vector2(3, 3)), colour)
	canvas.draw_string(FONT, at + Vector2(6, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)
	var width := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var bands := Sound.radio_spectrum(8)
	for i in bands.size():
		var height := clampf(bands[i] * 12.0, 1.0, 10.0)
		canvas.draw_rect(Rect2(at + Vector2(12 + width + i * 3, 11 - height), Vector2(2, height)), Color(colour, 0.85))
	if sending:
		var key := Rect2(at + Vector2(12 + width + 28, 2), Vector2(9, 9))
		canvas.draw_rect(key, Color(colour, 0.85))
		_draw_digit("V", key.position + Vector2(3, 2), Color(DARK, 1.0))


# --- The glass ---------------------------------------------------------------------------------

## Blood thrown across the glass from an edge of the visor: a few big drops, each with a smear
## inward and a spray of droplets round it.
func _splash() -> void:
	_spatter.clear()
	var size := canvas.size
	var edge := [Vector2(randf_range(0.15, 0.85) * size.x, 0.0), Vector2(size.x, randf_range(0.2, 0.8) * size.y),
			Vector2(randf_range(0.15, 0.85) * size.x, size.y), Vector2(0.0, randf_range(0.2, 0.8) * size.y)].pick_random() as Vector2
	var inward := (size / 2.0 - edge).normalized()
	for drop in randi_range(3, 5):
		var heading := inward.rotated(randf_range(-0.9, 0.9))
		var at := edge + heading * randf_range(4.0, size.y * 0.22)
		var radius := randf_range(4.0, 8.0)
		_spatter.append([at, radius])
		for i in randi_range(3, 6): # the smear, thinning inward
			_spatter.append([at + heading * radius * (0.6 + i * 0.7), radius * (0.7 - i * 0.1)])
		for i in randi_range(6, 12): # the spray round it
			_spatter.append([at + Vector2.from_angle(randf() * TAU) * randf_range(radius, radius * 3.5), randf_range(0.7, 2.2)])


func _draw_spatter() -> void:
	if _spatter.is_empty() or player.since_hurt > SPATTER:
		return
	var alpha := 0.85 * (1.0 - player.since_hurt / SPATTER)
	for drop in _spatter:
		canvas.draw_circle(drop[0], drop[1], Color(BLOOD, alpha))


# --- The prompt and the belt -------------------------------------------------------------------

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
	var start := anchor + ((elbow - anchor).normalized() * 3.0 if elbow != anchor else Vector2.ZERO)
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
	canvas.draw_rect(rect, Color(DARK, 0.55 * alpha))
	canvas.draw_rect(rect.grow(-0.5), Color(COLOUR, 0.75 * text), false, 1.0)
	if _usable:
		var key := Rect2(rect.position + Vector2(4, 3), Vector2(9, 9))
		canvas.draw_rect(key, Color(COLOUR, 0.85 * alpha))
		_draw_digit("E", key.position + Vector2(3, 2), Color(DARK, alpha))
	canvas.draw_string(FONT, rect.position + Vector2(17 if _usable else 6, 12), _verb, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(COLOUR, text))
	# A thing that takes a hold (the Jump Lever) has a gauge under its box that fills while it's held.
	if _usable and _target != null and _target.hold_for(player) > 0.0:
		var gauge := Rect2(rect.position + Vector2(0, height + 2), Vector2(width, 3))
		canvas.draw_rect(gauge.grow(-0.5), Color(COLOUR, 0.4 * alpha), false, 1.0)
		var filled := player.hold_progress(_target)
		if filled > 0.0:
			canvas.draw_rect(Rect2(gauge.position, Vector2(roundf(width * filled), 3)), Color(COLOUR, 0.9 * alpha))


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
		canvas.draw_rect(rect, Color(DARK, (0.5 if selected else 0.3) * alpha))
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
