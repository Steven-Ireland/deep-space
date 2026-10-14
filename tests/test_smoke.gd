extends SceneTree
## A scene smoke test (TECH §8): every scene in the game and every built model loads and
## instances without an error; then the world runs, and a jump is played through on its own (no
## crew, no network, time sped up): the scan charts the first row, the route is plotted, the lever
## is pulled, a cell is burnt, and the LANTERN arrives at a derelict waiting off the bow with its
## loot put out. The collar docks it; the airlock cycles out to it and back; undocking, the siren
## counts down while the airlock comes in, and the derelict drifts off vented, its loot aboard; it
## docks again. Then, moved to a gas giant, the LANTERN skims the cell back.
##   tools/godot.sh --headless -s tests/test_smoke.gd

var failures := 0
var errors := ErrorCount.new()


func _initialize() -> void:
	OS.add_logger(errors)
	_run.call_deferred()


func _run() -> void:
	var paths := _files("res://game", ".tscn") + _files("res://assets/models", ".glb")
	for path in paths:
		var scene := load(path) as PackedScene
		_check(scene != null, "%s doesn't load" % path)
		if scene != null:
			var node := scene.instantiate()
			_check(node != null, "%s doesn't instance" % path)
			if node != null:
				node.free()
	print("Loaded %d scenes and models." % paths.size())

	var world: Node = load("res://game/world.tscn").instantiate()
	root.add_child(world)
	await _frames(10)
	var run: Node = world.get_node("Run")
	run._begin()
	await _frames(5)
	_check(run.at == Vector2i(0, 0) and run.fuel_left() == 3, "the run doesn't start at its departure with three cells")
	Engine.time_scale = 8.0
	run.scan()
	await _until(func() -> bool: return run.scanned, 3.0)
	_check(run.scanned, "the scan never finished")
	var jumps: Array = run.jumps()
	_check(not jumps.is_empty() and jumps.all(func(node: Vector2i) -> bool: return node in run.charted), "the scan didn't chart the next row")
	run.plot(jumps[0])
	await _frames(2)
	_check(run.route == jumps[0], "the route wasn't plotted")
	_check(run.jump_blocker() == "", "the lever won't engage: %s" % run.jump_blocker())
	run.jump()
	await _frames(2)
	_check(run.jumping() and run.fuel_left() == 2, "the jump didn't start, or didn't burn a cell")
	await _until(func() -> bool: return run.in_tunnel(), 5.0)
	_check(world.get_node("System").planets.is_empty(), "the system wasn't cleared for hyperspace")
	await _until(func() -> bool: return not run.jumping(), 5.0)
	_check(run.at == jumps[0], "the LANTERN didn't arrive (at %s)" % run.at)
	await _frames(5)
	_check(world.get_node("Encounter").get_child_count() == 1, "no derelict alongside at the first row")
	_check(world.get_node("Items").get_child_count() >= 10, "the derelict's loot wasn't put out")
	await _dock(world)
	# At a gas giant (or a depot: every chart has one or the other), Engineering takes on a cell
	# into the empty bay, once.
	var stop: Vector2i = run.map.nodes().filter(func(node: Vector2i) -> bool:
			return SectorMap.info(run.map.type_of(node)).get("refuel", false)).front()
	run.at = stop
	run._broadcast()
	await _frames(5)
	if run.map.type_of(stop) == &"gas_giant":
		_check(world.get_node("System").planets[0].kind == "gas giant", "no gas giant ahead at a gas giant node")
	_check(world.get_node("Encounter").get_child_count() == 0, "the derelict wasn't cast off")
	_check(run.can_refuel(), "can't skim at a gas giant with a bay empty")
	run.refuel()
	await _until(func() -> bool: return run.refuelled, 5.0)
	_check(run.fuel_left() == 3 and not run.can_refuel(), "the skim didn't fill the bay, or can be done again")
	Engine.time_scale = 1.0
	world.queue_free()
	await _frames(5)
	_check(errors.count == 0, "%d errors logged" % errors.count)
	print("test_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


## Docking, the airlock and undocking, played through (time sped up).
func _dock(world: Node) -> void:
	var collar: Node = world.get_node("Lantern/Collar")
	var lock: Node = collar.airlock
	var derelict = collar.derelict # untyped: a test can't name Derelict (it reaches the autoloads)
	_check(derelict != null and collar.stage == &"away", "the derelict isn't waiting for the collar")
	if derelict == null:
		return
	var docked: Transform3D = collar._mouth * derelict.dock_point().affine_inverse()
	_check(derelict.global_position.distance_to(docked.origin) > 30.0, "the derelict waits right alongside")
	_check(not lock.prompt(&"") == "CYCLE", "the airlock would cycle out with nothing sealed to it")
	lock.use(&"")
	await _frames(2)
	_check(lock.state == &"in", "the airlock cycled out with nothing sealed to it")
	collar._lever_used()
	await _frames(2)
	_check(collar.stage == &"approach", "the lever didn't start docking")
	await _until(func() -> bool: return collar.stage == &"docked", 8.0)
	_check(collar.stage == &"docked", "it never docked (%s)" % collar.stage)
	_check(derelict.global_transform.is_equal_approx(docked), "the derelict didn't come to rest at the collar")
	await _frames(30)
	_check(derelict.entry.passable(), "the derelict's hatch didn't open")
	_check(collar.outside_pressure() == 1.0, "the dock panel doesn't read the derelict's air")
	lock.use(&"")
	await _until(func() -> bool: return lock.state == &"out", 3.0)
	await _frames(30)
	_check(lock.state == &"out" and collar.hatch.passable() and not lock.inner.open, "the airlock didn't cycle out")
	var lantern: Node = world.get_node("Lantern")
	_check(lantern.room_at(Vector3(16, 1, 0)) == "COLLAR", "the tube isn't part of the collar")
	collar._lever_used()
	await _frames(2)
	_check(collar.stage == &"countdown" and lock.state == &"to_in", "undocking didn't sound the siren and bring the airlock in")
	await _until(func() -> bool: return collar.stage == &"away", 8.0)
	_check(collar.stage == &"away" and lock.state == &"in", "it didn't undock (%s, the airlock %s)" % [collar.stage, lock.state])
	_check(derelict.vented and not derelict.entry_air(), "the derelict didn't vent as it went")
	_check(derelict.global_position.distance_to(docked.origin) > 30.0, "the derelict didn't drift back out")
	var aboard: Array = world.get_node("Items").get_children().filter(func(item: Node3D) -> bool:
			return derelict.at(item.get_world_3d(), item.global_position + Vector3.UP * 0.05) == derelict)
	_check(aboard.size() >= 8, "the derelict's loot didn't go with it (%d aboard)" % aboard.size())
	collar._lever_used()
	await _until(func() -> bool: return collar.stage == &"docked", 8.0)
	_check(collar.stage == &"docked" and collar.outside_pressure() == 0.0, "it didn't dock again, or reads air it's lost")


func _files(folder: String, extension: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(extension):
			out.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		out.append_array(_files(folder.path_join(sub), extension))
	return out


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## Waits until `done` is true, or `seconds` of real time pass.
func _until(done: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Counts every error and warning the engine logs while the test runs.
class ErrorCount extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			count += 1
