"""Rigs and animation for characters and creatures (TECH §5): an armature from a bone list, a mesh
of rigid parts bound to it (geo.Mesh.bone), and clips keyed from pose functions: at 12 fps with
stepped interpolation, the PlayStation's choppy motion, or every frame and interpolated for
locomotion, where planted feet must stay put as the body moves over them. Clips named `*-loop`
import into Godot as looping animations.

Bones here point along the body (legs down, spine up), so for every bone X is the body's
left-right axis and a positive X turn pitches it forward over the bone's head: a leg swings back,
the spine leans forward. `sagittal` and `leg_ik` work in that side-on (y, z) plane, front -y.
"""

import math

import bpy
from mathutils import Euler, Matrix, Vector

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


def clip(rig, name, length, pose, loop=True, smooth=False):
    """Keys an action `name` (`-loop` appended if looping) of `length` seconds: `pose(t)` (t in
    0..1 through the clip) returns {bone: (rx, ry, rz) degrees, or (rx, ry, rz, x, y, z) to move
    the bone too, in its own axes} and optionally "root_location", the root's offset in the
    model's own axes (x left, y back, z up). `smooth` keys every frame and interpolates
    (locomotion); otherwise 12 stepped poses a second."""
    action = bpy.data.actions.new(name + ("-loop" if loop else ""))
    action.use_fake_user = True
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    frames = max(2, int(length * FPS))
    for frame in range(0, frames + 1, 1 if smooth else STEP):
        t = frame / frames
        values = pose(t)
        for bone_name, value in values.items():
            if bone_name == "root_location":
                pb = rig.pose.bones["root"]
                # Pose locations are in the bone's own axes, not the model's.
                pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector(value)
                pb.keyframe_insert("location", frame=frame)
                continue
            pb = rig.pose.bones[bone_name]
            pb.rotation_euler = Euler(tuple(math.radians(a) for a in value[:3]), "XYZ")
            pb.keyframe_insert("rotation_euler", frame=frame)
            if len(value) == 6:
                pb.location = Vector(value[3:])
                pb.keyframe_insert("location", frame=frame)
    for curve in _fcurves(action, rig):
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR" if smooth else "CONSTANT"
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


def smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def sagittal(v, angle):
    """A side-on vector (y, z) turned by `angle` radians the way a positive X turn turns a bone:
    pointing down, it swings back (+y)."""
    y, z = v
    c, s = math.cos(angle), math.sin(angle)
    return (y * c - z * s, y * s + z * c)


def leg_ik(hip, ankle, upper, lower):
    """Two-bone IK, side-on: the angles from straight down (radians, + back) of the upper and lower
    bones that put the chain's end from `hip` at `ankle`, both (y, z), bending the knee forward.
    Out of reach, the leg straightens toward it."""
    dy, dz = ankle[0] - hip[0], ankle[1] - hip[1]
    length = min(math.hypot(dy, dz), (upper + lower) * 0.9995)
    aim = math.atan2(dy, -dz)
    at_hip = math.acos(max(-1.0, min(1.0, (upper ** 2 + length ** 2 - lower ** 2) / (2 * upper * length))))
    at_ankle = math.acos(max(-1.0, min(1.0, (lower ** 2 + length ** 2 - upper ** 2) / (2 * lower * length))))
    return aim - at_hip, aim + at_ankle


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


def pose_matrices(rig, angles):
    """Armature-space pose matrices for every bone with `angles` ({bone: (rx, ry, rz) degrees, or
    with a move (rx, ry, rz, x, y, z) as clip() takes}, the rest at rest), computed as Blender's
    forward kinematics would, without a scene update."""
    matrices = {}
    for bone in sorted(rig.data.bones, key=lambda b: len(b.parent_recursive)):
        value = angles.get(bone.name, (0, 0, 0))
        turn = Euler(tuple(math.radians(a) for a in value[:3]), "XYZ").to_matrix().to_4x4()
        if len(value) == 6:
            turn = Matrix.Translation(Vector(value[3:])) @ turn
        if bone.parent is None:
            matrices[bone.name] = bone.matrix_local @ turn
        else:
            matrices[bone.name] = matrices[bone.parent.name] @ bone.parent.matrix_local.inverted() @ bone.matrix_local @ turn
    return matrices


def deform(rig, matrices, bone, point, direction=False):
    """Where `point` (rest, model space), carried rigidly by `bone`, is in a pose; or where a
    `direction` points."""
    m = matrices[bone] @ rig.data.bones[bone].matrix_local.inverted()
    if direction:
        return (m.to_3x3() @ Vector(point)).normalized()
    return m @ Vector(point)


def solve(cost, start, step=10.0, iterations=1500):
    """Minimises `cost(x)` over a list of floats from `start` (Nelder-Mead, initial simplex `step`
    wide), for poses easier to describe by what they achieve than by their angles."""
    n = len(start)
    simplex = [list(start)] + [[v + (step if i == j else 0.0) for j, v in enumerate(start)] for i in range(n)]
    scores = [cost(p) for p in simplex]
    for _ in range(iterations):
        order = sorted(range(n + 1), key=lambda i: scores[i])
        simplex = [simplex[i] for i in order]
        scores = [scores[i] for i in order]
        centre = [sum(p[j] for p in simplex[:-1]) / n for j in range(n)]
        worst = simplex[-1]

        def toward(k):
            return [c + k * (w - c) for c, w in zip(centre, worst)]

        reflected = toward(-1.0)
        r = cost(reflected)
        if r < scores[0]:
            expanded = toward(-2.0)
            e = cost(expanded)
            simplex[-1], scores[-1] = (expanded, e) if e < r else (reflected, r)
        elif r < scores[-2]:
            simplex[-1], scores[-1] = reflected, r
        else:
            contracted = toward(0.5)
            c = cost(contracted)
            if c < scores[-1]:
                simplex[-1], scores[-1] = contracted, c
            else:
                best = simplex[0]
                simplex = [best] + [[b + 0.5 * (v - b) for b, v in zip(best, p)] for p in simplex[1:]]
                scores = [scores[0]] + [cost(p) for p in simplex[1:]]
    best = min(range(n + 1), key=lambda i: scores[i])
    return simplex[best], scores[best]
