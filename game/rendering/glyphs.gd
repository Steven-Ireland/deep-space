class_name Glyphs
## A 3x5 pixel font, for words too small for the VT323 face: the wrist cuff's screen, the visor's
## key caps, labels on small readouts. Each glyph is five rows of three bits, the left pixel the
## highest bit; drawn as whole pixels, so it stays crisp at any scale the screen's shown at.

const FONT := {
	"A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6], "E": [7, 4, 6, 4, 7],
	"F": [7, 4, 6, 4, 4], "G": [3, 4, 5, 5, 3], "H": [5, 5, 7, 5, 5], "I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2],
	"K": [5, 5, 6, 5, 5], "L": [4, 4, 4, 4, 7], "M": [5, 7, 7, 5, 5], "N": [6, 5, 5, 5, 5], "O": [2, 5, 5, 5, 2],
	"P": [6, 5, 6, 4, 4], "Q": [2, 5, 5, 6, 3], "R": [6, 5, 6, 5, 5], "S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2], "W": [5, 5, 7, 7, 5], "X": [5, 5, 2, 5, 5], "Y": [5, 5, 2, 2, 2],
	"Z": [7, 1, 2, 4, 7],
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [6, 1, 2, 4, 7], "3": [6, 1, 2, 1, 6], "4": [5, 5, 7, 1, 1],
	"5": [7, 4, 6, 1, 6], "6": [3, 4, 6, 5, 2], "7": [7, 1, 2, 2, 2], "8": [2, 5, 2, 5, 2], "9": [2, 5, 3, 1, 6],
	"-": [0, 0, 7, 0, 0], "%": [5, 1, 2, 4, 5], ":": [0, 2, 0, 2, 0], ".": [0, 0, 0, 0, 2], "/": [1, 1, 2, 4, 4],
	"+": [0, 2, 7, 2, 0], "!": [2, 2, 2, 0, 2], "?": [6, 1, 2, 0, 2], ">": [4, 2, 1, 2, 4], "<": [1, 2, 4, 2, 1],
	"#": [5, 7, 5, 7, 5], "*": [5, 2, 7, 2, 5], "(": [1, 2, 2, 2, 1], ")": [4, 2, 2, 2, 4], "'": [2, 2, 0, 0, 0],
	",": [0, 0, 0, 2, 4], "=": [0, 7, 0, 7, 0], "&": [2, 5, 2, 5, 3], " ": [0, 0, 0, 0, 0],
}
const WIDTH := 3
const HEIGHT := 5
## Pixels between letters.
const GAP := 1


## Draws `text` (upper-cased) on `canvas` with its top left at `at`, each font pixel `scale` across.
static func draw(canvas: CanvasItem, text: String, at: Vector2, colour: Color, scale := 1) -> void:
	var x := 0
	for c in text.to_upper():
		var rows: Array = FONT.get(c, FONT["?"])
		for y in HEIGHT:
			for bit in WIDTH:
				if int(rows[y]) & (4 >> bit):
					canvas.draw_rect(Rect2(at + Vector2(x + bit, y) * scale, Vector2(scale, scale)), colour)
		x += WIDTH + GAP


## How wide `text` is drawn, in pixels at `scale`.
static func width(text: String, scale := 1) -> int:
	return maxi(0, text.length() * (WIDTH + GAP) - GAP) * scale
