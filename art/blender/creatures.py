"""The things living in the derelicts (GDD §12): few, singular, and remembered. Rigid PSX segments
on skeletons (lib/rig.py), clips at 12 fps. Wet, fleshy, bone-white bodies with faint
bioluminescent sacs, so in the dark a creature is sometimes glimpsed before it's seen.
Face -Y in Blender (+Z in Godot).
"""

import math

from mathutils import Vector

import bridge as br
from lib import Model, asset, geo, mats, rig
from lib.geo import Mesh, frame


def _flesh():
    return dict(
        flesh=mats.plain("cr_flesh", (0.6, 0.48, 0.46), grime=0.5, variation=0.12, detail="PaintedMetal013", detail_strength=0.25),
        pale=mats.plain("cr_pale", (0.78, 0.72, 0.66), grime=0.45, variation=0.1, detail_strength=0.3),
        bone=mats.plain("cr_bone", (0.86, 0.82, 0.72), grime=0.4, variation=0.06),
        dark=mats.plain("cr_dark", (0.12, 0.06, 0.06), grime=0.2),
        wet=mats.paint("cr_wet", (0.45, 0.2, 0.2), wear=0.0, grime=0.3, variation=0.15),
        sac=mats.glowing("cr_sac", (0.35, 0.9, 1.0), base=(0.15, 0.3, 0.35), flicker=0.4),
        scrap=mats.plain("cr_scrap", (0.7, 0.66, 0.56), grime=0.6, detail_strength=0.35),
        orange=mats.paint("cr_orange", (0.7, 0.36, 0.1), wear=0.6, grime=0.55),
    )


CRAWLER_BONES = [
    ("root", (0, 0, 0), (0, 0, 0.2), None),
    ("pelvis", (0, 0.55, 0.58), (0, 0.3, 0.64), "root"),
    ("spine", (0, 0.3, 0.64), (0, -0.05, 0.72), "pelvis"),
    ("chest", (0, -0.05, 0.72), (0, -0.4, 0.74), "spine"),
    ("neck", (0, -0.4, 0.74), (0, -0.7, 0.68), "chest"),
    ("head", (0, -0.7, 0.68), (0, -1.05, 0.6), "neck"),
    ("jaw", (0, -0.72, 0.62), (0, -1.0, 0.52), "head"),
]
for _side, _sx in (("L", 1), ("R", -1)):
    CRAWLER_BONES += [
        (f"upper_arm.{_side}", (_sx * 0.17, -0.35, 0.72), (_sx * 0.32, -0.55, 0.45), "chest"),
        (f"forearm.{_side}", (_sx * 0.32, -0.55, 0.45), (_sx * 0.3, -0.78, 0.06), f"upper_arm.{_side}"),
        (f"hand.{_side}", (_sx * 0.3, -0.78, 0.06), (_sx * 0.3, -0.98, 0.0), f"forearm.{_side}"),
        (f"thigh.{_side}", (_sx * 0.13, 0.52, 0.56), (_sx * 0.2, 0.3, 0.32), "pelvis"),
        (f"shin.{_side}", (_sx * 0.2, 0.3, 0.32), (_sx * 0.2, 0.6, 0.14), f"thigh.{_side}"),
        (f"foot.{_side}", (_sx * 0.2, 0.6, 0.14), (_sx * 0.2, 0.52, 0.0), f"shin.{_side}"),
    ]


def _segment(m, a, b, r_a, r_b, material, sides=6):
    """A tapered limb segment from a to b (a short swept tube)."""
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2
    m.pipe([a, mid, b], (r_a + r_b) / 2, material, sides=sides)


