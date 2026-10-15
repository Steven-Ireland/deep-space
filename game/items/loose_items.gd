class_name LooseItems
extends MultiplayerSpawner
## Everything loose in the world (GDD §9.4, TECH §2): Pickups, and dead crew's bodies (LooseBody).
## Only the host adds or removes one, and the spawner makes it on every peer, late joiners included. Crew report taking things and letting
## go of them; the host applies it. On a fresh start the host puts out what the station is stocked
## with (Deck.stock: markers in the "loot" group), and what each derelict is stocked with as it
## docks. Casting off, the host clears away whatever's loose outside the station: left behind.

const PICKUP := preload("res://game/items/pickup.tscn")
## How far round a body the things they had on them come to rest.
const SCATTER := 0.5

var _next_id := 1


static func of(node: Node) -> LooseItems:
	return node.get_tree().get_first_node_in_group(&"loose_items") as LooseItems


func _ready() -> void:
	add_to_group(&"loose_items")
	spawn_function = _make
	NetworkEvents.on_server_start.connect(_stock)


func _stock() -> void:
	stock(get_tree().root)


## Host: puts out what's stocked under `root`, once.
func stock(root: Node) -> void:
	for spot: Node3D in get_tree().get_nodes_in_group(&"loot"):
		if root == spot or root.is_ancestor_of(spot):
			spot.remove_from_group(&"loot")
			put(Items.make(spot.get_meta(&"kind")), spot.global_transform, Vector3.ZERO, spot.get_meta(&"racked", false))


## Everything loose in the world now (Pickups and LooseBodies; each has a `record`, a `centre()`
## and a `carry(moved)`).
func loose() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in get_node(spawn_path).get_children():
		if (child is Pickup or child is LooseBody) and not child.is_queued_for_deletion():
			out.append(child)
	return out


## Host: takes away everything loose that isn't aboard the station.
func clear_outside() -> void:
	var lantern := get_tree().get_first_node_in_group(&"lantern")
	if lantern == null:
		return
	for thing in loose():
		if lantern.room_at(thing.centre()) == "OUTSIDE":
			thing.queue_free()


## Host: puts `record` loose at `where`, moving at `velocity`; or `racked`, held where it is until
## someone takes it.
func put(record: Dictionary, where: Transform3D, velocity := Vector3.ZERO, racked := false) -> void:
	if record.is_empty():
		return
	spawn({"id": _next_id, "record": record, "at": where, "velocity": velocity, "racked": racked})
	_next_id += 1
	if Items.kind_of(record) == &"body":
		# A body coming down is heard (its bones aren't the host's to watch, as a Pickup's are).
		Noises.make(self, where.origin, &"clatter", null, 14.0)


## On a crew member's machine: they let go of `record` at `where`, moving at `velocity`.
func let_go(record: Dictionary, where: Transform3D, velocity: Vector3) -> void:
	_let_go.rpc_id(1, record, where, velocity)


@rpc("any_peer", "call_local", "reliable")
func _let_go(record: Dictionary, where: Transform3D, velocity: Vector3) -> void:
	if multiplayer.is_server():
		put(record, where, velocity)


## On the dying crew member's machine (GDD §11): they fell at `where`, moving at `velocity`; their
## body (`body`, a record) lies there and everything they had on them (`records`) drops round it.
func fall(body: Dictionary, records: Array[Dictionary], where: Transform3D, velocity: Vector3) -> void:
	_fall.rpc_id(1, body, records, where, velocity)


@rpc("any_peer", "call_local", "reliable")
func _fall(body: Dictionary, records: Array, where: Transform3D, velocity: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_empty():
		put(body, where, velocity)
	for i in records.size():
		var angle := TAU * i / maxf(records.size(), 1.0)
		var spot := where.origin + Vector3(cos(angle), 0.0, sin(angle)) * SCATTER + Vector3.UP * 0.6
		put(records[i], Transform3D(where.basis, spot), velocity * 0.5)


## Host: `peer` takes `pickup` (a Pickup or a LooseBody). It leaves the world and goes to their belt
## or hands; a second request for it finds it gone.
func take(pickup: Node3D, peer: int) -> void:
	var player := Player.of_peer(get_tree(), peer)
	if pickup.is_queued_for_deletion() or player == null:
		return
	pickup.queue_free()
	player.receive.rpc_id(peer, pickup.record)


## On a crew member's machine: their swing hit `pickup` at `where`, knocking it with `impulse`.
func whack(pickup: Pickup, impulse: Vector3, where: Vector3) -> void:
	_whack.rpc_id(1, pickup.name, impulse, where - pickup.global_position)


@rpc("any_peer", "call_local", "reliable")
func _whack(item: String, impulse: Vector3, offset: Vector3) -> void:
	var pickup := get_node(spawn_path).get_node_or_null(item) as Pickup
	if multiplayer.is_server() and pickup != null:
		pickup.apply_impulse(impulse, offset)
		Noises.make(self, pickup.global_position, &"hit")


## Host: `pickup` struck something, losing `speed` m/s: everyone hears it clatter, and so does
## anything listening, farther the harder and heavier (GDD §9.4).
func clatter(pickup: Pickup, speed: float) -> void:
	var heft := sqrt(Items.mass(Items.kind_of(pickup.record)))
	var reach := clampf(speed * heft * 1.2, 2.0, 18.0)
	Noises.make(pickup, pickup.global_position, &"clatter", null, reach)
	_clatter.rpc(pickup.name, clampf(speed / 6.0, 0.15, 1.0))


@rpc("authority", "call_local", "unreliable")
func _clatter(item: String, strength: float) -> void:
	var thing := get_node(spawn_path).get_node_or_null(item) as Node3D
	if thing != null and thing.get("record") != null:
		Sound.clatter(thing, Items.mass(Items.kind_of(thing.record)), strength)


func _make(data: Dictionary) -> Node:
	if Items.kind_of(data.record) == &"body":
		var body := LooseBody.new()
		body.name = "Item%d" % data.id
		body.record = data.record
		body.transform = data.at
		body.launch = data.velocity
		return body
	var pickup: Pickup = PICKUP.instantiate()
	pickup.name = "Item%d" % data.id
	pickup.record = data.record
	pickup.transform = data.at
	pickup.launch = data.velocity
	pickup.racked = data.get("racked", false)
	return pickup
