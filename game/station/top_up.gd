class_name TopUp
## Where crew top up their suit (GDD §5, §9): a verb across the front of a fitting, topping up
## whatever it gives (Player.top_up: "o2" at an O2 rack, "lamp" at the lamp charger). The LANTERN's
## suit room has both; a working relay's stowage has an O2 rack that still works; a derelict's work
## once their section has power again (`powered`, a Callable answering whether it has; NO POWER
## until then).


## `verb` across `fitting` (`size`, at `centre` in its own space), topping up `what`; only while
## `powered` says so, if it's given.
static func fit(fitting: Node3D, verb: String, centre: Vector3, size: Vector2, what: String, powered := Callable()) -> Interactable:
	var point := Point.new()
	point.powered = powered
	point.name = verb.capitalize()
	point.verb = verb
	point.housing = fitting
	point.position = centre
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, 0.06)
	shape.shape = box
	point.add_child(shape)
	fitting.add_child(point)
	point.used.connect(func(peer: int):
		var player := Player.of_peer(point.get_tree(), peer)
		if player != null:
			player.top_up.rpc_id(peer, what))
	return point


## The fitting's front: its verb, or NO POWER while it has none.
class Point extends Interactable:
	var powered: Callable

	func _live() -> bool:
		return not powered.is_valid() or powered.call()

	func prompt(_player: Player) -> String:
		return verb if _live() else "NO POWER"

	func usable_by(_player: Player) -> bool:
		return enabled and _live()
