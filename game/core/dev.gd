extends Node
## Development helpers driven from the command line (an autoload, `Dev`), so a build can be checked
## without anyone at the keyboard. Flags (after `--`):
##   --screenshot=<path>   save the window's image after `--frames` frames, then quit
##   --frames=<n>          frames to wait first (default 90)
##   --wait-crew=<n>       and before counting them, wait (up to 30 s) for n crew aboard, e.g. 2
##                         for a host waiting on a client (tools/pair.sh)
##   --shots=<n>           take n screenshots, <path>_0.png..., --shot-gap frames apart (default 4)
##   --quit-after=<s>      quit after this many seconds
##   --lamp                the local crew member starts with their helmet lamp on (Player)
##   --look=<yaw>,<pitch>  their starting view, in degrees (Player)
##   --view=<x>,<y>,<z>,<yaw>,<pitch>  look from a fixed camera instead (degrees), e.g. for shots
##   --system-seed=<n>     build this star system at the run's departure instead (Run)
##   --run-seed=<n>        the run's seed, instead of a fresh one (Run)
##   --scanned, --route, --jump  start with the departure scanned; and the first jump plotted; and
##                         jumping along it a second in (Run)
##   --derelict            dock a derelict at the departure too, grown from its seed (Run);
##                         =away, have it waiting out for the collar instead
##   --fuel=<n>            start the run with n cells loaded (Run)
##   --cuff                the local crew member holds their wrist cuff up (Player)
##   --at=<x>,<y>,<z>      the local crew member starts here (Player)
##   --belt=<kind>,...     what's on their belt, slot by slot (blank for empty), e.g.
##                         crowbar,,o2_canister (Player)
##   --hold=<kind>         and holds this: from the belt, or put there, or carried if it's big,
##                         e.g. crowbar (Player)
##   --o2=<s>, --health=<h>, --battery=<b>  their suit starts with this much O2 (seconds), health
##                         and lamp charge (0..1) (Player)
##   --die=<s>             they die that many seconds in (Player): a body, the station's cameras
##   --take                a second in, they take whatever's under the crosshair (Player)
##   --use                 half a second later, they use what's in hand (LMB) (Player)
##   --throw=<s>           a second later, they let go of what's in hand as if Q were held that
##                         long: 0 sets it down (Player)
##   --no-gi               no screen-space bounced light or reflections, for comparing
##   --check-aim           stand in front of every terminal, check the crosshair finds it, quit
##   --check-jump          press jump ten times, about a second apart; say how many took off, quit
##   --check-lever         a second and a half in, hold interact 2.4 s on what's under the
##                         crosshair (put them at the Jump Lever with --at and --look, and plot a
##                         route with --route); say whether the jump began, quit
##   --interact=<s>        a second and a half in (or --interact-at seconds), hold interact that
##                         long on what's under the crosshair (the dock panel's lever: 2.4), and
##                         carry on
##   --clone=<s>           (host) that many seconds in, the med bay clones the first dead crew member
##   --move=<x>,<y>        the local crew member walks as if holding that move input, y-
##                         forward; with --sprint or --crouch (Player)
##   --operate=<screen>    step up to the terminal on that screen mesh, e.g. screen_survey (Player)
##   --satellite           set the departure's own relay satellite out off the EVA airlock (Run)
##   --harness             the local crew member starts wearing the EVA harness (Player)
##   --brake               weightless, they hold the harness's jets against their drift (Player)
##   --tour=<dir>          (with --satellite) float through every room of the satellite, a shot
##                         four ways from each (<dir>/<room>_<way>.png), and quit
##   --provoke=<s>         (host) that many seconds in, every Crawler aboard hunts the crew member
##                         nearest it, as if it had heard them (Crawler)
##   --debug-creatures     every peer prints what each creature's doing and where, every second
##   --wound=<s>           that many seconds in, the local crew member takes a Crawler's blow (Player)
##   --check-eva[=<dir>]   (with --satellite) an EVA, played through with the keys: put on a harness
##                         at the rack, cycle the EVA airlock out, fly across to the satellite on the
##                         jets, stop, open its hatch, go in and float up through it; say how each
##                         step went, shots of it in <dir> if given, and quit


