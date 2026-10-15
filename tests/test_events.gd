extends SceneTree
## The Prize's events (GDD §8.3, TECH §8). Across 300 seeds, as rolled: the quiet is common, every
## event turns up, and each is laid out by its rules: a security system's lockdown takes only doors
## (never the secure store's) and its sentries hang in the Prize's section; a depressurization's
## rooms hold the Prize, stay in its section and short of the entry, its doors start shut and its
## blowout is an outer wall of one of them; a structural breach's buckled door always leaves another
## way back; a nest lies on the way out of the Prize's room. Forced, each comes out as asked.
## Then each is set off in a derelict of its own, run on its own (no network), and played forward:
## the lockdown seals the doors (a crowbar FORCEs one) and wakes the sentries, and lifts; the wall
## blows out, the air goes and the doors round it seal; the door buckles under its heap; the nest
## bursts and a Crawler comes out.
##   tools/godot.sh --headless -s tests/test_events.gd

const SEED := 14256631
## The kit's grid and room height (Deck), as numbers: naming Deck here would reach autoloads.
const CELL := 4.0
const ROOM_HEIGHT := 3.0

var failures := 0
var errors := ErrorCount.new()


func _initialize() -> void:
	OS.add_logger(errors)
	_run.call_deferred()


var rooms: GDScript


func _run() -> void:
	rooms = load("res://game/encounter/room_layout.gd")
	_check_layouts()
	var world: Node = load("res://game/world.tscn").instantiate()
	root.add_child(world)
	await _frames(10)
	var player: Node = load("res://game/player/player.tscn").instantiate()
	player.name = "1"
	world.get_node("Players").add_child(player)
	await _frames(3)
	for kind: StringName in [&"security", &"vent", &"collapse", &"nest"]:
		await _play(world, player, kind)
	_finish()


# --- Laid out by its rules ---------------------------------------------------------------------

func _check_layouts() -> void:
	var layouts: GDScript = load("res://game/encounter/derelict_layout.gd")
	var counts := {}
	for i in 300:
		var seed := 9100 + i * 173
		var layout = layouts.generate(seed, 1 + i % 3)
		counts[layout.event] = counts.get(layout.event, 0) + 1
		_check_event(layout, seed)
	print("test_events: rolled %s" % counts)
	_check(counts.get(&"", 0) > 300 * 0.2 and counts.get(&"", 0) < 300 * 0.5, "the quiet's rolled %d times in 300" % counts.get(&"", 0))
	for kind: StringName in [&"security", &"vent", &"collapse", &"nest"]:
		_check(counts.get(kind, 0) >= 20, "%s rolled only %d times in 300" % [kind, counts.get(kind, 0)])
		var made := 0
		for i in 40:
			var seed := 31000 + i * 97
			var layout = layouts.generate(seed, 1, kind)
			made += 1 if layout.event == kind else 0
			_check_event(layout, seed)
		_check(made >= 36, "%s, forced, came out %d times in 40" % [kind, made])


func _check_event(layout, seed: int) -> void:
	var section: int = layout.section_of[layout.prize]
	match layout.event:
		&"security":
			for key: String in layout.lockdown:
				_check(layout.joins.has(key) and layout.joins[key].kind == "door", "seed %d: lockdown on %s, not a door" % [seed, key])
				_check(key != layout.vault_door, "seed %d: the lockdown takes the secure store's door" % seed)
			for at: Transform3D in layout.sentries:
				var room: int = layout.room_of.get(Vector3i(roundi(at.origin.x / CELL), 0, roundi(at.origin.z / CELL)), -1)
				_check(room >= 0 and layout.section_of[room] == section, "seed %d: a sentry hangs outside the Prize's section" % seed)
				_check(is_equal_approx(at.origin.y, ROOM_HEIGHT), "seed %d: a sentry isn't on the ceiling" % seed)
		&"vent":
			_check(layout.sealed.has(layout.prize), "seed %d: the Prize's room doesn't hold air" % seed)
			_check(not layout.sealed.has(0), "seed %d: the entry holds air" % seed)
			for index: int in layout.sealed:
				_check(layout.section_of[index] == section, "seed %d: room %d holds air outside the Prize's section" % [seed, index])
			for key: String in layout.vent_doors:
				_check(layout.joins[key].kind == "door" and layout.shut.has(key), "seed %d: way out %s isn't a shut door" % [seed, key])
			var outer := false
			for index: int in layout.sealed:
				for cell: Vector3i in layout.rooms[index].cells:
					for side: String in rooms.AROUND:
						if rooms.edge_key(cell, side) == layout.blowout and not layout.room_of.has(cell + rooms.SIDES[side]):
							outer = true
			_check(outer, "seed %d: the blowout %s isn't an outer wall of a room that holds air" % [seed, layout.blowout])
		&"collapse":
			if layout.buckle != "":
				_check(layout.joins[layout.buckle].kind == "door", "seed %d: the buckle isn't a door" % seed)
				_check(not layout.path(layout.prize, 0, layout.buckle).is_empty(), "seed %d: the buckled door leaves no way back" % seed)
			_check(layout.buckle != "" or not layout.falls.is_empty(), "seed %d: a structural breach with nothing in it" % seed)
		&"nest":
			var nests: Array = layout.props.filter(func(prop: Dictionary) -> bool: return prop.get("role", "") == "nest")
			_check(nests.size() == 1, "seed %d: %d nests" % [seed, nests.size()])
			if nests.size() == 1:
				var way: Array = layout.path(layout.prize, 0)
				_check(nests[0].room == layout.prize or (way.size() > 1 and nests[0].room == way[1]), "seed %d: the nest isn't by the Prize" % seed)


