extends CrtScreen
## The wrist cuff's little screen (GDD §10): too small for words, so it speaks in bars and blips.
## O2 as a bar, suit integrity as a bar, a heartbeat blip at the crew member's pulse, the helmet
## lamp's battery as a row of cells.

var player: Player


func _draw_screen() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		return
	var w := size.x
	var h := size.y
	var o2 := player.o2 / Player.O2_CAPACITY
	var integrity := 1.0
	var battery := player.battery
	# O2 blinks when it's nearly gone.
	var o2_colour := GREEN if o2 > 0.25 else (RED if o2 > 0.1 or blink(0.5) else DIM)
	_bar(Rect2(4, 6, w - 8, 7), o2, o2_colour)
	_bar(Rect2(4, 18, w - 8, 7), integrity, GREEN if integrity > 0.5 else AMBER)
	# Heartbeat: a blip that flashes at the pulse, red as health fails; a flat line, dead.
	var bpm := player.heart_rate()
	var pulse := GREEN if player.health > 0.3 else RED
	if bpm > 0.0:
		var beat := fmod(time * bpm / 60.0, 1.0)
		draw_circle(Vector2(10, h - 16), 4, Color(pulse, 1.0 - beat * 1.5))
	draw_line(Vector2(18, h - 16), Vector2(w - 4, h - 16), DIM if bpm > 0.0 else RED, 1.0)
	# The helmet lamp's battery.
	for i in 4:
		var lit := battery > i / 4.0
		draw_rect(Rect2(4 + i * ((w - 8) / 4.0), h - 7, (w - 8) / 4.0 - 2, 4), AMBER if lit else DIM)


func _bar(r: Rect2, value: float, colour: Color) -> void:
	draw_rect(r, DIM, false, 1.0)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((r.size.x - 2) * clampf(value, 0, 1), r.size.y - 2)), colour)
