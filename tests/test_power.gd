extends SceneTree
## A derelict's power (GDD §8.3, TECH §8), run on its own: no network, a crew member stood where the
## test wants them. Run 14256631's departure derelict, docked. Its rooms are grouped into sections,
## each all of a piece with a breaker box in one of its own rooms; some boxes hold a charged cell,
## some don't. Everything starts dead: no light, every door stuck as it is. A crowbar forces a dead
## door open, and nothing else does. Throwing a charged box's switch brings its section back: its
## lights come up, its doors work from their panels, its O2 rack refills; a dead box's switch does
## nothing until a cell is seated; a cell can't come out while the switch is thrown, and comes out
## into the crew member's hand once it's cut. Across 200 seeds every derelict's sections and
## breakers keep the rules.
##   tools/godot.sh --headless -s tests/test_power.gd

const SEED := 14256631

var failures := 0
var errors := ErrorCount.new()


func _initialize() -> void:
	OS.add_logger(errors)
	_run.call_deferred()


func _run() -> void:
	_check_layouts()
	var world: Node = load("res://game/world.tscn").instantiate()
	root.add_child(world)
	await _frames(10)
	var run: Node = world.get_node("Run")
	run._begin()
	run.seed = SEED
	run.map = SectorMap.generate(SEED, 1)
	run.dev_derelict = "docked"
	run._shown_sector = -1
	run._broadcast()
	await _frames(10)
	var derelict = world.get_node_or_null("Encounter/Derelict")
	_check(derelict != null and derelict.power != null, "no derelict docked, or no power in it")
	if derelict == null or derelict.power == null:
		_finish()
		return
	var power = derelict.power
	var layout = derelict.layout
	var player: Node = load("res://game/player/player.tscn").instantiate()
	player.name = "1"
	world.get_node("Players").add_child(player)
	await _frames(3)
	player.teleport(derelict.to_global(Vector3(0.5, 0, 0)))

	# Dead to begin with.
	for s in layout.sections:
		_check(not power.powered(s), "section %s starts powered" % s)
	_check(_lit(power) == 0, "%d lights burn in a dead derelict" % _lit(power))
	for door in derelict.doors.values():
		_check(not door.powered, "door %s has power in a dead derelict" % door.name)
	_check(power.breakers.size() == layout.sections and not power.breakers.has(null), "a section has no breaker box")

	# A dead shut door: nothing opens it but a crowbar.
	var dead_door = _shut_door(derelict, power, -1)
	_check(dead_door != null, "no shut door to try")
	if dead_door != null:
		var panel = dead_door.panels[0]
		_check(panel.prompt(player) == "NO POWER" and not panel.usable_by(player), "a dead door answers an empty hand (%s)" % panel.prompt(player))
		player._dev_hold(&"crowbar")
		_check(panel.prompt(player) == "PRY" and panel.usable_by(player) and panel.hold_for(player) > 2.0,
				"a dead door doesn't take a crowbar (%s)" % panel.prompt(player))
		dead_door._on_used(1)
		await _frames(30)
		_check(dead_door.open and dead_door.forced and dead_door.blocker.disabled, "the crowbar didn't force it open")

	# A charged box: its switch brings the section back.
	var charged := -1
	var empty := -1
	for s in layout.sections:
		if power.cells[s] and charged < 0:
			charged = s
		if not power.cells[s] and empty < 0:
			empty = s
	_check(charged >= 0 and empty >= 0, "no charged box, or no empty one")
	if charged >= 0:
		var door = _shut_door(derelict, power, charged)
		power._throw(charged)
		_check(power.powered(charged), "a charged box's switch didn't bring section %s back" % charged)
		await _until(func() -> bool: return _lit(power) > 0, 3.0)
		await _frames(60)
		_check(_lit(power) > 0, "section %s's lights never came up" % charged)
		if door != null:
			_check(door.powered and door.panels[0].prompt(player) == "OPEN", "a door in the powered section doesn't work (%s)" % door.panels[0].prompt(player))
		power._throw(charged)
		_check(not power.powered(charged), "cut, section %s still has power" % charged)
		await _frames(5)
		_check(_lit(power) == 0, "cut, its lights still burn")
		power._throw(charged)

	# An empty box: its switch does nothing until a cell's seated; the cell won't come out while
	# it's thrown, and comes out into the hand once it's cut.
	if empty >= 0:
		power._throw(empty)
		_check(not power.powered(empty), "an empty box's switch brought section %s back" % empty)
		power._insert(empty, Transform3D())
		_check(power.cells[empty] and power.powered(empty), "a cell seated with the switch thrown didn't bring it back")
		for i in player.belt.size():
			player.belt[i] = {}
		power._take(empty)
		_check(power.cells[empty], "the cell came out with the switch thrown")
		power._throw(empty)
		power._take(empty)
		await _frames(3)
		_check(not power.cells[empty], "the cell didn't come out once the switch was cut")
		_check(player.belt.any(func(record: Dictionary) -> bool: return record.get("kind", &"") == &"power_cell"),
				"the cell taken out isn't in the crew member's hand")

	# A fitting: an O2 rack refills only with its section's power.
	var rack = _fitting(derelict, "REFILL")
	_check(rack != null, "no O2 rack in the derelict")
	if rack != null:
		var section: int = power.section_at(rack.global_position)
		for s in layout.sections:
			if power.on[s]:
				power._throw(s)
		_check(not rack.usable_by(player) and rack.prompt(player) == "NO POWER", "a dead O2 rack refills")
		power.cells[section] = true
		power._throw(section)
		_check(rack.usable_by(player) and rack.prompt(player) == "REFILL", "a powered O2 rack doesn't refill")
	_finish()


