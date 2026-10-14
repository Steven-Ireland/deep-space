class_name SectorMap
extends RefCounted
## A sector's chart (GDD §6): the LANTERN's point of departure, seven rows of star systems, then
## the boss. Two to four systems to a row, joined by jump routes that branch and merge but never
## cross, like Slay the Spire's map. Each system is a node with a weighted encounter type, under the
## GDD's rules: the first row is all derelicts, every route passes a gas giant or a depot before
## the boss, and no route runs three EVA nodes in a row. It all comes from the run's seed (TECH §6),
## so every peer charts the same sector; a map that still breaks a rule is redrawn.
##
## A node is named by `Vector2i(index, row)`: across the row (port to starboard on the chart), and
## the row, 0 the departure and BOSS_ROW the boss.

## Rows of systems between the departure (row 0) and the boss.
const ROWS := 7
const BOSS_ROW := ROWS + 1
## Systems to a row, fewest and most.
const WIDTH := Vector2i(2, 4)

## Encounter types: weight (percent), the chart's mark, the name; EVAs, and where fuel's to be had.
const TYPES := {
	&"derelict": {"weight": 30, "mark": "D", "name": "DERELICT"},
	&"colony": {"weight": 15, "mark": "C", "name": "COLONY", "eva": true},
	&"relay": {"weight": 15, "mark": "R", "name": "RELAY", "eva": true},
	&"signal": {"weight": 15, "mark": "?", "name": "SIGNAL"},
	&"anomaly": {"weight": 10, "mark": "A", "name": "ANOMALY"},
	&"gas_giant": {"weight": 10, "mark": "G", "name": "GAS GIANT", "refuel": true},
	&"depot": {"weight": 5, "mark": "$", "name": "DEPOT", "refuel": true},
}
## The two that aren't rolled: where the crossing starts, and the guardian at its end.
const FIXED := {
	&"start": {"mark": "+", "name": "DEPARTURE"},
	&"boss": {"mark": "B", "name": "GUARDIAN"},
}
## Redraws allowed before giving up on a map that breaks the rules (the repairs make it rare).
const ATTEMPTS := 16

var run_seed := 0
var sector := 1
## rows[row][index]: {"type", "x" (0..1 across the chart), "next" (indices into the next row),
## "seed" (its star system's)}.
var rows: Array = []


## Sector `sector` of the run seeded `run_seed`.
static func generate(seed_: int, sector_: int) -> SectorMap:
	var map: SectorMap
	for attempt in ATTEMPTS:
		map = SectorMap.new()
		map.run_seed = seed_
		map.sector = sector_
		map._build(Seeds.rng(seed_, "sector%d/map/%d" % [sector_, attempt]))
		var problems := map.problems()
		if problems.is_empty():
			return map
		push_warning("SectorMap: sector %d attempt %d redrawn: %s" % [sector_, attempt, ", ".join(problems)])
	push_error("SectorMap: no valid map for sector %d of run %d." % [sector_, seed_])
	return map


## A type's chart mark, name and the rest (TYPES, FIXED).
static func info(type: StringName) -> Dictionary:
	return TYPES.get(type, FIXED.get(type, {"mark": "-", "name": "UNKNOWN"}))


static func start() -> Vector2i:
	return Vector2i(0, 0)


static func boss() -> Vector2i:
	return Vector2i(0, BOSS_ROW)


func has(at: Vector2i) -> bool:
	return at.y >= 0 and at.y < rows.size() and at.x >= 0 and at.x < rows[at.y].size()


func node(at: Vector2i) -> Dictionary:
	return rows[at.y][at.x] if has(at) else {}


func type_of(at: Vector2i) -> StringName:
	return node(at).get("type", &"")


