"""The LANTERN's hull (GDD §5, §14): armour plating around the deck, seen on EVA, through other
ships' windows, and as the crew drifts away from it. A kit the Deck places around any layout:
sides over exterior walls (plain, window, viewport, hatch), outer corners, roof and belly plates,
plus hero pieces (comms mast, thrusters, the station's name), and the docking collar the LANTERN
runs out to a derelict's hatch. Derelicts re-bake the same kit as dh_* in the derelict style:
teal-grey armour eaten by rust, dead running lights, panels torn off, scorch (GDD §14's palette).

Side pieces stand on a cell edge like a wall: X along the edge, the hull's outer face toward -Y.
"""

import math

from mathutils import Vector

import bridge as br
from lib import Model, asset, geo, mats
from lib.geo import Mesh, clip, frame

WIDTH = 4.0
# The hull stands clear of the deck inside it: a plane shared with a wall, floor or ceiling, or a
# wall detail poking through the plating, flickers as vertices snap to pixels.
HALF_WALL = 0.15 + 0.02  # the plating's inner edge: the wall's outer face, plus a gap
OUT = 0.56          # the hull's outer face, metres out from the wall's centre line (clear of the
                    # wall's outer chamfer, which reaches 0.47)
BOTTOM, TOP = -0.6, 3.7
ROOF = 3.1 + 0.03   # the roof plate's underside: the ceiling's top, plus a gap
BELLY = -0.1 - 0.03  # the belly plate's top: the floor's underside, less a gap
THRUSTER_REACH = 0.95  # a thruster pod's origin, out from the plating it's mounted on
HATCH_CZ = 1.15     # a pressure hatch's centre above the deck (station_kit.py: wall_hatch)

# The kit's two looks, as in station_kit.py: the LANTERN's ("station") and a derelict's
# ("derelict"), with `damage` picking which wounds a derelict's side plating shows (0 for none).
STYLE = {"name": "station", "damage": 0}


def _materials():
    if STYLE["name"] == "derelict":
        return dict(
            armour=mats.paint("dh_armour", (0.29, 0.35, 0.35), wear=0.6, grime=0.75, streaks=0.8, under=(0.42, 0.4, 0.36),
                              detail="PaintedMetal013", detail_strength=0.4, rust=0.6),
            insert=mats.paint("dh_insert", (0.46, 0.48, 0.45), wear=0.6, grime=0.7, streaks=0.6, rust=0.45),
            dark=mats.metal("dh_dark", (0.13, 0.13, 0.13), grime=0.6),
            steel=mats.metal("dh_steel", (0.4, 0.37, 0.33), grime=0.6, detail="Metal021"),
            orange=mats.paint("dh_orange", (0.55, 0.3, 0.14), wear=0.7, grime=0.6, rust=0.45),
            rail=mats.paint("dh_rail", (0.6, 0.5, 0.18), wear=0.7, grime=0.5, rust=0.5),
        )
    return dict(
        armour=mats.paint("hl_armour", (0.36, 0.38, 0.4), wear=0.35, grime=0.4, streaks=0.4, under=(0.55, 0.55, 0.52),
                          detail="PaintedMetal013", detail_strength=0.3),
        insert=mats.paint("hl_insert", (0.62, 0.6, 0.54), wear=0.3, grime=0.4, streaks=0.3),
        dark=mats.metal("hl_dark", (0.2, 0.21, 0.22), grime=0.4),
        steel=mats.metal("hl_steel", (0.55, 0.55, 0.53), grime=0.35),
        orange=mats.paint("hl_orange", (0.86, 0.42, 0.1), wear=0.45, grime=0.35),
        rail=mats.paint("hl_rail", (0.88, 0.7, 0.12), wear=0.5, grime=0.3),
    )


