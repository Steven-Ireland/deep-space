"""What the earlier waves left behind (GDD §3, §8): pieces that only appear in derelicts. Decay and
damage over the LANTERN's own tech language (the kit's dk_* variants are in station_kit.py):
breached walls, debris, hanging cable spills, emergency strobes, the breaker boxes that bring a
dead section back, alien growth, and the Prize.
"""

import math

from mathutils import Vector

import bridge as br
import station_kit as kit
from lib import Model, asset, geo, mats
from lib.geo import Mesh, clip, frame

FRONT = Vector((0, -1, 0))


def _socket(name, at):
    import bpy
    e = bpy.data.objects.new(f"SOCKET_{name}", None)
    e.location = at
    bpy.context.scene.collection.objects.link(e)
    return e


@asset("dk_wall_breach", "derelict", texture=256, colors=32, ao=0.55)
def wall_breach():
    """A derelict wall with a panel torn out: the hole shows the wall's guts (a pipe run, cable
    looms, a ruptured duct), the torn panel hangs off one corner, and wires spill to the floor."""
    kit.STYLE["name"] = "derelict"
    try:
        k = kit._materials()
        dm = kit._decal_materials()
        m = Mesh("dk_wall_breach")
        d = Mesh("dk_wall_breach_decals")
        kit.geo_text.clear()
        # The wall around a ragged opening on the -Y face only; the +Y face stays whole.
        m.box((kit.WIDTH, kit.THICK * 0.4, kit.HEIGHT), k["backing"], at=(0, kit.THICK * 0.3, kit.HEIGHT / 2))
        kit._wall_side(m, k, -kit.WIDTH / 2, kit.WIDTH / 2, 1)
        kit._chamfer(m, k, -kit.WIDTH / 2, kit.WIDTH / 2, 1)
        kit._chamfer(m, k, -kit.WIDTH / 2, kit.WIDTH / 2, -1)
        kit._wall_decals(d, dm, -kit.WIDTH / 2, kit.WIDTH / 2, 1)
        side = -1
        y = side * kit.HALF
        m.box((kit.WIDTH, 0.04, 0.32), k["kick"], at=(0, y - 0.02, 0.16), bevel=0.008)
        # Left panel intact, right panel gone: the frame around the hole, ragged edges.
        m.box((1.9, 0.025, 2.13), k["panel"], at=(-1.0, y - 0.0125, 1.415), bevel=0.006)
        m.box((0.12, 0.08, 2.13), k["frame"], at=(0.06, y + 0.02, 1.415), bevel=0.01)
        m.box((0.12, 0.08, 2.13), k["frame"], at=(1.94, y + 0.02, 1.415), bevel=0.01)
        m.box((1.9, 0.08, 0.1), k["frame"], at=(1.0, y + 0.02, 0.4), bevel=0.01)
        m.box((1.9, 0.08, 0.1), k["frame"], at=(1.0, y + 0.02, 2.43), bevel=0.01)
        # The guts: a fat pipe, a cable loom, a ruptured duct.
        m.pipe([(0.1, -0.02, 0.6), (1.9, -0.02, 0.6)], 0.07, k["steel"], sides=6)
        m.pipe([(0.1, 0.03, 1.5), (0.8, 0.0, 1.45), (1.2, -0.02, 1.2), (1.9, 0.0, 1.25)], 0.05, br._materials()["cable"], sides=5)
        m.pipe([(0.1, 0.0, 1.62), (1.1, -0.03, 1.6), (1.9, 0.02, 1.7)], 0.03, br._materials()["cable_red"], sides=4)
        m.box((1.0, 0.1, 0.3), k["steel"], at=(1.2, 0.0, 2.05), rot=(0, 4, 0), bevel=0.01)
        m.box((0.4, 0.1, 0.35), k["vent"], at=(1.55, -0.03, 2.0), rot=(0, -20, 8), bevel=0.01)
        # The torn panel, hanging off its lower corner at an angle.
        m.box((1.0, 0.025, 1.6), k["panel"], at=(1.55, y - 0.25, 0.75), rot=(10, -35, 22), bevel=0.006)
        # Wires spilling out to the floor.
        for i, (x, col) in enumerate(((0.6, "cable"), (0.75, "cable_red"), (0.9, "cable"))):
            m.pipe([(x, -0.05, 1.45), (x - 0.05, -0.25, 0.9), (x + 0.05, -0.4, 0.3), (x + 0.15, -0.55, 0.02)], 0.012,
                   br._materials()[col], sides=4)
        m.subdivide(1.0)
        low = m.to_object()
        decals = [d.to_object()] + kit.geo_text
        kit.geo_text.clear()
        collider = kit._collider("dk_wall_breach_col", (kit.WIDTH, kit.THICK, kit.HEIGHT), (0, 0, kit.HEIGHT / 2))
        return Model(low=low, decals=decals, extras=[collider])
    finally:
        kit.STYLE["name"] = "station"


