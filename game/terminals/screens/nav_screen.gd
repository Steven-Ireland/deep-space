extends CrtScreen
## HELM: the Nav Chart (GDD §6). The sector starts uncharted; the long-range scan (M3) fills in
## the next jumpable systems. For now it shows where the LANTERN is and that no route is plotted.


func _draw_screen() -> void:
	header("NAV CHART")
	var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
	text(1, 2, "SECTOR 1", AMBER)
	text(1, 3, "UNCHARTED", DIM)
	# The chart: faint grid, the LANTERN's system as a lit marker, the unknown beyond.
	var chart := Rect2(Vector2(140, 36), Vector2(170, 170))
	for i in 6:
		var x := chart.position.x + chart.size.x * i / 5.0
		var y := chart.position.y + chart.size.y * i / 5.0
		draw_line(Vector2(x, chart.position.y), Vector2(x, chart.end.y), Color(DIM, 0.5))
		draw_line(Vector2(chart.position.x, y), Vector2(chart.end.x, y), Color(DIM, 0.5))
	var here := chart.position + Vector2(chart.size.x / 2, chart.size.y - 22)
	draw_circle(here, 4, GREEN if blink(0.8) else DIM)
	draw_arc(here, 9, 0, TAU, 12, GREEN, 1.0)
	for i in 3:
		var p := chart.position + Vector2(30 + i * 55, 40)
		text(p.x / CELL.x - 0.5, p.y / CELL.y - 0.5, "?", DIM)
	draw_line(here + Vector2(0, -12), Vector2(here.x, chart.position.y + 8), Color(DIM, 0.6), 1.0)
	text(1, 5, "SYSTEM", DIM)
	text(1, 6, system.designation if system else "----", GREEN)
	text(1, 7, (system.star_type.to_upper() if system else ""), GREEN)
	text(1, 9, "ROUTE", DIM)
	text(1, 10, "NONE PLOTTED", AMBER if blink() else DIM)
	text(1, 12, "LONG-RANGE SCAN", DIM)
	text(1, 13, "REQUIRED", AMBER)
