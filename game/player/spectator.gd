class_name Spectator
extends CanvasLayer
## A dead crew member's view (GDD §11): their eyes move to the LANTERN's systems. They look through
## the station's cameras and their living teammates' helmet cams in turn (LMB or the wheel for the
## next, RMB for the last), with a camera feed's caption over it, and wait for the med bay. Made by
## the dead crew member's Player on their own machine, and gone when they're brought back.

const COLOUR := Color(0.72, 0.95, 0.78)
const RED := Color(1.0, 0.3, 0.2)
const FONT := preload("res://assets/fonts/VT323-Regular.ttf")
## A helmet cam rides just ahead of its wearer's eyes.
const HELMET := Vector3(0, 0.05, -0.18)

var player: Player
var camera: Camera3D
var _index := 0
var _time := 0.0
var _canvas: Control


func _ready() -> void:
	layer = 9
	camera = Camera3D.new()
	camera.name = "SpectatorCamera"
	camera.fov = 70.0
	camera.near = 0.05
	camera.top_level = true
	player.add_child(camera)
	camera.make_current()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)


func _exit_tree() -> void:
	if camera != null:
		camera.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use") or event.is_action_pressed("slot_next"):
		_index += 1
	elif event.is_action_pressed("alt_use") or event.is_action_pressed("slot_prev"):
		_index -= 1


## What can be looked through now: the station's cameras, then each living teammate's helmet cam.
## Each is [caption, the node whose transform it takes, an offset in that node's space].
func views() -> Array:
	var out := []
	var cameras := player.get_tree().get_nodes_in_group(&"station_camera")
	for i in cameras.size():
		out.append(["CAM %d  %s" % [i + 1, String(cameras[i].name).to_upper()], cameras[i], Vector3.ZERO])
	var crew := player.get_tree().get_nodes_in_group(&"crew")
	crew.sort_custom(func(a, b): return int(str(a.name)) < int(str(b.name)))
	for mate: Player in crew:
		if mate != player and not mate.dead:
			out.append(["%s  HELMET CAM" % mate.crew_name(), mate.head, HELMET])
	return out


func _process(delta: float) -> void:
	_time += delta
	var all := views()
	if all.is_empty():
		return
	var view: Array = all[posmod(_index, all.size())]
	var node := view[1] as Node3D
	camera.global_transform = node.global_transform * Transform3D(Basis(), view[2])
	_canvas.queue_redraw()


func _draw_overlay() -> void:
	var all := views()
	var size := _canvas.size
	var block := float(Psx.block)
	var font_size := int(16 * block)
	var line := font_size * 1.1
	if not all.is_empty():
		var caption: String = all[posmod(_index, all.size())][0]
		_canvas.draw_string(FONT, Vector2(12, 12) * block + Vector2(0, line), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOUR)
	if fmod(_time, 1.2) < 0.7:
		_canvas.draw_circle(Vector2(size.x - 18 * block, 18 * block), 3.0 * block, RED)
	var why: String = Player.CAUSES.get(player.cause, String(player.cause).to_upper())
	var status := "SIGNAL LOST  -  THE MED BAY CAN CLONE YOU" if player.cause == &"lost" \
			else "%s  -  BRING THE BODY TO THE MED BAY" % why
	_canvas.draw_string(FONT, Vector2(12 * block, size.y - 14 * block), status, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, RED if fmod(_time, 2.0) < 1.4 else COLOUR)
	var hint := "LMB / WHEEL: NEXT CAM"
	var width := FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.75)).x
	_canvas.draw_string(FONT, Vector2(size.x - 12 * block - width, 12 * block + line * 2.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.75), Color(COLOUR, 0.5))
