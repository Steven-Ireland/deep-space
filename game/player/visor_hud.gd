extends CanvasLayer
## The minimal visor HUD (GDD §10): drawn on the same pixel grid as the 3D (rendered small and
## shown big, unsmoothed), in one phosphor colour, and only when it has something to say. For
## now: a centre dot and a one-word verb when looking at something usable.

const COLOUR := Color(0.72, 0.95, 0.78, 0.85)

var player: Player

@onready var container: SubViewportContainer = $Screen
@onready var dot: ColorRect = %Dot
@onready var verb: Label = %Verb


func _ready() -> void:
	layer = 10
	container.stretch_shrink = Psx.block
	get_window().size_changed.connect(func(): container.stretch_shrink = Psx.block)
	dot.color = COLOUR
	verb.add_theme_color_override("font_color", COLOUR)


func _process(_delta: float) -> void:
	var target := player.aimed_at
	visible = player.operating == null
	dot.visible = target != null
	verb.visible = target != null
	if target != null:
		verb.text = target.verb
