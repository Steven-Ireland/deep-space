extends CrtScreen
## OPS: station cameras (GDD §10, §11). A tiny live feed from fixed cameras around the LANTERN,
## cycling every few seconds; dead crew will watch through these.

const PERIOD := 6.0

var _view: SubViewport
var _camera: Camera3D
var _index := -1


func _ready() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(96, 72)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_camera = Camera3D.new()
	_camera.fov = 80
	_view.add_child(_camera)
	add_child(_view)


func _draw_screen() -> void:
	var cameras := get_tree().get_nodes_in_group(&"station_camera")
	if cameras.is_empty():
		text(4, 6, "NO CAMERAS", DIM)
		return
	var index := int(time / PERIOD) % cameras.size()
	if index != _index:
		_index = index
		_view.world_3d = (cameras[index] as Node3D).get_world_3d()
	_camera.global_transform = (cameras[index] as Node3D).global_transform
	draw_texture_rect(_view.get_texture(), Rect2(Vector2.ZERO, size), false, Color(0.75, 1.0, 0.8))
	text(0.5, 0, "CAM %d" % (index + 1), WHITE)
	text(0.5, size.y / CELL.y - 1.2, String(cameras[index].name).to_upper(), WHITE)
	if blink(1.2):
		draw_circle(Vector2(size.x - 10, 9), 3, RED)
