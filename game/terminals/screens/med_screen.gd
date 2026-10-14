extends CrtScreen
## MED POD (GDD §5, §11): the med bay pod's console. Each crew member and how they are: OK, DEAD
## (their body somewhere) or LOST (left behind); the dead can be cloned from here, one at a time.
## While the pod works, who it's bringing back and how far along it is.

const ROW := 1.5 # text rows per crew member
const FIRST := 1.6
## A CLONE button's box, by row, in screen pixels.
const BUTTON := Vector2(46, 13)


func _gui_input(event: InputEvent) -> void:
	var bay := MedBay.of(self)
	if bay == null or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var crew := _crew()
	for i in crew.size():
		var player: Player = crew[i]
		if _button(i).grow(3).has_point(event.position):
			if bay.job == &"" and player.dead:
				bay.clone(int(str(player.name)))
				confirm()
			else:
				refuse()


func _draw_screen() -> void:
	header("MED POD")
	var bay := MedBay.of(self)
	if bay == null:
		return
	var crew := _crew()
	for i in crew.size():
		var player: Player = crew[i]
		var row := FIRST + i * ROW
		text(1, row, player.crew_name(), GREEN if not player.dead else AMBER)
		if not player.dead:
			text(9, row, "OK", DIM)
		else:
			text(9, row, "LOST" if player.cause == &"lost" else "DEAD", RED)
			if bay.job == &"":
				var box := _button(i)
				draw_rect(box, GREEN if blink() else DIM, false, 1.0)
				text(box.position.x / CELL.x, row, "CLONE", GREEN)
	var foot := size.y / CELL.y - 1.4
	if bay.job != &"":
		var who := Player.of_peer(get_tree(), bay.who)
		text(1, foot - 1.2, "%s %s" % ["REVIVING" if bay.job == &"revive" else "CLONING", who.crew_name() if who != null else ""], AMBER)
		var bar := Rect2(Vector2(CELL.x, foot * CELL.y + 5), Vector2(size.x - CELL.x * 2, 7))
		draw_rect(bar, DIM, false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * bay.progress(), 5)), AMBER)
	elif crew.any(func(p: Player) -> bool: return p.dead):
		text(1, foot, "INSERT BODY TO REVIVE", DIM)
	else:
		text(1, foot, "READY", DIM)


func _crew() -> Array:
	var crew := get_tree().get_nodes_in_group(&"crew")
	crew.sort_custom(func(a, b): return int(str(a.name)) < int(str(b.name)))
	return crew


func _button(index: int) -> Rect2:
	return Rect2(Vector2(14 * CELL.x + 2, (FIRST + index * ROW) * CELL.y + 2), BUTTON)
