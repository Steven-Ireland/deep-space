extends MultiplayerSpawner
## The crew aboard (GDD §11): the host spawns a Player for each peer as it joins, at the next free
## spawn point, and removes it when the peer leaves. Spawns carry their position as spawn data, so
## every peer creates the body in the same place.

const PLAYER := preload("res://game/player/player.tscn")

## Marker3Ds where crew appear, in order (the crew cabins).
@export var spawn_points: Array[Node3D] = []


func _ready() -> void:
	spawn_function = _make_player
	NetworkEvents.on_server_start.connect(func(): _spawn(1))
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server():
			_spawn(peer))
	NetworkEvents.on_peer_leave.connect(_despawn)


func _spawn(peer: int) -> void:
	var index := get_node(spawn_path).get_child_count()
	var at := Transform3D()
	if not spawn_points.is_empty():
		at = spawn_points[index % spawn_points.size()].global_transform
	spawn({"peer": peer, "origin": at.origin, "yaw": at.basis.get_euler().y})


func _despawn(peer: int) -> void:
	if not multiplayer.is_server():
		return
	var player := get_node(spawn_path).get_node_or_null(str(peer))
	if player != null:
		player.queue_free()


func _make_player(data: Dictionary) -> Node:
	print("Crew: peer %d aboard." % data.peer)
	var player := PLAYER.instantiate()
	player.name = str(data.peer)
	player.position = data.origin
	player.rotation.y = data.yaw
	return player
