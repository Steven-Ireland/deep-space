extends CrtScreen
## AIRLOCK (GDD §5, §11): the collar's airlock on its cycle panel, inside the chamber. The chamber's
## pressure, the inner door and the outer hatch, and the cycle under way; read it before you open
## anything.


func _draw_screen() -> void:
	header("AIRLOCK")
	var collar := Collar.of(self)
	if collar == null or collar.airlock == null:
		return
	var lock := collar.airlock
	var pressure := lock.pressure()
	text(1, 1.6, "CHAMBER", DIM)
	text(1, 2.6, "%.2f ATM" % pressure if pressure > 0.05 else "VACUUM", GREEN if pressure > 0.5 else AMBER)
	text(1, 4.0, "INNER", DIM)
	text(8, 4.0, "OPEN" if lock.inner.open else ("SHUT" if lock.state == &"in" else "LOCKED"), GREEN)
	text(1, 5.0, "OUTER", DIM)
	var outer := "OPEN" if lock.state == &"out" else ("SHUT" if collar.stage == &"docked" else "NO SEAL")
	text(8, 5.0, outer, GREEN if outer != "NO SEAL" else DIM)
	if lock.cycling():
		if blink(0.5):
			text(1, size.y / CELL.y - 1.4, "CYCLING", AMBER)
	else:
		text(1, size.y / CELL.y - 1.4, "READY", DIM)
