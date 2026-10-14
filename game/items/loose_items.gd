class_name LooseItems
extends MultiplayerSpawner
## Everything loose in the world (GDD §9.4, TECH §2). Only the host adds or removes a Pickup, and
## the spawner makes it on every peer, late joiners included. Crew report taking things and letting
## go of them; the host applies it. On a fresh start the host puts out what the station and the
## derelict are stocked with (Deck.stock: markers in the "loot" group).

const PICKUP := preload("res://game/items/pickup.tscn")

var _next_id := 1


static func of(node: Node) -> LooseItems:
	return node.get_tree().get_first_node_in_group(&"loose_items") as LooseItems


func _ready() -> void:
	add_to_group(&"loose_items")
	spawn_function = _make
	NetworkEvents.on_server_start.connect(_stock)


func _stock() -> void:
	for spot: Node3D in get_tree().get_nodes_in_group(&"loot"):
		put(Items.make(spot.get_meta(&"kind")), spot.global_transform)


## Host: puts `record` loose at `where`, moving at `velocity`.
func put(record: Dictionary, where: Transform3D, velocity := Vector3.ZERO) -> void:
	if record.is_empty():
		return
	spawn({"id": _next_id, "record": record, "at": where, "velocity": velocity})
	_next_id += 1


## On a crew member's machine: they let go of `record` at `where`, moving at `velocity`.
func let_go(record: Dictionary, where: Transform3D, velocity: Vector3) -> void:
	_let_go.rpc_id(1, record, where, velocity)


@rpc("any_peer", "call_local", "reliable")
func _let_go(record: Dictionary, where: Transform3D, velocity: Vector3) -> void:
	if multiplayer.is_server():
		put(record, where, velocity)


## Host: `peer` takes `pickup`. It leaves the world and goes to their belt or hands; a second
## request for it finds it gone.
func take(pickup: Pickup, peer: int) -> void:
	if pickup.is_queued_for_deletion():
		return
	for player: Player in get_tree().get_nodes_in_group(&"crew"):
		if player.name == str(peer):
			pickup.queue_free()
			player.receive.rpc_id(peer, pickup.record)
			return


func _make(data: Dictionary) -> Node:
	var pickup: Pickup = PICKUP.instantiate()
	pickup.name = "Item%d" % data.id
	pickup.record = data.record
	pickup.transform = data.at
	pickup.launch = data.velocity
	return pickup
