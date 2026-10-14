extends CrtScreen
## DOCKING (GDD §5, §8.1): the collar's readout on the dock panel. What's alongside (named once the
## long-range scan has identified it), how far off it lies, what the collar's doing, the pressure
## beyond it once it's sealed, and the undock countdown; at the foot, what the lever does now.


func _draw_screen() -> void:
	header("DOCKING")
	var collar := Collar.of(self)
	var run := Run.of(self)
	if collar == null:
		return
	var target := "NONE"
	if collar.derelict != null:
		target = run.oddity()[0] if run != null and run.scanned else "UNIDENTIFIED"
	text(1, 1.6, "TARGET", DIM)
	text(1, 2.6, target, GREEN if collar.derelict != null else DIM)
	text(1, 4.0, "COLLAR", DIM)
	var state := _collar(collar)
	text(9, 4.0, state, AMBER if state in ["EXTENDING", "CONTACT", "RETRACTING", "CLOSING"] else GREEN)
	if collar.derelict != null and not collar.sealed():
		var range_m := collar.derelict.global_position.distance_to(collar._mouth * collar.derelict.dock_point().affine_inverse().origin)
		text(1, 5.2, "RANGE", DIM)
		text(9, 5.2, "%d M" % roundi(range_m), GREEN)
	elif collar.sealed():
		var pressure := collar.outside_pressure()
		text(1, 5.2, "EXT PRESS", DIM)
		text(11, 5.2, "%.2f ATM" % pressure if pressure > 0.05 else "VACUUM", GREEN if pressure > 0.5 else AMBER)
	if collar.stage == &"countdown":
		if blink(0.5):
			text(1, 7.0, "RELEASE IN %02d" % ceili(collar.left), RED)
	var prompt := collar.lever_prompt()
	if prompt in ["DOCK", "UNDOCK", "ABORT"]:
		text(1, size.y / CELL.y - 1.4, "HOLD LEVER: %s" % prompt, AMBER if blink() else DIM)


func _collar(collar: Collar) -> String:
	match collar.stage:
		&"approach":
			return "EXTENDING" if collar.extension() > 0.0 else "STANDING BY"
		&"clamp":
			return "CONTACT"
		&"docked":
			return "SEALED"
		&"countdown":
			return "RELEASING"
		&"depart":
			return "RETRACTING" if collar.extension() > 0.0 else "CLEAR"
	return "RETRACTED"
