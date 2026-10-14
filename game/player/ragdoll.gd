class_name Ragdoll
extends Node3D
## A crew suit gone limp (GDD §11): the suit model (ch_suit) with a physical bone on each rigid
## segment (PSX bodies don't bend between joints), joined by cone joints, falling where it falls.
## Hands ride their forearms and feet their shins. A dead crew member's body lying loose
## (LooseBody), and one carried across a teammate's arms (`hold_torso`: its torso steered to the
## arms every physics frame, the head and limbs swinging from it), are both Ragdolls.
##
## Every peer simulates its own: they may lie a little differently, in the same place (LooseBody).

const SUIT := preload("res://assets/models/characters/ch_suit.glb")

## Each simulated bone: its length along its own +Y (to its child; hands and feet are taken in),
## its shape (a box's size, or a capsule's radius), its mass, and how far its joint to its parent
## swings and twists (degrees).
const BONES := {
	&"hips": {"length": 0.15, "box": Vector3(0.34, 0.2, 0.24), "mass": 14.0},
	&"spine": {"length": 0.18, "box": Vector3(0.34, 0.2, 0.24), "mass": 10.0, "swing": 20.0, "twist": 12.0},
	&"chest": {"length": 0.22, "box": Vector3(0.42, 0.26, 0.32), "mass": 20.0, "swing": 20.0, "twist": 12.0},
	&"head": {"length": 0.28, "sphere": 0.15, "mass": 6.0, "swing": 40.0, "twist": 30.0},
	&"upper_arm.L": {"length": 0.28, "radius": 0.07, "mass": 4.0, "swing": 75.0, "twist": 30.0},
	&"upper_arm.R": {"length": 0.28, "radius": 0.07, "mass": 4.0, "swing": 75.0, "twist": 30.0},
	&"forearm.L": {"length": 0.37, "radius": 0.06, "mass": 3.0, "swing": 55.0, "twist": 10.0},
	&"forearm.R": {"length": 0.37, "radius": 0.06, "mass": 3.0, "swing": 55.0, "twist": 10.0},
	&"thigh.L": {"length": 0.43, "radius": 0.09, "mass": 9.0, "swing": 55.0, "twist": 15.0},
	&"thigh.R": {"length": 0.43, "radius": 0.09, "mass": 9.0, "swing": 55.0, "twist": 15.0},
	&"shin.L": {"length": 0.45, "radius": 0.08, "mass": 6.0, "swing": 50.0, "twist": 8.0},
	&"shin.R": {"length": 0.45, "radius": 0.08, "mass": 6.0, "swing": 50.0, "twist": 8.0},
}
## What a carried body's arms hold still: its torso. The rest swings.
const TORSO: Array[StringName] = [&"hips", &"spine", &"chest"]
## The physics layer a loose body's on (as loose items are: it rests on the world, and crew pass
## through it), and what it rests on.
const LAYER := 1 << 3
const MASK := 1

var model: Node3D
var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
## The physical bones, by bone name, in the skeleton's order (parents first).
var bones: Array[PhysicalBone3D] = []
## Whether its torso's held where it lies in its own frame (carried), the rest hanging from it.
var hold_torso := false


func _init() -> void:
	model = SUIT.instantiate()
	model.name = "Suit"
	model.rotation.y = PI # the suit model faces +Z; turned, it faces -Z like everything else
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	skeleton.add_child(simulator)
	for index in skeleton.get_bone_count():
		var name := StringName(skeleton.get_bone_name(index))
		if BONES.has(name):
			bones.append(_bone(name, BONES[name]))
	# A body: the lamp's out, the cuff's dark, the spine lights dead.
	for part in ["lamp_lens", "cuff_screen"]:
		var mesh := model.find_child(part, true, false) as Node3D
		if mesh != null:
			mesh.visible = false
	var spine := model.find_child("spine_lights", true, false) as MeshInstance3D
	if spine != null and spine.get_active_material(0) is ShaderMaterial:
		var dead: ShaderMaterial = spine.get_active_material(0).duplicate()
		dead.set_shader_parameter("albedo", Color(0.04, 0.05, 0.04))
		spine.material_override = dead
	Deck._mark_interior(model)


## A physical bone for `name`: its shape centred along it, its joint at its head.
func _bone(name: StringName, spec: Dictionary) -> PhysicalBone3D:
	var bone := PhysicalBone3D.new()
	bone.name = String(name).replace(".", "_")
	bone.bone_name = name
	var half: float = spec.length / 2.0
	bone.body_offset = Transform3D(Basis(), Vector3(0, half, 0))
	# The cone's twist runs along the joint's X: turned onto the bone.
	bone.joint_offset = Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0, -half, 0))
	bone.mass = spec.mass
	bone.friction = 0.9
	bone.bounce = 0.0
	bone.linear_damp = 0.2
	bone.angular_damp = 1.5
	bone.collision_layer = LAYER
	bone.collision_mask = MASK
	var shape := CollisionShape3D.new()
	if spec.has("box"):
		var box := BoxShape3D.new()
		box.size = spec.box
		shape.shape = box
	elif spec.has("sphere"):
		var ball := SphereShape3D.new()
		ball.radius = spec.sphere
		shape.shape = ball
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = spec.radius
		capsule.height = maxf(spec.length, spec.radius * 2.0 + 0.01)
		shape.shape = capsule
	bone.add_child(shape)
	simulator.add_child(bone)
	if spec.has("swing"):
		bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		bone.set("joint_constraints/swing_span", spec.swing)
		bone.set("joint_constraints/twist_span", spec.twist)
	return bone


## Lets it fall: every bone, or only `which`, simulated from where they are, moving at `velocity`.
## Its bones need a physics frame in the world first (started sooner, they never move, or worse).
func go_limp(velocity := Vector3.ZERO, which: Array[StringName] = []) -> void:
	if not is_inside_tree():
		await tree_entered
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	simulator.physical_bones_start_simulation(which)
	for bone in bones:
		if which.is_empty() or bone.bone_name in which:
			bone.linear_velocity = velocity


## Carried: the torso's bones go where its rest pose puts them in this node's frame, with no
## momentum of their own, so the head and limbs hang and swing from wherever it's carried.
func _physics_process(_delta: float) -> void:
	if not hold_torso or not simulator.is_simulating_physics():
		return
	for bone in bones:
		if bone.bone_name in TORSO:
			var index := skeleton.find_bone(bone.bone_name)
			bone.global_transform = skeleton.global_transform * skeleton.get_bone_global_rest(index) * bone.body_offset
			bone.linear_velocity = Vector3.ZERO
			bone.angular_velocity = Vector3.ZERO


## Holds it still where the skeleton puts it (the bones stop simulating).
func hold_still() -> void:
	simulator.physical_bones_stop_simulation()


## Whether it's still settling.
func moving() -> bool:
	for bone in bones:
		if bone.linear_velocity.length_squared() > 0.0025 or bone.angular_velocity.length_squared() > 0.01:
			return true
	return false


## Where it lies: its hips, in the world.
func centre() -> Vector3:
	return bones[0].global_position if not bones.is_empty() else global_position


## Moves the whole thing by `moved` (in the world), as it lies.
func carry(moved: Transform3D) -> void:
	for bone in bones:
		bone.global_transform = moved * bone.global_transform
		bone.linear_velocity = moved.basis * bone.linear_velocity
