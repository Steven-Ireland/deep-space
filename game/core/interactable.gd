class_name Interactable
extends Area3D
## Something a crew member can use: a door panel, a lever, a terminal, an item to pick up. The
## player aiming at it sees `verb` on the visor; pressing interact reports the use to the host,
## which applies it (TECH §2: clients report their actions, the host applies them).
##
## Lives on the "interact" physics layer. Owners connect to `used`, which fires on the host only.

## Fires on the host when `peer` uses this.
signal used(peer: int)

## The one word the visor shows ("OPEN", "TAKE", "PULL").
@export var verb := "USE"
@export var enabled := true
## The solid this is set into, which doesn't hide it from a crew member's aim: a console's
## collision box encloses its own screens.
var housing: Node3D


## The physics layer interactables are on.
const LAYER := 1 << 2


func _init() -> void:
	collision_layer = LAYER # interact
	collision_mask = 0
	monitoring = false


## Called on the using player's machine.
func request_use() -> void:
	_use.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _use() -> void:
	if not multiplayer.is_server() or not enabled:
		return
	var peer := multiplayer.get_remote_sender_id()
	used.emit(1 if peer == 0 else peer)
