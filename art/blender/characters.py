"""The crew (GDD §9, §10): the EVA suit every player wears, seen by the others, and the first-person
arms each player sees of themselves. PSX-style rigid segments on a skeleton (lib/rig.py), clips
at 12 fps. Faces -Y in Blender (+Z in Godot; the player turns it to face -Z).
"""

import math

import bpy
from mathutils import Matrix, Vector

import bridge as br
from lib import Model, asset, geo, mats, rig
from lib.geo import Mesh, frame

SUIT_BONES = [
    ("root", (0, 0, 0), (0, 0, 0.2), None),
    ("hips", (0, 0, 0.95), (0, 0, 1.1), "root"),
    ("spine", (0, 0, 1.1), (0, 0, 1.28), "hips"),
    ("chest", (0, 0, 1.28), (0, 0, 1.5), "spine"),
    ("head", (0, 0, 1.5), (0, 0, 1.78), "chest"),
]
for side, sx in (("L", 1), ("R", -1)):
    SUIT_BONES += [
        (f"upper_arm.{side}", (sx * 0.25, 0, 1.43), (sx * 0.28, 0, 1.15), "chest"),
        (f"forearm.{side}", (sx * 0.28, 0, 1.15), (sx * 0.29, -0.02, 0.9), f"upper_arm.{side}"),
        (f"hand.{side}", (sx * 0.29, -0.02, 0.9), (sx * 0.29, -0.03, 0.78), f"forearm.{side}"),
        (f"thigh.{side}", (sx * 0.11, 0, 0.95), (sx * 0.12, 0, 0.52), "hips"),
        (f"shin.{side}", (sx * 0.12, 0, 0.52), (sx * 0.12, 0.02, 0.1), f"thigh.{side}"),
        (f"foot.{side}", (sx * 0.12, 0.02, 0.1), (sx * 0.12, -0.1, 0.03), f"shin.{side}"),
    ]


def _suit_materials():
    return dict(
        fabric=mats.plain("ch_fabric", (0.78, 0.74, 0.63), grime=0.45, variation=0.08, detail_strength=0.35),
        hard=mats.paint("ch_hard", (0.7, 0.68, 0.6), wear=0.35, grime=0.4),
        dark=mats.plain("ch_dark", (0.17, 0.17, 0.18), grime=0.3),
        orange=mats.paint("ch_orange", (0.86, 0.42, 0.1), wear=0.4, grime=0.35),
        steel=mats.metal("ch_steel", (0.55, 0.55, 0.53), grime=0.3),
        visor=mats.glowing("ch_visor", (0.1, 0.16, 0.15), base=(0.04, 0.06, 0.06), flicker=0.0),
        lamp=mats.glowing("ch_lamp", (1.0, 0.85, 0.6), base=(0.6, 0.5, 0.35)),
    )


def _limb(m, k, x, top, bottom, r_top, r_bottom, material, sides=6):
    m.lathe([(r_bottom, bottom), (r_top, top)], material, sides=sides, at=(x, 0, 0))