func _ready() -> void:
	var shot := Args.value("--screenshot", "")
	if shot != "":
		_screenshot(shot, int(Args.value("--frames", "90")))
	var view := Args.value("--view", "")
	if view != "":
		_fixed_camera(view.split_floats(","))
	if Args.flag("--no-gi"):
		_no_gi.call_deferred()
	if Args.flag("--check-aim"):
		_check_aim()
	if Args.flag("--check-jump"):
		_check_jump()
	if Args.flag("--check-lever"):
		_check_lever()
	if Args.flag("--check-eva"):
		_check_eva(Args.value("--check-eva", ""))
	if Args.flag("--tour"):
		_tour(Args.value("--tour", ""))
	if Args.flag("--clone"):
		_clone(float(Args.value("--clone", "3")))
	if Args.flag("--provoke"):
		_provoke(float(Args.value("--provoke", "2")))
	if Args.flag("--interact"):
		_interact(float(Args.value("--interact", "0.2")))
	var quit_after := float(Args.value("--quit-after", "0"))
	if quit_after > 0.0:
		get_tree().create_timer(quit_after).timeout.connect(get_tree().quit)


func _screenshot(path: String, frames: int) -> void:
	var crew := int(Args.value("--wait-crew", "0"))
	var deadline := Time.get_ticks_msec() + 30000
	while get_tree().get_nodes_in_group(&"crew").size() < crew and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if get_tree().get_nodes_in_group(&"crew").size() < crew:
		push_warning("Screenshot: only %d of %d crew aboard." % [get_tree().get_nodes_in_group(&"crew").size(), crew])
	for i in frames:
		await get_tree().process_frame
	var shots := int(Args.value("--shots", "1"))
	for shot in shots:
		if shot > 0:
			for i in int(Args.value("--shot-gap", "4")):
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var file := path if shots == 1 else "%s_%d.png" % [path.get_basename(), shot]
		var error := image.save_png(file)
		print("Screenshot %s: %s" % [file, error_string(error)])
	get_tree().quit()


func _fixed_camera(v: PackedFloat64Array) -> void:
	var camera := Camera3D.new()
	camera.fov = 75
	camera.near = 0.05
	camera.position = Vector3(v[0], v[1], v[2])
	camera.rotation_degrees = Vector3(v[4] if v.size() > 4 else 0.0, v[3] if v.size() > 3 else 0.0, 0)
	add_child(camera)
	if Args.flag("--lamp"):
		var lamp := SpotLight3D.new()
		lamp.position = Player.LAMP_OFFSET
		lamp.light_color = Color(1, 0.95, 0.86)
		lamp.light_energy = 6.0
		lamp.shadow_enabled = true
		lamp.spot_range = 18.0
		lamp.spot_angle = 22.0
		camera.add_child(lamp)
	# Players make their own cameras current as they spawn; take over after them.
	for i in 30:
		await get_tree().process_frame
		camera.make_current()


func _no_gi() -> void:
	for world: WorldEnvironment in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		world.environment.ssil_enabled = false
		world.environment.ssr_enabled = false


