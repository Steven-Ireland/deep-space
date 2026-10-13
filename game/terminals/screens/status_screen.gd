extends CrtScreen
## A simple readout: a header, a few lines of text, an optional big figure, and a blinking prompt.
## Used by small terminals (airlock, recycler, fabricator, cabin logs, med pod) until they get
## screens of their own. Configured through the Terminal's screen_settings.

@export var title := "STATUS"
## Each line: [text, colour name] with colour one of GREEN, AMBER, RED, DIM, WHITE.
@export var lines: Array = []
## A large figure in the middle (e.g. the salvage count), or "" for none.
@export var figure := ""
@export var prompt := ""


func _draw_screen() -> void:
	header(title)
	var row := 2.0
	for line: Array in lines:
		text(1, row, line[0], _colour(line[1] if line.size() > 1 else "GREEN"))
		row += 1.0
	if figure != "":
		draw_string(FONT, Vector2(8, size.y * 0.5 + 16), figure, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE * 3, AMBER)
	if prompt != "" and blink():
		text(1, size.y / CELL.y - 1.4, prompt, AMBER)


func _colour(name: String) -> Color:
	return {"GREEN": GREEN, "AMBER": AMBER, "RED": RED, "DIM": DIM, "WHITE": WHITE}.get(name, GREEN)