@asset("dk_debris", "derelict", texture=128, colors=32, ao=0.55, angles=((-35, 35), (145, 40), (90, 15), (-20, 70)))
def debris():
    """A debris pile: a fallen ceiling panel, a buckled duct section, scattered plate fragments and
    a burst cable loom, about 1.6 m across. Blocks and hides; makes noise if kicked."""
    kit.STYLE["name"] = "derelict"
    try:
        k = kit._materials()
    finally:
        kit.STYLE["name"] = "station"
    c = br._materials()
    m = Mesh("dk_debris")
    m.box((1.4, 1.0, 0.06), k["chamfer"], at=(0.0, 0.0, 0.25), rot=(18, -8, 12), bevel=0.01)
    m.box((0.9, 0.4, 0.35), k["steel"], at=(0.45, 0.35, 0.18), rot=(0, 0, 25), bevel=0.015)
    m.box((0.5, 0.35, 0.03), k["panel"], at=(-0.5, -0.3, 0.05), rot=(4, 6, -30), bevel=0.005)
    m.box((0.35, 0.25, 0.03), k["frame"], at=(-0.2, 0.45, 0.04), rot=(-6, 3, 50), bevel=0.005)
    m.box((0.3, 0.2, 0.025), k["panel"], at=(0.6, -0.4, 0.03), rot=(2, -5, 70), bevel=0.004)
    m.pipe([(-0.7, 0.1, 0.02), (-0.3, 0.0, 0.2), (0.1, -0.2, 0.32), (0.6, -0.1, 0.05)], 0.025, c["cable"], sides=4)
    m.pipe([(-0.6, 0.3, 0.02), (-0.2, 0.25, 0.15), (0.3, 0.3, 0.38)], 0.015, c["cable_red"], sides=4)
    low = m.to_object()
    collider = br._console_collider("dk_debris", (1.5, 1.1, 0.4), (0, 0, 0.2))
    return Model(low=low, decals=[], extras=[collider])


@asset("dk_cables", "derelict", texture=64, colors=16, ao=0.5, angles=((-30, -10), (150, -10), (90, 0), (-20, -45)))
def cables():
    """A spill of cables hanging from a torn ceiling panel, drooping to head height: they brush
    the crew's helmets in the dark (and hide a Hanger's tendrils well). Hangs from z = 0."""
    c = br._materials()
    m = Mesh("dk_cables")
    m.box((0.8, 0.5, 0.04), c["casing_dark"], at=(0, 0, -0.02), rot=(0, 12, 0))
    for i in range(7):
        x = -0.3 + i * 0.1
        length = 0.9 + (i * 37 % 7) * 0.12
        sway = 0.1 * math.sin(i * 1.7)
        m.pipe([(x, 0.0, -0.02), (x + sway * 0.4, 0.05, -length * 0.4), (x + sway, -0.02, -length * 0.8), (x + sway * 1.3, 0.04, -length)],
               0.012, c["cable_red"] if i % 3 == 1 else c["cable"], sides=4)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[])


@asset("dk_strobe", "derelict", texture=64, colors=16, ao=0.5)
def strobe():
    """An emergency strobe: a wall-mounted red lens in a wire cage over a steel base. Godot pulses
    a light from it; the derelict's only light in most rooms."""
    c = br._materials()
    lens = mats.glowing("dk_strobe_lens", (1.0, 0.18, 0.1), base=(0.4, 0.05, 0.03), flicker=0.1)
    m = Mesh("dk_strobe")
    m.box((0.16, 0.06, 0.12), c["dark_steel"], at=(0, 0.03, 0), bevel=0.01)
    m.lathe([(0.0, 0.0), (0.05, 0.0), (0.05, 0.04), (0.03, 0.08), (0.0, 0.09)], lens, sides=8, at=(0, -0.0, 0), rot=(90, 0, 0))
    for a in range(4):
        ang = a / 4 * math.tau
        m.pipe([(math.cos(ang) * 0.055, -0.0, math.sin(ang) * 0.055), (math.cos(ang) * 0.055, -0.07, math.sin(ang) * 0.055),
                (0, -0.1, 0)], 0.004, c["steel"], sides=3, caps=False)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[_socket("light", (0, -0.08, 0))])