@asset("ch_suit", "characters", texture=256, colors=32, ao=0.5)
def suit():
    """The crew EVA suit (GDD §9, §10): 1.8 m. A bulky cream suit with ribbed joints and orange
    bands, a domed helmet with a dark visor and a side lamp, a chest unit with status lamps, a life
    support pack on the back carrying the SPINE LIGHTS (`spine_lights`, separate: Godot colours
    them by health so the crew can read each other), dark gloves and heavy boots, a wrist cuff on
    the left forearm. Rigid segments on 17 bones."""
    k = _suit_materials()
    dk = br._decals()
    m = Mesh("ch_suit")
    d = Mesh("ch_suit_decals")
    # Pelvis and belt.
    m.bone("hips")
    m.box((0.36, 0.25, 0.22), k["fabric"], at=(0, 0, 1.0), bevel=0.04)
    m.box((0.39, 0.28, 0.06), k["dark"], at=(0, 0, 1.08), bevel=0.01)
    for x in (-0.14, 0.14):
        m.box((0.08, 0.06, 0.08), k["dark"], at=(x, -0.15, 1.02), bevel=0.01)
    # Lower torso: a bellows of ribs.
    m.bone("spine")
    m.box((0.36, 0.25, 0.2), k["fabric"], at=(0, 0, 1.19), bevel=0.04)
    for z in (1.14, 1.2, 1.26):
        m.box((0.37, 0.26, 0.018), k["dark"], at=(0, 0, z))
    # Chest, shoulders, chest unit, backpack.
    m.bone("chest")
    m.box((0.46, 0.3, 0.3), k["fabric"], at=(0, 0, 1.38), bevel=0.06)
    m.box((0.22, 0.07, 0.13), k["hard"], at=(0, -0.17, 1.36), bevel=0.015)
    for x in (-0.25, 0.25):
        m.box((0.14, 0.28, 0.12), k["hard"], at=(x, 0, 1.47), bevel=0.04)
    m.box((0.42, 0.2, 0.52), k["hard"], at=(0, 0.25, 1.3), bevel=0.04)
    for z in (1.12, 1.48):
        m.box((0.43, 0.21, 0.04), k["dark"], at=(0, 0.25, z), bevel=0.008)
    m.cylinder(0.05, 0.14, k["steel"], sides=6, at=(0.16, 0.25, 1.62))
    m.lathe([(0.17, 1.47), (0.18, 1.52)], k["dark"], sides=10, cap_start=False, cap_end=False)  # neck ring
    # Helmet.
    m.bone("head")
    m.lathe([(0.0, 1.5), (0.15, 1.5), (0.17, 1.56), (0.175, 1.66), (0.16, 1.74), (0.12, 1.8), (0.06, 1.825), (0.0, 1.83)],
            k["hard"], sides=8)
    m.box((0.24, 0.06, 0.13), k["visor"], at=(0, -0.145, 1.66), rot=(-8, 0, 0), bevel=0.03)
    m.box((0.28, 0.05, 0.03), k["dark"], at=(0, -0.15, 1.74), bevel=0.01)
    m.box((0.05, 0.08, 0.06), k["dark"], at=(0.17, -0.06, 1.7), bevel=0.01)
    m.box((0.03, 0.01, 0.03), k["lamp"], at=(0.17, -0.1, 1.7))
    m.pipe([(-0.12, 0.08, 1.76), (-0.14, 0.12, 1.95)], 0.006, k["dark"], sides=4)
    # Arms.
    for side, sx in (("L", 1), ("R", -1)):
        m.bone(f"upper_arm.{side}")
        _limb(m, k, sx * 0.265, 1.44, 1.16, 0.075, 0.065, k["fabric"])
        m.lathe([(0.077, 1.33), (0.077, 1.37)], k["orange"], sides=6, at=(sx * 0.265, 0, 0), cap_start=False, cap_end=False)
        m.lathe([(0.072, 1.15), (0.072, 1.19)], k["dark"], sides=6, at=(sx * 0.27, 0, 0), cap_start=False, cap_end=False)
        m.bone(f"forearm.{side}")
        _limb(m, k, sx * 0.285, 1.15, 0.9, 0.064, 0.055, k["fabric"])
        if side == "L":
            m.box((0.08, 0.1, 0.12), k["dark"], at=(sx * 0.29, -0.03, 0.97), bevel=0.012)
        m.bone(f"hand.{side}")
        m.box((0.08, 0.1, 0.12), k["dark"], at=(sx * 0.29, -0.02, 0.83), bevel=0.02)
        m.box((0.03, 0.04, 0.06), k["dark"], at=(sx * 0.25, -0.07, 0.85), bevel=0.01)
        m.lathe([(0.062, 0.89), (0.062, 0.93)], k["dark"], sides=6, at=(sx * 0.29, -0.02, 0), cap_start=False, cap_end=False)
    # Legs.
    for side, sx in (("L", 1), ("R", -1)):
        m.bone(f"thigh.{side}")
        _limb(m, k, sx * 0.115, 0.96, 0.54, 0.095, 0.08, k["fabric"])
        m.lathe([(0.097, 0.72), (0.097, 0.76)], k["orange"], sides=6, at=(sx * 0.115, 0, 0), cap_start=False, cap_end=False)
        m.box((0.13, 0.06, 0.12), k["hard"], at=(sx * 0.12, -0.08, 0.54), bevel=0.03)
        m.bone(f"shin.{side}")
        _limb(m, k, sx * 0.12, 0.53, 0.16, 0.075, 0.07, k["fabric"])
        m.bone(f"foot.{side}")
        m.box((0.13, 0.26, 0.14), k["dark"], at=(sx * 0.12, -0.04, 0.07), bevel=0.03)
        m.box((0.14, 0.27, 0.03), k["steel"], at=(sx * 0.12, -0.04, 0.015), bevel=0.008)
    low = m.to_object()
    # Decals: chest unit lamps, crew number on the backpack, a hazard tab.
    front = Vector((0, -1, 0))
    for i, lamp in enumerate(("green_lit", "amber_lit", "unlit", "green_lit")):
        d.polygon([(-0.01, -0.008), (0.01, -0.008), (0.01, 0.008), (-0.01, 0.008)], dk[lamp], frame((-0.06 + i * 0.04, -0.206, 1.38), front))
    d.polygon([(-0.08, -0.015), (0.08, -0.015), (0.08, 0.015), (-0.08, 0.015)], dk["dark"], frame((0, -0.206, 1.335), front))
    texts = [geo.text("LTN", 0.05, dk["orange"], matrix=frame((0, 0.351, 1.38), (0, 1, 0), lift=0.002))]
    # Spine lights: four lamps down the backpack, a separate mesh Godot recolours.
    lights = Mesh("spine_lights")
    lights.bone("chest")
    for i in range(4):
        lights.box((0.05, 0.02, 0.035), mats.plain("ch_spine", (0.3, 1.0, 0.45)), at=(0, 0.355, 1.46 - i * 0.07), bevel=0.004)
    lights_obj = lights.to_object()
    # The wrist cuff's screen on the front of the left bracer: dark, until its wearer raises it to
    # read it and Godot lights it, so the crew can see who's checking their vitals.
    cuff_centre = Vector((0.29, -0.0815, 0.97))
    cuff_frame = frame(cuff_centre, (0, -1, 0), up=(0, 0, -1), lift=0.0)
    cuff = Mesh("cuff_screen")
    cuff.bone("forearm.L")
    cuff.polygon([(-0.03, -0.04), (0.03, -0.04), (0.03, 0.04), (-0.03, 0.04)], mats.plain("ch_cuff_screen", (0.2, 0.9, 0.4)), cuff_frame)
    cuff_obj = cuff.to_object()

    skeleton = rig.armature("suit_rig", SUIT_BONES)
    rig.bind(low, skeleton)
    rig.bind(lights_obj, skeleton)
    rig.bind(cuff_obj, skeleton)
    # Whatever's held sits in the right glove (`SOCKET_grip`), along the body's forward axis.
    grip = _bone_socket(skeleton, "SOCKET_grip", "hand.R", (-0.29, -0.035, 0.83))
    _suit_clips(skeleton, _cuff_pose(skeleton, cuff_centre, Vector((0, -1, 0)), Vector((0, 0, -1))))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[skeleton, lights_obj, cuff_obj, grip])