def _decals():
    if STYLE["name"] == "derelict":
        return dict(
            black=mats.decal("dh_d_black", (0.06, 0.06, 0.06)),
            white=mats.decal("dh_d_white", (0.6, 0.6, 0.55)),
            orange=mats.decal("dh_d_orange", (0.5, 0.28, 0.13)),
            dark=mats.decal("dh_d_dark", (0.1, 0.1, 0.1)),
            amber_lit=mats.decal("dh_d_amber_dead", (0.24, 0.17, 0.09)),  # long dead
            scorch=mats.decal("dh_d_scorch", (0.07, 0.065, 0.06)),
            scorch_halo=mats.decal("dh_d_scorch_halo", (0.19, 0.16, 0.13)),
        )
    return dict(
        black=mats.decal("hl_d_black", (0.06, 0.06, 0.06)),
        white=mats.decal("hl_d_white", (0.86, 0.85, 0.8)),
        orange=mats.decal("hl_d_orange", (0.86, 0.42, 0.1)),
        dark=mats.decal("hl_d_dark", (0.14, 0.14, 0.15)),
        amber_lit=mats.decal("hl_d_amber", (1.0, 0.7, 0.2), glow=True),
    )


def _side_shell(m, k, holes=()):
    """The side plating, as horizontal bands around rectangular `holes` (x0, x1, z0, z1)."""
    y = -OUT + 0.06
    # Chamfered lips top and bottom give the hull a rounded silhouette.
    m.prism([(-OUT + 0.12, TOP - 0.35), (-OUT, TOP - 0.35), (-OUT + 0.2, TOP), (-HALF_WALL, TOP), (-HALF_WALL, TOP - 0.35)],
            WIDTH, k["armour"], rot=(0, 0, 90))
    m.prism([(-HALF_WALL, BOTTOM + 0.35), (-HALF_WALL, BOTTOM), (-OUT + 0.2, BOTTOM), (-OUT, BOTTOM + 0.35), (-OUT + 0.12, BOTTOM + 0.35)],
            WIDTH, k["armour"], rot=(0, 0, 90))
    z0, z1 = BOTTOM + 0.35, TOP - 0.35
    if not holes:
        m.box((WIDTH, 0.12, z1 - z0), k["armour"], at=(0, y, (z0 + z1) / 2))
        return
    for hx0, hx1, hz0, hz1 in holes:
        m.box((WIDTH, 0.12, hz0 - z0), k["armour"], at=(0, y, (z0 + hz0) / 2))
        m.box((WIDTH, 0.12, z1 - hz1), k["armour"], at=(0, y, (hz1 + z1) / 2))
        m.box((hx0 + WIDTH / 2, 0.12, hz1 - hz0), k["armour"], at=((-WIDTH / 2 + hx0) / 2, y, (hz0 + hz1) / 2))
        m.box((WIDTH / 2 - hx1, 0.12, hz1 - hz0), k["armour"], at=((hx1 + WIDTH / 2) / 2, y, (hz0 + hz1) / 2))
        # A thick frame round the opening, through to the wall.
        for x in (hx0 - 0.06, hx1 + 0.06):
            m.box((0.12, OUT - HALF_WALL, hz1 - hz0 + 0.24), k["dark"], at=(x, -(OUT + HALF_WALL) / 2, (hz0 + hz1) / 2), bevel=0.01)
        for z in (hz0 - 0.06, hz1 + 0.06):
            m.box((hx1 - hx0 + 0.24, OUT - HALF_WALL, 0.12), k["dark"], at=((hx0 + hx1) / 2, -(OUT + HALF_WALL) / 2, z), bevel=0.01)


