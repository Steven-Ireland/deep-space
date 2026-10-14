class_name TopUp
## Where crew top up their suit (GDD §5, §9): a verb across the front of a fitting, topping up
## whatever it gives (Player.top_up: "o2" at an O2 rack, "lamp" at the lamp charger). The LANTERN's
## suit room has both; a working relay's stowage has an O2 rack that still works.


## `verb` across `fitting` (`size`, at `centre` in its own space), topping up `what`.
static func fit(fitting: Node3D, verb: String, centre: Vector3, size: Vector2, what: String) -> Interactable:
	var point := Interactable.new()
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