@asset("dk_breaker", "derelict", texture=128, colors=32, ao=0.55)
def breaker():
    """A section breaker box (GDD §8.3): wall-mounted, door hanging open on one hinge, a big
    two-handed knife switch (`breaker_handle`, separate: thrown to restore a dead section), a row
    of dead fuse lamps, a hazard stripe and SECTION stencilled. Throwing it brings back lights,
    doors and gravity, and wakes what was asleep."""
    c = br._materials()
    dk = br._decals()
    m = Mesh("dk_breaker")
    d = Mesh("dk_breaker_decals")
    texts = []
    m.box((0.6, 0.18, 0.8), c["casing_dark"], at=(0, 0.09, 1.3), bevel=0.015)
    m.box((0.54, 0.02, 0.74), c["bezel"], at=(0, -0.005, 1.3))
    m.box((0.58, 0.03, 0.78), c["casing"], at=(-0.58, -0.25, 1.3), rot=(0, 0, -70), bevel=0.01)  # the door, swung open
    m.box((0.3, 0.06, 0.12), c["steel"], at=(0, -0.03, 1.2), bevel=0.01)
    for i in range(5):
        d.polygon([(-0.02, -0.015), (0.02, -0.015), (0.02, 0.015), (-0.02, 0.015)], dk["unlit"], frame((-0.16 + i * 0.08, -0.016, 1.58), FRONT))
    _hazard = [(-0.25, -0.03), (0.25, -0.03), (0.25, 0.03), (-0.25, 0.03)]
    d.polygon(_hazard, dk["orange"], frame((0, -0.016, 1.0), FRONT))
    for i in range(-4, 4):
        x = i * 0.07
        d.polygon(clip([(x, -0.03), (x + 0.03, -0.03), (x + 0.06, 0.03), (x + 0.03, 0.03)], -0.25, 0.25, -0.03, 0.03), dk["black"],
                  frame((0, -0.016, 1.0), FRONT, lift=0.0015))
    texts.append(geo.text("SECTION", 0.035, dk["cream"], matrix=frame((0, -0.016, 1.47), FRONT, lift=0.002)))
    # The knife switch, baked here and split off so it can be thrown.
    m.box((0.32, 0.03, 0.03), c["steel"], at=(0, -0.09, 1.32), bevel=0.006)
    for x in (-0.13, 0.13):
        m.box((0.03, 0.08, 0.03), c["steel"], at=(x, -0.06, 1.32))
    m.box((0.2, 0.04, 0.04), br.mats.paint("dk_handle", (0.7, 0.1, 0.07), wear=0.5, grime=0.5), at=(0, -0.11, 1.32), bevel=0.012)
    low = m.to_object()

    def split(model):
        in_handle = lambda p: abs(p.x) < 0.17 and p.y < -0.075 and 1.29 < p.z < 1.35
        box, handle = geo.split_object(model.low, {"dk_breaker": lambda p: not in_handle(p), "breaker_handle": in_handle})
        model.low = box
        model.extras.append(handle)

    collider = br._console_collider("dk_breaker", (0.6, 0.2, 0.8), (0, 0.08, 1.3))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider], after_bake=split)