def _bone_socket(skeleton, name, bone, at):
    """An empty carried by `bone`, at `at` (model space, rest pose) with the model's own axes.
    (Set through matrix_world: a bone child's location counts from the bone's tail.)"""
    socket = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(socket)
    socket.empty_display_size = 0.03
    socket.parent = skeleton
    socket.parent_type = "BONE"
    socket.parent_bone = bone
    bpy.context.view_layer.update()
    socket.matrix_world = Matrix.Translation(Vector(at))
    return socket


# Legs, side-on (rig.leg_ik): the hip joint's height, the thigh and shin, the shin's rest lean back,
# and the foot's contact points from the ankle (y back, z up): it lands on its heel and leaves
# from its toe.
HIP_Z = 0.95
THIGH, SHIN = 0.43, 0.4205
SHIN_LEAN = math.atan2(0.02, 0.42)
ANKLE_Z = 0.1
HEEL = (0.07, -0.1)
TOE = (-0.19, -0.1)

# Gaits (GDD §9.1). Each clip is one cycle in one second, left heel strike first; Godot plays
# them at 1 / period cycles a second and blends walk into run in step (player.gd keeps these
# periods). `speed` is the ground the body covers, so planted feet ride back under it exactly.
# `duty` is how much of a cycle each foot is down (under half: both feet leave the ground);
# `back` sets the planted stretch behind the hip; `strike`/`push` the foot's roll in degrees.
WALK = dict(speed=2.2, period=0.7, duty=0.56, back=0.06, strike=-15, push=40, lift=0.11,
            height=lambda t: 0.932 + 0.01 * math.cos(4 * math.pi * (t - 0.28)))
RUN = dict(speed=4.0, period=0.66, duty=0.33, back=0.1, strike=-8, push=55, lift=0.3,
           height=lambda t: 0.88 - 0.03 * math.cos(4 * math.pi * (t - 0.165)))
SNEAK = dict(speed=1.2, period=1.0, duty=0.65, back=0.04, strike=-10, push=30, lift=0.08,
             height=lambda t: 0.6 + 0.012 * math.cos(4 * math.pi * (t - 0.33)))


