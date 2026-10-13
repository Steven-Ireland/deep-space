class_name CrtScreen
extends Control
## The contents of a terminal (GDD §10): drawn every frame in phosphor colours on a small grid of
## text cells, like the computers of 1979. Screens subclass this and override _draw_screen();
## `terminal` is set by the Terminal running them, for reaching the game around it.

const FONT := preload("res://assets/fonts/VT323-Regular.ttf")
const FONT_SIZE := 16
const CELL := Vector2(8, 15)

const GREEN := Color(0.42, 1.0, 0.55)
const DIM := Color(0.16, 0.42, 0.22)
const AMBER := Color(1.0, 0.72, 0.25)
const RED := Color(1.0, 0.3, 0.2)
const WHITE := Color(0.9, 1.0, 0.92)

var terminal: Node
var time := 0.0
## Where the operator's cursor is, in screen pixels, or negative when nobody's at the console.
var cursor := Vector2(-1, -1)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	_draw_screen()
	if cursor.x >= 0:
		draw_rect(Rect2(cursor - Vector2(1, 1), Vector2(3, 3)), WHITE)


## Override: draw this screen's contents.
func _draw_screen() -> void:
	pass


## Text at text cell (col, row).
func text(col: float, row: float, value: String, colour := GREEN) -> void:
	draw_string(FONT, Vector2(col * CELL.x + 4, row * CELL.y + 14), value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


## A box outline around text cells (col, row) to (col + w, row + h).
func frame_box(col: float, row: float, w: float, h: float, colour := DIM) -> void:
	draw_rect(Rect2(Vector2(col * CELL.x + 2, row * CELL.y + 2), Vector2(w * CELL.x, h * CELL.y)), colour, false, 1.0)


## A header bar across the top: the station's name on the left, `title` on the right.
func header(title: String) -> void:
	draw_rect(Rect2(0, 0, size.x, CELL.y + 2), DIM)
	text(0, 0, "LANTERN", Color.BLACK)
	text(size.x / CELL.x - title.length() - 1, 0, title, Color.BLACK)


func blink(period := 1.0) -> bool:
	return fmod(time, period) < period * 0.6
