class_name Interactable
extends Area3D
## Something a crew member can use: a door panel, a lever, a terminal, an item to pick up. The
## player aiming at it sees its prompt (`verb`, unless it says otherwise) on the visor; pressing
## interact reports the use to the host, which applies it (TECH §2: clients report their actions,
## the host applies them).
##
## Lives on the "interact" physics layer. Owners connect to `used`, which fires on the host only.

## Fires on the host when `peer` uses this.
signal used(peer: int)

## The one word the visor shows ("OPEN", "TAKE", "PULL").
@export var verb := "USE"
@export var enabled := true
## Seconds interact must be held to use it (the Jump Lever), or 0 for a press.
@export var hold := 0.0
## The solid this is set into, which doesn't hide it from a crew member's aim: a console's
## collision box encloses its own screens.
var housing: Node3D


## The physics layer interactables are on.
const LAYER := 1 << 2


func _init() -> void:
	collision_layer = LAYER # interact
	collision_mask = 0
	monitoring = false


## What the visor shows `player` aiming at this.
func prompt(_player: Player) -> String:
	return verb


## Seconds `player` must hold interact on it to use it (0 for a press): its `hold`, unless it
## depends on who's using it (a dead door takes a crowbar's heaving).
func hold_for(_player: Player) -> float:
	return hold


## Whether `player` can use it now; when not, the visor shows its prompt dimmed, without its key.
func usable_by(_player: Player) -> bool:
	return enabled


## Called on the using player's machine.
func request_use() -> void:
	_use.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _use() -> void:
	if not multiplayer.is_server() or not enabled:
		return
	var peer := multiplayer.get_remote_sender_id()
	used.emit(1 if peer == 0 else peer)