def _side_details(m, d, k, dk, holes=(), rail=True, light=True):
    """Ribs, panel inserts, the EVA handrail, a running light, rivet lines, avoiding `holes`. A
    derelict's plating (STYLE's `damage`) has lost things: 1, an access panel torn off and hanging
    by a corner, the handrail snapped and bent away; 2, a scorch across the plating, the lower
    panel gone, the rail sagging where a stand-off sheared."""
    def clear(x, z, r=0.3):
        return all(not (hx0 - r < x < hx1 + r and hz0 - r < z < hz1 + r) for hx0, hx1, hz0, hz1 in holes)

    damage = STYLE["damage"] if STYLE["name"] == "derelict" else 0
    face = -OUT
    for x in (-WIDTH / 2 + 0.08, WIDTH / 2 - 0.08):
        m.box((0.16, 0.08, TOP - BOTTOM - 0.7), k["dark"], at=(x, face - 0.02, (TOP + BOTTOM) / 2), bevel=0.01)
    if clear(0, 0.2, 0.0):
        m.box((WIDTH - 0.3, 0.05, 0.16), k["dark"], at=(0, face - 0.02, 0.2), bevel=0.01)
    torn = {1: (1.0, 2.6), 2: (-1.0, -0.1)}.get(damage)
    for x, z, w, h in ((-1.0, 2.6, 1.4, 0.7), (1.0, 2.6, 1.4, 0.7), (-1.0, -0.1, 1.2, 0.3)):
        if not clear(x, z, max(w, h) / 2):
            continue
        if (x, z) == torn:
            # The panel's gone: its dark bay, the bolts' lugs, a pipe run across the hole.
            m.box((w - 0.04, 0.02, h - 0.04), k["dark"], at=(x, face - 0.002, z))
            m.pipe([(x - w / 2 + 0.04, face - 0.03, z + h * 0.15), (x + w / 2 - 0.04, face - 0.03, z + h * 0.1)], 0.03, k["steel"], sides=5)
            if damage == 1:
                # ...and hangs by its lower corner, swung out and down.
                m.box((w * 0.8, 0.03, h * 0.9), k["insert"], at=(x + w * 0.3, face - 0.12, z - h * 0.75), rot=(14, -6, 38), bevel=0.008)
            continue
        faces = m.box((w, 0.04, h), k["insert"], at=(x, face - 0.01, z), bevel=0.01)
        front = max(m.faces(among=faces, normal=(0, -1, 0), min_dot=0.99), key=lambda f: f.calc_area())
        m.inset([front], thickness=0.05, depth=0.008)
    if rail and clear(0, 1.0, 0.1):
        ry = face - 0.16
        if damage == 1:
            # Snapped past its middle stand-off, the loose end bent out and down.
            m.pipe([(-WIDTH / 2 + 0.2, ry, 1.0), (0.35, ry, 1.0), (0.75, ry - 0.18, 0.78)], 0.025, k["rail"], sides=6)
            stands = (-1.5, 0.0)
        elif damage == 2:
            m.pipe([(-WIDTH / 2 + 0.2, ry, 1.0), (0.0, ry, 1.0), (1.0, ry - 0.03, 0.9), (WIDTH / 2 - 0.2, ry - 0.06, 0.76)],
                   0.025, k["rail"], sides=6)
            stands = (-1.5, 0.0)
        else:
            m.pipe([(-WIDTH / 2 + 0.2, ry, 1.0), (WIDTH / 2 - 0.2, ry, 1.0)], 0.025, k["rail"], sides=6)
            stands = (-1.5, 0.0, 1.5)
        for x in stands:
            m.pipe([(x, face, 1.0), (x, ry, 1.0)], 0.018, k["rail"], sides=5, caps=False)
    if damage == 2 and clear(-0.4, 1.4, 0.6):
        # A scorch across the plating between the panels: a brown halo, a black heart.
        for scale, colour, lift in ((1.0, "scorch_halo", 0.001), (0.55, "scorch", 0.0015)):
            pts = []
            for i in range(20):
                a = i / 20 * math.tau
                r = scale * (0.8 + 0.1 * math.sin(i * 2.7) + 0.06 * math.sin(i * 5.3))
                pts.append((-0.4 + math.cos(a) * r * 1.25, 1.45 + math.sin(a) * r * 0.6))
            d.polygon(clip(pts, -1.78, 1.78, 0.32, 2.2), dk[colour], frame((0, face, 0), (0, -1, 0), lift=lift))
    if light and clear(1.6, 3.15, 0.2):
        m.box((0.16, 0.08, 0.1), k["dark"], at=(1.6, face - 0.04, 3.15), bevel=0.01)
        d.polygon([(-0.05, -0.03), (0.05, -0.03), (0.05, 0.03), (-0.05, 0.03)], dk["amber_lit"], frame((1.6, face - 0.081, 3.15), (0, -1, 0)))
    normal = Vector((0, -1, 0))
    for z in (0.12, 2.15):
        for i in range(13):
            x = -1.8 + i * 0.3
            if clear(x, z, 0.05):
                d.polygon([(-0.012, -0.012), (0.012, -0.012), (0.012, 0.012), (-0.012, 0.012)], dk["dark"], frame((x, face - 0.001, z), normal))


