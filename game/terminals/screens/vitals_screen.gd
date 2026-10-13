extends CrtScreen
## OPS: one crew member's vitals (GDD §5, §10): heartbeat trace, O2, where they are. One tile per
## crew slot; a vacant slot shows static.

@export var slot := 0

var _trace: PackedFloat32Array = []


func _draw_screen() -> void:
	var crew := get_tree().get_nodes_in_group(&"crew")
	crew.sort_custom(func(a, b): return int(str(a.name)) < int(str(b.name)))
	text(0.5, 0, "CREW %d" % (slot + 1), DIM)
	if slot >= crew.size():
		for i in 120:
			var p := Vector2(randf() * size.x, randf() * size.y)
			draw_rect(Rect2(p, Vector2(2, 1)), Color(DIM, randf()))
		text(size.x / CELL.x / 2 - 4, size.y / CELL.y / 2 - 0.5, "NO SIGNAL", DIM)
		return
	var player: Player = crew[slot]
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var bpm := 68.0 + speed * 18.0 + (25.0 if player.sprinting else 0.0)
	# ECG: a scrolling trace with a spike each beat.
	var beat := fmod(time * bpm / 60.0, 1.0)
	var spike := 0.0
	if beat < 0.04:
		spike = -1.0
	elif beat < 0.08:
		spike = 0.6
	elif beat > 0.3 and beat < 0.4:
		spike = -0.15
	_trace.append(spike + randf_range(-0.03, 0.03))
	if _trace.size() > int(size.x / 2):
		_trace.remove_at(0)
	var mid := size.y * 0.42
	for i in range(1, _trace.size()):
		draw_line(Vector2((i - 1) * 2, mid + _trace[i - 1] * 22), Vector2(i * 2, mid + _trace[i] * 22), GREEN, 1.0)
	text(0.5, 6.2, "%3d BPM" % int(bpm), GREEN)
	text(0.5, 7.2, "O2 100%", GREEN)
	var lantern := get_tree().get_first_node_in_group(&"lantern")
	var where := "ABOARD"
	if lantern != null and lantern.has_method("room_at"):
		where = lantern.room_at(player.global_position)
	text(0.5, 8.2, where, AMBER)
