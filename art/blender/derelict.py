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


## The breaker box's knife switch: where its blades hinge (model space), and where the cell sits.
BREAKER_HINGE = (0.0, -0.075, 1.2)
BREAKER_CELL = (-0.02, -0.15, 0.735)


@asset("dk_breaker", "derelict", texture=128, colors=32, ao=0.55)
def breaker():
    """A section breaker box (GDD §8.3): what brings a dead section of a derelict back.

    Purpose: one per power section, on a wall near the way in. Throw its knife switch and, if a
    charged cell sits in its cradle, the section's lights, doors and fittings come back; cut it
    again to make the section safe. A dead cradle wants a power cell carried in.
    Size: a 0.62 x 0.8 m steel box, its lower edge at 1.0 m, a cell cradle bolted under it.
    Silhouette: the box, its door hanging open on one hinge, the big red-handled switch standing
    out of it, the cradle's tray, a conduit running up the wall into the ceiling.
    Details: two lamps (`lamp_power`, `lamp_cell`: separate meshes Godot lights green, red or dark)
    labelled PWR and CELL, a SECTION header over a blank plate (Godot letters it: SOCKET_letter),
    the switch's copper clips, the cradle's contact block, hazard stripes on its lip.
    Parts: the switch (`breaker_handle`: two blades and the handle bar) is split off after baking
    to swing about SOCKET_hinge (built closed, standing up); a cell is shown at SOCKET_cell.
    Palette: the derelict kit's dark casing, a cream door, orange header, red handle, bare copper.
    """
    c = br._materials()
    dk = br._decals()
    copper = mats.metal("dk_copper", (0.72, 0.42, 0.24), grime=0.5, detail_strength=0.35)
    handle_red = mats.paint("dk_handle", (0.7, 0.1, 0.07), wear=0.5, grime=0.5)
    m = Mesh("dk_breaker")
    d = Mesh("dk_breaker_decals")
    texts = []
    # The box: a housing standing off the wall, its inner face recessed, its door swung open.
    m.box((0.62, 0.18, 0.8), c["casing_dark"], at=(0, 0.09, 1.42), bevel=0.015)
    m.box((0.56, 0.02, 0.74), c["bezel"], at=(0, -0.005, 1.42))
    m.box((0.58, 0.03, 0.78), c["casing"], at=(-0.58, -0.25, 1.42), rot=(0, 0, -70), bevel=0.01)
    m.box((0.04, 0.05, 0.12), c["steel"], at=(-0.31, -0.02, 1.62), bevel=0.006)
    m.box((0.04, 0.05, 0.12), c["steel"], at=(-0.31, -0.02, 1.22), bevel=0.006)
    # The header: an orange band with SECTION and a blank plate for its letter.
    m.box((0.62, 0.03, 0.1), c["orange"], at=(0, -0.01, 1.77), bevel=0.008)
    texts.append(geo.text("SECTION", 0.035, dk["black"], matrix=frame((-0.07, -0.026, 1.77), FRONT, lift=0.002)))
    m.box((0.12, 0.012, 0.09), c["keycap"], at=(0.21, -0.03, 1.77), bevel=0.004)
    # Lamps: bezels baked, lenses split off (Godot lights them).
    for x in (-0.15, 0.15):
        m.cylinder(0.034, 0.02, c["bezel"], sides=8, at=(x, -0.012, 1.63), rot=(90, 0, 0))
    lamps = []
    for name, x in (("lamp_power", -0.15), ("lamp_cell", 0.15)):
        lamp = Mesh(name)
        lamp.cylinder(0.025, 0.03, mats.plain("lk_lamp", (0.2, 0.9, 0.3)), sides=8, at=(x, -0.03, 1.63), rot=(90, 0, 0))
        lamps.append(lamp.to_object())
    texts.append(geo.text("PWR", 0.026, dk["cream"], matrix=frame((-0.15, -0.016, 1.57), FRONT, lift=0.002)))
    texts.append(geo.text("CELL", 0.026, dk["cream"], matrix=frame((0.15, -0.016, 1.57), FRONT, lift=0.002)))
    # The switch's seat: an insulating block, the lower hinge posts and the upper copper clips the
    # blades close into.
    m.box((0.34, 0.04, 0.34), c["bezel"], at=(0, -0.025, 1.31), bevel=0.006)
    hx, hy, hz = BREAKER_HINGE
    # The clips stand behind the blades' path (y over -0.06); everything of the switch is in front.
    for x in (-0.09, 0.09):
        m.box((0.03, 0.06, 0.04), copper, at=(x, hy + 0.02, hz))
        m.box((0.036, 0.04, 0.05), copper, at=(x, -0.04, hz + 0.24), bevel=0.004)
    # The switch itself: two copper blades up from the hinge, closed against the clips, the red
    # handle bar across their tops on an insulated stem.
    for x in (-0.09, 0.09):
        m.box((0.012, 0.016, 0.26), copper, at=(x, hy, hz + 0.13))
    m.box((0.21, 0.02, 0.02), c["steel"], at=(0, hy, hz + 0.25))
    m.box((0.03, 0.06, 0.03), c["bezel"], at=(0, hy - 0.03, hz + 0.26))
    m.box((0.22, 0.045, 0.045), handle_red, at=(0, hy - 0.07, hz + 0.26), bevel=0.014)
    for i in range(5):
        d.polygon([(-0.02, -0.012), (0.02, -0.012), (0.02, 0.012), (-0.02, 0.012)], dk["unlit"], frame((-0.2 + i * 0.1, -0.016, 1.1), FRONT))
    # The cell cradle under the box: a tray on two brackets, its contact block on the right, a
    # heavy lead up into the housing.
    cx, cy, cz = BREAKER_CELL
    m.box((0.5, 0.3, 0.02), c["dark_steel"], at=(cx, cy + 0.01, cz - 0.01), bevel=0.004)
    m.box((0.5, 0.02, 0.07), c["dark_steel"], at=(cx, cy - 0.14, cz + 0.025), bevel=0.004)
    m.box((0.02, 0.3, 0.07), c["dark_steel"], at=(cx - 0.25, cy + 0.01, cz + 0.025), bevel=0.004)
    m.box((0.06, 0.26, 0.16), c["bezel"], at=(cx + 0.23, cy + 0.01, cz + 0.08), bevel=0.008)
    for z in (0.08, 0.16):
        m.box((0.02, 0.04, 0.04), copper, at=(cx + 0.195, cy, cz + z - 0.005))
    for x in (cx - 0.2, cx + 0.2):
        m.box((0.03, 0.03, 0.24), c["dark_steel"], at=(x, -0.09, cz - 0.08), rot=(-50, 0, 0))
    m.box((0.5, 0.02, 0.3), c["dark_steel"], at=(cx, 0.005, cz + 0.13), bevel=0.004)
    m.pipe([(cx + 0.26, cy + 0.08, cz + 0.12), (cx + 0.31, cy + 0.12, cz + 0.3), (0.25, 0.02, 1.02)], 0.022, c["cable"], sides=5)
    _hazard_lip = [(-0.24, -0.025), (0.24, -0.025), (0.24, 0.025), (-0.24, 0.025)]
    d.polygon(_hazard_lip, dk["orange"], frame((cx, cy - 0.151, cz + 0.025), FRONT))
    for i in range(-5, 5):
        x = i * 0.05
        d.polygon(clip([(x, -0.025), (x + 0.025, -0.025), (x + 0.05, 0.025), (x + 0.025, 0.025)], -0.24, 0.24, -0.025, 0.025), dk["black"],
                  frame((cx, cy - 0.151, cz + 0.025), FRONT, lift=0.0015))
    # The conduit up the wall into the ceiling, clamped twice.
    m.pipe([(0.22, 0.12, 1.82), (0.22, 0.12, 3.0)], 0.035, c["dark_steel"], sides=6)
    for z in (2.2, 2.7):
        m.box((0.1, 0.04, 0.03), c["steel"], at=(0.22, 0.1, z))
    low = m.to_object()

    def split(model):
        def in_handle(p):
            return abs(p.x) < 0.14 and p.y < -0.06 and hz + 0.01 < p.z < hz + 0.3
        box, handle = geo.split_object(model.low, {"dk_breaker": lambda p: not in_handle(p), "breaker_handle": in_handle})
        model.low = box
        model.extras.append(handle)

    collider = br._console_collider("dk_breaker", (0.62, 0.32, 1.12), (0, -0.04, 1.26))
    sockets = [_socket("hinge", BREAKER_HINGE), _socket("cell", BREAKER_CELL), _socket("letter", (0.21, -0.037, 1.77))]
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider] + lamps + sockets, after_bake=split)