def _stance(s, gait):
    """A planted foot `s` (0..1) through its stance: (ankle y, ankle z, foot pitch radians, toe
    down +). The foot rides back under the body: heel first, rolling flat, peeling up to its toe."""
    reach = gait["duty"] * gait["speed"] * gait["period"]
    flat = gait["back"] - reach / 2 + reach * s
    if s < 0.15:
        pitch = math.radians(gait["strike"]) * (1 - s / 0.15)
        dy, dz = rig.sagittal((-HEEL[0], -HEEL[1]), pitch)
        return flat + HEEL[0] + dy, dz, pitch
    if s > 0.6:
        pitch = math.radians(gait["push"]) * ((s - 0.6) / 0.4) ** 1.5
        dy, dz = rig.sagittal((-TOE[0], -TOE[1]), pitch)
        return flat + TOE[0] + dy, dz, pitch
    return flat, ANKLE_Z, 0.0


def _foot(t, gait):
    """A foot `t` (0..1) through the cycle from its heel strike: (y, z, pitch, planted)."""
    if t < gait["duty"]:
        return (*_stance(t / gait["duty"], gait), True)
    u = (t - gait["duty"]) / (1 - gait["duty"])
    y0, z0, p0 = _stance(1.0, gait)
    y1, z1, p1 = _stance(0.0, gait)
    y = y0 + (y1 - y0) * rig.smoothstep(u)
    z = z0 + (z1 - z0) * u + gait["lift"] * math.sin(math.pi * u ** 0.75)
    return y, z, p0 + (p1 - p0) * rig.smoothstep(u * 1.4), False


def _hip_height(t, gait):
    """The hips' height: the gait's own rise and fall, kept low enough for planted feet to reach."""
    height = gait["height"](t)
    for offset in (0.0, 0.5):
        y, z, _, planted = _foot((t - offset) % 1.0, gait)
        if planted:
            height = min(height, z + math.sqrt(max(0.0, ((THIGH + SHIN) * 0.995) ** 2 - y ** 2)))
    return height


def _legs(feet, hip_z, hips=(0.0, 0.0, 0.0)):
    """Leg bones for ankle targets {side: (y, z, foot pitch)} under hips at `hip_z`, turned `hips`
    (pitch, yaw, roll degrees), which the thighs undo so the feet stay square to the ground."""
    pitch, yaw, roll = hips
    pose = {}
    for side, sx in (("L", 1), ("R", -1)):
        y, z, foot_pitch = feet[side]
        # The hip joint shifts as the pelvis turns and tilts.
        hip = (sx * 0.11 * math.sin(math.radians(yaw)), hip_z + sx * 0.11 * math.sin(math.radians(roll)))
        thigh, shin = rig.leg_ik(hip, (y, z), THIGH, SHIN)
        pose[f"thigh.{side}"] = (math.degrees(thigh) - pitch, yaw, roll)
        pose[f"shin.{side}"] = (math.degrees(shin - thigh - SHIN_LEAN), 0, 0)
        pose[f"foot.{side}"] = (math.degrees(foot_pitch - shin + SHIN_LEAN), 0, 0)
    return pose


def _gait_clip(gait, lean=0.0, arm_swing=18.0, elbow=18.0, pump=8.0, twist=5.0, tilt=3.0, head=0.0, bounce=0.0):
    """A locomotion pose function: the legs walking the gait, the pelvis turning with the stride and
    tilting over the planted leg, the shoulders countering it, the arms swinging opposite the legs,
    the head held level and forward."""
    def pose(t):
        smooth = sum(_hip_height((t + d) % 1.0, gait) for d in (-1 / 48, 0.0, 1 / 48)) / 3
        hip_z = min(smooth, _hip_height(t, gait))
        yaw = -twist * math.cos(math.tau * t)
        roll = tilt * math.sin(math.tau * t)
        feet = {"L": _foot(t, gait)[:3], "R": _foot((t - 0.5) % 1.0, gait)[:3]}
        hips_pitch = lean * 0.4
        result = _legs(feet, hip_z, (hips_pitch, yaw, roll))
        swing = math.cos(math.tau * (t - 0.04))
        result.update({
            "hips": (hips_pitch, yaw, roll),
            "spine": (lean * 0.3, -yaw * 0.6, -roll * 0.5),
            "chest": (lean * 0.3 + bounce * math.cos(4 * math.pi * t), -yaw * 0.7, -roll * 0.5),
            "head": (head - lean, yaw * 0.3, 0),
            "upper_arm.L": (arm_swing * swing, 0, -5), "upper_arm.R": (-arm_swing * swing, 0, 5),
            "forearm.L": (-elbow - pump * max(0.0, -swing), 0, 0), "forearm.R": (-elbow - pump * max(0.0, swing), 0, 0),
            "root_location": (0, 0, hip_z - HIP_Z),
        })
        return result
    return pose


