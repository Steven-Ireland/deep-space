extends CrtScreen
## SCIENCE: the long-range scanner's scope (GDD §6): a sweeping beam over range rings, a blip for
## each planet at its true bearing, fading after the beam passes.

const SWEEP := 2.8 # seconds per turn


func _draw_screen() -> void:
	var centre := size / 2
	var radius := minf(size.x, size.y) / 2 - 8
	for i in range(1, 4):
		draw_arc(centre, radius * i / 3.0, 0, TAU, 32, Color(DIM, 0.8), 1.0)
	draw_line(centre - Vector2(radius, 0), centre + Vector2(radius, 0), Color(DIM, 0.6))
	draw_line(centre - Vector2(0, radius), centre + Vector2(0, radius), Color(DIM, 0.6))
	var sweep := fmod(time / SWEEP, 1.0) * TAU
	for i in 12:
		var a := sweep - i * 0.035
		draw_line(centre, centre + Vector2(sin(a), -cos(a)) * radius, Color(GREEN, 0.5 * (1.0 - i / 12.0)), 1.0)
	var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
	if system == null:
		return
	for planet in system.planets:
		var d: Vector3 = planet.direction
		var bearing := atan2(d.x, -d.z) # 0 is dead ahead (fore)
		var r := clampf(planet.distance / 6000.0, 0.15, 0.95) * radius
		var at := centre + Vector2(sin(bearing), -cos(bearing)) * r
		var since := fposmod(sweep - fposmod(bearing, TAU), TAU) / TAU
		var fade := clampf(1.0 - since * 1.4, 0.15, 1.0)
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(GREEN, fade))
	text(0.5, 0.2, "LRS", DIM)
	text(size.x / CELL.x - 5, size.y / CELL.y - 1.4, "%d CNT" % system.planets.size(), DIM)
