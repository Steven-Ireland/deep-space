extends CrtScreen
## HELM: the Nav Chart (GDD §6). The sector from its departure (bottom) to the boss (top): every
## system identified so far, by its type's mark, with the jump routes between them; the way the
## LANTERN came, bright; where it is, boxed and blinking. The systems a jump from here can reach
## always show: as "?" UNKNOWN until a survey core's been read at the core reader, by their marks
## once it has. Clicking one plots the route (blind or not), and the panel says whether the drive's
## ready to jump.

## The chart, in screen pixels: the departure's row at the bottom, the boss's at the top.
const CHART := Rect2(150, 20, 166, 216)
const BOTTOM := 212.0
const TOP := 42.0
## How near (pixels) the cursor must be to a node to pick it.
const PICK := 9.0

var _hover := Run.NOWHERE


func _gui_input(event: InputEvent) -> void:
	var run := Run.of(self)
	if run == null or run.map == null or not event is InputEventMouse:
		return
	_hover = _node_at(run, event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover in run.jumps() and _hover != run.route:
			if run.jumping():
				refuse()
			else:
				run.plot(_hover)
				confirm()


func _draw_screen() -> void:
	header("NAV CHART")
	var run := Run.of(self)
	if run == null or run.map == null:
		text(1, 2, "NO CHART DATA", DIM)
		return
	if cursor.x < 0:
		_hover = Run.NOWHERE
	_draw_chart(run)
	_draw_panel(run)


func _draw_panel(run: Run) -> void:
	var system := get_tree().get_first_node_in_group(&"star_system") as StarSystem
	text(1, 1.4, "SECTOR %d" % run.sector, AMBER)
	text(1, 2.6, "AT", DIM)
	text(4, 2.6, _label(run.here()), GREEN)
	text(4, 3.6, system.designation if system != null and system.designation != "" else "--------", GREEN)
	text(1, 5.2, "ROUTE", DIM)
	if run.jumping():
		text(1, 6.2, _label(_type(run, run.jump_to)), GREEN)
	elif run.route != Run.NOWHERE:
		text(1, 6.2, _label(_type(run, run.route)), WHITE)
	elif run.jumps().is_empty():
		text(1, 6.2, "END OF CHART", DIM)
	else:
		text(1, 6.2, "SELECT A JUMP", AMBER if blink() else DIM)
	if not run.scanned and not run.jumping() and not run.jumps().is_empty():
		Glyphs.draw(self, "JUMPS UNKNOWN" if not run.scanning() else "READING CORE", Vector2(1 * CELL.x + 4, 7.2 * CELL.y + 4),
				AMBER if run.scanning() else DIM)
	text(1, 7.8, "FUEL", DIM)
	for i in run.fuel.size():
		var cell := Rect2(Vector2(1 * CELL.x + 4 + i * 12, 8.8 * CELL.y + 4), Vector2(9, 9))
		if run.fuel[i]:
			draw_rect(cell, GREEN)
		else:
			draw_rect(cell.grow(-0.5), DIM, false, 1.0)
	text(6, 8.8, "%d / %d" % [run.fuel_left(), run.fuel.size()], GREEN if run.fuel_left() > 0 else RED)
	text(1, 10.4, "DRIVE", DIM)
	text(1, 11.4, _drive(run), _drive_colour(run))
	if _hover != Run.NOWHERE:
		text(1, 13.4, "> " + _label(_type(run, _hover)), WHITE)
		if _hover in run.jumps() and not run.jumping():
			text(1, 14.4, "CLICK TO PLOT", DIM)


func _drive(run: Run) -> String:
	if run.jumping():
		if run.jump_elapsed() < Run.SPOOL:
			return "SPOOLING"
		if run.in_tunnel():
			return "IN JUMP %d%%" % roundi(100.0 * run.jump_elapsed() / run.jump_time)
		return "ARRIVING"
	var blocker := run.jump_blocker()
	return "READY: PULL LEVER" if blocker == "" else blocker


func _drive_colour(run: Run) -> Color:
	if run.jumping():
		return AMBER
	var blocker := run.jump_blocker()
	if blocker == "":
		return GREEN if blink() else WHITE
	return RED if blocker == "NO FUEL" else DIM


func _draw_chart(run: Run) -> void:
	# A faint dotted rule for every row, charted or not: how far there is to go.
	for row in SectorMap.BOSS_ROW + 1:
		var y := _row_y(row)
		for x in range(int(CHART.position.x) + 4, int(CHART.end.x) - 2, 6):
			draw_rect(Rect2(x, y, 1, 1), Color(DIM, 0.7))
	var map := run.map
	var shown := _shown(run)
	# Routes between the systems shown: the way taken bright, the route plotted brighter.
	for from in shown:
		for to in map.next_of(from):
			if to not in shown:
				continue
			var taken := from in run.visited and to in run.visited
			var plotted := from == run.at and (to == run.route or to == run.jump_to)
			var colour := DIM
			if taken:
				colour = GREEN
			elif plotted:
				colour = WHITE if not run.jumping() or blink(0.4) else GREEN
			elif from == run.at:
				colour = Color(GREEN, 0.5)
			_route_line(_point(run, from), _point(run, to), colour)
	for node in shown:
		_draw_node(run, node)
	# From the boss, the way on to the next sector.
	if run.at == SectorMap.boss() and Run.NEXT_SECTOR in run.jumps():
		var colour := WHITE if run.route == Run.NEXT_SECTOR else GREEN
		_route_line(_point(run, SectorMap.boss()), _point(run, Run.NEXT_SECTOR), colour)
		_glyph(_point(run, Run.NEXT_SECTOR), "^", colour)


func _draw_node(run: Run, node: Vector2i) -> void:
	var at := _point(run, node)
	var type := run.map.type_of(node)
	var colour := DIM
	if node == run.at:
		colour = WHITE
	elif node in run.jumps():
		colour = GREEN
	elif node in run.visited:
		colour = Color(GREEN, 0.6)
	if type == &"boss":
		colour = RED if node != run.at else WHITE
	if not run.identified(node):
		colour = Color(GREEN, 0.75) if blink(1.2) or node == run.route else Color(GREEN, 0.45)
	_glyph(at, SectorMap.info(type).mark if run.identified(node) else "?", colour)
	var box := Rect2(at - Vector2(6, 7), Vector2(13, 14))
	if node == run.at and blink(0.8):
		draw_rect(box, WHITE, false, 1.0)
	if node == run.route or node == run.jump_to:
		draw_rect(box.grow(2), WHITE if blink(0.5) else GREEN, false, 1.0)
	if node == _hover:
		draw_rect(box.grow(1), AMBER, false, 1.0)


## A single character centred on `at`.
func _glyph(at: Vector2, mark: String, colour: Color) -> void:
	draw_string(FONT, at + Vector2(-3.5, 5), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


## A route between two nodes, stopping short of their marks.
func _route_line(a: Vector2, b: Vector2, colour: Color) -> void:
	var along := (b - a).normalized()
	draw_line(a + along * 6.0, b - along * 6.0, colour, 1.0)


func _row_y(row: int) -> float:
	return roundf(lerpf(BOTTOM, TOP, float(row) / SectorMap.BOSS_ROW))


## Where `node` is drawn on the chart.
func _point(run: Run, node: Vector2i) -> Vector2:
	if node == Run.NEXT_SECTOR:
		return Vector2(CHART.get_center().x, TOP - 20)
	var x: float = run.map.node(node).get("x", 0.5)
	return Vector2(roundf(CHART.position.x + 12 + x * (CHART.size.x - 24)), _row_y(node.y))


## What the chart shows: every system identified, and the jumps from here (identified or not).
func _shown(run: Run) -> Array[Vector2i]:
	var out := run.charted.duplicate()
	for node in run.jumps():
		if node != Run.NEXT_SECTOR and node not in out:
			out.append(node)
	return out


## The node shown (or the way on from the boss) under `pointer`, or NOWHERE.
func _node_at(run: Run, pointer: Vector2) -> Vector2i:
	var candidates := _shown(run)
	if run.at == SectorMap.boss():
		candidates.append(Run.NEXT_SECTOR)
	for node: Vector2i in candidates:
		if _point(run, node).distance_to(pointer) <= PICK:
			return node
	return Run.NOWHERE


func _type(run: Run, node: Vector2i) -> StringName:
	if node == Run.NEXT_SECTOR:
		return &"next"
	return run.map.type_of(node) if run.identified(node) else &"unknown"


func _label(type: StringName) -> String:
	if type == &"next":
		return "^ NEXT SECTOR"
	if type == &"unknown":
		return "? UNKNOWN"
	var info := SectorMap.info(type)
	return "%s %s" % [info.mark, info.name]