def _stand(hip_z, feet, hips=(0.0, 0.0, 0.0)):
    """Standing legs: each foot's ankle (y, z, pitch)."""
    return _legs(feet, hip_z, hips) | {"hips": hips, "root_location": (0, 0, hip_z - HIP_Z)}


# Holding things in the right hand (seen by the rest of the crew): the torch raised and pointed
# ahead at chest height, a tool carried low and ready.
HOLD_TORCH = {"upper_arm.R": (-62, 0, -6), "forearm.R": (-28, 0, 0), "hand.R": (0, 0, 0)}
HOLD_TOOL = {"upper_arm.R": (-14, 0, 6), "forearm.R": (-38, 0, 0), "hand.R": (8, 0, 0)}


def _cuff_pose(skeleton, cuff_centre, cuff_normal, cuff_up):
    """Reading the wrist cuff, as the others see it: the left forearm lifted across the chest with
    the cuff's face turned up to the visor, the head bowed to it. Solved for what it achieves."""
    eye = Vector((0.0, -0.12, 1.66))
    target = Vector((0.06, -0.36, 1.3))
    bones = ("upper_arm.L", "forearm.L")

    def angles(x):
        return {bones[0]: tuple(x[0:3]), bones[1]: tuple(x[3:6])}

    def cost(x):
        m = rig.pose_matrices(skeleton, angles(x))
        c = rig.deform(skeleton, m, "forearm.L", cuff_centre)
        n = rig.deform(skeleton, m, "forearm.L", cuff_normal, direction=True)
        up = rig.deform(skeleton, m, "forearm.L", cuff_up, direction=True)
        to_eye = (eye - c).normalized()
        facing = 1 - n.dot(to_eye)
        # Upright to the eye: the cuff's up runs away from the reader, not across.
        upright = 1 - max(-1.0, min(1.0, up.dot(Vector((0, 0, 1)) - to_eye * to_eye.z)))
        place = (c - target).length_squared / 0.03 ** 2
        limits = sum(max(0.0, abs(a) - 150) ** 2 for a in x) / 100
        return 6 * facing + upright + place + limits

    x, _ = rig.solve(cost, [-70, 0, 20, -100, 60, 0], step=25.0, iterations=2500)
    pose = angles(x)
    # The head looks down at it.
    m = rig.pose_matrices(skeleton, pose)
    look = rig.deform(skeleton, m, "forearm.L", cuff_centre) - eye
    yaw = math.degrees(math.atan2(look.x, -look.y))
    pitch = math.degrees(math.atan2(-look.z, math.hypot(look.x, look.y)))
    pose["head"] = (pitch * 0.8, yaw * 0.6, 0)
    pose["chest"] = (4, yaw * 0.2, 0)
    return {name: tuple(round(a, 2) for a in rot) for name, rot in pose.items()}


