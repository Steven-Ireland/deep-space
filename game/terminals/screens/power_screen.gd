extends CrtScreen
## ENGINEERING: power and drive at a glance (GDD §5). Bars for each bus; the drive's charge.

const BUSES := [["REACTOR", 0.82], ["LIFE SUP", 0.64], ["DRIVE", 0.0], ["LIGHTS", 0.48], ["DOCKING", 0.3]]


func _draw_screen() -> void:
	header("POWER")
	for i in BUSES.size():
		var row := 2 + i * 1.6
		var value: float = BUSES[i][1] + sin(time * 1.3 + i) * 0.015
		text(1, row, BUSES[i][0], GREEN if value > 0.05 else DIM)
		var bar := Rect2(Vector2(11 * CELL.x, row * CELL.y + 6), Vector2(size.x - 13 * CELL.x, 8))
		draw_rect(bar, DIM, false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(value, 0, 1), 6)), GREEN if value > 0.05 else DIM)
	text(1, 11, "DRIVE", DIM)
	text(9, 11, "COLD", AMBER if blink() else DIM)
	text(1, 12, "FUEL CELLS", DIM)
	text(13, 12, "0 / 3 LOADED", AMBER)
