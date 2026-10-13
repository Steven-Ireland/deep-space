"""Rigs and animation for characters and creatures (TECH §5): an armature from a bone list, a mesh
of rigid parts bound to it (geo.Mesh.bone), and clips keyed from pose functions at 12 fps with
stepped interpolation, the PlayStation's choppy motion. Clips named `*-loop` import into Godot
as looping animations.
"""

import math

import bpy
from mathutils import Euler, Vector

FPS = 24
STEP = 2  # key every other frame: 12 poses a second


def armature(name, bones):
    """An armature from `bones`: (name, head, tail, parent or None). Returns the object."""
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj]):
        bpy.ops.object.mode_set(mode="EDIT")
        for bone_name, head, tail, parent in bones:
            bone = data.edit_bones.new(bone_name)
            bone.head = Vector(head)
            bone.tail = Vector(tail)
            bone.roll = 0.0
            if parent:
                bone.parent = data.edit_bones[parent]
                bone.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in obj.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    return obj


def bind(mesh_obj, rig):
    """Skins `mesh_obj` (whose vertex groups name bones) to `rig`."""
    mesh_obj.parent = rig
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig


def clip(rig, name, length, pose, loop=True):
    """Keys an action `name` (`-loop` appended if looping) of `length` seconds: `pose(t)` (t in
    0..1 through the clip) returns {bone: (rx, ry, rz) degrees} and optionally "root_location"."""
    action = bpy.data.actions.new(name + ("-loop" if loop else ""))
    action.use_fake_user = True
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    frames = max(2, int(length * FPS))
    for frame in range(0, frames + 1, STEP):
        t = frame / frames
        values = pose(t)
        for bone_name, value in values.items():
            if bone_name == "root_location":
                pb = rig.pose.bones["root"]
                pb.location = Vector(value)
                pb.keyframe_insert("location", frame=frame)
                continue
            pb = rig.pose.bones[bone_name]
            pb.rotation_euler = Euler(tuple(math.radians(a) for a in value), "XYZ")
            pb.keyframe_insert("rotation_euler", frame=frame)
    for curve in _fcurves(action, rig):
        for key in curve.keyframe_points:
            key.interpolation = "CONSTANT"
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_euler = Euler((0, 0, 0))
        pb.location = Vector((0, 0, 0))
    return action


def _fcurves(action, rig):
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])):
        return list(action.fcurves)
    from bpy_extras import anim_utils
    curves = []
    for slot in action.slots:
        bag = anim_utils.action_get_channelbag_for_slot(action, slot)
        if bag is not None:
            curves += list(bag.fcurves)
    return curves


def wave(t, cycles=1.0, phase=0.0):
    """sin over the clip, `cycles` times, offset by `phase` (0..1)."""
    return math.sin((t * cycles + phase) * math.tau)


def ik_pose(rig, bone, target, pole=None, chain=2, pole_angle=0.0):
    """Solves a reach with Blender's IK: the tip of `bone` (and `chain` bones up from it) toward
    `target`, the elbow or knee toward `pole`. Returns {bone: (rx, ry, rz) degrees}, for clip poses
    that are awkward to find by hand (lifting a wrist into view, planting a foot)."""
    empties = []

    def empty(at):
        e = bpy.data.objects.new("ik_helper", None)
        bpy.context.scene.collection.objects.link(e)
        e.location = Vector(at)
        empties.append(e)
        return e

    pb = rig.pose.bones[bone]
    constraint = pb.constraints.new("IK")
    constraint.target = empty(target)
    constraint.chain_count = chain
    if pole is not None:
        constraint.pole_target = empty(pole)
        constraint.pole_angle = math.radians(pole_angle)
    bpy.context.view_layer.update()
    result = {}
    current = pb
    for _ in range(chain):
        local = rig.convert_space(pose_bone=current, matrix=current.matrix, from_space="POSE", to_space="LOCAL")
        e = local.to_euler("XYZ")
        result[current.name] = (math.degrees(e.x), math.degrees(e.y), math.degrees(e.z))
        current = current.parent
    pb.constraints.remove(constraint)
    for e in empties:
        bpy.data.objects.remove(e)
    bpy.context.view_layer.update()
    return result
