"""The crew (GDD §9, §10): the EVA suit every player wears, seen by the others, and the first-person
arms each player sees of themselves. PSX-style rigid segments on a skeleton (lib/rig.py), clips
at 12 fps. Faces -Y in Blender (+Z in Godot; the player turns it to face -Z).
"""

import math

import bpy
from mathutils import Vector

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

    skeleton = rig.armature("suit_rig", SUIT_BONES)
    rig.bind(low, skeleton)
    rig.bind(lights_obj, skeleton)
    _suit_clips(skeleton)
    return Model(low=low, decals=[d.to_object()] + texts, extras=[skeleton, lights_obj])


def _legs(t, swing, bend, phase=0.0):
    """Walking legs: thighs swing opposite, shins bend on the back swing."""
    a = rig.wave(t, 1, phase)
    b = rig.wave(t, 1, phase + 0.5)
    return {
        "thigh.L": (-swing * a, 0, 0), "thigh.R": (-swing * b, 0, 0),
        "shin.L": (bend * max(0.0, a), 0, 0), "shin.R": (bend * max(0.0, b), 0, 0),
        "foot.L": (-bend * 0.3 * max(0.0, -a), 0, 0), "foot.R": (-bend * 0.3 * max(0.0, -b), 0, 0),
    }


def _suit_clips(skeleton):
    def idle(t):
        breath = rig.wave(t)
        return {"chest": (1.5 * breath, 0, 0), "head": (-1.0 * breath, 3 * rig.wave(t, 0.5), 0),
                "upper_arm.L": (2 * breath, 0, 4), "upper_arm.R": (2 * breath, 0, -4),
                "forearm.L": (-8, 0, 0), "forearm.R": (-8, 0, 0)}

    def walk(t):
        pose = _legs(t, 22, 35)
        pose.update({"upper_arm.L": (16 * rig.wave(t, 1, 0.5), 0, 4), "upper_arm.R": (16 * rig.wave(t), 0, -4),
                     "forearm.L": (-14, 0, 0), "forearm.R": (-14, 0, 0), "spine": (3, 4 * rig.wave(t), 0),
                     "chest": (2, -3 * rig.wave(t), 0), "root_location": (0, 0, 0.025 * abs(rig.wave(t, 2)))})
        return pose

    def run(t):
        pose = _legs(t, 34, 60)
        pose.update({"upper_arm.L": (30 * rig.wave(t, 1, 0.5), 0, 6), "upper_arm.R": (30 * rig.wave(t), 0, -6),
                     "forearm.L": (-45, 0, 0), "forearm.R": (-45, 0, 0), "spine": (10, 6 * rig.wave(t), 0),
                     "chest": (5, -5 * rig.wave(t), 0), "root_location": (0, 0, 0.05 * abs(rig.wave(t, 2)))})
        return pose

    def crouch(t):
        pose = _legs(t, 12, 20)
        for side in ("L", "R"):
            thigh = pose[f"thigh.{side}"]
            pose[f"thigh.{side}"] = (thigh[0] - 55, 0, 0)
            pose[f"shin.{side}"] = (pose[f"shin.{side}"][0] + 85, 0, 0)
            pose[f"foot.{side}"] = (-30, 0, 0)
        pose.update({"spine": (25, 0, 0), "chest": (10, 0, 0), "head": (-25, 0, 0),
                     "upper_arm.L": (-15, 0, 8), "upper_arm.R": (-15, 0, -8), "forearm.L": (-40, 0, 0), "forearm.R": (-40, 0, 0),
                     "root_location": (0, 0, -0.42)})
        return pose

    def carry(t):
        pose = _legs(t, 16, 25)
        pose.update({"upper_arm.L": (-55, 0, 12), "upper_arm.R": (-55, 0, -12), "forearm.L": (-50, 0, -10),
                     "forearm.R": (-50, 0, 10), "spine": (-4, 0, 0), "root_location": (0, 0, 0.015 * abs(rig.wave(t, 2)))})
        return pose

    def death(t):
        e = min(1.0, t * 1.6)
        fall = max(0.0, (t - 0.35) / 0.65)
        return {"shin.L": (70 * e, 0, 0), "shin.R": (60 * e, 0, 0), "thigh.L": (-50 * e, 0, 5), "thigh.R": (-40 * e, 0, -5),
                "spine": (30 * e, 0, 0), "chest": (20 * e, 0, 0), "head": (-30 * e, 15 * e, 0),
                "upper_arm.L": (40 * e, 0, 30 * e), "upper_arm.R": (50 * e, 0, -25 * e),
                "root": (85 * fall, 0, 0), "root_location": (0, -0.55 * fall, -0.25 * e)}

    rig.clip(skeleton, "idle", 2.0, idle)
    rig.clip(skeleton, "walk", 0.9, walk)
    rig.clip(skeleton, "run", 0.6, run)
    rig.clip(skeleton, "crouch", 1.2, crouch)
    rig.clip(skeleton, "carry", 1.0, carry)
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
    (at the origin, looking -Y). Cream suit sleeves with orange bands, dark gloves; the right hand
    grips whatever's held (`SOCKET_grip`, follows hand.R); on the left forearm, the WRIST CUFF, a
    chunky device with its own small CRT (`screen_cuff`) the player raises to read vitals and O2."""
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
        m.bone(f"hand.{side}")
        m.box((0.075, 0.1, 0.06), k["dark"], at=(sx * 0.165, -0.42, -0.255), rot=(-8, 0, sx * 8), bevel=0.015)
        for i in range(4):
            m.box((0.017, 0.05, 0.02), k["dark"], at=(sx * (0.14 + i * 0.017), -0.48, -0.27), rot=(40, 0, 0), bevel=0.004)
        m.box((0.022, 0.05, 0.022), k["dark"], at=(sx * 0.2, -0.43, -0.245), rot=(0, 0, sx * 35), bevel=0.005)
    # The wrist cuff on the left forearm: a chunky box, a hinged visor lip over its little screen.
    m.bone("forearm.L")
    m.box((0.09, 0.13, 0.045), k["hard"], at=(0.2, -0.27, -0.272), rot=(-17, 0, 10), bevel=0.01)
    m.box((0.1, 0.02, 0.03), k["dark"], at=(0.2, -0.2, -0.26), rot=(-17, 0, 10), bevel=0.006)
    low = m.to_object()
    # The screen lies on the cuff's top face: the cuff's own tilt, turned so the screen faces out.
    cuff_rot = geo.place((0, 0, 0), (-17, 0, 10))
    cuff_top = Vector((0.2, -0.27, -0.272)) + cuff_rot.to_3x3() @ Vector((0, 0, 0.0245))
    cuff_frame = geo.place(cuff_top, (-107, 0, 10))
    screen = geo.screen("screen_cuff", 0.07, 0.085, cuff_frame, bulge=0.003, grid=(2, 2))
    screen.vertex_groups.new(name="forearm.L").add(list(range(len(screen.data.vertices))), 1.0, "REPLACE")
    for i, lamp in enumerate(("green_lit", "amber_lit", "red_lit")):
        d.polygon([(-0.005, -0.004), (0.005, -0.004), (0.005, 0.004), (-0.005, 0.004)], dk[lamp],
                  frame((0.245, -0.25 - i * 0.02, -0.27), (1, 0, 0.3), up=(0, -1, 0), lift=0.001))
    skeleton = rig.armature("arms_rig", ARM_BONES)
    rig.bind(low, skeleton)
    rig.bind(screen, skeleton)
    grip = bpy.data.objects.new("SOCKET_grip", None)
    bpy.context.scene.collection.objects.link(grip)
    grip.parent = skeleton
    grip.parent_type = "BONE"
    grip.parent_bone = "hand.R"
    grip.location = (0.0, 0.06, -0.015)
    _arm_clips(skeleton)
    return Model(low=low, decals=[d.to_object()], extras=[skeleton, screen, grip])


def _arm_clips(skeleton):
    def idle(t):
        b = rig.wave(t)
        return {"root": (0.8 * b, 0, 0), "arm.L": (1.5 * b, 0, 0), "arm.R": (1.5 * rig.wave(t, 1, 0.2), 0, 0)}

    def walk(t):
        b = rig.wave(t, 2)
        return {"root": (1.5 * b, 1.5 * rig.wave(t), 0), "arm.L": (4 * rig.wave(t, 1, 0.5), 0, 0), "arm.R": (3 * rig.wave(t), 0, 0)}

    # Reading the cuff: the left forearm lifted and turned in, like glancing at a wristwatch, so
    # its screen sits in the lower left of view. (Found by rendering from the camera; IK put the
    # arm across the face, which hid more than it showed.)
    reach = {"arm.L": (-13, 0, -17), "forearm.L": (-4, -12, -6)}

    def cuff_raise(t):
        e = min(1.0, t * 1.3)
        e = e * e * (3 - 2 * e)
        pose = {name: tuple(a * e for a in rot) for name, rot in reach.items()}
        pose["arm.R"] = (-8 * e, 0, 0)
        return pose

    def cuff_hold(t):
        b = rig.wave(t)
        pose = {name: (rot[0] + b * 0.8, rot[1], rot[2]) for name, rot in reach.items()}
        pose["arm.R"] = (-8, 0, 0)
        return pose

    def carry(t):
        b = rig.wave(t, 2)
        return {"arm.L": (-10 + 2 * b, 0, -18), "arm.R": (-10 + 2 * b, 0, 18), "forearm.L": (15, 0, -25), "forearm.R": (15, 0, 25),
                "hand.L": (0, 0, -30), "hand.R": (0, 0, 30)}

    def swing(t):
        wind = max(0.0, 1 - t * 3)
        hit = min(1.0, max(0.0, (t - 0.3) * 4)) * max(0.0, 1 - (t - 0.55) * 3)
        return {"arm.R": (40 * wind - 55 * hit, 0, 25 * wind - 20 * hit), "forearm.R": (35 * wind - 20 * hit, 0, 0)}

    rig.clip(skeleton, "idle", 3.0, idle)
    rig.clip(skeleton, "walk", 0.9, walk)
    rig.clip(skeleton, "cuff_raise", 0.4, cuff_raise, loop=False)
    rig.clip(skeleton, "cuff_hold", 2.0, cuff_hold)
    rig.clip(skeleton, "carry", 1.0, carry)
    rig.clip(skeleton, "swing", 0.6, swing, loop=False)
