extends SceneTree
## A scene smoke test (TECH §8): every scene in the game and every built model loads and
## instances without an error; then the world runs, and a jump is played through on its own (no
## crew, no network, time sped up): the scan charts the first row, the route is plotted, the lever
## is pulled, a cell is burnt, and the LANTERN arrives at a derelict, docked with its loot put out.
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
	_check(world.get_node("Encounter").get_child_count() == 1, "no derelict docked at the first row")
	_check(world.get_node("Items").get_child_count() >= 10, "the derelict's loot wasn't put out")
	Engine.time_scale = 1.0
	world.queue_free()
	await _frames(5)
	_check(errors.count == 0, "%d errors logged" % errors.count)
	print("test_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


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
