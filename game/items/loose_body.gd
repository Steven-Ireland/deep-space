class_name LooseBody
extends Node3D
## A dead crew member's body lying loose (GDD §11): a Ragdoll where they fell, or where a teammate
## let go of it. It's a loose thing like any other (LooseItems): crew aim at it and CARRY it in
## both hands, take it to the med bay's pod and revive whoever it was. Its record names them:
## {kind: &"body", peer, crew}.
##
## Every peer lets its own copy fall from the same start, so the limbs may lie a little differently
## for each; what matters is where it lies. The host sends that (`at`, its hips, ten times a second
## while it moves), and a copy that's strayed further than DRIFT from it is eased back over.

## How often where it lies goes out, how far a copy may stray, and how quickly it's eased back.
const SEND_EVERY := 0.1
const DRIFT := 0.3
const EASE := 3.0
## Below this, it's fallen off whatever it was on, out into space: gone.
const LOST_BELOW := -40.0

## The body: its kind and who it was. Set before it enters the tree.
var record: Dictionary
## How it's moving as it appears (it fell, or was thrown), set before it enters the tree.
var launch := Vector3.ZERO
## Where it lies (its hips), from the host.
var at := Vector3.ZERO

var ragdoll: Ragdoll
var handle: Pickup.Handle
var _sent := 0.0
var _settled := false


func _init() -> void:
	ragdoll = Ragdoll.new()
	ragdoll.name = "Ragdoll"
	add_child(ragdoll)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:at")
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	sync.replication_interval = SEND_EVERY
	sync.root_path = NodePath("..")
	add_child(sync)


func _ready() -> void:
	handle = Pickup.Handle.new()
	handle.name = "Handle"
	handle.pickup = self
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.6, 1.6) # a body lies 1.8 m long, any way round its middle
	reach.shape = box
	handle.add_child(reach)
	add_child(handle)
	handle.used.connect(func(peer: int): LooseItems.of(self).take(self, peer))
	ragdoll.go_limp(launch)
	if not multiplayer.is_server() and at != Vector3.ZERO:
		ragdoll.carry(Transform3D(Basis(), at - ragdoll.centre()))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_sent += delta
	var moving := ragdoll.moving()
	if (moving or not _settled) and _sent >= SEND_EVERY:
		_sent = 0.0
		at = ragdoll.centre()
		_settled = not moving
	if ragdoll.centre().y < LOST_BELOW:
		queue_free()


func _process(delta: float) -> void:
	if not multiplayer.is_server() and at != Vector3.ZERO:
		var off := at - ragdoll.centre()
		if off.length() > DRIFT:
			ragdoll.carry(Transform3D(Basis(), off.normalized() * (off.length() - DRIFT) * minf(1.0, delta * EASE)))
	handle.global_position = ragdoll.centre()


## Where it lies.
func centre() -> Vector3:
	return ragdoll.centre()


## Host: what it lies on has moved by `moved` (a derelict drifting): it goes along.
func carry(moved: Transform3D) -> void:
	ragdoll.carry(moved)
	_settled = false