@asset("cr_crawler", "creatures", texture=256, colors=32, ao=0.55)
def crawler():
    """THE CRAWLER (GDD §12): the sound hunter. ~2 m long on all fours, eyeless, maybe once crew.
    Organic, not mechanical: a hunched torso of grey-pink skin pulled tight over a ribcage that
    bulges and a waist that pinches in, knuckled vertebrae down an arched spine, a long neck, a
    swollen eyeless skull tapering to a narrow snout with a slack jaw of teeth; very long front
    limbs ending in three hooked fingers, digitigrade hind legs. Cyan sacs glow faintly down its
    spine. Rags of a crew suit hang off its shoulders, and a dead spine-light module is still grown
    into its back. ~1000 triangles."""
    k = _flesh()
    dk = br._decals()
    m = Mesh("cr_crawler")
    d = Mesh("cr_crawler_decals")
    # Torso: three tapered sections along the arched spine (each lathe runs along -Y, flattened).
    m.bone("pelvis")
    m.lathe([(0.05, 0.0), (0.1, 0.06), (0.11, 0.16), (0.08, 0.26)], k["flesh"], sides=7, at=(0, 0.62, 0.6),
            rot=(90 + 12, 0, 0), scale=(1.0, 1.0, 0.85))
    m.bone("spine")
    m.lathe([(0.075, 0.0), (0.065, 0.12), (0.09, 0.28), (0.12, 0.36)], k["flesh"], sides=7, at=(0, 0.38, 0.66),
            rot=(90 + 8, 0, 0), scale=(1.0, 1.0, 0.85))
    m.bone("chest")
    m.lathe([(0.12, 0.0), (0.16, 0.1), (0.165, 0.22), (0.13, 0.34), (0.08, 0.42)], k["pale"], sides=7, at=(0, 0.0, 0.72),
            rot=(90 - 2, 0, 0), scale=(1.05, 1.0, 0.9))
    # Ribs sagging out of the skin, vertebrae knuckled along the top.
    for i in range(4):
        y = -0.05 - i * 0.08
        for sx in (-1, 1):
            m.pipe([(sx * 0.03, y, 0.86), (sx * 0.17, y - 0.02, 0.78), (sx * 0.14, y - 0.03, 0.62)], 0.01, k["bone"], sides=3, caps=False)
    for i, (y, z, bone) in enumerate(((0.52, 0.71, "pelvis"), (0.36, 0.74, "spine"), (0.2, 0.77, "spine"), (0.04, 0.84, "chest"),
                                     (-0.12, 0.87, "chest"), (-0.28, 0.86, "chest"))):
        m.bone(bone)
        m.box((0.04, 0.05, 0.045), k["bone"], at=(0, y, z))
    # Glowing sacs, the dead module, suit rags.
    for i, (y, z, bone) in enumerate(((0.44, 0.72, "pelvis"), (0.28, 0.75, "spine"), (0.12, 0.79, "spine"), (-0.2, 0.86, "chest"))):
        m.bone(bone)
        m.lathe([(0.0, 0.0), (0.028, 0.012), (0.03, 0.04), (0.0, 0.06)], k["sac"], sides=5, at=(0.055 * (1 if i % 2 else -1), y, z - 0.02))
    m.bone("chest")
    m.box((0.11, 0.05, 0.09), k["orange"], at=(0.0, -0.02, 0.86), rot=(-20, 0, 0))
    for sx in (-1, 1):
        m.box((0.17, 0.2, 0.012), k["scrap"], at=(sx * 0.15, -0.3, 0.84), rot=(12, sx * 32, 0))
        m.box((0.05, 0.012, 0.18), k["scrap"], at=(sx * 0.2, -0.36, 0.72), rot=(0, sx * 12, 0))
    # Neck.
    m.bone("neck")
    m.lathe([(0.075, 0.0), (0.06, 0.12), (0.045, 0.28), (0.05, 0.33)], k["flesh"], sides=6, at=(0, -0.38, 0.76), rot=(90 + 14, 0, 0))
    # Skull: swollen cranium tapering to a narrow snout, eyeless, pitted.
    m.bone("head")
    m.lathe([(0.0, 0.0), (0.07, 0.02), (0.1, 0.09), (0.095, 0.17), (0.065, 0.27), (0.04, 0.34), (0.02, 0.38), (0.0, 0.39)],
            k["bone"], sides=6, at=(0, -0.66, 0.7), rot=(90 + 10, 0, 0), scale=(0.9, 1.0, 0.75))
    for x in (-0.045, 0.045):
        for j in range(3):
            d.polygon([(-0.009, -0.009), (0.009, -0.009), (0.009, 0.009), (-0.009, 0.009)], dk["black"],
                      frame((x, -0.76 - j * 0.05, 0.772 - j * 0.01), (0, -0.1, 1), up=(0, 1, 0), lift=0.004))
    # Jaw: slack, wet inside, teeth.
    m.bone("jaw")
    m.lathe([(0.0, 0.0), (0.06, 0.02), (0.05, 0.16), (0.02, 0.3), (0.0, 0.31)], k["bone"], sides=5, at=(0, -0.7, 0.62),
            rot=(90 + 24, 0, 0), scale=(0.9, 1.0, 0.45))
    m.box((0.06, 0.2, 0.012), k["wet"], at=(0, -0.83, 0.62), rot=(-12, 0, 0))
    for i in range(4):
        for sx in (-1, 1):
            m.cylinder(0.008, 0.04, k["bone"], sides=3, at=(sx * 0.035, -0.76 - i * 0.05, 0.645 - i * 0.012), radius_top=0.001)
    # Front limbs: very long, knuckled, three hooked fingers.
    for side, sx in (("L", 1), ("R", -1)):
        m.bone(f"upper_arm.{side}")
        m.pipe([(sx * 0.17, -0.35, 0.72), (sx * 0.32, -0.55, 0.45)], 0.04, k["flesh"], sides=5)
        m.box((0.045, 0.045, 0.045), k["bone"], at=(sx * 0.32, -0.55, 0.45))
        m.bone(f"forearm.{side}")
        m.pipe([(sx * 0.32, -0.55, 0.45), (sx * 0.3, -0.78, 0.07)], 0.026, k["pale"], sides=4)
        m.bone(f"hand.{side}")
        m.box((0.065, 0.07, 0.025), k["pale"], at=(sx * 0.3, -0.8, 0.04))
        for f in (-1, 0, 1):
            m.pipe([(sx * 0.3 + f * 0.022, -0.83, 0.04), (sx * 0.3 + f * 0.03, -0.92, 0.03), (sx * 0.3 + f * 0.032, -0.98, 0.0)],
                   0.007, k["bone"], sides=3)
    # Hind legs: digitigrade.
    for side, sx in (("L", 1), ("R", -1)):
        m.bone(f"thigh.{side}")
        m.pipe([(sx * 0.13, 0.52, 0.56), (sx * 0.2, 0.3, 0.32)], 0.05, k["flesh"], sides=5)
        m.bone(f"shin.{side}")
        m.pipe([(sx * 0.2, 0.3, 0.32), (sx * 0.2, 0.6, 0.14)], 0.03, k["pale"], sides=4)
        m.box((0.04, 0.045, 0.045), k["bone"], at=(sx * 0.2, 0.3, 0.32))
        m.bone(f"foot.{side}")
        m.pipe([(sx * 0.2, 0.6, 0.14), (sx * 0.2, 0.52, 0.01)], 0.022, k["pale"], sides=4)
        for f in (-1, 1):
            m.pipe([(sx * 0.2 + f * 0.02, 0.52, 0.01), (sx * 0.2 + f * 0.03, 0.44, 0.0)], 0.008, k["bone"], sides=3)
    low = m.to_object()
    skeleton = rig.armature("crawler_rig", CRAWLER_BONES)
    rig.bind(low, skeleton)
    _crawler_clips(skeleton)
    return Model(low=low, decals=[d.to_object()], extras=[skeleton])


