extends CrtScreen
## TELEMETRY: a relay satellite's own console (GDD §8.1), still at work after its wave went silent.
## The link it holds and how long it's held it, the carrier's strength, the traffic it's passing
## on, when it last heard from anyone it knew; under it all, the spectrum it listens to, and a
## signal it can't place.

## Years the relay has been up, set by the satellite from its seed.
@export var years := 30.0

var _traffic := 0
var _bars: PackedFloat32Array = []


func _draw_screen() -> void:
	header("TELEMETRY")
	var up := years * 365.25 * 86400.0 + time
	var days := floori(up / 86400.0)
	text(1, 1.5, "LINK", DIM)
	text(12, 1.5, "ACTIVE", GREEN)
	text(1, 2.5, "UPTIME", DIM)
	text(12, 2.5, "%dY %03dD %02d:%02d:%02d" % [days / 365, days % 365, floori(up / 3600.0) % 24, floori(up / 60.0) % 60, floori(up) % 60], GREEN)
	text(1, 3.5, "CARRIER", DIM)
	var strength := 0.62 + 0.05 * sin(time * 0.7) + 0.02 * sin(time * 5.3)
	for i in 10:
		var cell := Rect2(Vector2(12 * CELL.x + 4 + i * 9, 3.5 * CELL.y + 5), Vector2(7, 8))
		if strength > i / 10.0:
			draw_rect(cell, GREEN)
		else:
			draw_rect(cell.grow(-0.5), DIM, false, 1.0)
	text(24, 3.5, "%d DBM" % roundi(-95 + strength * 40), GREEN)
	_traffic += randi_range(0, 3)
	text(1, 4.5, "RELAYED", DIM)
	text(12, 4.5, "%09d PKT" % (418_220_000 + _traffic), GREEN)
	text(1, 5.5, "LAST HEARD", DIM)
	text(12, 5.5, "WAVE 6, %dY AGO" % maxi(1, roundi(years) - 3), AMBER)
	# The spectrum it listens to: a band of bars that never sit still.
	if _bars.size() != 36:
		_bars.resize(36)
	var floor_y := size.y - 2.2 * CELL.y
	for i in _bars.size():
		var target := 0.15 + 0.1 * randf() + (0.7 if absi(i - 23) < 2 and blink(3.1) else 0.0)
		_bars[i] = lerpf(_bars[i], target, 0.25)
		var h := _bars[i] * 4.0 * CELL.y
		draw_rect(Rect2(Vector2(6 + i * 8.6, floor_y - h), Vector2(6, h)), AMBER if absi(i - 23) < 2 else DIM)
	draw_line(Vector2(4, floor_y + 1), Vector2(size.x - 4, floor_y + 1), DIM, 1.0)
	if blink(3.1):
		text(19, 7.0, "RX 7.4 GHZ  NO ORIGIN", AMBER)
	if blink(0.8):
		text(1, size.y / CELL.y - 1.4, "RELAYING", GREEN)