def _suit_clips(skeleton, cuff):
    def idle(t):
        breath = rig.wave(t)
        pose = _stand(0.94, {"L": (0.0, ANKLE_Z, 0.0), "R": (0.03, ANKLE_Z, 0.0)}, (0, 2 * rig.wave(t, 0.5), 1.0))
        pose.update({"chest": (1.5 * breath, 0, 0), "head": (-1.0 * breath, 3 * rig.wave(t, 0.5), 0),
                     "upper_arm.L": (2 * breath, 0, -5), "upper_arm.R": (2 * breath, 0, 5),
                     "forearm.L": (-10, 0, 0), "forearm.R": (-10, 0, 0)})
        return pose

    def crouch(t):
        breath = rig.wave(t)
        dy, dz = rig.sagittal((-TOE[0], -TOE[1]), math.radians(25))
        pose = _stand(0.58 + 0.005 * breath, {"L": (-0.14, ANKLE_Z, 0.0), "R": (0.2 + TOE[0] + dy, dz, math.radians(25))}, (22, 0, 0))
        pose.update({"spine": (14, 0, 0), "chest": (8 + 2 * breath, 0, 0), "head": (-38, 0, 0),
                     "upper_arm.L": (-22, 0, -8), "upper_arm.R": (-22, 0, 8), "forearm.L": (-48, 0, 0), "forearm.R": (-48, 0, 0)})
        return pose

    def carry(t):
        pose = _gait_clip(WALK, arm_swing=0.0)(t)
        pose.update({"upper_arm.L": (-55, 0, 12), "upper_arm.R": (-55, 0, -12), "forearm.L": (-50, 0, -10),
                     "forearm.R": (-50, 0, 10), "spine": (-4, 0, 0)})
        return pose

    def death(t):
        e = min(1.0, t * 1.6)
        fall = max(0.0, (t - 0.35) / 0.65)
        return {"shin.L": (70 * e, 0, 0), "shin.R": (60 * e, 0, 0), "thigh.L": (-50 * e, 0, 5), "thigh.R": (-40 * e, 0, -5),
                "spine": (30 * e, 0, 0), "chest": (20 * e, 0, 0), "head": (-30 * e, 15 * e, 0),
                "upper_arm.L": (40 * e, 0, 30 * e), "upper_arm.R": (50 * e, 0, -25 * e),
                "root": (85 * fall, 0, 0), "root_location": (0, 0.25 * e, -0.55 * fall)}

    def held(base):
        def pose(t):
            b = rig.wave(t)
            return {name: (rot[0] + 1.2 * b, *rot[1:]) for name, rot in base.items()}
        return pose

    rig.clip(skeleton, "idle", 2.0, idle, smooth=True)
    rig.clip(skeleton, "walk", 1.0, _gait_clip(WALK), smooth=True)
    rig.clip(skeleton, "run", 1.0, _gait_clip(RUN, lean=14, arm_swing=42, elbow=78, pump=14, twist=9, tilt=4, head=2, bounce=3),
             smooth=True)
    rig.clip(skeleton, "crouch", 2.0, crouch, smooth=True)
    rig.clip(skeleton, "crouch_walk", 1.0, _gait_clip(SNEAK, lean=50, arm_swing=10, elbow=45, twist=4, tilt=2, head=10),
             smooth=True)
    rig.clip(skeleton, "carry", 1.0, carry, smooth=True)
    rig.clip(skeleton, "cuff", 2.0, held(cuff), smooth=True)
    rig.clip(skeleton, "hold_torch", 2.0, held(HOLD_TORCH), smooth=True)
    rig.clip(skeleton, "hold_tool", 2.0, held(HOLD_TOOL), smooth=True)
    rig.clip(skeleton, "death", 1.4, death, loop=False)


ARM_BONES = [("root", (0, 0, 0), (0, -0.1, 0), None)]
for side, sx in (("L", 1), ("R", -1)):
    ARM_BONES += [
        (f"arm.{side}", (sx * 0.24, 0.1, -0.36), (sx * 0.22, -0.14, -0.34), "root"),
        (f"forearm.{side}", (sx * 0.22, -0.14, -0.34), (sx * 0.17, -0.38, -0.26), f"arm.{side}"),
        (f"hand.{side}", (sx * 0.17, -0.38, -0.26), (sx * 0.16, -0.47, -0.25), f"forearm.{side}"),
    ]


@asset("ch_arms", "characters", texture=128, colors=32, ao=0.5,
       angles=((160, 10), (200, 25), (90, 0), (180, 60)))