def _side(name, holes=(), rail=True, extra=None):
    k = _materials()
    dk = _decals()
    m = Mesh(name)
    d = Mesh(f"{name}_decals")
    texts = []
    _side_shell(m, k, holes)
    _side_details(m, d, k, dk, holes, rail=rail)
    if extra:
        extra(m, d, k, dk, texts)
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()] + texts, extras=[])


@asset("hl_side", "hull", texture=256, colors=32, ao=0.45, angles=((-30, 15), (30, 40), (0, 0), (-60, -20)))
def side():
    """Hull side plating over an exterior wall: grey armour between dark ribs, pale access-panel
    inserts, a yellow EVA handrail on stand-offs, a running light, rivet lines."""
    return _side("hl_side")


@asset("hl_side_window", "hull", texture=256, colors=32, ao=0.45, angles=((-30, 15), (30, 40), (0, 0), (-60, -20)))
def side_window():
    """Hull side over a window wall: the port framed deep in the armour (matches lk_wall_window)."""
    return _side("hl_side_window", holes=((-1.45, 1.45, 0.86, 2.44),))


@asset("hl_side_viewport", "hull", texture=256, colors=32, ao=0.45, angles=((-30, 15), (30, 40), (0, 0), (-60, -20)))
def side_viewport():
    """Hull side over the bridge viewport: a tall opening under a heavy brow, orange edge markings."""
    def brow(m, d, k, dk, texts):
        m.box((WIDTH, 0.3, 0.2), k["dark"], at=(0, -OUT - 0.1, 2.68), bevel=0.03)
        d.polygon([(-2.0, -0.04), (2.0, -0.04), (2.0, 0.04), (-2.0, 0.04)], dk["orange"], frame((0, -OUT - 0.251, 2.6), (0, -1, 0)))
    return _side("hl_side_viewport", holes=((-1.9, 1.9, 0.41, 2.54),), rail=False, extra=brow)


@asset("hl_side_hatch", "hull", texture=256, colors=32, ao=0.45, angles=((-30, 15), (30, 40), (0, 0), (-60, -20)))
def side_hatch():
    """Hull side over a pressure hatch: a deep collar ring around the round door, docking guides
    and EVA rails either side, a hazard ring painted on the armour around it."""
    def collar(m, d, k, dk, texts):
        cz = 1.15
        m.lathe([(1.1, 0.0), (1.1, 0.5), (1.18, 0.56), (1.3, 0.56), (1.3, 0.0)], k["dark"], sides=16, at=(0, -OUT + 0.06, cz),
                rot=(90, 0, 0), cap_start=False, cap_end=False)
        for i in range(4):
            a = i / 4 * math.tau + math.pi / 4
            m.box((0.14, 0.4, 0.14), k["orange"], at=(math.cos(a) * 1.42, -OUT - 0.2, cz + math.sin(a) * 1.42), bevel=0.02)
        for x in (-1.7, 1.7):
            m.pipe([(x, -OUT - 0.14, 0.2), (x, -OUT - 0.14, 2.3)], 0.025, k["rail"], sides=6)
        normal = Vector((0, -1, 0))
        for i in range(20):
            a0, a1 = i / 20 * math.tau, (i + 1) / 20 * math.tau
            pts = [(math.cos(a0) * 1.32, math.sin(a0) * 1.32), (math.cos(a1) * 1.32, math.sin(a1) * 1.32),
                   (math.cos(a1) * 1.5, math.sin(a1) * 1.5), (math.cos(a0) * 1.5, math.sin(a0) * 1.5)]
            d.polygon(pts, dk["black"] if i % 2 else dk["orange"], frame((0, -OUT + 0.0, cz), normal, lift=0.001))
    return _side("hl_side_hatch", holes=((-1.1, 1.1, 0.05, 2.25),), rail=False, extra=collar)


@asset("hl_corner", "hull", texture=128, colors=24, ao=0.45)
def corner():
    """An outer hull corner: a rounded eight-sided post filling the notch where two sides meet,
    capped top and bottom, with a red-or-green navigation light housing near the top."""
    k = _materials()
    dk = _decals()
    m = Mesh("hl_corner")
    d = Mesh("hl_corner_decals")
    m.lathe([(0.2, BOTTOM), (0.42, BOTTOM + 0.3), (0.42, TOP - 0.3), (0.2, TOP)], k["armour"], sides=8, angle_offset=math.pi / 8)
    for z in (0.2, 2.2):
        m.lathe([(0.44, z - 0.08), (0.44, z + 0.08)], k["dark"], sides=8, angle_offset=math.pi / 8, cap_start=False, cap_end=False)
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[])


