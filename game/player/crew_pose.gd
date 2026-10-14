class_name CrewPose
extends SkeletonModifier3D
## Runs on the suit after its clips (CrewAnimation): turns the legs toward where its crew member
## is going while the body keeps facing where they look, so a strafe or a diagonal walks instead of
## sliding, and tips the head and chest with their gaze. Bones pitch forward and turn left with
## positive angles (TECH §5).

## Radians the legs turn from the facing, + toward the suit's left.
var legs_yaw := 0.0
## Radians the crew member looks up (+) or down.
var pitch := 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_turn(skeleton, &"hips", Vector3.UP, legs_yaw)
	_turn(skeleton, &"spine", Vector3.UP, -legs_yaw * 0.5)
	_turn(skeleton, &"chest", Vector3.UP, -legs_yaw * 0.5)
	_turn(skeleton, &"chest", Vector3.RIGHT, -pitch * 0.25)
	_turn(skeleton, &"head", Vector3.RIGHT, -pitch * 0.6)


## Turns `bone` by `angle` about `axis`: its own, or its parent's.
func _turn(skeleton: Skeleton3D, bone: StringName, axis: Vector3, angle: float, parent_axis := false) -> void:
	var i := skeleton.find_bone(bone)
	if i >= 0 and not is_zero_approx(angle):
		var pose := skeleton.get_bone_pose_rotation(i)
		skeleton.set_bone_pose_rotation(i, Quaternion(axis, angle) * pose if parent_axis else pose * Quaternion(axis, angle))
