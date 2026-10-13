extends CrtScreen
## SCIENCE: the planet survey (GDD §7). Lists the system's planets; clicking one selects it as the
## survey target. (Running the survey and its readout come with M3.)

var selected := 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var row := int((event.position.y - 4) / CELL.y) - 3
		var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
		if system != null and row >= 0 and row < system.planets.size():
			selected = row


func _draw_screen() -> void:
	header("SURVEY")
	var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
	if system == null:
		return
	text(1, 1.6, "%s  %s" % [system.designation, system.star_type.to_upper()], AMBER)
	for i in system.planets.size():
		var planet: Dictionary = system.planets[i]
		var row := 3 + i
		var colour := GREEN
		if i == selected:
			draw_rect(Rect2(2, row * CELL.y + 3, size.x - 4, CELL.y), DIM)
			colour = WHITE
		var km := int(planet.radius * 150.0)
		text(1, row, "%s" % String(planet.name).right(1).to_upper(), colour)
		text(4, row, String(planet.kind).to_upper(), colour)
		text(18, row, "R%6d KM" % km, colour)
		text(31, row, "--", colour)
	text(1, 9, "ATMOSPHERE", DIM)
	text(15, 9, "UNKNOWN", DIM)
	text(1, 10, "GRAVITY", DIM)
	text(15, 10, "UNKNOWN", DIM)
	text(1, 11, "WATER", DIM)
	text(15, 11, "UNKNOWN", DIM)
	text(1, 12, "BIOSIGNS", DIM)
	text(15, 12, "UNKNOWN", DIM)
	text(1, 14, "SELECT TARGET", AMBER if blink() else DIM)
