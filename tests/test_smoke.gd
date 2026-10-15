extends SceneTree
## A scene smoke test (TECH §8): every scene in the game and every built model loads and
## instances without an error; then the world runs, and a jump is played through on its own (no
## crew, no network, time sped up): a blind jump plots, a survey core read identifies the first row,
## a second isn't taken, the route is plotted, the lever
## is pulled, a cell is burnt, and the LANTERN arrives at a derelict waiting off the bow with its
## loot put out. The collar docks it; the airlock cycles out to it and back; undocking, the siren
## counts down while the airlock comes in, and the derelict drifts off vented, its loot aboard; it
## docks again. A crew member dies with a crowbar in hand: their body and the crowbar lie where they
## fell; the body goes in the med bay's pod and they're revived beside it; lost to a jump, they're
## cloned. Then, moved to a gas giant, the LANTERN skims the cell back. Last, an EVA: the EVA
## airlock cycles out to space and back; a relay satellite is set out off it, weightless and
## airless, its hatch opening by hand, its loot hanging where it was put; a crew member takes a
## harness from the rack, floats outside, hauls along the hull, flies on the jets and brakes, and
## stows the harness again.
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
	var jumps: Array = run.jumps()
	_check(not jumps.is_empty() and jumps.all(func(node: Vector2i) -> bool: return not run.identified(node)), "the next row starts identified")
	run.plot(jumps[-1])
	await _frames(2)
	_check(run.route == jumps[-1], "a blind jump couldn't be plotted")
	run._read_core(Transform3D())
	_check(run.core_seated and run.scanning(), "a survey core seated in the reader isn't being read")
	await _until(func() -> bool: return run.scanned, 3.0)
	_check(run.scanned, "the survey core was never read")
	_check(jumps.all(func(node: Vector2i) -> bool: return node in run.charted), "the survey core didn't identify the next row")
	run._read_core(Transform3D())
	_check(run.core_seated and not run.scanning(), "a second core was read in the same system")
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
	await _death(world)
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
	await _eva(world)
	Engine.time_scale = 1.0
	world.queue_free()
	await _frames(5)
	_check(errors.count == 0, "%d errors logged" % errors.count)
	print("test_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


## Docking, the airlock and undocking, played through (time sped up).
func _dock(world: Node) -> void:
	var collar: Node = world.get_node("Lantern/DockingCollar")
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
	_check(derelict.zones.values().all(func(zone: Area3D) -> bool: return not zone.pressurized), "the derelict holds air")
	_check(collar.outside_pressure() == 0.0, "the dock panel reads air beyond the collar")
	_check(lock.chamber.pressurized, "the airlock's chamber isn't the station's air before it cycles")
	lock.use(&"")
	await _frames(2)
	_check(not lock.chamber.pressurized, "crew in the airlock aren't on their suits the moment it cycles")
	await _until(func() -> bool: return lock.state == &"out", 3.0)
	await _frames(30)
	_check(lock.state == &"out" and collar.hatch.passable() and not lock.inner.open, "the airlock didn't cycle out")
	lock.use(&"in")
	await _until(func() -> bool: return lock.state == &"in", 3.0)
	await _frames(30)
	_check(lock.inner.passable() and not collar.hatch.open, "calling the airlock in from its inner hatch didn't bring it round")
	lock.use(&"in")
	await _frames(2)
	_check(not lock.inner_open, "the inner hatch doesn't shut by hand")
	lock.use(&"")
	await _until(func() -> bool: return lock.state == &"out", 3.0)
	var lantern: Node = world.get_node("Lantern")
	_check(lantern.room_at(Vector3(16, 1, 0)) == "COLLAR", "the tube isn't part of the collar")
	collar._lever_used()
	await _frames(2)
	_check(collar.stage == &"countdown" and lock.state == &"to_in", "undocking didn't sound the siren and bring the airlock in")
	_check(not lock.chamber.pressurized, "the airlock's chamber is the station's air before it's back in")
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


## Death, a revive from the body, and a clone (time sped up).
func _death(world: Node) -> void:
	var player: Node = load("res://game/player/player.tscn").instantiate()
	player.name = "1"
	world.get_node("Players").add_child(player)
	await _frames(3)
	player.teleport(Vector3(-8, 0, 0))
	player.belt[0] = {"kind": &"crowbar"}
	await _frames(3)
	player.die(&"suffocated")
	await _frames(20)
	_check(player.dead and player.belt[0].is_empty(), "the crew member didn't die, or kept their belt")
	var bodies: Array = world.get_node("Items").get_children().filter(func(item: Node) -> bool:
			return item.get("record") != null and item.record.get("kind") == &"body")
	_check(bodies.size() == 1 and bodies[0].record.peer == 1, "no body lies where they fell")
	var crowbar: Array = world.get_node("Items").get_children().filter(func(item: Node) -> bool:
			return item.get("record") != null and item.record.get("kind") == &"crowbar" and item.global_position.distance_to(Vector3(-8, 0, 0)) < 2.0)
	_check(crowbar.size() == 1, "what they had didn't drop by the body")
	var bay: Node = world.find_child("MedBay", true, false)
	_check(bay != null, "no med bay")
	if bay == null or bodies.is_empty():
		return
	var record: Dictionary = bodies[0].record
	bodies[0].queue_free()
	bay._insert(record, Transform3D())
	await _frames(2)
	_check(bay.job == &"revive", "the pod wouldn't take the body")
	await _until(func() -> bool: return not player.dead, 4.0)
	_check(not player.dead and player.health == 1.0, "the pod didn't revive them")
	_check(player.global_position.distance_to(bay.global_transform * bay.EXIT.origin) < 0.5, "they didn't step out beside the pod")
	player.die(&"lost")
	await _frames(5)
	_check(world.get_node("Items").get_children().filter(func(item: Node) -> bool:
			return item.get("record") != null and item.record.get("kind") == &"body").is_empty(), "the lost left a body")
	bay._clone(1)
	await _frames(2)
	_check(bay.job == &"clone", "the pod wouldn't clone them")
	await _until(func() -> bool: return not player.dead, 7.0)
	_check(not player.dead, "the pod didn't clone them")
	player.queue_free()
	await _frames(3)


## The EVA airlock, a satellite and a crew member weightless on the harness's jets (time sped up).
func _eva(world: Node) -> void:
	var lantern: Node = world.get_node("Lantern")
	var lock: Node = lantern.eva
	_check(lock != null and lock.prompt(&"") == "CYCLE", "the EVA airlock won't cycle out")
	lock.use(&"")
	await _frames(2)
	_check(not lock.chamber.pressurized, "crew in the EVA airlock aren't on their suits as it cycles")
	await _until(func() -> bool: return lock.state == &"out", 3.0)
	await _frames(30)
	_check(lock.state == &"out" and lock.outer.passable() and not lock.inner.open, "the EVA airlock didn't cycle out")
	# A satellite, set out at the departure.
	var run: Node = world.get_node("Run")
	run.dev_satellite = true
	run.at = SectorMap.start()
	run._broadcast()
	await _frames(10)
	var satellite = world.get_tree().get_first_node_in_group(&"satellite")
	_check(satellite != null, "no satellite set out")
	if satellite == null:
		return
	var hatch: Vector3 = satellite.entry.centre()
	_check(hatch.distance_to(lock.outer.centre()) > 18.0 and hatch.distance_to(lock.outer.centre()) < 40.0,
			"the satellite's hatch is %.1f m from the airlock's" % hatch.distance_to(lock.outer.centre()))
	var inside: Vector3 = satellite.global_transform * Vector3(0, 1.4, 0)
	_check(satellite.at(satellite.get_world_3d(), inside) == satellite, "the satellite's entry isn't part of it")
	var zone = load("res://game/core/zone.gd")
	_check(zone.weight_at(satellite.get_world_3d(), inside) == 0.0 and not zone.has_air(satellite.get_world_3d(), inside),
			"the satellite has weight or air")
	_check(zone.weight_at(satellite.get_world_3d(), Vector3(-30, 1, 0)) == 0.0, "space has weight")
	_check(zone.weight_at(satellite.get_world_3d(), Vector3(-8, 1, 0)) == 1.0, "the suit room is weightless")
	satellite._toggle_hatch()
	await _frames(40)
	_check(satellite.entry.passable(), "the satellite's hatch didn't open")
	var loot: Array = world.get_node("Items").get_children().filter(func(item: Node) -> bool:
			return item is RigidBody3D and satellite.at(item.get_world_3d(), item.global_position) == satellite)
	_check(loot.size() >= 6, "the satellite's loot wasn't put out (%d)" % loot.size())
	await _frames(10)
	_check(loot.all(func(item: RigidBody3D) -> bool: return item.gravity_scale == 0.0), "the satellite's loot isn't weightless")
	# A crew member: the harness, then outside.
	var player: Node = load("res://game/player/player.tscn").instantiate()
	player.name = "1"
	world.get_node("Players").add_child(player)
	await _frames(3)
	var rack: Node = world.find_child("HarnessRack", true, false)
	_check(rack != null and rack.prompt(player) == "DON", "no harness rack, or it won't give a harness")
	rack._on_used(1)
	await _frames(2)
	_check(player.harness and rack.left() == 3 and rack.prompt(player) == "STOW", "the rack didn't give them a harness")
	# Out beside the hull, clear of the hatch's opening: an arm's length from the plating.
	var out: Vector3 = lock.outer.centre() - lock.chamber.global_position
	out = Vector3(out.x, 0, out.z).normalized()
	player.teleport(lock.outer.centre() + out * 0.95 + Vector3.DOWN * 1.0 + Vector3.UP.cross(out) * 2.2)
	for i in 3:
		player._tick(1.0 / 30.0, i)
	_check(player.floating and player.in_vacuum, "outside the airlock they aren't weightless and on their suit")
	_check(player._gripping(), "beside the hull, they can't reach it")
	# Facing fore along the plating, they haul themselves aft along it, away from the opening.
	player.look = Vector2(0.0, 0.0)
	Input.action_press("move_back")
	for i in 20:
		player._tick(1.0 / 30.0, i)
	Input.action_release("move_back")
	_check(player.velocity.length() > 0.5 and player.rcs == player.RCS_FUEL, "hauling along the hull didn't move them, or burnt the jets")
	player.teleport(Vector3(-24, 1, 6))
	player.look = Vector2(PI / 2, 0.0)
	for i in 3:
		player._tick(1.0 / 30.0, i)
	_check(not player._gripping(), "out in space, they can still reach something")
	Input.action_press("move_forward")
	for i in 60:
		player._tick(1.0 / 30.0, i)
	Input.action_release("move_forward")
	var flying: Vector3 = player.velocity
	_check(flying.length() > 1.5 and flying.length() <= player.THRUST_TOP + 0.01 and flying.x < -1.0,
			"the jets didn't push them where they look (%s)" % flying)
	_check(player.rcs < player.RCS_FUEL - 1.5, "the jets burnt no propellant")
	for i in 30:
		player._tick(1.0 / 30.0, i)
	_check(player.velocity.distance_to(flying) < 0.05, "they didn't drift on as they were going")
	Input.action_press("sprint")
	for i in 120:
		player._tick(1.0 / 30.0, i)
	Input.action_release("sprint")
	_check(player.velocity.length() < 0.05, "the jets didn't brake them (%.2f m/s)" % player.velocity.length())
	player.teleport(Vector3(-8.6, 0, 0.6))
	for i in 3:
		player._tick(1.0 / 30.0, i)
	_check(not player.floating, "back aboard, they're still weightless")
	rack._on_used(1)
	await _frames(2)
	_check(not player.harness and rack.left() == 4, "the harness wasn't stowed")
	player.queue_free()
	await _frames(3)


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
