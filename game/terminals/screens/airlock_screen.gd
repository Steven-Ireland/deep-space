extends CrtScreen
## AIRLOCK (GDD §5, §11): an airlock on its cycle panel, inside the chamber: the docking collar's
## (`lock` &"collar") or the EVA airlock's (&"eva"). The chamber's pressure, the inner door and the
## outer hatch, and the cycle under way; read it before you open anything.

@export var lock := &"collar"

var _airlock: Airlock


func _draw_screen() -> void:
	header("AIRLOCK" if lock == &"collar" else "EVA LOCK")
	if _airlock == null:
		_airlock = Airlock.named(get_tree(), lock)
		if _airlock == null:
			return
	var pressure := _airlock.pressure()
	text(1, 1.6, "CHAMBER", DIM)
	text(1, 2.6, "%.2f ATM" % pressure if pressure > 0.05 else "VACUUM", GREEN if pressure > 0.5 else AMBER)
	text(1, 4.0, "INNER", DIM)
	text(8, 4.0, "OPEN" if _airlock.inner_open and _airlock.state == &"in" else ("SHUT" if _airlock.state == &"in" else "LOCKED"), GREEN)
	text(1, 5.0, "OUTER", DIM)
	var outer := "OPEN" if _airlock.state == &"out" else ("SHUT" if _airlock.sealed_to.call() else "NO SEAL")
	text(8, 5.0, outer, GREEN if outer != "NO SEAL" else DIM)
	if _airlock.cycling():
		if blink(0.5):
			text(1, size.y / CELL.y - 1.4, "CYCLING", AMBER)
	elif lock == &"eva" and _airlock.state == &"out":
		text(1, size.y / CELL.y - 1.4, "SPACE", AMBER if blink(1.2) else DIM)
	else:
		text(1, size.y / CELL.y - 1.4, "READY", DIM)