def arms():
    """The first-person arms (GDD §9, §10): what each player sees of themselves, from the camera
    (at the origin, looking -Y). Cream suit sleeves with orange bands, dark gloves; the right glove
    is a fist closed round whatever's held (`SOCKET_grip`, the middle of the fist, follows hand.R);
    on the left forearm, the WRIST CUFF, a chunky device with its own small CRT (`screen_cuff`) the
    player raises to read vitals and O2."""
    k = _suit_materials()
    dk = br._decals()
    m = Mesh("ch_arms")
    d = Mesh("ch_arms_decals")
    for side, sx in (("L", 1), ("R", -1)):
        m.bone(f"arm.{side}")
        m.pipe([(sx * 0.245, 0.12, -0.365), (sx * 0.22, -0.15, -0.34)], 0.06, k["fabric"], sides=6)
        m.bone(f"forearm.{side}")
        m.pipe([(sx * 0.222, -0.13, -0.338), (sx * 0.172, -0.37, -0.262)], 0.05, k["fabric"], sides=6)
        m.pipe([(sx * 0.21, -0.19, -0.32), (sx * 0.203, -0.22, -0.31)], 0.052, k["orange"], sides=6, caps=False)
        m.pipe([(sx * 0.178, -0.34, -0.27), (sx * 0.172, -0.37, -0.262)], 0.054, k["dark"], sides=6)
    # The left hand, open and relaxed.
    m.bone("hand.L")
    m.box((0.075, 0.1, 0.06), k["dark"], at=(0.165, -0.42, -0.255), rot=(-8, 0, 8), bevel=0.015)
    for i in range(4):
        m.box((0.017, 0.05, 0.02), k["dark"], at=(0.14 + i * 0.017, -0.48, -0.27), rot=(40, 0, 0), bevel=0.004)
    m.box((0.022, 0.05, 0.022), k["dark"], at=(0.2, -0.43, -0.245), rot=(0, 0, 35), bevel=0.005)
    # The right hand, a fist round a handle running straight ahead through GRIP: knuckles along
    # its top outside edge, the thumb laid along the top.
    m.bone("hand.R")
    g = Vector(GRIP)
    m.box((0.074, 0.09, 0.08), k["dark"], at=g + Vector((-0.004, 0.006, 0.002)), bevel=0.02)
    for i in range(4):
        m.box((0.019, 0.019, 0.017), k["dark"], at=g + Vector((-0.031, -0.03 + i * 0.021, 0.03)), rot=(0, -35, 0), bevel=0.004)
    m.box((0.024, 0.062, 0.022), k["dark"], at=g + Vector((0.021, -0.034, 0.036)), rot=(-6, 0, 18), bevel=0.006)
    m.box((0.06, 0.012, 0.05), k["dark"], at=g + Vector((-0.006, -0.042, -0.012)), bevel=0.006)  # the curled fingers' front
    # The wrist cuff on the left forearm: a chunky box, a hinged visor lip over its little screen.
    m.bone("forearm.L")
    m.box((0.09, 0.13, 0.045), k["hard"], at=(0.2, -0.27, -0.272), rot=(-17, 0, 10), bevel=0.01)
    m.box((0.1, 0.02, 0.03), k["dark"], at=(0.2, -0.2, -0.26), rot=(-17, 0, 10), bevel=0.006)
    low = m.to_object()
    # The screen lies on the cuff's top face, its top toward the wrist: lifted to the eye, the
    # forearm points away, so that reads upright.
    cuff_rot = geo.place((0, 0, 0), (-17, 0, 10)).to_3x3()
    cuff_top = Vector((0.2, -0.27, -0.272)) + cuff_rot @ Vector((0, 0, 0.0245))
    cuff_frame = frame(cuff_top, cuff_rot @ Vector((0, 0, 1)), up=cuff_rot @ Vector((0, -1, 0)), lift=0.0)
    screen = geo.screen("screen_cuff", 0.07, 0.085, cuff_frame, bulge=0.003, grid=(2, 2))
    screen.vertex_groups.new(name="forearm.L").add(list(range(len(screen.data.vertices))), 1.0, "REPLACE")
    for i, lamp in enumerate(("green_lit", "amber_lit", "red_lit")):
        d.polygon([(-0.005, -0.004), (0.005, -0.004), (0.005, 0.004), (-0.005, 0.004)], dk[lamp],
                  frame((0.245, -0.25 - i * 0.02, -0.27), (1, 0, 0.3), up=(0, -1, 0), lift=0.001))
    skeleton = rig.armature("arms_rig", ARM_BONES)
    rig.bind(low, skeleton)
    rig.bind(screen, skeleton)
    grip = _bone_socket(skeleton, "SOCKET_grip", "hand.R", GRIP)
    axes = cuff_frame.to_3x3()
    reach = _arm_cuff_pose(skeleton, cuff_top, axes @ Vector((0, -1, 0)), axes @ Vector((0, 0, 1)))
    print(f"ch_arms cuff pose: {reach}")
    _arm_clips(skeleton, reach)
    return Model(low=low, decals=[d.to_object()], extras=[skeleton, screen, grip])


# The middle of the right fist, where a held item's grip goes.
GRIP = (-0.165, -0.43, -0.25)