def _walk():
    """Non-slip deck plate: the roof's EVA walkway, the collar's floor."""
    if STYLE["name"] == "derelict":
        return mats.metal("dh_walk", (0.25, 0.24, 0.22), grime=0.75, brushed=False, detail="DiamondPlate008A")
    return mats.metal("hl_walk", (0.3, 0.31, 0.32), grime=0.5, brushed=False, detail="DiamondPlate008A")


@asset("hl_roof", "hull", texture=256, colors=32, ao=0.45, angles=((-30, 40), (150, 50), (0, 70), (90, 25)))
def roof():
    """Hull roof plate over a cell: armour plating with seams and rivets on a 2 m grid, a low vent
    block, a walkway strip of non-slip plate with hazard edging for EVA."""
    k = _materials()
    dk = _decals()
    walk = _walk()
    m = Mesh("hl_roof")
    d = Mesh("hl_roof_decals")
    m.box((WIDTH, WIDTH, 0.35), k["armour"], at=(0, 0, ROOF + 0.175))
    m.box((1.0, WIDTH, 0.04), walk, at=(0, 0, ROOF + 0.37))
    m.box((1.0, 0.8, 0.25), k["dark"], at=(1.3, -0.9, ROOF + 0.47), bevel=0.03)
    for i in range(5):
        m.box((0.9, 0.04, 0.1), k["steel"], at=(1.3, -1.25 + i * 0.17, ROOF + 0.63), bevel=0.01)
    up = Vector((0, 0, 1))
    for x in (-2.0, 0.0, 2.0):
        d.polygon([(-0.015, -2), (0.015, -2), (0.015, 2), (-0.015, 2)], dk["dark"], frame((x, 0, ROOF + 0.35), up, up=(0, 1, 0)))
    for y in (-2.0, 0.0, 2.0):
        d.polygon([(-2, -0.015), (2, -0.015), (2, 0.015), (-2, 0.015)], dk["dark"], frame((0, y, ROOF + 0.35), up, up=(0, 1, 0)))
    for x in (-0.5, 0.5):
        f = frame((x, 0, ROOF + 0.39), up, up=(0, 1, 0))
        d.polygon([(-0.04, -2), (0.04, -2), (0.04, 2), (-0.04, 2)], dk["orange"], f)
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[])


@asset("hl_belly", "hull", texture=128, colors=24, ao=0.45, angles=((-30, -40), (150, -50), (0, -70), (90, -25)))
def belly():
    """Hull belly plate under a cell: armour with a keel rib and seams."""
    k = _materials()
    dk = _decals()
    m = Mesh("hl_belly")
    d = Mesh("hl_belly_decals")
    m.box((WIDTH, WIDTH, 0.35), k["armour"], at=(0, 0, BELLY - 0.175))
    m.box((0.3, WIDTH, 0.16), k["dark"], at=(0, 0, BELLY - 0.43), bevel=0.02)
    down = Vector((0, 0, -1))
    for x in (-2.0, 0.0, 2.0):
        d.polygon([(-0.015, -2), (0.015, -2), (0.015, 2), (-0.015, 2)], dk["dark"], frame((x, 0, BELLY - 0.35), down, up=(0, 1, 0)))
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[])


