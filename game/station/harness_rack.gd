class_name HarnessRack
extends Interactable
## The EVA harness rack in the suit room (GDD §5, §8.1): four thruster harnesses hanging on its
## wall, each plugged into the propellant manifold. Hold interact to put one on (DON), fuelled
## full; back at the rack, hold to stow it (STOW), and it fills up again. With all four taken it's
## EMPTY. Wearing one, crew walk slowly (Player.HARNESS_SPEED) but can fly outside.
##
## Who wears one is each crew member's own (synced) state, so every peer works out how many still
## hang here, and shows that many on the rack. The host applies a DON or a STOW, refusing a DON
## when none is left.

const HARNESSES := 4
## Seconds interact is held to put one on or stow it.
const HOLD := 1.2

## The rack (rm_eva_rack): its harnesses are the meshes harness_1 .. harness_4.
var rack: Node3D
var _hanging: Array[Node3D] = []


## Fits the rack's controls to `prop` (an rm_eva_rack): the whole front of it, `size` wide and
## tall, centred at `centre` in its own space.
static func fit(prop: Node3D, centre: Vector3, size: Vector2) -> HarnessRack:
	var point := HarnessRack.new()
	point.name = "HarnessRack"
	point.rack = prop
	point.housing = prop
	point.hold = HOLD
	point.position = centre
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, 0.12)
	shape.shape = box
	point.add_child(shape)
	prop.add_child(point)
	point.used.connect(point._on_used)
	return point


func _ready() -> void:
	for i in HARNESSES:
		var mesh := rack.find_child("harness_%d" % (i + 1), true, false) as Node3D
		if mesh != null:
			_hanging.append(mesh)


## How many still hang on the rack: four, less those being worn.
func left() -> int:
	var worn := 0
	for crew: Player in get_tree().get_nodes_in_group(&"crew"):
		if crew.harness and not crew.dead:
			worn += 1
	return maxi(0, HARNESSES - worn)


func prompt(player: Player) -> String:
	if player.harness:
		return "STOW"
	return "DON" if left() > 0 else "EMPTY"


func usable_by(player: Player) -> bool:
	return enabled and (player.harness or left() > 0)


func _process(_delta: float) -> void:
	var count := left()
	for i in _hanging.size():
		_hanging[i].visible = i < count


## Host: `peer` held it: on with a harness, or off with theirs.
func _on_used(peer: int) -> void:
	var player := Player.of_peer(get_tree(), peer)
	if player == null:
		return
	if player.harness:
		player.equip.rpc_id(peer, false)
	elif left() > 0:
		player.equip.rpc_id(peer, true)
