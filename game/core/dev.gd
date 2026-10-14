extends Node
## Development helpers driven from the command line (an autoload, `Dev`), so a build can be checked
## without anyone at the keyboard. Flags (after `--`):
##   --screenshot=<path>   save the window's image after `--frames` frames, then quit
##   --frames=<n>          frames to wait first (default 90)
##   --shots=<n>           take n screenshots, <path>_0.png..., --shot-gap frames apart (default 4)
##   --quit-after=<s>      quit after this many seconds
##   --flashlight          the local crew member starts with the flashlight on (Player)
##   --look=<yaw>,<pitch>  their starting view, in degrees (Player)
##   --view=<x>,<y>,<z>,<yaw>,<pitch>  look from a fixed camera instead (degrees), e.g. for shots
##   --system-seed=<n>     build this star system instead of the default (StarSystem)
##   --cuff                the local crew member holds their wrist cuff up (Player)
##   --at=<x>,<y>,<z>      the local crew member starts here (Player)
##   --hold=<kind>         and holds this from their belt, e.g. crowbar (Player)
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
	if Args.flag("--flashlight"):
		var torch := SpotLight3D.new()
		torch.position = Vector3(0.22, -0.2, 0)
		torch.light_color = Color(1, 0.95, 0.86)
		torch.light_energy = 6.0
		torch.shadow_enabled = true
		torch.spot_range = 18.0
		torch.spot_angle = 22.0
		camera.add_child(torch)
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