@asset("hl_mast", "hull", texture=128, colors=32, ao=0.45)
def mast():
    """The comms mast over the bridge: a lattice tower with a dish turned to the stars, whip
    antennas, a blinking red beacon at its tip."""
    k = _materials()
    dk = _decals()
    dish_face = mats.paint("hl_dish", (0.8, 0.79, 0.74), wear=0.25, grime=0.35)
    m = Mesh("hl_mast")
    d = Mesh("hl_mast_decals")
    for x, y in ((-0.3, -0.3), (0.3, -0.3), (0.3, 0.3), (-0.3, 0.3)):
        m.pipe([(x, y, 0.0), (x * 0.4, y * 0.4, 3.0)], 0.04, k["steel"], sides=5)
    for z in (0.6, 1.3, 2.0, 2.6):
        s = 0.3 - z * 0.06
        m.pipe([(-s, -s, z), (s, -s, z), (s, s, z), (-s, s, z), (-s, -s, z)], 0.025, k["steel"], sides=4, caps=False)
    m.box((0.6, 0.6, 0.2), k["dark"], at=(0, 0, 0.1), bevel=0.03)
    m.lathe([(0.0, 0.0), (0.5, 0.06), (0.75, 0.2), (0.8, 0.28)], dish_face, sides=12, at=(0, -0.2, 2.2), rot=(-60, 0, 0),
            cap_end=False)
    m.pipe([(0, -0.2, 2.2), (0, -0.75, 2.55)], 0.02, k["steel"], sides=4)
    for x in (-0.12, 0.12):
        m.pipe([(x, 0.1, 3.0), (x, 0.1, 4.2)], 0.01, k["dark"], sides=4)
    m.cylinder(0.06, 0.1, k["dark"], sides=6, at=(0, 0, 3.05))
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[])


@asset("hl_thruster", "hull", texture=128, colors=32, ao=0.45)
def thruster():
    """A manoeuvring thruster pod for an aft face of the hull: an armoured housing standing off the
    plating on a pylon, a bell nozzle with a scorched lip pointing aft (-Y, so +Z in Godot), a
    faintly glowing throat. The pylon's end (+Y) meets the hull: place the origin THRUSTER_REACH
    out from the plating."""
    k = _materials()
    throat = mats.glowing("hl_throat", (1.0, 0.55, 0.2), base=(0.3, 0.12, 0.05), flicker=0.3)
    scorch = mats.metal("hl_scorch", (0.16, 0.14, 0.12), grime=0.6, brushed=False)
    m = Mesh("hl_thruster")
    d = Mesh("hl_thruster_decals")
    m.box((0.5, 0.9, 0.6), k["dark"], at=(0, 0.0, 0), bevel=0.04)
    m.lathe([(0.25, 0.0), (0.42, 0.25), (0.7, 0.9), (0.66, 0.92), (0.22, 0.12)], scorch, sides=10, at=(0, -0.5, 0), rot=(90, 0, 0),
            cap_start=False, cap_end=False)
    m.cylinder(0.24, 0.06, throat, sides=10, at=(0, -0.42, 0), rot=(90, 0, 0))
    m.box((0.34, THRUSTER_REACH - 0.45, 0.34), k["armour"], at=(0, (THRUSTER_REACH + 0.45) / 2, 0), bevel=0.03)
    m.box((0.6, 0.06, 0.6), k["dark"], at=(0, THRUSTER_REACH - 0.03, 0), bevel=0.01)  # the mounting plate
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[])


@asset("hl_name", "hull", texture=256, colors=8, ao=0.2, angles=((0, 80), (0, 60), (-20, 60), (20, 60)))
def name():
    """The station's name, painted big across the roof: LANTERN, and its registry under it."""
    dk = _decals()
    plate = mats.paint("hl_name_plate", (0.36, 0.38, 0.4), wear=0.35, grime=0.4, streaks=0.4,
                       detail="PaintedMetal013", detail_strength=0.3)
    m = Mesh("hl_name")
    m.box((11.6, 3.6, 0.01), plate, at=(0, 0, 0.005))
    low = m.to_object()
    up = Vector((0, 0, 1))
    texts = [geo.text("LANTERN", 1.6, dk["white"], matrix=frame((0, 0.5, 0.012), up, up=(0, 1, 0))),
             geo.text("DSS-7   EARTH SURVEY", 0.45, dk["orange"], matrix=frame((0, -1.2, 0.012), up, up=(0, 1, 0)))]
    return Model(low=low, decals=texts, extras=[])


def _hazard(d, dk, centre, normal, w, h, up=(0, 0, 1), pitch=0.16):
    """A black-on-orange hazard band, `w` x `h`, flat on a face."""
    d.polygon([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], dk["orange"], frame(centre, normal, up=up, lift=0.001))
    f = frame(centre, normal, up=up, lift=0.0015)
    for i in range(-int(w / pitch) - 2, int(w / pitch) + 3):
        x = i * pitch
        stripe = [(x, -h / 2), (x + pitch * 0.45, -h / 2), (x + pitch * 0.45 + h * 0.6, h / 2), (x + h * 0.6, h / 2)]
        d.polygon(clip(stripe, -w / 2, w / 2, -h / 2, h / 2), dk["black"], f)