def _crawler_clips(skeleton):
    def gait(t, stride, lift):
        """Diagonal pairs: front-left with hind-right, then the other pair."""
        a = rig.wave(t)
        b = -a
        pose = {}
        for side, s in (("L", a), ("R", b)):
            pose[f"upper_arm.{side}"] = (-stride * s, 0, 0)
            pose[f"forearm.{side}"] = (lift * max(0.0, s), 0, 0)
        for side, s in (("L", b), ("R", a)):
            pose[f"thigh.{side}"] = (-stride * 0.8 * s, 0, 0)
            pose[f"shin.{side}"] = (-lift * 0.7 * max(0.0, s), 0, 0)
        return pose

    def idle(t):
        twitch = 1.0 if 0.6 < t < 0.66 else 0.0
        return {"chest": (2 * rig.wave(t), 0, 0), "neck": (-3 * rig.wave(t), 6 * rig.wave(t, 0.5), 0),
                "head": (4 * twitch, -10 * twitch, 0), "jaw": (6 + 4 * rig.wave(t, 2), 0, 0)}

    def crawl(t):
        pose = gait(t, 22, 30)
        pose.update({"spine": (0, 5 * rig.wave(t), 0), "chest": (0, -6 * rig.wave(t), 0), "neck": (0, 4 * rig.wave(t, 1, 0.25), 0),
                     "root_location": (0, 0, 0.03 * abs(rig.wave(t, 2)))})
        return pose

    def investigate(t):
        sweep = rig.wave(t)
        return {"neck": (-8, 30 * sweep, 0), "head": (-10, 15 * sweep, 0), "jaw": (12 * abs(sweep), 0, 0),
                "chest": (-4, 6 * sweep, 0)}

    def lunge(t):
        coil = min(1.0, t / 0.35)
        spring = max(0.0, (t - 0.35) / 0.65)
        return {"thigh.L": (-30 * coil + 50 * spring, 0, 0), "thigh.R": (-30 * coil + 50 * spring, 0, 0),
                "shin.L": (-25 * coil + 30 * spring, 0, 0), "shin.R": (-25 * coil + 30 * spring, 0, 0),
                "upper_arm.L": (20 * coil - 70 * spring, 0, 10), "upper_arm.R": (20 * coil - 70 * spring, 0, -10),
                "chest": (8 * coil - 25 * spring, 0, 0), "neck": (-10 * spring, 0, 0), "jaw": (35 * spring, 0, 0),
                "root_location": (0, -1.6 * spring, 0.25 * math.sin(spring * math.pi) - 0.08 * coil)}

    def attack(t):
        swipe = math.sin(t * math.pi)
        return {"upper_arm.R": (-60 * swipe, 0, -30 * swipe), "forearm.R": (-40 * swipe, 0, 0),
                "upper_arm.L": (-20 * swipe, 0, 10), "jaw": (40 * swipe, 0, 0), "neck": (-15 * swipe, -10 * swipe, 0),
                "chest": (-10 * swipe, 0, 0)}

    def death(t):
        e = min(1.0, t * 1.5)
        # Collapsing flat: limbs splayed out from under it, belly down on the deck.
        return {"upper_arm.L": (30 * e, 0, 70 * e), "upper_arm.R": (30 * e, 0, -70 * e), "forearm.L": (40 * e, 0, 0),
                "forearm.R": (40 * e, 0, 0), "thigh.L": (20 * e, 0, 65 * e), "thigh.R": (20 * e, 0, -65 * e),
                "shin.L": (-30 * e, 0, 0), "shin.R": (-30 * e, 0, 0),
                "neck": (25 * e, 20 * e, 0), "head": (15 * e, 0, 20 * e), "jaw": (30 * e, 0, 0),
                "root_location": (0, 0, -0.3 * e), "chest": (0, 0, 10 * e)}

    rig.clip(skeleton, "idle", 2.4, idle)
    rig.clip(skeleton, "crawl", 1.0, crawl)
    rig.clip(skeleton, "investigate", 2.0, investigate)
    rig.clip(skeleton, "lunge", 0.7, lunge, loop=False)
    rig.clip(skeleton, "attack", 0.5, attack, loop=False)
    rig.clip(skeleton, "death", 1.2, death, loop=False)


