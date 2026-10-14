"""The LANTERN's hull (GDD §5, §14): armour plating around the deck, seen on EVA, through other
ships' windows, and as the crew drifts away from it. A kit the Deck places around any layout:
sides over exterior walls (plain, window, viewport, hatch), outer corners, roof and belly plates,
plus hero pieces (comms mast, thrusters, the station's name). Derelicts re-bake the same kit.

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


def _materials():
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
    """Ribs, panel inserts, the EVA handrail, a running light, rivet lines, avoiding `holes`."""
    def clear(x, z, r=0.3):
        return all(not (hx0 - r < x < hx1 + r and hz0 - r < z < hz1 + r) for hx0, hx1, hz0, hz1 in holes)

    face = -OUT
    for x in (-WIDTH / 2 + 0.08, WIDTH / 2 - 0.08):
        m.box((0.16, 0.08, TOP - BOTTOM - 0.7), k["dark"], at=(x, face - 0.02, (TOP + BOTTOM) / 2), bevel=0.01)
    if clear(0, 0.2, 0.0):
        m.box((WIDTH - 0.3, 0.05, 0.16), k["dark"], at=(0, face - 0.02, 0.2), bevel=0.01)
    for x, z, w, h in ((-1.0, 2.6, 1.4, 0.7), (1.0, 2.6, 1.4, 0.7), (-1.0, -0.1, 1.2, 0.3)):
        if clear(x, z, max(w, h) / 2):
            faces = m.box((w, 0.04, h), k["insert"], at=(x, face - 0.01, z), bevel=0.01)
            front = max(m.faces(among=faces, normal=(0, -1, 0), min_dot=0.99), key=lambda f: f.calc_area())
            m.inset([front], thickness=0.05, depth=0.008)
    if rail and clear(0, 1.0, 0.1):
        ry = face - 0.16
        m.pipe([(-WIDTH / 2 + 0.2, ry, 1.0), (WIDTH / 2 - 0.2, ry, 1.0)], 0.025, k["rail"], sides=6)
        for x in (-1.5, 0.0, 1.5):
            m.pipe([(x, face, 1.0), (x, ry, 1.0)], 0.018, k["rail"], sides=5, caps=False)
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


@asset("hl_roof", "hull", texture=256, colors=32, ao=0.45, angles=((-30, 40), (150, 50), (0, 70), (90, 25)))
def roof():
    """Hull roof plate over a cell: armour plating with seams and rivets on a 2 m grid, a low vent
    block, a walkway strip of non-slip plate with hazard edging for EVA."""
    k = _materials()
    dk = _decals()
    walk = mats.metal("hl_walk", (0.3, 0.31, 0.32), grime=0.5, brushed=False, detail="DiamondPlate008A")
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