def _arm_cuff_pose(skeleton, centre, normal, up):
    """Reading the cuff: the left forearm lifted in front, low and left of centre, its screen square
    to the eye and upright, near enough to fill a good part of the view. Solved for what it
    achieves, from the camera's point of view (the origin, looking -Y, up +Z, right -X)."""
    # The eye, in the arms' space: the game sets the view model 6 cm up and 2 cm back.
    eye = Vector((0.0, -0.02, -0.06))
    target = eye + Vector((0.07, -0.26, -0.1))

    def angles(x):
        # The shoulder may lift and come forward (centimetres, in the bone's own axes).
        return {"arm.L": tuple(x[0:3]) + tuple(v / 100 for v in x[9:12]), "forearm.L": tuple(x[3:6]), "hand.L": tuple(x[6:9])}

    def cost(x):
        m = rig.pose_matrices(skeleton, angles(x))
        c = rig.deform(skeleton, m, "forearm.L", centre)
        n = rig.deform(skeleton, m, "forearm.L", normal, direction=True)
        u = rig.deform(skeleton, m, "forearm.L", up, direction=True)
        facing = 1 - n.dot((eye - c).normalized())
        upright = 1 - Vector((u.x, u.z)).normalized().y
        place = (c - target).length_squared / 0.01 ** 2
        # Keep the hand out of the middle of the view.
        tail = m["hand.L"] @ Vector((0, skeleton.data.bones["hand.L"].length, 0)) - eye
        central = max(0.0, 0.2 - math.hypot(tail.x, tail.z) / max(0.05, -tail.y)) * 10
        limits = (sum(max(0.0, abs(a) - 110) ** 2 for a in x[:6]) + sum(max(0.0, abs(a) - 50) ** 2 for a in x[6:9])
                  + sum(max(0.0, abs(a) - 12) ** 2 for a in x[9:12]) * 10) / 100
        return 8 * facing + 3 * upright + place + central + limits

    best = None
    for start in ([-13, 0, -17, -4, -12, -6, 0, 0, 0, 0, 0, 0], [-40, 10, -30, -40, -40, 0, 20, 0, 0, 0, 5, 0],
                  [-60, -20, -10, -50, 20, 10, -20, 0, 0, 0, 0, 5], [20, 30, -40, 40, 0, 30, 0, 0, 0, 5, 0, 0]):
        x, score = rig.solve(cost, start, step=20.0, iterations=5000)
        if best is None or score < best[1]:
            best = (x, score)
    print(f"ch_arms cuff solve: score {best[1]:.4f}")
    return {name: tuple(round(a, 2) for a in rot) for name, rot in angles(best[0]).items()}


def _arm_clips(skeleton, reach):
    def idle(t):
        b = rig.wave(t)
        return {"root": (0.8 * b, 0, 0), "arm.L": (1.5 * b, 0, 0), "arm.R": (1.5 * rig.wave(t, 1, 0.2), 0, 0)}

    # Walk and run are one stride cycle in a second, in step with the body's (player.gd): the arms
    # dip at each footfall (twice a cycle) and sway with the stride.
    def walk(t):
        step = math.cos(4 * math.pi * t)
        return {"root": (1.2 * step, 1.0 * math.sin(math.tau * t), 0), "arm.L": (3 * math.cos(math.tau * t), 0, 0),
                "arm.R": (2 * math.cos(math.tau * t + math.pi), 0, 0)}

    def run(t):
        step = math.cos(4 * math.pi * t)
        sway = math.sin(math.tau * t)
        return {"root": (3.2 * step, 2.5 * sway, 2.0 * sway), "arm.L": (11 * math.cos(math.tau * t), 0, 3 * sway),
                "forearm.L": (8 * math.cos(math.tau * t), 0, 0), "arm.R": (5 * math.cos(math.tau * t + math.pi), 0, 0),
                "forearm.R": (-4 * step, 0, 0)}

    def cuff(t):
        b = rig.wave(t)
        pose = {name: (rot[0] + b * 0.6, *rot[1:]) for name, rot in reach.items()}
        pose["arm.R"] = (-6, 0, 0)
        return pose

    def carry(t):
        b = rig.wave(t, 2)
        return {"arm.L": (-10 + 2 * b, 0, -18), "arm.R": (-10 + 2 * b, 0, 18), "forearm.L": (15, 0, -25), "forearm.R": (15, 0, 25),
                "hand.L": (0, 0, -30), "hand.R": (0, 0, 30)}

    def swing(t):
        wind = max(0.0, 1 - t * 3)
        hit = min(1.0, max(0.0, (t - 0.3) * 4)) * max(0.0, 1 - (t - 0.55) * 3)
        return {"arm.R": (40 * wind - 55 * hit, 0, 25 * wind - 20 * hit), "forearm.R": (35 * wind - 20 * hit, 0, 0)}

    rig.clip(skeleton, "idle", 3.0, idle, smooth=True)
    rig.clip(skeleton, "walk", 1.0, walk, smooth=True)
    rig.clip(skeleton, "run", 1.0, run, smooth=True)
    rig.clip(skeleton, "cuff", 2.0, cuff, smooth=True)
    rig.clip(skeleton, "carry", 1.0, carry, smooth=True)
    rig.clip(skeleton, "swing", 0.6, swing, loop=False, smooth=True)