TENDRILS = 7
TENDRIL_SEGMENTS = 4
TENDRIL_LENGTH = 2.3


def _hanger_bones():
    bones = [("root", (0, 0, 0), (0, 0, -0.2), None), ("body", (0, 0, -0.1), (0, 0, -0.6), "root")]
    for i in range(TENDRILS):
        a = i / TENDRILS * math.tau
        x, y = math.cos(a) * 0.18, math.sin(a) * 0.18
        parent = "body"
        seg = TENDRIL_LENGTH / TENDRIL_SEGMENTS
        for j in range(TENDRIL_SEGMENTS):
            name = f"tendril_{i}_{j}"
            bones.append((name, (x, y, -0.6 - j * seg), (x, y, -0.6 - (j + 1) * seg), parent))
            parent = name
    return bones


@asset("cr_hanger", "creatures", texture=256, colors=32, ao=0.55, angles=((-30, -15), (150, -10), (90, -5), (-20, -50)))
def hanger():
    """THE HANGER (GDD §12): the ceiling trap. A bulbous sac of wet flesh gripping the ceiling with
    six hooked legs, a puckered maw underneath, and seven long translucent tendrils hanging nearly
    to the floor, each ending in a faintly glowing bead. They're only visible in a flashlight beam.
    Touch one and it snaps up. Built hanging from z = 0 (the ceiling)."""
    k = _flesh()
    tendril = mats.glowing("cr_tendril", (0.85, 0.75, 0.78), base=(0.55, 0.45, 0.48), flicker=0.2)
    bead = mats.glowing("cr_bead", (0.4, 0.95, 1.0), base=(0.2, 0.4, 0.45), flicker=0.5)
    m = Mesh("cr_hanger")
    m.bone("root")
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        c, s = math.cos(a), math.sin(a)
        m.pipe([(c * 0.2, s * 0.2, -0.25), (c * 0.42, s * 0.42, -0.12), (c * 0.55, s * 0.55, -0.02)], 0.03, k["pale"], sides=5)
        m.pipe([(c * 0.55, s * 0.55, -0.02), (c * 0.62, s * 0.62, 0.0)], 0.018, k["bone"], sides=4)
    m.bone("body")
    m.lathe([(0.0, -0.02), (0.22, -0.06), (0.36, -0.2), (0.4, -0.36), (0.34, -0.5), (0.2, -0.6), (0.08, -0.64), (0.0, -0.62)],
            k["flesh"], sides=10)
    for i in range(5):
        a = i / 5 * math.tau
        m.lathe([(0.0, 0.0), (0.05, 0.01), (0.06, 0.05), (0.03, 0.09), (0.0, 0.1)], k["sac"], sides=6,
                at=(math.cos(a) * 0.3, math.sin(a) * 0.3, -0.42))
    m.lathe([(0.1, -0.6), (0.06, -0.66), (0.02, -0.64)], k["wet"], sides=8, cap_end=False)
    seg = TENDRIL_LENGTH / TENDRIL_SEGMENTS
    for i in range(TENDRILS):
        a = i / TENDRILS * math.tau
        x, y = math.cos(a) * 0.18, math.sin(a) * 0.18
        for j in range(TENDRIL_SEGMENTS):
            m.bone(f"tendril_{i}_{j}")
            r0 = 0.022 - j * 0.004
            m.pipe([(x, y, -0.58 - j * seg), (x, y, -0.6 - (j + 1) * seg - 0.01)], r0, tendril, sides=4)
        m.lathe([(0.0, 0.0), (0.025, 0.015), (0.025, 0.04), (0.0, 0.055)], bead, sides=5,
                at=(x, y, -0.6 - TENDRIL_LENGTH - 0.05))
    low = m.to_object()
    skeleton = rig.armature("hanger_rig", _hanger_bones())
    rig.bind(low, skeleton)
    _hanger_clips(skeleton)
    return Model(low=low, decals=[], extras=[skeleton])


def _hanger_clips(skeleton):
    def idle(t):
        pose = {"body": (0, 0, 4 * rig.wave(t))}
        for i in range(TENDRILS):
            for j in range(TENDRIL_SEGMENTS):
                pose[f"tendril_{i}_{j}"] = (3 * rig.wave(t, 1, i / TENDRILS + j * 0.15), 0, 3 * rig.wave(t, 1, i / TENDRILS + 0.3))
        return pose

    def grab(t):
        e = min(1.0, t * 3)
        pose = {"body": (0, 0, 20 * e)}
        for i in range(TENDRILS):
            for j in range(TENDRIL_SEGMENTS):
                pose[f"tendril_{i}_{j}"] = (35 * e * (1 + j * 0.3), 0, 15 * e * rig.wave(0.2, 1, i / TENDRILS))
        return pose

    rig.clip(skeleton, "idle", 3.0, idle)
    rig.clip(skeleton, "grab", 0.6, grab, loop=False)
