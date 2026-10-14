class_name JumpLever
extends Interactable
## The Jump Lever at the helm (GDD §5): held for two seconds, it jumps the station along the route
## plotted, if the drive has a cell loaded and the whole crew is aboard; otherwise the visor says
## why not (Run.jump_blocker). Its red T handle swings back toward whoever holds it, and stays back
## for everyone through the jump.

## Seconds it's held to engage.
const PULL := 2.0
## The handle's tilt (radians, toward the operator) at rest, pushed forward, and pulled.
const REST := -0.45
const PULLED := 0.42
## Where the handle pivots in the helm's slot, and the box crew aim at around it, in the helm's
## space (art/blender/bridge.py: helm, the lever pedestal).
const PIVOT := Vector3(1.15, 1.0, 0.0)
const GRIP := Vector3(1.15, 1.25, 0.0)
const GRIP_SIZE := Vector3(0.34, 0.42, 0.34)

var _pivot: Node3D
var _tilt := REST


## Fits the lever into `helm`: its handle on a pivot that can swing, and this to aim at.
static func fit(helm: Node3D) -> JumpLever:
	var lever := JumpLever.new()
	lever.name = "JumpLever"
	lever.verb = "JUMP"
	lever.hold = PULL
	lever.housing = helm
	lever.position = GRIP
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = GRIP_SIZE
	shape.shape = box
	lever.add_child(shape)
	helm.add_child(lever)
	var handle := helm.find_child("jump_lever", true, false) as Node3D
	if handle != null:
		lever._pivot = Node3D.new()
		lever._pivot.name = "LeverPivot"
		helm.add_child(lever._pivot)
		lever._pivot.position = PIVOT
		var at := handle.global_transform
		handle.get_parent().remove_child(handle)
		lever._pivot.add_child(handle)
		handle.global_transform = at
	lever.used.connect(func(_peer: int): Run.of(lever).jump())
	return lever


func prompt(_player: Player) -> String:
	var run := Run.of(self)
	var blocker := run.jump_blocker() if run != null else "NO DRIVE"
	return verb if blocker == "" else blocker


func usable_by(_player: Player) -> bool:
	var run := Run.of(self)
	return enabled and run != null and run.jump_blocker() == ""


func _process(delta: float) -> void:
	if _pivot == null:
		return
	var run := Run.of(self)
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var pull := 0.0
	if run != null and run.jumping():
		pull = 1.0
	elif player != null:
		pull = player.hold_progress(self)
	_tilt = move_toward(_tilt, lerpf(REST, PULLED, pull), delta * 4.0)
	_pivot.rotation.x = _tilt
