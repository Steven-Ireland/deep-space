extends CrtScreen
## ENGINEERING: power and drive at a glance (GDD §5). Bars for each bus; the drive's state and the
## cells in the fuel rack. At a gas giant (or a depot) it offers to take on fuel: a skim fills one
## empty bay, once a system.

const BUSES := [["REACTOR", 0.82], ["LIFE SUP", 0.64], ["DRIVE", 0.0], ["LIGHTS", 0.48], ["DOCKING", 0.3]]
const BUTTON := Rect2(8, 214, 196, 20)


func _gui_input(event: InputEvent) -> void:
	var run := Run.of(self)
	if run == null or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if BUTTON.grow(4).has_point(event.position) and run.can_refuel() and not run.refuelling():
		run.refuel()


func _draw_screen() -> void:
	header("POWER")
	var run := Run.of(self)
	for i in BUSES.size():
		var row := 1.6 + i * 1.4
		var value: float = BUSES[i][1] + sin(time * 1.3 + i) * 0.015
		if BUSES[i][0] == "DRIVE" and run != null:
			value = _drive_load(run)
		text(1, row, BUSES[i][0], GREEN if value > 0.05 else DIM)
		var bar := Rect2(Vector2(11 * CELL.x, row * CELL.y + 6), Vector2(size.x - 13 * CELL.x, 8))
		draw_rect(bar, DIM, false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(value, 0, 1), 6)), GREEN if value > 0.05 else DIM)
	if run == null or not run.started:
		return
	text(1, 9.0, "DRIVE", DIM)
	text(13, 9.0, _drive(run), AMBER if run.jumping() or (run.fuel_left() == 0 and blink()) else GREEN)
	text(1, 10.2, "FUEL CELLS", DIM)
	text(13, 10.2, "%d / %d LOADED" % [run.fuel_left(), run.fuel.size()], GREEN if run.fuel_left() > 0 else RED)
	var refuel: bool = SectorMap.info(run.here()).get("refuel", false)
	if not refuel:
		return
	var skim := run.here() == &"gas_giant"
	text(1, 12.0, "GAS GIANT IN RANGE" if skim else "DEPOT IN RANGE", AMBER)
	if run.refuelling():
		var done := 1.0 - run.refuel_left / Run.REFUEL_TIME
		text(1, 14.5, "SKIMMING" if skim else "DRAWING FUEL", AMBER)
		var bar := Rect2(Vector2(15 * CELL.x, 14.5 * CELL.y + 6), Vector2(size.x - 17 * CELL.x, 8))
		draw_rect(bar, DIM, false, 1.0)
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * done, 6)), AMBER)
	elif run.refuelled:
		text(1, 14.5, "CELL FILLED", GREEN)
	elif run.can_refuel():
		draw_rect(BUTTON, GREEN if blink() else DIM, false, 1.0)
		text(2, 14.5, "SKIM FUEL: FILL A BAY" if skim else "DRAW FUEL: FILL A BAY", GREEN)
	else:
		text(1, 14.5, "BAYS FULL", DIM)


func _drive(run: Run) -> String:
	if run.jumping():
		return "SPOOLING" if run.jump_elapsed() < Run.SPOOL else ("IN JUMP" if run.in_tunnel() else "ARRIVING")
	if run.fuel_left() == 0:
		return "NO FUEL"
	return "READY" if run.route != Run.NOWHERE else "IDLE"


## The drive bus: the cells it has to draw on, surging in a jump.
func _drive_load(run: Run) -> float:
	if run.jumping():
		return 0.9 + sin(time * 9.0) * 0.08
	return 0.25 * run.fuel_left() + sin(time * 1.3 + 2.0) * 0.015
