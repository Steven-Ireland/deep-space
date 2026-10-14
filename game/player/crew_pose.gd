class_name CrewPose
extends SkeletonModifier3D
## Runs on the suit after its clips (CrewAnimation): turns the legs toward where its crew member
## is going while the body keeps facing where they look, so a strafe or a diagonal walks instead of
## sliding, and tips the head, chest and a raised torch with their gaze. Bones pitch forward and
## turn left with positive angles (TECH §5).

## Radians the legs turn from the facing, + toward the suit's left.
var legs_yaw := 0.0
## Radians the crew member looks up (+) or down.
var pitch := 0.0
## 0..1, how far the right arm is holding a torch up (it follows the gaze).
var torch := 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_turn(skeleton, &"hips", Vector3.UP, legs_yaw)
	_turn(skeleton, &"spine", Vector3.UP, -legs_yaw * 0.5)
	_turn(skeleton, &"chest", Vector3.UP, -legs_yaw * 0.5)
	_turn(skeleton, &"chest", Vector3.RIGHT, -pitch * 0.25)
	_turn(skeleton, &"head", Vector3.RIGHT, -pitch * 0.6)
	_turn(skeleton, &"upper_arm.R", Vector3.RIGHT, -pitch * 0.8 * torch)


func _turn(skeleton: Skeleton3D, bone: StringName, axis: Vector3, angle: float) -> void:
	var i := skeleton.find_bone(bone)
	if i >= 0 and not is_zero_approx(angle):
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * Quaternion(axis, angle))
