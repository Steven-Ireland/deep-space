class_name Pickup
extends RigidBody3D
## A loose item (GDD §9.4): lying where it was left, or flying where it was thrown. The host
## simulates and owns it (TECH §2); everyone else sees it follow the host's (its synchronizer sends
## where it is only while it moves). A crew member aiming at it sees TAKE, or CARRY for a big
## thing, if they have room for it. Taking it is reported to the host, which hands them its record
## and takes it out of the world: first request wins (LooseItems).

## The physics layer loose items are on ("items"). They rest on the world and on each other, and
## bounce off crew without ever blocking them.
const LAYER := 1 << 3
## The least an item's handle measures along each axis, so small things are easy to aim at.
const HANDLE_MIN := 0.22

## The item: its kind (Items) and any state of its own. Set before it enters the tree.
var record: Dictionary
## How it's moving as it appears (thrown), set before it enters the tree.
var launch := Vector3.ZERO
## Whether it's racked: held where it hangs, not falling, until it's taken.
var racked := false
## Where it is and how it's turned, from the host.
var at := Vector3.ZERO
var turn := Quaternion.IDENTITY

var handle: Handle
var _flame: Flame


func _ready() -> void:
	var kind := Items.kind_of(record)
	collision_layer = LAYER
	collision_mask = 1 | 2 | LAYER
	mass = Items.mass(kind)
	angular_damp = 1.5 # cans and bottles don't roll forever
	continuous_cd = true # small things thrown hard don't pass through walls
	var model: Node3D = Items.model(kind).instantiate()
	add_child(model)
	Deck._mark_interior(model)
	var box := Items.bounds(model)
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.02)
	$Shape.shape = shape
	$Shape.position = box.get_center()
	handle = Handle.new()
	handle.name = "Handle"
	handle.pickup = self
	var reach := CollisionShape3D.new()
	var reach_box := BoxShape3D.new()
	reach_box.size = box.size.max(Vector3.ONE * HANDLE_MIN)
	reach.shape = reach_box
	reach.position = box.get_center()
	handle.add_child(reach)
	add_child(handle)
	handle.used.connect(func(peer: int): LooseItems.of(self).take(self, peer))
	if Items.burning(record):
		# A burning flare casts no shadow, so its tube can't shade its own flame.
		for mesh: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame = Flame.light(model)
		_flame.rise = 0.3
	if multiplayer.is_server():
		linear_velocity = launch
		at = position
		turn = quaternion
		if racked:
			freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			freeze = true
	else:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		if at != Vector3.ZERO:
			position = at
			quaternion = turn


## Below this, a thing's fallen off whatever it was on, out into space: gone.
const LOST_BELOW := -40.0


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		# It weighs what the zone it's in gives it (GDD §9.1): nothing in a satellite or out in
		# space, where it hangs, or drifts on as it was knocked.
		gravity_scale = Zone.weight_at(get_world_3d(), global_position)
		at = position
		turn = quaternion
		if position.y < LOST_BELOW:
			queue_free()


## Host: what it lies on has moved by `moved` (a derelict drifting): it goes along.
func carry(moved: Transform3D) -> void:
	global_transform = moved * global_transform
	linear_velocity = moved.basis * linear_velocity
	at = position
	turn = quaternion


func _process(delta: float) -> void:
	if _flame != null:
		# A struck flare burns down where it lies; the host clears it away once it's out.
		record.burn = maxf(0.0, record.burn - delta)
		_flame.strength = record.burn / Player.FLARE_BURN
		if record.burn <= 0.0 and multiplayer.is_server():
			queue_free()
	if multiplayer.is_server() or at == Vector3.ZERO:
		return
	var follow := 1.0 - exp(-delta * 20.0)
	position = position.lerp(at, follow)
	quaternion = quaternion.slerp(turn, follow)


## Where it lies.
func centre() -> Vector3:
	return global_position


## What crew aim at: TAKE, or CARRY for a big thing, when they have room for it. (A Pickup's, or a
## LooseBody's: anything loose with a `record`.)
class Handle extends Interactable:
	var pickup: Node3D

	func prompt(player: Player) -> String:
		var kind := Items.kind_of(pickup.record)
		if not player.carrying.is_empty():
			return "HANDS FULL"
		if Items.two_handed(kind):
			return "CARRY"
		return "TAKE" if player.free_slot() >= 0 else "BELT FULL"

	func usable_by(player: Player) -> bool:
		return enabled and player.room_for(Items.kind_of(pickup.record))