@asset("dk_growth", "derelict", texture=128, colors=32, ao=0.6, angles=((-35, 35), (145, 40), (90, 10), (-20, 70)))
def growth():
    """Alien growth (GDD §3, §12): a wet mound spreading over deck or wall where something nests,
    folded flesh over bone-white nodules, cyan sacs glowing in its folds, veins running out from it
    across the floor. About 1.8 m across."""
    k = dict(
        flesh=mats.plain("cr_flesh", (0.6, 0.48, 0.46), grime=0.5, variation=0.12, detail="PaintedMetal013", detail_strength=0.25),
        wet=mats.paint("cr_wet", (0.45, 0.2, 0.2), wear=0.0, grime=0.3, variation=0.15),
        bone=mats.plain("cr_bone", (0.86, 0.82, 0.72), grime=0.4, variation=0.06),
        sac=mats.glowing("cr_sac", (0.35, 0.9, 1.0), base=(0.15, 0.3, 0.35), flicker=0.4),
    )
    m = Mesh("dk_growth")
    for i, (x, y, r, h) in enumerate(((0, 0, 0.6, 0.35), (0.45, 0.25, 0.4, 0.25), (-0.4, 0.3, 0.35, 0.2), (0.2, -0.45, 0.38, 0.22),
                                     (-0.5, -0.3, 0.3, 0.15))):
        m.lathe([(r, 0.0), (r * 0.9, h * 0.5), (r * 0.55, h * 0.9), (0.0, h)], k["flesh"] if i % 2 == 0 else k["wet"], sides=7,
                at=(x, y, 0), scale=(1.0, 0.85, 1.0))
    for i in range(6):
        a = i / 6 * math.tau + 0.4
        m.lathe([(0.0, 0.0), (0.04, 0.02), (0.045, 0.06), (0.0, 0.09)], k["sac"], sides=5, at=(math.cos(a) * 0.4, math.sin(a) * 0.35, 0.18))
        m.lathe([(0.0, 0.0), (0.03, 0.01), (0.0, 0.05)], k["bone"], sides=4, at=(math.cos(a + 0.5) * 0.5, math.sin(a + 0.5) * 0.4, 0.1))
    for i in range(7):
        a = i / 7 * math.tau
        m.pipe([(math.cos(a) * 0.5, math.sin(a) * 0.45, 0.02), (math.cos(a + 0.2) * 1.0, math.sin(a + 0.2) * 0.9, 0.01),
                (math.cos(a + 0.1) * 1.5, math.sin(a + 0.1) * 1.3, 0.005)], 0.015, k["wet"], sides=3)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[])


@asset("dk_prize_core", "derelict", texture=256, colors=32, ao=0.5)
def prize_core():
    """THE PRIZE (GDD §8.3): a recovered jump core, the earlier wave's own drive heart, worth more
    than two fuel cells. A heavy capsule twice a fuel cell's size cradled on a wheeled sled with a
    tow bar, its radium core showing through a ring of windows, cables trailing where it was torn
    out. Two-handed and slow to drag; taking it may set something off."""
    k = br._materials()
    dk = br._decals()
    core = mats.glowing("rm_core", (0.72, 1.0, 0.32), base=(0.2, 0.3, 0.1), flicker=0.35, streaks=0.6)
    m = Mesh("dk_prize_core")
    d = Mesh("dk_prize_core_decals")
    texts = []
    # Sled: a low frame on four small wheels, a tow bar.
    m.box((0.9, 1.4, 0.08), k["dark_steel"], at=(0, 0, 0.18), bevel=0.01)
    for x in (-0.38, 0.38):
        for y in (-0.55, 0.55):
            m.cylinder(0.09, 0.06, k["rubber"], sides=8, at=(x, y, 0.09), rot=(0, 90, 0))
    m.pipe([(0, -0.7, 0.22), (0, -1.1, 0.45), (0.15, -1.15, 0.47), (-0.15, -1.15, 0.47)], 0.02, k["steel"], sides=5)
    # The capsule lying in two cradles.
    for y in (-0.4, 0.4):
        m.box((0.7, 0.12, 0.3), k["orange"], at=(0, y, 0.35), bevel=0.02)
    m.lathe([(0.0, -0.75), (0.25, -0.72), (0.32, -0.6), (0.32, 0.6), (0.25, 0.72), (0.0, 0.75)], k["casing"], sides=8,
            at=(0, 0, 0.62), rot=(90, 0, 0))
    for y in (-0.25, 0.0, 0.25):
        m.lathe([(0.327, -0.07), (0.327, 0.07)], core, sides=8, at=(0, y, 0.62), rot=(90, 0, 0), cap_start=False, cap_end=False)
    for y in (-0.5, 0.5):
        m.lathe([(0.34, -0.04), (0.34, 0.04)], k["dark_steel"], sides=8, at=(0, y, 0.62), rot=(90, 0, 0), cap_start=False, cap_end=False)
    # Torn cables trailing from its far end.
    for i, col in enumerate(("cable", "cable_red", "cable")):
        m.pipe([(-0.1 + i * 0.1, 0.76, 0.62), (-0.15 + i * 0.12, 0.95, 0.4), (-0.2 + i * 0.15, 1.1, 0.12)], 0.02, k[col], sides=4)
    texts.append(geo.text("JUMP CORE", 0.07, dk["black"], matrix=frame((0, -0.46, 0.4), FRONT, lift=0.003)))
    low = m.to_object()
    collider = br._console_collider("dk_prize_core", (0.9, 1.5, 0.95), (0, 0, 0.47))
    return Model(low=low, decals=[d.to_object()] + texts,
                 extras=[collider, _socket("grip_l", (-0.15, -1.15, 0.47)), _socket("grip_r", (0.15, -1.15, 0.47))])
