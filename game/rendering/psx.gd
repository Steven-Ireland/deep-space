extends CanvasLayer
## The PSX look for the whole window (an autoload, `Psx`): the 3D is drawn at about LINES pixels
## on the window's shorter side with nearest-neighbour scaling, then cut to 15-bit colour with a
## 4x4 dither by a full-window rect under all 2D. 2D (menus, the visor HUD) draws over it at the
## window's own resolution. The approach is ultraskeletal's psx-look.

## Pixels on the shorter side of the 3D image: near the PlayStation's 240, at 16:9.
const LINES := 270.0

const _DITHER_SHADER := preload("res://game/rendering/psx_dither.gdshader")

## Screen pixels per 3D pixel, for HUD elements that want to sit on the same grid.
var block := 1

var _material := ShaderMaterial.new()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	layer = -128 # under everything 2D
	_material.shader = _DITHER_SHADER
	var cover := ColorRect.new()
	cover.material = _material
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	get_window().size_changed.connect(_fit)
	_fit()


## Whether the 15-bit dither is applied (a player setting).
func set_dithered(dithered: bool) -> void:
	RenderingServer.global_shader_parameter_set(&"psx_dithered", dithered)


func _fit() -> void:
	var window := get_window()
	block = pixelate(window, window.size)
	_material.set_shader_parameter("pixel", block)


## Draws `viewport`'s 3D (`size` pixels) at about LINES on its shorter side, each pixel shown as a
## square block, unsmoothed. Returns how many screen pixels across each block is.
static func pixelate(viewport: Viewport, size: Vector2i) -> int:
	var b := maxi(1, roundi(minf(size.x, size.y) / LINES))
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	viewport.scaling_3d_scale = 1.0 / b
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	return b