def _ring_hazard(d, dk, t, facing, r0, r1, count=16):
    """A hazard ring painted on a collar ring's end face, `t` out along the tube, facing -Y (+1) or +Y (-1)."""
    normal = Vector((0, -facing, 0))
    for i in range(count):
        a0, a1 = i / count * math.tau, (i + 1) / count * math.tau
        pts = [(math.cos(a0) * r0, math.sin(a0) * r0), (math.cos(a1) * r0, math.sin(a1) * r0),
               (math.cos(a1) * r1, math.sin(a1) * r1), (math.cos(a0) * r1, math.sin(a0) * r1)]
        if facing < 0:
            pts = [(-x, z) for x, z in pts]
        d.polygon(pts, dk["black"] if i % 2 else dk["orange"], frame((0, -t, HATCH_CZ), normal, lift=0.001))


COLLAR_LENGTH = WIDTH  # wall line to wall line: the LANTERN's collar hatch to the derelict's


@asset("lk_collar_tube", "hull", texture=256, colors=32, ao=0.5, angles=((-55, 15), (125, 20), (90, 0), (0, 0)))
def collar_tube():
    """The DOCKING COLLAR, run out (GDD §5, §8.1): the short tube the LANTERN extends from its
    collar hatch to a derelict's, 4 m wall line to wall line, so every derelict docks one cell out.
    Steel clamp rings at either end sleeve over the two hulls' hatch collars, rams biting on the
    far hull; between them, pleated black bellows. Inside: a non-slip walkway with hazard edges at
    floor height, a cable tray and a warm light bar along the crown, hazard rings painted on the
    rings' inner faces. Seen from within it's the threshold between home and the dark.

    Built along -Y from the LANTERN's wall line (y = 0) to the derelict's (y = -4), its axis at
    the hatches' centre height; the walkway's top is the deck's (z = 0). Its bore faces look in
    (the lathe profiles run back down the tube), its outer skin out. Colliders: the walkway, the
    walls and roof of the passage, so nobody steps off into the bellows."""
    k = _materials()
    dk = _decals()
    bellows = mats.plain("hl_bellows", (0.17, 0.17, 0.16), grime=0.45, detail_strength=0.35)
    lamp = mats.glowing("hl_tube_light", (1.0, 0.82, 0.55), base=(0.45, 0.38, 0.28), flicker=0.08)
    walk = _walk()
    m = Mesh("lk_collar_tube")
    d = Mesh("lk_collar_tube_decals")
    texts = []
    cz = HATCH_CZ
    sides = 12
    tube = dict(at=(0, 0, cz), rot=(90, 0, 0), sides=sides, cap_start=False, cap_end=False)  # lathe z runs out along -Y
    # A bore wide enough at the deck for the walkway (0.96 m either side of the axis at z = 0),
    # clear of each hull's hatch collar (r 1.3, 0.5..1.06 out) and docking guides (r 1.35..1.49,
    # 0.56..0.96 out): the clamp rings' bands pass over the guides, their faces stand past them.
    bore, pleat, skin, band = 1.5, 1.58, 1.64, 1.74
    near0, near1 = 0.6, 1.12
    far0, far1 = COLLAR_LENGTH - near1, COLLAR_LENGTH - 0.7
    # Bellows between the rings: pleats in and out, seen from within, and a plain outer skin.
    pleats = 6
    folds = [(pleat if i % 2 else bore, near1 + (far0 - near1) * i / (pleats * 2)) for i in range(pleats * 2 + 1)]
    m.lathe(list(reversed(folds)), bellows, **tube)
    m.lathe([(skin, near1), (skin, far0)], bellows, **tube)
    for i in range(1, pleats):
        t = near1 + (far0 - near1) * i / pleats
        m.lathe([(skin, t - 0.03), (skin + 0.04, t - 0.02), (skin + 0.04, t + 0.02), (skin, t + 0.03)], k["dark"], **tube)
    # The clamp rings: the back face toward their hull, the outer band, and the face looking
    # into the tube, down past the hull's own hatch collar.
    m.lathe([(bore, near0), (band, near0), (band, near1), (1.31, near1)], k["steel"], **tube)
    m.lathe([(1.31, far0), (band, far0), (band, far1), (bore, far1)], k["steel"], **tube)
    _ring_hazard(d, dk, near1, 1, 1.34, band - 0.03)
    _ring_hazard(d, dk, far0, -1, 1.34, band - 0.03)
    # Clamp feet at the diagonals, from the far ring onto the derelict's hull.
    for i in range(4):
        a = i / 4 * math.tau + math.pi / 4
        x, z = math.cos(a) * 1.62, cz + math.sin(a) * 1.62
        reach = (COLLAR_LENGTH - OUT) - far1
        m.box((0.14, reach + 0.02, 0.14), k["dark"], at=(x, -(far1 + reach / 2), z), bevel=0.01)
        m.box((0.26, 0.05, 0.26), k["orange"], at=(x, -(COLLAR_LENGTH - OUT) + 0.03, z), bevel=0.012)
    # The walkway, wall line to wall line, edged in hazard stripes.
    m.box((1.7, COLLAR_LENGTH, 0.03), walk, at=(0, -COLLAR_LENGTH / 2, -0.015))
    for x in (-0.79, 0.79):
        _hazard(d, dk, (x, -COLLAR_LENGTH / 2, 0.0), (0, 0, 1), COLLAR_LENGTH - 0.3, 0.1, up=(1, 0, 0))
    texts.append(geo.text("MIND THE SEAL", 0.09, dk["white"], matrix=frame((0, -0.75, 0.0), (0, 0, 1), up=(0, -1, 0), lift=0.001)))
    # The crown: a cable tray and the light bar under it.
    top = cz + 1.42
    m.box((0.3, far0 - near1 + 0.1, 0.05), k["dark"], at=(0, -(near1 + far0) / 2, top - 0.02))
    m.box((0.16, far0 - near1 - 0.3, 0.05), lamp, at=(0, -(near1 + far0) / 2, top - 0.07))
    for x in (-0.11, 0.11):
        m.pipe([(x, -near1 + 0.1, top - 0.03), (x, -far0 - 0.1, top - 0.03)], 0.018, br._materials()["cable"], sides=4)
    m.subdivide(1.0)
    low = m.to_object()
    colliders = [
        kit_collider("lk_collar_tube_floor", (2.0, COLLAR_LENGTH, 0.2), (0, -COLLAR_LENGTH / 2, -0.1)),
        kit_collider("lk_collar_tube_wall_l", (0.1, COLLAR_LENGTH - 0.3, 2.4), (-1.0, -COLLAR_LENGTH / 2, 1.2)),
        kit_collider("lk_collar_tube_wall_r", (0.1, COLLAR_LENGTH - 0.3, 2.4), (1.0, -COLLAR_LENGTH / 2, 1.2)),
        kit_collider("lk_collar_tube_roof", (2.2, COLLAR_LENGTH - 0.3, 0.1), (0, -COLLAR_LENGTH / 2, 2.35)),
    ]
    return Model(low=low, decals=[d.to_object()] + texts, extras=colliders)


def kit_collider(name, size, at):
    """A box collider for Godot (its -colonly suffix makes a StaticBody shape, no mesh)."""
    m = Mesh(f"{name}-colonly")
    m.box(size, mats.plain("collider", (1, 0, 1)), at=at)
    return m.to_object()


# Derelict variants: the hull kit re-baked in the derelict style, as dh_* (two plain sides with
# different wounds, so neighbouring panels don't repeat).
def _derelict(build, damage):
    def variant():
        STYLE.update(name="derelict", damage=damage)
        try:
            return build()
        finally:
            STYLE.update(name="station", damage=0)
    return variant


import lib as _lib  # noqa: E402

for _source, _name, _damage in (("hl_side", "dh_side", 1), ("hl_side", "dh_side_b", 2), ("hl_side_window", "dh_side_window", 2),
                                ("hl_side_hatch", "dh_side_hatch", 1), ("hl_corner", "dh_corner", 0), ("hl_roof", "dh_roof", 0),
                                ("hl_belly", "dh_belly", 0)):
    _spec = _lib.ASSETS[_source]
    asset(_name, "hull", texture=_spec.texture, colors=_spec.colors, ao=_spec.ao, angles=_spec.angles)(_derelict(_spec.build, _damage))