## The lock panel's screen: its middle (model space) and size.
LOCK_SCREEN = (0.0, -0.035, 1.5)
LOCK_SCREEN_SIZE = (0.24, 0.18)


@asset("dk_lock_panel", "derelict", texture=128, colors=32, ao=0.55)
def lock_panel():
    """A secure store's lock panel (GDD §8.3): the wall terminal beside a locked door that guards an
    earlier wave's armoury. Dead until its section has power; then its screen asks for a code, and
    keeps a log of the guesses made at it.

    Size: a 0.46 x 0.66 m armoured housing, its screen's middle at 1.5 m, standing off the wall.
    Silhouette: a squat box with a hooded screen, a keypad under it, a heavy conduit up the wall.
    Details: the CRT (`screen_lock`, not baked: Godot shows the lock's screen on it) under a sun
    hood, a 3 x 4 keypad, a card slot, a lock lamp over the screen (`lamp_lock`, split off: Godot
    lights it red or green), SECURE stencilled on a hazard-striped plate, bolts at the corners.
    Palette: the derelict kit's dark casing, a cream bezel, orange and black stripes, red lettering.
    """
    c = br._materials()
    dk = br._decals()
    m = Mesh("dk_lock_panel")
    d = Mesh("dk_lock_panel_decals")
    texts = []
    # The housing and its chamfered front frame.
    m.box((0.46, 0.12, 0.66), c["casing_dark"], at=(0, 0.06, 1.33), bevel=0.02)
    m.box((0.42, 0.02, 0.62), c["bezel"], at=(0, -0.005, 1.33))
    # The screen in its bezel, a hood over it against glare.
    sx, sy, sz = LOCK_SCREEN
    sw, sh = LOCK_SCREEN_SIZE
    m.box((sw + 0.05, 0.03, sh + 0.05), c["casing"], at=(sx, -0.02, sz), bevel=0.008)
    m.box((sw + 0.07, 0.07, 0.015), c["casing_dark"], at=(sx, -0.05, sz + sh / 2 + 0.035), rot=(-12, 0, 0), bevel=0.004)
    for x in (-1, 1):
        m.box((0.012, 0.07, sh * 0.5), c["casing_dark"], at=(sx + x * (sw / 2 + 0.03), -0.05, sz + sh * 0.2))
    screen = geo.screen("screen_lock", sw, sh, geo.place((sx, sy - 0.002, sz)), bulge=0.006)
    # The keypad: twelve keys under the screen, a card slot beside them.
    for r in range(4):
        for col in range(3):
            m.box((0.036, 0.016, 0.028), c["keycap"] if r < 3 else c["keycap_dark"], at=(-0.05 + col * 0.045, -0.018, 1.27 - r * 0.036), bevel=0.004)
    m.box((0.07, 0.02, 0.012), c["bezel"], at=(0.12, -0.018, 1.25))
    d.polygon([(-0.03, -0.003), (0.03, -0.003), (0.03, 0.003), (-0.03, 0.003)], dk["black"], frame((0.12, -0.0285, 1.25), FRONT, lift=0.001))
    # The lock lamp over the screen, split off.
    m.cylinder(0.028, 0.02, c["bezel"], sides=8, at=(0.17, -0.012, 1.62), rot=(90, 0, 0))
    lamp = Mesh("lamp_lock")
    lamp.cylinder(0.02, 0.03, mats.plain("lk_lamp", (0.2, 0.9, 0.3)), sides=8, at=(0.17, -0.03, 1.62), rot=(90, 0, 0))
    # SECURE on a striped plate along the foot.
    m.box((0.42, 0.015, 0.07), c["orange"], at=(0, -0.012, 1.06), bevel=0.004)
    for i in range(-5, 5):
        x = i * 0.045
        d.polygon(clip([(x, -0.035), (x + 0.02, -0.035), (x + 0.045, 0.035), (x + 0.025, 0.035)], -0.21, 0.21, -0.035, 0.035),
                  dk["black"], frame((0, -0.0201, 1.06), FRONT, lift=0.001))
    m.box((0.2, 0.004, 0.05), c["casing_dark"], at=(0, -0.021, 1.06))
    texts.append(geo.text("SECURE", 0.032, dk["red"], matrix=frame((0, -0.024, 1.06), FRONT, lift=0.002)))
    for x in (-0.2, 0.2):
        for z in (1.03, 1.63):
            m.cylinder(0.012, 0.012, c["steel"], sides=6, at=(x, -0.015, z), rot=(90, 0, 0))
    # The conduit up the wall into the ceiling.
    m.pipe([(-0.17, 0.08, 1.66), (-0.17, 0.08, 3.0)], 0.03, c["dark_steel"], sides=6)
    for z in (2.1, 2.6):
        m.box((0.09, 0.035, 0.025), c["steel"], at=(-0.17, 0.065, z))
    low = m.to_object()
    collider = br._console_collider("dk_lock_panel", (0.46, 0.16, 0.68), (0, 0.04, 1.33))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider, screen, lamp.to_object()])


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
