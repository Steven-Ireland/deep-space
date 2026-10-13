extends Node
## Development helpers driven from the command line (an autoload, `Dev`), so a build can be checked
## without anyone at the keyboard. Flags (after `--`):
##   --screenshot=<path>   save the window's image after `--frames` frames, then quit
##   --frames=<n>          frames to wait first (default 90)
##   --quit-after=<s>      quit after this many seconds
##   --flashlight          the local crew member starts with the flashlight on (Player)
##   --look=<yaw>,<pitch>  their starting view, in degrees (Player)
##   --view=<x>,<y>,<z>,<yaw>,<pitch>  look from a fixed camera instead (degrees), e.g. for shots
##   --system-seed=<n>     build this star system instead of the default (StarSystem)
##   --cuff                the local crew member holds their wrist cuff up (Player)
##   --operate=<screen>    step up to the terminal on that screen mesh, e.g. screen_survey (Player)


func _ready() -> void:
	var shot := Args.value("--screenshot", "")
	if shot != "":
		_screenshot(shot, int(Args.value("--frames", "90")))
	var view := Args.value("--view", "")
	if view != "":
		_fixed_camera(view.split_floats(","))
	var quit_after := float(Args.value("--quit-after", "0"))
	if quit_after > 0.0:
		get_tree().create_timer(quit_after).timeout.connect(get_tree().quit)


func _screenshot(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("Screenshot %s: %s" % [path, error_string(error)])
	get_tree().quit()


func _fixed_camera(v: PackedFloat64Array) -> void:
	var camera := Camera3D.new()
	camera.fov = 75
	camera.near = 0.05
	camera.position = Vector3(v[0], v[1], v[2])
	camera.rotation_degrees = Vector3(v[4] if v.size() > 4 else 0.0, v[3] if v.size() > 3 else 0.0, 0)
	add_child(camera)
	# Players make their own cameras current as they spawn; take over after them.
	for i in 30:
		await get_tree().process_frame
		camera.make_current()