## Every terminal a crew member can step up to must be usable from where they'd stand: in front of
## it, looking at its screen. Prints each, then quits.
func _check_aim() -> void:
	await get_tree().create_timer(1.5).timeout
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var failed := 0
	for terminal: Terminal in get_tree().root.find_children("*", "Terminal", true, false):
		if not terminal.interactive or terminal.mesh == null:
			continue
		var centre := terminal.screen_centre()
		var out := terminal.screen_normal()
		out.y = 0.0
		player.teleport(Vector3(centre.x, 0.0, centre.z) + out.normalized() * 0.8)
		for i in 3:
			await get_tree().physics_frame
		var look := centre - player.head.global_position
		player.look = Vector2(atan2(-look.x, -look.z), asin(look.normalized().y))
		await get_tree().process_frame
		await get_tree().process_frame
		var aimed := player.aimed_at
		if Args.flag("--verbose-aim"):
			var from := player.camera.global_position
			var q := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * Player.REACH, Interactable.LAYER)
			q.collide_with_areas = true
			q.collide_with_bodies = false
			var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
			var solid := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * Player.REACH, 1, [player.get_rid()]))
			print("  player %s eye %s fwd %s centre %s area %s solid %s" % [player.global_position, from, -player.camera.global_basis.z, centre, hit.get("collider"), solid.get("collider")])
		var ok := aimed is Terminal.TerminalPanel and (aimed as Terminal.TerminalPanel).terminal == terminal
		if not ok:
			failed += 1
		print("Aim %s %s/%s" % ["ok    " if ok else "MISSED", terminal.get_parent().name, terminal.screen_mesh_name])
	print("Aim check: %d missed." % failed)
	get_tree().quit()


func _check_jump() -> void:
	await get_tree().create_timer(2.0).timeout
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var took_off := 0
	for i in 10:
		var floor_y := player.global_position.y
		_press("jump", true)
		await get_tree().process_frame
		_press("jump", false)
		var rose := false
		for f in 30:
			await get_tree().physics_frame
			rose = rose or player.global_position.y > floor_y + 0.05
		took_off += 1 if rose else 0
		await get_tree().create_timer(0.8).timeout
	print("Jump check: %d of 10 took off." % took_off)
	get_tree().quit()


func _check_lever() -> void:
	await get_tree().create_timer(1.5).timeout
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var run := Run.of(self)
	var aimed := player.aimed_at
	print("Lever check: aiming at %s (%s)." % [aimed.name if aimed != null else "nothing", aimed.prompt(player) if aimed != null else "-"])
	_press("interact", true)
	await get_tree().create_timer(2.4).timeout
	_press("interact", false)
	await get_tree().create_timer(0.5).timeout
	print("Lever check: %s." % ("the jump began" if run.jumping() else "no jump (%s)" % run.jump_blocker()))
	get_tree().quit()


