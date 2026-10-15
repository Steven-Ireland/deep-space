extends CrtScreen
## The wrist cuff's communicator (GDD §10): suit-to-suit radio on one channel. Hold talk (V) and the
## cuff comes up to speak into, the channel keyed open for the whole crew with the old keying tones.
## Its little screen:
##   - the channel and a lamp: amber TX while it's sending, green RX while it hears someone, dark
##     while the channel's quiet
##   - a waterfall of what's on the channel: its spectrum (the Radio bus: Sound.radio_spectrum),
##     low notes left, high right, the newest line at the top, scrolling down and fading
##   - who's on it: TX, the crew member heard, or a dim CH 1 standing by; and their signal's bars
## The voices themselves are to come (TECH §2): for now the channel carries its hiss and its tones.

const BANDS := 44
const WATERFALL := Rect2i(2, 11, BANDS, 33)
## How fast the waterfall scrolls (lines a second).
const SCROLL := 24.0

var player: Player
var _image: Image
var _texture: ImageTexture
var _scroll := 0.0


func _ready() -> void:
	_image = Image.create(WATERFALL.size.x, WATERFALL.size.y, false, Image.FORMAT_RGB8)
	_image.fill(Color.BLACK)
	_texture = ImageTexture.create_from_image(_image)


func _process(delta: float) -> void:
	super._process(delta)
	_scroll += delta * SCROLL
	var lines := int(_scroll)
	if lines <= 0:
		return
	_scroll -= lines
	var on := not Sound.talking().is_empty()
	for i in mini(lines, WATERFALL.size.y):
		_line(Sound.radio_spectrum(BANDS) if on else PackedFloat32Array())
	_texture.update(_image)


## The waterfall moves down a line and takes `levels` as its newest, along the top.
func _line(levels: PackedFloat32Array) -> void:
	var w := _image.get_width()
	var h := _image.get_height()
	_image.blit_rect(_image, Rect2i(0, 0, w, h - 1), Vector2i(0, 1))
	for x in w:
		var level := levels[x] if x < levels.size() else 0.0
		# A faint speckle of the receiver's own noise, so a quiet channel still looks alive.
		level = maxf(level, randf() * 0.12)
		_image.set_pixel(x, 0, _phosphor(level))
	# What's older fades: each line a little dimmer than the one above it.
	for y in range(1, h):
		if y % 4 == 0:
			for x in w:
				_image.set_pixel(x, y, _image.get_pixel(x, y) * 0.94)


## A level on the phosphor's ramp: black, through the dim green and the bright, to white.
static func _phosphor(level: float) -> Color:
	if level < 0.4:
		return Color.BLACK.lerp(DIM, level / 0.4)
	if level < 0.8:
		return DIM.lerp(GREEN, (level - 0.4) / 0.4)
	return GREEN.lerp(WHITE, (level - 0.8) / 0.2)


func _draw_screen() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		return
	var w := size.x
	var on := Sound.talking()
	var sending := on.has(player)
	var hearing := not on.is_empty() and not sending
	Glyphs.draw(self, "CH1", Vector2(2, 3), DIM if on.is_empty() else GREEN)
	var lamp := AMBER if sending else (GREEN if hearing else Color(DIM, 0.6))
	draw_rect(Rect2(w - 6, 3, 4, 5), lamp if on.is_empty() or blink(0.5) else Color(lamp, 0.35))
	if not on.is_empty():
		Glyphs.draw(self, "TX" if sending else "RX", Vector2(w - 15, 3), lamp)
	draw_rect(Rect2(WATERFALL.position - Vector2i(1, 1), WATERFALL.size + Vector2i(2, 2)), DIM, false, 1.0)
	draw_texture(_texture, Vector2(WATERFALL.position))
	var who := "TX" if sending else (_short((on[0] as Player).crew_name()) if hearing else "STBY")
	Glyphs.draw(self, who, Vector2(2, size.y - 8), AMBER if sending else (GREEN if hearing else DIM))
	# Signal bars: full on the station's own channel, for now.
	for i in 3:
		var height := 2 + i * 2
		draw_rect(Rect2(w - 11 + i * 3, size.y - 3 - height, 2, height), GREEN if not on.is_empty() else Color(DIM, 0.6))


## A crew member's name short enough for the cuff: CREW 2 is C2.
static func _short(crew: String) -> String:
	return "C" + crew.get_slice(" ", 1)
