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
##   --derelict            dock the sample derelict at the departure too (Run)
##   --fuel=<n>            start the run with n cells loaded (Run)
##   --cuff                the local crew member holds their wrist cuff up (Player)
##   --at=<x>,<y>,<z>      the local crew member starts here (Player)
##   --belt=<kind>,...     what's on their belt, slot by slot (blank for empty), e.g.
##                         crowbar,,o2_canister (Player)
##   --hold=<kind>         and holds this: from the belt, or put there, or carried if it's big,
##                         e.g. crowbar (Player)
##   --o2=<s>, --health=<h>, --battery=<b>  their suit starts with this much O2 (seconds), health
##                         and lamp charge (0..1) (Player)
##   --take                a second in, they take whatever's under the crosshair (Player)
##   --use                 half a second later, they use what's in hand (LMB) (Player)
##   --throw=<s>           a second later, they let go of what's in hand as if Q were held that
##                         long: 0 sets it down (Player)
##   --no-gi               no screen-space bounced light or reflections, for comparing
##   --check-aim           stand in front of every terminal, check the crosshair finds it, quit
##   --move=<x>,<y>        the local crew member walks as if holding that move input, y-
##                         forward; with --sprint or --crouch (Player)
##   --operate=<screen>    step up to the terminal on that screen mesh, e.g. screen_survey (Player)


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
