extends SceneTree
## What lives in a derelict (GDD §12, TECH §8), run on its own: no network, time sped up, a crew
## member stood where the test wants them. Run 14256631's departure derelict, docked, holds a
## Crawler and a Hanger. The ways through its rooms are worked out and lead to both. The Crawler
## doesn't hear a crouched step from metres off, or anything aboard the LANTERN; a sprint sets it
## hunting, a quiet step sends it to listen, a flare's hiss lures it and holds it. Faced, it wounds;
## from behind, it grabs (dead); a shock prod's jolt drops it twitching; five crowbar blows kill it;
## a door shut on it crushes it. The Hanger catches whoever walks into its tendrils and draws them
## up; struck, it lets them go and draws up out of reach; left alone, it kills them.
##   tools/godot.sh --headless -s tests/test_creatures.gd

const SEED := 14256631

var failures := 0
var errors := ErrorCount.new()
var noises: GDScript


func _initialize() -> void:
	OS.add_logger(errors)
	_run.call_deferred()


func _run() -> void:
	noises = load("res://game/creatures/noises.gd")
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
	var derelict = world.get_node_or_null("Encounter/Derelict") # untyped: a test can't name Derelict
	_check(derelict != null, "no derelict docked")
	if derelict == null:
		_finish()
		return
	var living: Array = derelict.creatures()
	var crawler = living.filter(func(c: Node) -> bool: return c.kind() == &"crawler").front()
	var hanger = living.filter(func(c: Node) -> bool: return c.kind() == &"hanger").front()
	_check(crawler != null and hanger != null, "run %d's derelict should hold a Crawler and a Hanger" % SEED)
	if crawler == null or hanger == null:
		_finish()
		return
	Engine.time_scale = 4.0
	await _until(func() -> bool: return crawler._settled > 1.2, 3.0)
	var player: Node = load("res://game/player/player.tscn").instantiate()
	player.name = "1"
	world.get_node("Players").add_child(player)
	await _frames(3)
	player.teleport(Vector3(-3, 0, 0.5))

	# The ways through.
	var nav = derelict.nav()
	_check(nav.inside(crawler.position) and nav.inside(hanger.position), "the creatures aren't in the derelict's rooms")
	_check(nav.heard(Vector3.ZERO, crawler.position, 1000.0) < INF, "no way through from the entry to the Crawler")
	_check(not nav.path(crawler.position, crawler.position + Vector3(2, 0, 0)).is_empty() or
			not nav.path(crawler.position, crawler.position + Vector3(0, 0, 2)).is_empty(), "the Crawler can't move from its den")

	# Hearing.
	var near: Vector3 = crawler.global_position + derelict.global_basis * _open_near(nav, crawler.position, 3.0)
	noises.make(world, near, &"sneak", player)
	await _frames(2)
	_check(crawler.mode == &"wait", "a crouched step %.1f m off was heard (%s)" % [near.distance_to(crawler.global_position), crawler.mode])
	noises.make(world, Vector3(-3, 0, 0.5), &"sprint", player)
	await _frames(2)
	_check(crawler.mode == &"wait", "a sprint aboard the LANTERN was heard")
	var quiet: Vector3 = crawler.global_position + derelict.global_basis * _open_near(nav, crawler.position, 4.0)
	noises.make(world, quiet, &"step", player)
	await _frames(2)
	_check(crawler.mode == &"listen", "a step %.1f m off didn't send it to listen (%s)" % [quiet.distance_to(crawler.global_position), crawler.mode])
	crawler._rest()
	noises.make(world, near, &"sprint", player)
	await _frames(2)
	_check(crawler.mode == &"hunt" and crawler.prey == player, "a sprint close by didn't set it hunting (%s)" % crawler.mode)
	crawler._rest()

	# Lured by a flare's hiss, and held there: a quiet step doesn't draw it off.
	noises.make(world, quiet, &"flare")
	await _frames(2)
	_check(crawler.mode == &"listen" and crawler._lured, "a flare's hiss didn't lure it (%s)" % crawler.mode)
	noises.make(world, near, &"sneak", player)
	noises.make(world, crawler.global_position + derelict.global_basis * _open_near(nav, crawler.position, 3.5), &"step", player)
	await _frames(2)
	_check(crawler.mode == &"listen", "a quiet step drew it off the flare (%s)" % crawler.mode)
	crawler._rest()

	# Faced, it wounds; from behind, it grabs.
	var front: Vector3 = crawler.position + _open_near(nav, crawler.position, 1.0)
	player.teleport(derelict.to_global(front))
	_face(player, crawler.global_position)
	crawler._chase(player, front, 1.0)
	await _until(func() -> bool: return player.health < 1.0, 4.0)
	_check(is_equal_approx(player.health, 0.5) and not player.dead, "faced, its blow didn't take half their health (%.2f)" % player.health)
	_face(player, player.global_position * 2.0 - crawler.global_position)
	await _until(func() -> bool: return player.dead, 5.0)
	_check(player.dead and player.cause == &"grabbed", "from behind it didn't grab them (dead %s, %s)" % [player.dead, player.cause])
	await _frames(5)
	player.revive(Transform3D(Basis(), Vector3(-3, 0, 0.5)))
	crawler._rest()

	# A shock prod's jolt drops it; it gets up again.
	crawler._struck(&"shock_prod", true)
	await _frames(2)
	_check(crawler.mode == &"stunned" and crawler.clip == &"stunned", "the jolt didn't stun it (%s)" % crawler.mode)
	_check(crawler.jolts == 1 and crawler.health < 1.0, "the jolt wasn't counted, or didn't hurt it")
	await _until(func() -> bool: return crawler.mode != &"stunned", 3.0)
	_check(crawler.mode != &"stunned", "it never got up")

	# A door shut on it crushes it.
	var door = _open_door(derelict)
	_check(door != null, "no open door to shut on it")
	if door != null:
		crawler._rest()
		crawler.position = door.position
		door.open = false
		await _until(func() -> bool: return not crawler.alive(), 3.0)
		_check(not crawler.alive() and crawler.mode == &"dead", "the door shut on it didn't crush it (%s)" % crawler.mode)

	# Five blows of a crowbar kill another.
	var second = load("res://game/creatures/creature.gd").make(&"crawler", Transform3D(Basis(), crawler.position), 9)
	derelict.add_child(second)
	await _frames(3)
	for blow in 4:
		second._struck(&"crowbar", false)
	_check(second.alive(), "four crowbar blows killed it")
	second._struck(&"crowbar", false)
	_check(not second.alive() and second.clip == &"death", "five crowbar blows didn't kill it")

	# The Hanger: caught, struck free; caught again, and left.
	player.teleport(derelict.to_global(Vector3(hanger.position.x, 0.0, hanger.position.z) + Vector3(0.2, 0, 0)))
	await _until(func() -> bool: return player.seized, 2.0)
	_check(player.seized and hanger.mode == &"holding", "walking into its tendrils, they weren't caught (%s)" % hanger.mode)
	var floor_y: float = player.global_position.y
	for i in 30:
		player._tick(1.0 / 30.0, i)
	_check(player.global_position.y > floor_y + 0.3, "caught, they weren't drawn up")
	_check(player.health < 0.8 and player.health > 0.5, "held a second, their health isn't running out (%.2f)" % player.health)
	hanger._struck(&"crowbar", false)
	await _frames(2)
	_check(not player.seized and hanger.mode == &"recoil", "struck, it didn't let them go (%s)" % hanger.mode)
	for i in 45:
		player._tick(1.0 / 30.0, i)
	_check(player.global_position.y < floor_y + 0.1 and not player.seized, "let go, they didn't drop to the deck")
	await _until(func() -> bool: return hanger.mode == &"set", 6.0)
	_check(hanger.mode == &"set", "it never let its tendrils down again (%s)" % hanger.mode)
	await _until(func() -> bool: return player.seized, 2.0)
	_check(player.seized, "standing in its tendrils again, they weren't caught")
	for i in 120:
		player._tick(1.0 / 30.0, i)
	_check(player.dead and player.cause == &"hanger", "left in its tendrils, they didn't die of it (%s)" % player.cause)
	await _frames(10)
	_check(hanger.mode == &"sated", "fed, it didn't draw up (%s)" % hanger.mode)
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	await _frames(5)
	_check(errors.count == 0, "%d errors logged" % errors.count)
	print("test_creatures: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


## Where an open square's middle lies from `at` (the derelict's space): about `distance` metres
## off, reachable on foot, and as near as that to a sound.
func _open_near(nav, at: Vector3, distance: float) -> Vector3:
	for i in 32:
		var angle := TAU * i / 32.0
		var spot: Vector3 = at + Vector3(cos(angle), 0, sin(angle)) * distance
		var square: Vector2i = nav.nearest_open(spot)
		if nav.found(square):
			var point: Vector3 = nav.point_of(square)
			if absf(point.distance_to(at) - distance) < 0.4 and not nav.path(at, point).is_empty() and nav.heard(point, at, 100.0) < distance + 0.6:
				return point - at
	return Vector3(distance, 0, 0)


## Turns `player` to face `at` (world space).
func _face(player: Node, at: Vector3) -> void:
	var to: Vector3 = at - player.global_position
	player.look = Vector2(atan2(-to.x, -to.z), 0.0)


func _open_door(derelict) -> Node:
	for door in derelict.doors.values():
		if door.open:
			return door
	return null


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


## Counts every error the engine logs while the test runs.
class ErrorCount extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			count += 1
