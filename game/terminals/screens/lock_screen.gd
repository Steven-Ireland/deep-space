extends CrtScreen
## A secure store's lock panel (GDD §8.3; VaultLock): an earlier wave's door code, cracked by
## deduction. Three wheels of the symbols 1 to 6 (click above a wheel or on its top half to turn it
## up, below or its bottom half to turn it down), ENTER to try them. The log on the right answers
## each guess: a filled peg for each symbol right and in place, a hollow one for each right but in
## the wrong place. The code never repeats a symbol. Six wrong and it locks out, sounding the alarm;
## right, and the door opens. The wheels are the operator's own; the log is everyone's.

const WHEELS := [Rect2(10, 50, 30, 38), Rect2(46, 50, 30, 38), Rect2(82, 50, 30, 38)]
const ENTER := Rect2(10, 112, 102, 18)
const LOG_X := 126.0
const BIG := 32

var lock: VaultLock
var wheels: Array[int] = [1, 2, 3]


func _ready() -> void:
	station = "SECURE STORE"


func _gui_input(event: InputEvent) -> void:
	if lock == null or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var at: Vector2 = event.position
	if lock.open:
		return
	if lock.lockout > 0.0:
		refuse()
		return
	for i in WHEELS.size():
		var wheel: Rect2 = WHEELS[i]
		var reach := Rect2(wheel.position - Vector2(0, 12), wheel.size + Vector2(0, 24))
		if reach.has_point(at):
			var up := at.y < wheel.get_center().y
			wheels[i] = posmod(wheels[i] - 1 + (1 if up else -1), VaultLock.SYMBOLS) + 1
			return
	if ENTER.grow(3).has_point(at):
		lock.guess(wheels.duplicate())
		confirm()


func _draw_screen() -> void:
	header("LOCK")
	if lock == null:
		return
	if lock.open:
		_draw_open()
		return
	_draw_wheels()
	_draw_log()


func _draw_open() -> void:
	var title := "ACCESS GRANTED"
	draw_string(FONT, Vector2((size.x - FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x) / 2.0, 82), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GREEN)
	var line := "DOOR UNLOCKED"
	draw_string(FONT, Vector2((size.x - FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x) / 2.0, 106), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, DIM)
	var code := " ".join(lock.code.map(func(symbol: int) -> String: return str(symbol)))
	draw_string(FONT, Vector2((size.x - FONT.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG).x) / 2.0, 146), code,
			HORIZONTAL_ALIGNMENT_LEFT, -1, BIG, WHITE)


## The wheels, ENTER, the tries left; or, locked out, the countdown.
func _draw_wheels() -> void:
	if lock.lockout > 0.0:
		var left := ceili(lock.lockout)
		text(1, 1.6, "LOCKED OUT", RED if blink(0.5) else DIM)
		draw_string(FONT, Vector2(16, 96), "%d:%02d" % [left / 60, left % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, BIG, RED)
		text(1, 7.6, "SECURITY", AMBER)
		text(1, 8.6, "ALERTED", AMBER)
		text(1, 10.2, "RE-KEYING", DIM)
		return
	text(1, 1.6, "ENTER CODE", GREEN)
	for i in WHEELS.size():
		var wheel: Rect2 = WHEELS[i]
		var hover := cursor.x >= 0 and Rect2(wheel.position - Vector2(0, 12), wheel.size + Vector2(0, 24)).has_point(cursor)
		draw_rect(wheel, DIM if hover else Color(DIM, 0.4))
		draw_rect(wheel.grow(-0.5), GREEN, false, 1.0)
		var symbol := str(wheels[i])
		var width := FONT.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG).x
		draw_string(FONT, Vector2(wheel.get_center().x - width / 2.0, wheel.end.y - 7), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG, WHITE)
		_arrow(Vector2(wheel.get_center().x, wheel.position.y - 7), true)
		_arrow(Vector2(wheel.get_center().x, wheel.end.y + 7), false)
	var hover_enter := cursor.x >= 0 and ENTER.grow(3).has_point(cursor)
	draw_rect(ENTER, GREEN if hover_enter else DIM, not hover_enter, 1.0)
	draw_string(FONT, Vector2(ENTER.get_center().x - 18, ENTER.end.y - 4), "ENTER", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
			Color.BLACK if hover_enter else GREEN)
	text(1, 9.4, "TRIES", DIM)
	for i in VaultLock.TRIES:
		var cell := Rect2(Vector2(54 + i * 9, 9.4 * CELL.y + 7), Vector2(7, 8))
		var left := i < lock.tries_left()
		draw_rect(cell if left else cell.grow(-0.5), (AMBER if lock.tries_left() <= 2 else GREEN) if left else DIM, left, 1.0)
	if not lock.live():
		return
	var last: Array = lock.guesses.back() if not lock.guesses.is_empty() else []
	if not last.is_empty() and blink(0.6):
		text(1, 10.6, "DENIED", RED)


func _arrow(at: Vector2, up: bool) -> void:
	var tip := at + Vector2(0, -3 if up else 3)
	draw_colored_polygon(PackedVector2Array([tip, at + Vector2(-5, 3 if up else -3), at + Vector2(5, 3 if up else -3)]), DIM)


## The guesses so far, each with its pegs: filled for in place, hollow for out of place.
func _draw_log() -> void:
	draw_line(Vector2(LOG_X - 6, 22), Vector2(LOG_X - 6, size.y - 18), DIM, 1.0)
	draw_string(FONT, Vector2(LOG_X, 34), "LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, DIM)
	for i in lock.guesses.size():
		var entry: Array = lock.guesses[i]
		var y := 52.0 + i * 18.0
		draw_string(FONT, Vector2(LOG_X, y), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, DIM)
		var symbols := " ".join((entry[0] as Array).map(func(symbol: int) -> String: return str(symbol)))
		draw_string(FONT, Vector2(LOG_X + 14, y), symbols, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GREEN)
		var x := LOG_X + 62
		for p in entry[1]:
			draw_circle(Vector2(x, y - 5), 3.5, GREEN)
			x += 10
		for p in entry[2]:
			draw_arc(Vector2(x, y - 5), 3.0, 0.0, TAU, 10, AMBER, 1.0)
			x += 10
		if entry[1] == 0 and entry[2] == 0:
			draw_line(Vector2(x - 2, y - 5), Vector2(x + 6, y - 5), DIM, 1.0)
	# The key to the pegs, along the foot.
	draw_circle(Vector2(LOG_X + 2, size.y - 10), 3.0, GREEN)
	Glyphs.draw(self, "PLACE", Vector2(LOG_X + 8, size.y - 13), DIM)
	draw_arc(Vector2(LOG_X + 40, size.y - 10), 2.5, 0.0, TAU, 10, AMBER, 1.0)
	Glyphs.draw(self, "SYMBOL", Vector2(LOG_X + 46, size.y - 13), DIM)
