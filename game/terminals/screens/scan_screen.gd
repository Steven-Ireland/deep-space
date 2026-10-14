extends CrtScreen
## SCIENCE: the long-range scanner (GDD §6). Its scope sweeps over range rings, a blip for each
## planet at its true bearing, fading after the beam passes. Run the scan (click) and the beam
## races for a few seconds; then it names the system's oddity, marks it on the scope, and charts
## the systems a jump can reach (on the Nav Chart, by type; a signal stays unidentified). The
## screen is round: the scope in its upper part, a few centred lines of findings under it.

const SWEEP := 2.8 # seconds per turn, idle
const FAST_SWEEP := 0.7 # while scanning
const CENTRE := Vector2(120, 94)
const RADIUS := 66.0
## The findings' lines (text rows), and the button, in screen pixels.
const LINES := [11.2, 12.2, 13.2]
const BUTTON := Rect2(78, 184, 84, 20)

var _sweep := 0.0


func _gui_input(event: InputEvent) -> void:
	var run := Run.of(self)
	if run == null or not run.started:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if BUTTON.grow(4).has_point(event.position) and not run.scanned and not run.scanning() and not run.jumping():
			run.scan()


func _process(delta: float) -> void:
	super(delta)
	var run := Run.of(self)
	var scanning := run != null and run.scanning()
	_sweep = fmod(_sweep + delta / (FAST_SWEEP if scanning else SWEEP) * TAU, TAU)


func _draw_screen() -> void:
	var run := Run.of(self)
	var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
	var in_jump := run != null and run.jumping() and run.jump_elapsed() >= Run.SPOOL
	for i in range(1, 4):
		draw_arc(CENTRE, RADIUS * i / 3.0, 0, TAU, 32, Color(DIM, 0.8), 1.0)
	draw_line(CENTRE - Vector2(RADIUS, 0), CENTRE + Vector2(RADIUS, 0), Color(DIM, 0.6))
	draw_line(CENTRE - Vector2(0, RADIUS), CENTRE + Vector2(0, RADIUS), Color(DIM, 0.6))
	text(1.5, 5.6, "LRS", DIM)
	if in_jump:
		_centred(LINES[0], "NO RETURNS", AMBER if blink() else DIM)
		_centred(LINES[1], "DRIVE ENGAGED", DIM)
		return
	for i in 12:
		var a := _sweep - i * 0.035
		draw_line(CENTRE, CENTRE + _bearing(a) * RADIUS, Color(GREEN, 0.5 * (1.0 - i / 12.0)), 1.0)
	if system != null:
		for planet in system.planets:
			var d: Vector3 = planet.direction
			_blip(atan2(d.x, -d.z), clampf(planet.distance / 6000.0, 0.15, 0.95), GREEN, 4)
		text(25.5, 5.6, "CNT", DIM)
		text(26, 6.6, str(system.planets.size()), DIM)
	if run == null or not run.started:
		return
	if run.scanned:
		_draw_results(run)
	elif run.scanning():
		var done := 1.0 - run.scan_left / Run.SCAN_TIME
		_centred(LINES[0], "SCANNING %d%%" % roundi(done * 100.0), AMBER)
		var bar := Rect2(Vector2(CENTRE.x - 60, LINES[1] * CELL.y + 8), Vector2(120, 8))
		draw_rect(bar, DIM, false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * done, 6)), AMBER)
	else:
		_centred(LINES[0], "UNSCANNED", DIM)
		draw_rect(BUTTON, GREEN if blink() else DIM, false, 1.0)
		_centred(LINES[1] + 0.25, "RUN SCAN", GREEN)


## The scan's findings: the oddity named and marked, the jumps it charted along the rim.
func _draw_results(run: Run) -> void:
	var oddity := run.oddity()
	var bearing := _oddity_bearing(run)
	if not is_nan(bearing):
		var at := CENTRE + _bearing(bearing) * RADIUS * 0.55
		var pulse := 4.0 + 2.0 * sin(time * 5.0)
		draw_rect(Rect2(at - Vector2(pulse, pulse), Vector2(pulse, pulse) * 2), AMBER, false, 1.0)
	var jumps := run.jumps()
	for i in jumps.size():
		var a := TAU * (i + 0.5) / jumps.size() - PI * 0.5
		var mark: String = "^" if jumps[i] == Run.NEXT_SECTOR else SectorMap.info(run.map.type_of(jumps[i])).mark
		var at := CENTRE + _bearing(a) * (RADIUS + 9)
		draw_string(FONT, at + Vector2(-3.5, 5), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GREEN)
	_centred(LINES[0], oddity[0], AMBER)
	_centred(LINES[1], oddity[1], DIM)
	var marks := PackedStringArray()
	for node in jumps:
		marks.append("^" if node == Run.NEXT_SECTOR else SectorMap.info(run.map.type_of(node)).mark)
	_centred(LINES[2], "JUMPS " + (" ".join(marks) if not marks.is_empty() else "NONE"), GREEN)


## A line of text centred across the screen at text row `row`.
func _centred(row: float, value: String, colour: Color) -> void:
	text((size.x / CELL.x - value.length()) / 2.0 - 0.5, row, value, colour)


## Where the oddity lies (radians, 0 dead ahead): the derelict alongside, the gas giant ahead, or
## somewhere of its own; NAN when there's nothing.
func _oddity_bearing(run: Run) -> float:
	match run.here():
		&"start":
			return NAN
		&"derelict", &"boss":
			return PI * 0.5 # starboard, at the collar
		&"gas_giant":
			var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
			if system != null and not system.planets.is_empty():
				var d: Vector3 = system.planets[0].direction
				return atan2(d.x, -d.z)
	return fposmod(float(run.system_seed(run.at) % 6283) / 1000.0, TAU)


func _blip(bearing: float, reach: float, colour: Color, size: float) -> void:
	var at := CENTRE + _bearing(bearing) * reach * RADIUS
	var since := fposmod(_sweep - fposmod(bearing, TAU), TAU) / TAU
	var fade := clampf(1.0 - since * 1.4, 0.15, 1.0)
	draw_rect(Rect2(at - Vector2(size, size) / 2, Vector2(size, size)), Color(colour, fade))


## A unit vector on the scope for a bearing (0 up, clockwise).
static func _bearing(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))