## 200 seeds: every room in a section, each section one piece, its breaker in its own room on a
## wall, at least one box charged and one not; the same plan from the same seed.
func _check_layouts() -> void:
	var layouts: GDScript = load("res://game/encounter/derelict_layout.gd")
	var sizes := []
	for i in 200:
		var seed := 7000 + i * 131
		var layout = layouts.generate(seed, 1 + i % 3)
		var again = layouts.generate(seed, 1 + i % 3)
		_check(layout.checksum() == again.checksum(), "seed %d: power differs the second time" % seed)
		_check(layout.sections >= 3 and layout.sections <= 5, "seed %d: %d sections" % [seed, layout.sections])
		for index in layout.rooms.size():
			_check(layout.section_of[index] >= 0, "seed %d: room %d in no section" % [seed, index])
		for s in layout.sections:
			var members := range(layout.rooms.size()).filter(func(index: int) -> bool: return layout.section_of[index] == s)
			sizes.append(members.size())
			var reached := {members[0]: true}
			var queue := [members[0]]
			while not queue.is_empty():
				var at: int = queue.pop_front()
				for next: int in layout.links[at]:
					if layout.section_of[next] == s and not reached.has(next):
						reached[next] = true
						queue.append(next)
			_check(reached.size() == members.size(), "seed %d: section %d in pieces" % [seed, s])
		_check(layout.breakers.size() == layout.sections, "seed %d: %d breakers" % [seed, layout.breakers.size()])
		var charged := 0
		for box: Dictionary in layout.breakers:
			_check(layout.section_of[box.room] == box.section, "seed %d: a breaker outside its section" % seed)
			var cell := Vector3i(roundi(box.at.origin.x / 4.0), 0, roundi(box.at.origin.z / 4.0))
			_check(layout.room_of.get(cell, -1) == box.room, "seed %d: a breaker outside its room" % seed)
			charged += 1 if box.cell else 0
		_check(charged > 0 and charged < layout.breakers.size(), "seed %d: %d of %d boxes charged" % [seed, charged, layout.breakers.size()])
	sizes.sort()
	print("test_power: sections of %d to %d rooms, median %d" % [sizes.front(), sizes.back(), sizes[sizes.size() / 2]])


func _lit(power) -> int:
	var count := 0
	for section in power._lights:
		for each in power._lights[section]:
			if each[0].visible:
				count += 1
	return count


## A shut door, in `section` (or any, -1).
func _shut_door(derelict, power, section: int) -> Node:
	for key in derelict.doors:
		var door = derelict.doors[key]
		if door.open:
			continue
		var parts: PackedStringArray = key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if section < 0 or power.section_of_cell(cell) == section:
			return door
	return null


func _fitting(derelict, verb: String) -> Node:
	for node in derelict.find_children("*", "Area3D", true, false):
		if node.get("verb") == verb and node.has_method("_live"):
			return node
	return null


func _finish() -> void:
	await _frames(5)
	_check(errors.count == 0, "%d errors logged" % errors.count)
	print("test_power: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _until(done: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


class ErrorCount extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			count += 1
