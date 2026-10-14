class_name MedBay
extends Node3D
## The med bay's pod (GDD §5, §11): where the dead come back. Carry a body in and INSERT it to
## revive whoever it was (REVIVE_TIME); or, from the pod's screen, CLONE any crew member who's dead,
## body or no body (left behind by a jump), which takes longer (and will cost more, once salvage
## can be spent). One at a time; whoever it is lies on the bed under the glass while it works, then
## steps out beside the pod.
##
## The host owns what it's doing and sends it to everyone on each change (and to each crew member
## who joins); its timer runs down on every peer and the host finishes it.

const REVIVE_TIME := 10.0
const CLONE_TIME := 30.0
## In the pod's space: where the one being brought back lies (on their back, head away from the
## console), where they step out (by the bed's foot, facing the door), and the box crew aim at over
## the bed.
const LYING := Transform3D(Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)), Vector3(0.9, 0.8, 0))
const EXIT := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-0.8, 0, 1.4))
const SLOT_AT := Vector3(0, 0.85, 0)
const SLOT_SIZE := Vector3(2.0, 0.5, 0.8)

const LAMP_GREEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_AMBER := preload("res://assets/materials/lk_lamp_shut.tres")

## What it's doing: &"" nothing, &"revive" or &"clone"; who it's bringing back (their peer); and
## the seconds left.
var job := &""
var who := 0
var left := 0.0

var _pod: Node3D
var _lying: Ragdoll
var _lamp: MeshInstance3D
var _time := 0.0


static func of(node: Node) -> MedBay:
	return node.get_tree().get_first_node_in_group(&"med_bay") as MedBay


## The med bay, run from `pod` (an rm_med_pod).
static func make(pod: Node3D) -> MedBay:
	var bay := MedBay.new()
	bay.name = "MedBay"
	bay._pod = pod
	pod.add_child(bay)
	return bay


func _ready() -> void:
	add_to_group(&"med_bay")
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server():
			_state.rpc_id(peer, _pack()))
	_lamp = _pod.find_child("pod_lamp", true, false) as MeshInstance3D
	_lying = Ragdoll.new()
	_lying.name = "Lying"
	_lying.transform = LYING
	_lying.visible = false
	for bone in _lying.bones:
		bone.collision_layer = 0
		bone.collision_mask = 0
	add_child(_lying)
	var slot := Slot.new()
	slot.name = "Slot"
	slot.bay = self
	slot.housing = _pod
	slot.position = SLOT_AT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SLOT_SIZE
	shape.shape = box
	slot.add_child(shape)
	add_child(slot)


func _process(delta: float) -> void:
	_time += delta
	left = maxf(0.0, left - delta)
	if multiplayer.is_server() and job != &"" and left <= 0.0:
		_finish()
	# Whoever it is lies under the glass; a clone flickers into being, more solid as it goes.
	var working := job != &""
	var solid := 1.0 - left / CLONE_TIME if job == &"clone" else 1.0
	_lying.visible = working and (job == &"revive" or fmod(_time * 7.3, 1.0) < solid)
	if _lamp != null:
		_lamp.material_override = LAMP_AMBER if working else LAMP_GREEN
		_lamp.visible = not working or fmod(_time, 0.8) < 0.5


## Whether crew member `peer` is dead and here to bring back.
func can_bring_back(peer: int) -> bool:
	var player := Player.of_peer(get_tree(), peer)
	return player != null and player.dead


## How far through the job it is, 0..1.
func progress() -> float:
	var whole := REVIVE_TIME if job == &"revive" else CLONE_TIME
	return 1.0 - left / whole if job != &"" else 0.0


## The pod's screen: clone crew member `peer`.
func clone(peer: int) -> void:
	_clone.rpc_id(1, peer)


@rpc("any_peer", "call_local", "reliable")
func _clone(peer: int) -> void:
	if multiplayer.is_server() and job == &"" and can_bring_back(peer):
		_begin(&"clone", peer, CLONE_TIME)


## On the carrier's machine: they've put the body they carried (`record`) in the pod. If it can't
## take it (busy, or whoever it was isn't dead), the host lays it down at `spill`.
func insert(record: Dictionary, spill: Transform3D) -> void:
	_insert.rpc_id(1, record, spill)


@rpc("any_peer", "call_local", "reliable")
func _insert(record: Dictionary, spill: Transform3D) -> void:
	if not multiplayer.is_server():
		return
	var peer: int = record.get("peer", 0)
	if job == &"" and can_bring_back(peer):
		_begin(&"revive", peer, REVIVE_TIME)
	else:
		LooseItems.of(self).put(record, spill)


func _begin(what: StringName, peer: int, seconds: float) -> void:
	job = what
	who = peer
	left = seconds
	print("Med bay: %s %s." % ["reviving" if what == &"revive" else "cloning", Player.of_peer(get_tree(), peer).crew_name()])
	_broadcast()


## Host: done; they step out beside the pod.
func _finish() -> void:
	var player := Player.of_peer(get_tree(), who)
	if player != null and player.dead:
		player.revive.rpc_id(who, global_transform * EXIT)
	job = &""
	who = 0
	_broadcast()


## The bed: INSERT the body you're carrying.
class Slot extends Interactable:
	var bay: MedBay

	func prompt(player: Player) -> String:
		if bay.job != &"":
			return "BUSY"
		if Items.kind_of(player.carrying) != &"body":
			return "EMPTY"
		return "INSERT" if bay.can_bring_back(player.carrying.get("peer", 0)) else "NO MATCH"

	func usable_by(player: Player) -> bool:
		return enabled and prompt(player) == "INSERT"

	## On the carrier's machine: the body leaves their arms for the pod.
	func request_use() -> void:
		var player := get_tree().get_first_node_in_group(&"local_player") as Player
		if player == null or Items.kind_of(player.carrying) != &"body":
			return
		var record := player.take_from_hands()
		bay.insert(record, Transform3D(player.global_basis, player.global_position + player.global_basis * Vector3(0, 0.6, -0.8)))


# --- Keeping peers in step --------------------------------------------------------------------

func _broadcast() -> void:
	_state.rpc(_pack())


func _pack() -> Dictionary:
	return {"job": job, "who": who, "left": left}


@rpc("authority", "call_remote", "reliable")
func _state(data: Dictionary) -> void:
	job = data.job
	who = data.who
	left = data.left
