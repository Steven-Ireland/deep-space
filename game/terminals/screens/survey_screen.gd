extends CrtScreen
## SCIENCE: the Survey Console (GDD §7). Lists the system's planets; click one to select it, then
## SURVEY to scan it. A few seconds later its readout fills in (atmosphere, temperature, gravity,
## water, biosignatures) and it yields Survey Data, more for water and more again for signs of life.
## Everyone at the console sees the same survey; the selection is the operator's own.

const LIST_ROW := 3
const TRAIT_ROW := 9
const BUTTON := Rect2(8, 214, 196, 20)
const TRAITS := [["ATMOSPHERE", "atmosphere"], ["TEMPERATURE", "temperature"], ["GRAVITY", "gravity"],
		["WATER", "water"], ["BIOSIGNS", "biosigns"]]

var selected := 0


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
	var run := Run.of(self)
	if system == null:
		return
	var row := int((event.position.y - 3) / CELL.y) - LIST_ROW
	if row >= 0 and row < system.planets.size():
		selected = row
	elif BUTTON.grow(4).has_point(event.position) and run != null:
		if _can_survey(run, system):
			run.survey(selected)
			confirm()
		elif run.jumping() and selected < system.planets.size() and run.survey_target < 0 and selected not in run.surveyed:
			refuse() # shown while the drive spools, but there's no surveying in a jump


func _draw_screen() -> void:
	header("SURVEY")
	var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
	var run := Run.of(self)
	if run != null:
		text(30, 1.4, "DATA %4d" % run.survey_data, GREEN)
	if system == null or system.planets.is_empty() or (run != null and run.jumping() and run.jump_elapsed() >= Run.SPOOL):
		text(1, 1.4, "NO TARGETS", DIM)
		return
	selected = clampi(selected, 0, system.planets.size() - 1)
	text(1, 1.4, "%s  %s" % [system.designation, system.star_type.to_upper()], AMBER)
	for i in system.planets.size():
		var planet: Dictionary = system.planets[i]
		var row := LIST_ROW + i
		var colour := GREEN
		if i == selected:
			draw_rect(Rect2(2, row * CELL.y + 3, size.x - 4, CELL.y), DIM)
			colour = WHITE
		text(1, row, String(planet.name).right(1).to_upper(), colour)
		text(4, row, String(planet.kind).to_upper(), colour)
		text(17, row, "R%6d KM" % int(planet.radius * 150.0), colour)
		text(31, row, _status(run, i), colour)
	var target: Dictionary = system.planets[selected]
	var known := run != null and selected in run.surveyed
	var busy := run != null and run.survey_target == selected
	for t in TRAITS.size():
		var row := TRAIT_ROW + t
		text(1, row, TRAITS[t][0], DIM)
		if known:
			var value: String = target.traits[TRAITS[t][1]]
			text(15, row, value, AMBER if value in ["AMBIGUOUS", "DETECTED"] else GREEN)
		elif busy:
			text(15, row, _noise(t), DIM)
		else:
			text(15, row, "UNKNOWN", DIM)
	if run == null or not run.started:
		return
	if busy:
		var done := 1.0 - run.survey_left / Run.SURVEY_TIME
		text(1, 14.5, "SURVEYING %s" % String(target.name).right(1).to_upper(), AMBER)
		var bar := Rect2(Vector2(17 * CELL.x, 14.5 * CELL.y + 6), Vector2(size.x - 19 * CELL.x, 8))
		draw_rect(bar, DIM, false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * done, 6)), AMBER)
	elif known:
		text(1, 14.5, "SURVEYED  +%d DATA" % target.traits.data, GREEN)
	elif run.survey_target >= 0:
		text(1, 14.5, "CONSOLE BUSY", DIM)
	else:
		draw_rect(BUTTON, GREEN if blink() else DIM, false, 1.0)
		text(2, 14.5, "SURVEY PLANET %s" % String(target.name).right(1).to_upper(), GREEN)


func _can_survey(run: Run, system: StarSystem) -> bool:
	return run.started and run.survey_target < 0 and selected not in run.surveyed and selected < system.planets.size() \
			and not run.jumping()


func _status(run: Run, planet: int) -> String:
	if run == null:
		return "--"
	if run.survey_target == planet:
		return "SCAN" if blink(0.5) else ""
	return "DONE" if planet in run.surveyed else "--"


## A line of shifting static while a reading comes in.
func _noise(salt: int) -> String:
	var out := ""
	var seed := int(time * 12.0) * 31 + salt * 7
	for i in 8:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		out += "#%/<>=+*"[seed % 8]
	return out
