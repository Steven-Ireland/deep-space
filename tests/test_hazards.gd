extends SceneTree
## A derelict's hazards (GDD §11, TECH §8). Across 300 seeds, laid out by their rules: coolant
## spills only past the entry's section, never in the entry, the Prize's room or the secure store;
## a leaking core only in a drive room; a faulty door only where no event needs it; a Hanger only
## in a room with no strobe lit, whose lights stay dead. Then in a
## derelict of its own, run on its own (no network): a dead spill is harmless and a live one jolts
## whoever stands in it; near the leaking core the dose climbs; a faulty door won't answer its
## panel, and crushes whoever's in its doorway as it slams.
##   tools/godot.sh --headless -s tests/test_hazards.gd

var failures := 0
var errors := ErrorCount.new()
var rooms: GDScript


func _initialize() -> void:
	OS.add_logger(errors)
	_run.call_deferred()


func _run() -> void:
	rooms = load("res://game/encounter/room_layout.gd")
	var layouts: GDScript = load("res://game/encounter/derelict_layout.gd")
	var hot := 0
	var drives := 0
	var spilt := 0
	var picked = null
	for i in 300:
		var seed := 5300 + i * 211
		var layout = layouts.generate(seed, 1 + i % 3)
		_check_layout(layout, seed)
		drives += 1 if layout._first(&"drive") >= 0 else 0
		hot += 1 if layout.hot_core else 0
		spilt += 1 if not layout.puddles.is_empty() else 0
		if picked == null and layout.hot_core and not layout.puddles.is_empty() and not layout.faulty.is_empty():
			picked = layout
	print("test_hazards: %d of %d drive rooms leak, %d of 300 derelicts have spills" % [hot, drives, spilt])
	_check(hot > drives * 0.3 and hot < drives * 0.7, "%d of %d drive cores leak" % [hot, drives])
	_check(spilt > 300 * 0.5, "only %d of 300 derelicts have a spill" % spilt)
	_check(picked != null, "no derelict with every hazard to try")
	if picked != null:
		await _play(picked)
	_finish()


func _check_layout(layout, seed: int) -> void:
	for spill: Dictionary in layout.puddles:
		var index: int = spill.room
		_check(index != 0 and index != layout.prize and index != layout.vault and layout.section_of[index] > 0,
				"seed %d: a spill in room %d" % [seed, index])
	if layout.hot_core:
		var drive: int = layout._first(&"drive")
		_check(drive >= 0 and layout.hot_at.distance_to(layout.frame_of(drive) * Vector3(4.3, 0, 4.3)) < 0.01,
				"seed %d: a leaking core outside the drive room" % seed)
	for creature: Dictionary in layout.creatures:
		if creature.kind == &"hanger":
			var at: Vector3 = creature.at.origin
			var index: int = layout.room_of.get(Vector3i(roundi(at.x / 4.0), 0, roundi(at.z / 4.0)), -1)
			_check(index in layout.dark and not layout.strobes.any(func(strobe: Dictionary) -> bool: return strobe.room == index),
					"seed %d: a Hanger hangs in a room that's lit, or can be" % seed)
	for key: String in layout.faulty:
		_check(layout.joins[key].kind == "door", "seed %d: a faulty %s, not a door" % [seed, key])
		_check(not key in layout.lockdown and not key in layout.vent_doors and key != layout.buckle and key != layout.vault_door,
				"seed %d: the faulty door is one an event needs" % seed)


func _play(layout) -> void:
	var world: Node = load("res://game/world.tscn").instantiate()
	root.add_child(world)
	await _frames(10)
	var player: Node = load("res://game/player/player.tscn").instantiate()
	player.name = "1"
	world.get_node("Players").add_child(player)
	await _frames(3)
	var derelict = load("res://game/encounter/derelict.gd").make(layout, 1)
	derelict.position = Vector3(400, 0, 0)
	world.get_node("Encounter").add_child(derelict)
	await _frames(3)
	var hazards = derelict.hazards
	var power = derelict.power
	_check(hazards != null and hazards.spills.size() == layout.puddles.size(), "the spills weren't fitted")
	if hazards == null or hazards.spills.is_empty():
		return

	# A dead spill: nothing.
	var spill: Dictionary = hazards.spills[0]
	player.teleport(spill.prop.global_position + Vector3.UP * 0.05)
	await _seconds(0.8)
	_check(is_equal_approx(player.health, 1.0), "a dead spill hurt them (%.2f)" % player.health)
	# Live: a jolt, and they know what it was if it kills them.
	power.cells[spill.section] = true
	power.on[spill.section] = true
	power._apply(spill.section, false)
	player.teleport(spill.prop.global_position + Vector3.UP * 0.05)
	await _seconds(0.5)
	_check(player.health < 1.0 or player.dead, "a live spill didn't jolt them")
	await _seconds(2.0)
	_check(player.dead and player.cause == &"electrocuted", "standing in a live spill, %s (%s)" % ["dead" if player.dead else "alive", player.cause])
	player.revive(Transform3D(Basis(), Vector3(0, 0, 0)))
	await _frames(3)

	# The leaking core: the dose climbs beside it (a second's worth, as the crew member's own
	# machine counts it each tick: no network here, so no ticks).
	player.teleport(derelict.to_global(layout.hot_at + Vector3(1.4, 0, 0)))
	await _frames(3)
	load("res://game/encounter/hazards.gd").irradiate(player, 1.0)
	_check(player.radiation > 0.005 and player.exposure > 0.005, "no dose beside the leaking core (%.4f)" % player.radiation)
	player.teleport(Vector3(0, 0, 0))
	await _frames(3)
	load("res://game/encounter/hazards.gd").irradiate(player, 1.0)
	_check(player.exposure == 0.0, "a dose far from the leaking core (%.4f)" % player.exposure)

	# The faulty door: with power it's nobody's to work, and it crushes whoever's in it.
	var door = derelict.doors[rooms.deck_key(layout.faulty[0])]
	_check(door.faulty, "the faulty door doesn't know it")
	for s in power.cells.size():
		power.cells[s] = true
		power.on[s] = true
	power._apply(-1, false)
	await _frames(2)
	_check(door.panels[0].prompt(player) == "FAULT" and not door.panels[0].usable_by(player), "a faulty door answers its panel")
	var before: float = player.health
	player.teleport(door.global_position)
	await _frames(3)
	hazards._crush(door)
	await _frames(3)
	_check(player.health < before, "the faulty door didn't crush them in its doorway")


func _finish() -> void:
	await _frames(5)
	_check(errors.count == 0, "%d errors logged" % errors.count)
	print("test_hazards: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


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