# --- Set off ---------------------------------------------------------------------------------

func _play(world: Node, player: Node, kind: StringName) -> void:
	var layouts: GDScript = load("res://game/encounter/derelict_layout.gd")
	var layout = null
	for i in 40:
		layout = layouts.generate(SEED + i, 1, kind)
		if layout.event == kind and (kind != &"collapse" or layout.buckle != "") and (kind != &"security" or not layout.lockdown.is_empty()):
			break
	var derelict = load("res://game/encounter/derelict.gd").make(layout, 1)
	derelict.name = "Derelict_%s" % kind
	derelict.position = Vector3(400, 0, 0) * (1 + [&"security", &"vent", &"collapse", &"nest"].find(kind))
	world.get_node("Encounter").add_child(derelict)
	await _frames(3)
	var event = derelict.event
	_check(event != null and event.kind == kind, "%s: no event, or the wrong one" % kind)
	if event == null:
		return
	match kind:
		&"vent":
			var room: int = layout.sealed[0]
			var cell: Vector3i = layout.rooms[room].cells[0]
			_check(derelict.zones[Vector2i(cell.x, cell.z)].pressurized, "vent: a room that should hold air doesn't")
	derelict.prize_taken(player)
	await _frames(2)
	_check(event.begun, "%s: taking the Prize set nothing off" % kind)
	match kind:
		&"security":
			event.elapsed = event.START + event.SENTRY_WAKE + 0.1
			await _frames(3)
			var door = derelict.doors[rooms.deck_key(layout.lockdown[0])]
			_check(door.sealed and door.seal_text == "LOCKDOWN" and not door.open, "security: a lockdown door isn't locked down")
			player._dev_hold(&"crowbar")
			_check(door.panels[0].prompt(player) == "FORCE" and door.panels[0].usable_by(player) and door.panels[0].hold_for(player) > 4.0,
					"security: a crowbar can't force a lockdown door (%s)" % door.panels[0].prompt(player))
			player._dev_hold(&"flare")
			_check(not door.panels[0].usable_by(player), "security: an empty hand forces a lockdown door")
			_check(event.sentries.all(func(sentry) -> bool: return sentry.live()), "security: a sentry didn't wake")
			_check(event.beacons.all(func(beacon) -> bool: return beacon.on), "security: a beacon didn't light")
			event.elapsed = event.START + event.LOCKDOWN_TIME + 0.1
			await _frames(3)
			_check(not door.sealed, "security: the lockdown didn't lift")
			_check(event.sentries.all(func(sentry) -> bool: return not sentry.live()), "security: a sentry didn't stand down")
		&"vent":
			event.elapsed = event.START + event.SEAL_WARNING + 0.1
			await _frames(3)
			var room: int = layout.sealed[0]
			var cell: Vector3i = layout.rooms[room].cells[0]
			_check(not derelict.zones[Vector2i(cell.x, cell.z)].pressurized, "vent: the air didn't go")
			_check(derelict.find_child("blowout_*", false, false) != null, "vent: the wall didn't blow out")
			for key: String in event._vent_doors():
				var door = derelict.doors[rooms.deck_key(key)]
				_check(door.sealed and door.seal_text == "VENTING" and not door.open, "vent: a door round it didn't seal")
			player.teleport(derelict.to_global(layout.centre_of(layout.rooms[layout.prize].cells[0])))
			await _frames(3)
			_check(event.gale_on(player).length() > 0.1, "vent: no gale in the Prize's room")
			event.elapsed = event.START + event.SEAL_WARNING + event.VENT_TIME + 0.1
			await _frames(3)
			for key: String in event._vent_doors():
				_check(not derelict.doors[rooms.deck_key(key)].sealed, "vent: a door stayed sealed after it")
			player.teleport(Vector3(0, 0, 0))
		&"collapse":
			event.elapsed = event.START + event.BUCKLE_AT + 0.1
			await _frames(3)
			var door = derelict.doors[rooms.deck_key(layout.buckle)]
			_check(door.sealed and door.seal_text == "BUCKLED", "collapse: the door didn't buckle")
			player._dev_hold(&"crowbar")
			_check(not door.panels[0].usable_by(player), "collapse: a crowbar forces a buckled door")
		&"nest":
			event.elapsed = event.START + event.NEST_SWELL + 0.1
			await _frames(3)
			_check(derelict.get_node_or_null("Creature%d" % event.HATCHLING) != null, "nest: nothing came out of it")


func _finish() -> void:
	await _frames(5)
	_check(errors.count == 0, "%d errors logged" % errors.count)
	print("test_events: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
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
