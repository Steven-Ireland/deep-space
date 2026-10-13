extends Node
## Development helpers driven from the command line (an autoload, `Dev`), so a build can be checked
## without anyone at the keyboard. Flags (after `--`):
##   --screenshot=<path>   save the window's image after `--frames` frames, then quit
##   --frames=<n>          frames to wait first (default 90)
##   --quit-after=<s>      quit after this many seconds


func _ready() -> void:
	var shot := Args.value("--screenshot", "")
	if shot != "":
		_screenshot(shot, int(Args.value("--frames", "90")))
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