## An EVA from the suit room to a satellite and into it, with the keys, as a crew member would
## (GDD §8.1, §9.1).
func _check_eva(shots: String) -> void:
	await get_tree().create_timer(2.0).timeout
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var lantern := get_tree().get_first_node_in_group(&"lantern")
	var satellite := get_tree().get_first_node_in_group(&"satellite") as Satellite
	if player == null or satellite == null:
		print("EVA check: no %s." % ("crew" if player == null else "satellite (pass --satellite)"))
		get_tree().quit()
		return
	var lock: Airlock = lantern.eva
	# 1. The harness, from the rack.
	player.teleport(Vector3(-8.6, 0, 0.6))
	_aim(player, Vector3(-8.75, 1.2, 1.9))
	await get_tree().create_timer(0.3).timeout
	print("EVA check: at the rack, aiming at %s (%s)." % [player.aimed_at.name if player.aimed_at else "nothing",
			player.aimed_at.prompt(player) if player.aimed_at else "-"])
	await _hold("interact", HarnessRack.HOLD + 0.3)
	await get_tree().create_timer(0.5).timeout
	print("EVA check: harness %s, RCS %.0f s." % ["on" if player.harness else "NOT ON", player.rcs])
	await _shot(shots, "1_rack")
	# 2. Through the airlock: in by its inner hatch, then the lever.
	player.teleport(Vector3(-12.6, 0, 1.0))
	_aim(player, Vector3(-13.63, 1.06, 1.6))
	await get_tree().create_timer(0.3).timeout
	print("EVA check: at the cycle lever, aiming at %s (%s)." % [player.aimed_at.name if player.aimed_at else "nothing",
			player.aimed_at.prompt(player) if player.aimed_at else "-"])
	await _hold("interact", Airlock.LEVER_HOLD + 0.3)
	var cycled := await _wait(func() -> bool: return lock.state == &"out" and lock.outer.passable(), 10.0)
	print("EVA check: airlock %s; in vacuum %s, O2 %.0f s." % ["out" if cycled else "STUCK (%s)" % lock.state, player.in_vacuum, player.o2])
	_aim(player, lock.outer.centre() + (lock.outer.centre() - lock.chamber.global_position) * 4.0)
	await get_tree().create_timer(0.3).timeout
	await _shot(shots, "1_airlock")
	# 3. Out, and across on the jets: steer for a point off the satellite's hatch.
	var hatch := satellite.entry.centre()
	var off := satellite.entry.global_transform.basis.z * (-1.0 if satellite.entry.inward > 0.0 else 1.0)
	var target := hatch + Vector3(off.x, 0, off.z).normalized() * 2.5
	var started := Time.get_ticks_msec()
	var fuel := player.rcs
	_press("move_forward", true)
	var top := 0.0
	var outside := false
	while Time.get_ticks_msec() - started < 40000:
		await get_tree().process_frame
		_aim(player, target)
		top = maxf(top, player.velocity.length())
		outside = outside or player.floating
		if outside and player.global_position.distance_to(target - Vector3.UP * Player.CHEST_HEIGHT) < 4.0 + player.velocity.length() * 1.6:
			break
	_press("move_forward", false)
	print("EVA check: out and across in %.1f s, weightless %s, top speed %.2f m/s, RCS used %.1f s." % [
			(Time.get_ticks_msec() - started) / 1000.0, outside, top, fuel - player.rcs])
	await _shot(shots, "2_crossing")
	_press("sprint", true)
	await _wait(func() -> bool: return player.velocity.length() < 0.05, 8.0)
	_press("sprint", false)
	print("EVA check: braked to %.2f m/s, %.1f m from the hatch, RCS left %.0f s." % [player.velocity.length(),
			(player.global_position + Vector3.UP * Player.CHEST_HEIGHT).distance_to(hatch), player.rcs])
	# 4. The satellite's hatch, by hand.
	_press("move_forward", true)
	await _wait(func() -> bool:
		_aim(player, hatch)
		return player.aimed_at is Satellite.HatchHandle, 15.0)
	_press("move_forward", false)
	_press("sprint", true)
	await get_tree().create_timer(1.0).timeout
	_press("sprint", false)
	print("EVA check: at the hatch, aiming at %s (%s)." % [player.aimed_at.name if player.aimed_at else "nothing",
			player.aimed_at.prompt(player) if player.aimed_at else "-"])
	await _hold("interact", 0.2)
	var opened := await _wait(func() -> bool: return satellite.entry.passable(), 4.0)
	print("EVA check: the satellite's hatch %s." % ("opened" if opened else "STAYED SHUT"))
	await _shot(shots, "3_hatch")
	# 5. In, and up through a hatchway if there's one over the entry.
	var inside := Deck.centre_of(Vector2i.ZERO) + Vector3.UP * 1.9
	inside = satellite.global_transform * inside
	_press("move_forward", true)
	var aboard := await _wait(func() -> bool:
		_aim(player, inside)
		return Satellite.at(player.get_world_3d(), player.global_position + Vector3.UP * Player.CHEST_HEIGHT) == satellite, 20.0)
	_press("move_forward", false)
	print("EVA check: aboard %s, weightless %s, %s." % [aboard, player.floating, Sound.place_of(player)])
	await get_tree().create_timer(1.5).timeout
	await _shot(shots, "4_inside")
	if Vector2i.ZERO in satellite.layout.hatchways(0):
		# Steer for the room over the entry, up through the hatchway in its ceiling.
		var above := satellite.global_transform * (Deck.centre_of(Vector2i.ZERO) + Vector3.UP * (RoomLayout.PITCH + 1.9))
		_press("move_forward", true)
		var up := await _wait(func() -> bool:
			_aim(player, above)
			return satellite.to_local(player.global_position).y > RoomLayout.PITCH - 0.5, 20.0)
		_press("move_forward", false)
		_press("sprint", true)
		await get_tree().create_timer(1.0).timeout
		_press("sprint", false)
		print("EVA check: up the hatchway to the level above %s." % ("ok" if up else "FAILED"))
		await _shot(shots, "5_hatchway")
	print("EVA check: done; O2 %.0f s, RCS %.0f s." % [player.o2, player.rcs])
	get_tree().quit()


