extends CrtScreen
## The wrist cuff's little screen (GDD §10): too small for words, so it speaks in bars and blips.
## O2 as a bar, suit integrity as a bar, a heartbeat blip at the crew member's pulse, the flashlight
## battery as a row of cells.

var player: Player


func _draw_screen() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		return
	var w := size.x
	var h := size.y
	var o2 := 1.0
	var integrity := 1.0
	var battery := 1.0
	_bar(Rect2(4, 6, w - 8, 7), o2, GREEN if o2 > 0.25 else RED)
	_bar(Rect2(4, 18, w - 8, 7), integrity, GREEN if integrity > 0.5 else AMBER)
	# Heartbeat: a blip that flashes at the pulse.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var bpm := 68.0 + speed * 18.0 + (25.0 if player.sprinting else 0.0)
	var beat := fmod(time * bpm / 60.0, 1.0)
	var blip := Color(GREEN, 1.0 - beat * 1.5)
	draw_circle(Vector2(10, h - 16), 4, blip)
	draw_line(Vector2(18, h - 16), Vector2(w - 4, h - 16), DIM, 1.0)
	# Flashlight cells.
	for i in 4:
		var lit := battery > i / 4.0
		draw_rect(Rect2(4 + i * ((w - 8) / 4.0), h - 7, (w - 8) / 4.0 - 2, 4), AMBER if lit else DIM)


func _bar(r: Rect2, value: float, colour: Color) -> void:
	draw_rect(r, DIM, false, 1.0)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((r.size.x - 2) * clampf(value, 0, 1), r.size.y - 2)), colour)