## The systems a jump from `at` can reach.
func next_of(at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in node(at).get("next", []):
		out.append(Vector2i(i, at.y + 1))
	return out


## The systems a jump reaches `at` from.
func before(at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if at.y <= 0:
		return out
	for i in rows[at.y - 1].size():
		if at.x in rows[at.y - 1][i].next:
			out.append(Vector2i(i, at.y - 1))
	return out


## Every node, row by row.
func nodes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row in rows.size():
		for i in rows[row].size():
			out.append(Vector2i(i, row))
	return out


## A hash of the whole chart, for checking peers drew the same one (TECH §2).
func checksum() -> int:
	return hash([run_seed, sector, rows])


## What's wrong with the map against the rules (GDD §6); empty when nothing is.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if rows.size() != BOSS_ROW + 1:
		return PackedStringArray(["%d rows" % rows.size()])
	if rows[0].size() != 1 or type_of(start()) != &"start" or rows[BOSS_ROW].size() != 1 or type_of(boss()) != &"boss":
		out.append("no single departure and boss")
	for row in range(1, BOSS_ROW):
		if rows[row].size() < WIDTH.x or rows[row].size() > WIDTH.y:
			out.append("row %d has %d systems" % [row, rows[row].size()])
	for at in nodes():
		if at.y == 1 and type_of(at) != &"derelict":
			out.append("%s in the first row" % type_of(at))
		if at.y < BOSS_ROW and next_of(at).is_empty():
			out.append("%s leads nowhere" % at)
		if at.y > 0 and before(at).is_empty():
			out.append("%s can't be reached" % at)
		for to in next_of(at):
			if not has(to):
				out.append("%s leads off the chart" % at)
	for row in BOSS_ROW:
		for i in rows[row].size():
			for k in range(i + 1, rows[row].size()):
				for j: int in rows[row][i].next:
					for l: int in rows[row][k].next:
						if j > l:
							out.append("routes cross between rows %d and %d" % [row, row + 1])
	if out.is_empty():
		if _dry_routes()[boss()] > 0:
			out.append("a route reaches the boss without fuel")
		var runs := _eva_runs()
		for at in nodes():
			if runs[at] >= 3:
				out.append("three EVAs in a row at %s" % at)
				break
	return out


func _build(generator: RandomNumberGenerator) -> void:
	rows = [[_node(&"start", 0.5, Vector2i(0, 0))]]
	for row in range(1, BOSS_ROW):
		var count := generator.randi_range(WIDTH.x, WIDTH.y)
		var nodes_ := []
		for i in count:
			var x := (i + 0.5 + generator.randf_range(-0.2, 0.2)) / count
			nodes_.append(_node(&"derelict" if row == 1 else Seeds.pick(generator, TYPES), x, Vector2i(i, row)))
		rows.append(nodes_)
	rows.append([_node(&"boss", 0.5, boss())])
	for row in BOSS_ROW:
		_link(generator, row)
	_break_eva_runs(generator)
	_place_fuel(generator)


func _node(type: StringName, x: float, at: Vector2i) -> Dictionary:
	return {"type": type, "x": x, "next": [], "seed": Seeds.of(run_seed, "sector%d/row%d/node%d" % [sector, at.y, at.x])}


## Joins row `row` to the next: from a single node, to all of them; otherwise a staircase from the
## first pair to the last, each step moving on along one row or both, so routes branch and merge
## but never cross, and every node is on one.
func _link(generator: RandomNumberGenerator, row: int) -> void:
	var a: int = rows[row].size()
	var b: int = rows[row + 1].size()
	if a == 1 or b == 1:
		for i in a:
			for j in b:
				rows[row][i].next.append(j)
		return
	var i := 0
	var j := 0
	rows[row][0].next.append(0)
	while i < a - 1 or j < b - 1:
		var roll := generator.randf()
		var step_i := j == b - 1 or (i < a - 1 and roll < 0.75)
		var step_j := i == a - 1 or (j < b - 1 and (roll < 0.5 or roll >= 0.75))
		if step_i:
			i += 1
		if step_j:
			j += 1
		rows[row][i].next.append(j)


## No route runs three EVAs: the third of any run becomes something else.
func _break_eva_runs(generator: RandomNumberGenerator) -> void:
	var ground := {}
	for type: StringName in TYPES:
		if not TYPES[type].get("eva", false):
			ground[type] = TYPES[type]
	for row in range(2, BOSS_ROW):
		for i in rows[row].size():
			if _eva_runs()[Vector2i(i, row)] >= 3:
				rows[row][i].type = Seeds.pick(generator, ground)


## Every route passes fuel before the boss: while one doesn't, a node on such routes becomes a gas
## giant or a depot, more likely the one most of them share and never in the first two rows.
func _place_fuel(generator: RandomNumberGenerator) -> void:
	var fuel := {}
	for type: StringName in TYPES:
		if TYPES[type].get("refuel", false):
			fuel[type] = TYPES[type]
	while _dry_routes()[boss()] > 0:
		var from := _dry_routes()
		var to := _dry_routes_back()
		var weights := {}
		var total := 0
		for at in nodes():
			if at.y >= 3 and at.y < BOSS_ROW and from[at] * to[at] > 0:
				weights[at] = from[at] * to[at]
				total += weights[at]
		if total == 0:
			return
		var roll := generator.randi_range(1, total)
		for at: Vector2i in weights:
			roll -= weights[at]
			if roll <= 0:
				rows[at.y][at.x].type = Seeds.pick(generator, fuel)
				break


## For each node, how many routes from the departure reach it without passing fuel (counting the
## node itself: none, if it has fuel).
func _dry_routes() -> Dictionary:
	var count := {}
	for at in nodes():
		if info(type_of(at)).get("refuel", false):
			count[at] = 0
		elif at.y == 0:
			count[at] = 1
		else:
			count[at] = 0
			for from in before(at):
				count[at] += count[from]
	return count


## For each node, how many routes from it reach the boss without passing fuel (counting itself).
func _dry_routes_back() -> Dictionary:
	var count := {}
	var all := nodes()
	all.reverse()
	for at in all:
		if info(type_of(at)).get("refuel", false):
			count[at] = 0
		elif at.y == BOSS_ROW:
			count[at] = 1
		else:
			count[at] = 0
			for to in next_of(at):
				count[at] += count[to]
	return count


## For each node, the longest run of EVAs ending at it along any route.
func _eva_runs() -> Dictionary:
	var run := {}
	for at in nodes():
		run[at] = 0
		if info(type_of(at)).get("eva", false):
			for from in before(at):
				run[at] = maxi(run[at], run[from])
			run[at] += 1
	return run