## Shots of every room of the satellite: from beside each room's middle, looking along its four
## ways (the satellite's +X, +Z, -X, -Z) and a little down.
func _tour(dir: String) -> void:
	await get_tree().create_timer(2.0).timeout
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var satellite := get_tree().get_first_node_in_group(&"satellite") as Satellite
	if player == null or satellite == null or dir == "":
		print("Tour: needs --satellite and a folder.")
		get_tree().quit()
		return
	var layout := satellite.layout
	for index in layout.rooms.size():
		var room: Dictionary = layout.rooms[index]
		var middle := Vector3.ZERO
		for cell: Vector3i in room.cells:
			if cell.y == room.cells[0].y:
				middle += RoomLayout.centre_of(cell)
		middle /= room.cells.filter(func(cell: Vector3i) -> bool: return cell.y == room.cells[0].y).size()
		for way in 4:
			var along := Basis(Vector3.UP, way * PI / 2) * Vector3(1, 0, 0)
			var spot := satellite.global_transform * (middle - along * 1.2 + Vector3.UP * 0.2)
			player.teleport(spot)
			player.velocity = Vector3.ZERO
			_aim(player, satellite.global_transform * (middle + along * 3.0 + Vector3.UP * 1.0))
			for i in 8:
				await get_tree().process_frame
			await _shot(dir, "%02d_%s_%d" % [index, room.type, way])
	print("Tour: %d rooms." % layout.rooms.size())
	get_tree().quit()


## Turns `player` to look at `at`.
func _aim(player: Player, at: Vector3) -> void:
	var look := at - player.camera.global_position
	player.look = Vector2(atan2(-look.x, -look.z), asin(clampf(look.normalized().y, -0.99, 0.99)))


## Holds `action` for `seconds`.
func _hold(action: StringName, seconds: float) -> void:
	_press(action, true)
	await get_tree().create_timer(seconds).timeout
	_press(action, false)


## Waits until `done`, or `seconds`; whether it was done.
func _wait(done: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


## A screenshot `<dir>/<name>.png`, if shots are wanted.
func _shot(dir: String, name: String) -> void:
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _interact(seconds: float) -> void:
	await get_tree().create_timer(float(Args.value("--interact-at", "1.5"))).timeout
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var aimed := player.aimed_at if player != null else null
	print("Interact: %s (%s) for %.1f s." % [aimed.name if aimed != null else "nothing", aimed.prompt(player) if aimed != null else "-", seconds])
	_press("interact", true)
	await get_tree().create_timer(seconds).timeout
	_press("interact", false)


func _clone(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	for player: Player in get_tree().get_nodes_in_group(&"crew"):
		if player.dead:
			print("Clone: %s." % player.crew_name())
			MedBay.of(self).clone(int(str(player.name)))
			return
	print("Clone: nobody's dead.")


## Presses or lets go of an input action, as the keyboard would.
func _press(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## Host, `seconds` in: every Crawler aboard hunts the crew member nearest it.
func _provoke(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	for creature in get_tree().get_nodes_in_group(&"creatures"):
		if creature is Crawler:
			var nearest: Player = null
			for player: Player in get_tree().get_nodes_in_group(&"crew"):
				if nearest == null or player.global_position.distance_to(creature.global_position) < nearest.global_position.distance_to(creature.global_position):
					nearest = player
			if nearest != null:
				creature.provoke(nearest)
