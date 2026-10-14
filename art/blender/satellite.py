"""A relay satellite in working order (GDD §3, §8.1; TECH §5): one of the relays the earlier waves
left behind, still lit, still passing signals on, nobody aboard. Crew reach it by EVA from the
LANTERN's airlock and float through it weightless. Its interior is the station kit in the relay's
livery (station_kit.py: sk_*); this file holds its hull, what's mounted on the hull, and the
machines inside.

The hull (sh_*) is a working spacecraft's, not an armoured station's: white beta-cloth insulation
blankets quilted over a grey frame, gold metallised-film blankets over the hot faces, yellow EVA
handrails everywhere a gloved hand needs one, relay-blue stencils. It's built for levels stacked
4 m apart (RoomLayout.PITCH): each side piece spans its level's deck to the next one's (-0.5 to
3.5 m), so stacked levels close up into one hull with a rib at every level's joint. Every piece
has colliders on its outer face, so crew outside land on the plating, not in it.

On the hull: two solar wings on booms, a dish, a mast with a strobe, thruster clusters at the
corners. Inside: racks of relay electronics, battery banks, the telemetry console, stowage nets,
propellant tanks, the antenna's waveguide feed, a maintenance crew's sleeping restraint, and the
relay core, the thing the whole satellite serves.

Side pieces stand on a cell edge like a wall: X along the edge, the outer face toward -Y. Props
face -Y in Blender (+Z in Godot), their origin on the deck under their middle.
"""

import math

import bpy
from mathutils import Vector

import bridge as br
from lib import Model, asset, geo, mats
from lib.geo import Mesh, clip, frame, place

UP = Vector((0, 0, 1))
FRONT = Vector((0, -1, 0))

WIDTH = 4.0
HALF_WALL = 0.17   # the plating's inner edge: the wall's outer face, plus a gap
OUT = 0.56         # the hull's outer face, out from the wall's centre line (as the LANTERN's)
BOTTOM, TOP = -0.5, 3.5  # a level's band of hull: the deck below to the next level's
ROOF = 3.1 + 0.03  # the roof plate's underside: the ceiling's top, plus a gap
ROOF_TOP = 3.48
BELLY = -0.1 - 0.03
BELLY_BOTTOM = -0.45
HATCH_CZ = 1.15    # a pressure hatch's centre above the deck (station_kit.py: wall_hatch)


def _materials():
    return dict(
        blanket=mats.plain("sh_blanket", (0.86, 0.86, 0.83), grime=0.06, variation=0.05, detail_strength=0.22),
        foil=mats.foil("sh_foil", (0.93, 0.75, 0.33)),
        silver=mats.foil("sh_silver", (0.74, 0.76, 0.78), scale=1.3),
        frame=mats.paint("sh_frame", (0.55, 0.57, 0.6), wear=0.1, grime=0.12),
        dark=mats.metal("sh_dark", (0.16, 0.17, 0.19), grime=0.12),
        steel=mats.metal("sh_steel", (0.66, 0.67, 0.68), grime=0.1),
        rail=mats.paint("sh_rail", (0.88, 0.74, 0.18), wear=0.12, grime=0.08),
        blue=mats.paint("sh_blue", (0.16, 0.42, 0.68), wear=0.1, grime=0.08),
        radiator=mats.paint("sh_radiator", (0.93, 0.93, 0.91), wear=0.04, grime=0.05),
        cells=mats.paint("sh_cells", (0.07, 0.1, 0.24), wear=0.0, grime=0.02, variation=0.1, detail="Metal009",
                         detail_strength=0.12),
        substrate=mats.plain("sh_substrate", (0.72, 0.66, 0.46), grime=0.05),
        lens=mats.glowing("sh_lens", (1.0, 0.95, 0.85), base=(0.75, 0.72, 0.65), flicker=0.05),
    )


def _decals():
    return dict(
        black=mats.decal("sh_d_black", (0.06, 0.06, 0.07)),
        white=mats.decal("sh_d_white", (0.92, 0.92, 0.9)),
        yellow=mats.decal("sh_d_yellow", (0.9, 0.72, 0.12)),
        blue=mats.decal("sh_d_blue", (0.16, 0.42, 0.68)),
        dark=mats.decal("sh_d_dark", (0.3, 0.31, 0.32)),
        stitch=mats.decal("sh_d_stitch", (0.62, 0.62, 0.6)),
        silver=mats.decal("sh_d_silver", (0.8, 0.82, 0.84)),
        green_lit=mats.decal("sh_d_green_lit", (0.4, 1.0, 0.6), glow=True),
        amber_lit=mats.decal("sh_d_amber_lit", (1.0, 0.7, 0.2), glow=True),
        blue_lit=mats.decal("sh_d_blue_lit", (0.45, 0.8, 1.0), glow=True),
        red_lit=mats.decal("sh_d_red_lit", (1.0, 0.25, 0.15), glow=True),
    )


def _collider(name, size, at, rot=(0, 0, 0)):
    """A box collider for Godot (its -colonly suffix makes a StaticBody shape, no mesh)."""
    m = Mesh(f"{name}-colonly")
    m.box(size, mats.plain("collider", (1, 0, 1)), at=at, rot=rot)
    return m.to_object()


def _socket(name, at):
    e = bpy.data.objects.new(f"SOCKET_{name}", None)
    e.location = at
    bpy.context.scene.collection.objects.link(e)
    return e


def _plate(d, colour, centre, normal, w, h, up=(0, 0, 1), lift=0.001):
    d.polygon([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], colour, frame(centre, normal, up=up, lift=lift))


def _hazard(d, dk, centre, normal, w, h, up=(0, 0, 1), pitch=0.14):
    """A black-on-yellow hazard band, `w` x `h`, flat on a face."""
    _plate(d, dk["yellow"], centre, normal, w, h, up=up)
    f = frame(centre, normal, up=up, lift=0.0015)
    for i in range(-int(w / pitch) - 2, int(w / pitch) + 3):
        x = i * pitch
        stripe = [(x, -h / 2), (x + pitch * 0.45, -h / 2), (x + pitch * 0.45 + h * 0.6, h / 2), (x + h * 0.6, h / 2)]
        d.polygon(clip(stripe, -w / 2, w / 2, -h / 2, h / 2), dk["black"], f)


def _quilt(d, dk, centre, normal, w, h, up=(0, 0, 1), pitch=0.5):
    """The stitching of a quilted blanket: a grid of fine lines over a face."""
    f = frame(centre, normal, up=up, lift=0.0008)
    nx, nz = int(w / pitch), int(h / pitch)
    for i in range(1, nx):
        x = -w / 2 + i * w / nx
        d.polygon([(x - 0.006, -h / 2), (x + 0.006, -h / 2), (x + 0.006, h / 2), (x - 0.006, h / 2)], dk["stitch"], f)
    for j in range(1, nz):
        z = -h / 2 + j * h / nz
        d.polygon([(-w / 2, z - 0.006), (w / 2, z - 0.006), (w / 2, z + 0.006), (-w / 2, z + 0.006)], dk["stitch"], f)


def _rail(m, k, points, face_y, stands):
    """An EVA handrail along `points` (at the rail's own y), on stand-offs back to the face at `face_y`."""
    m.pipe(points, 0.022, k["rail"], sides=6)
    for p in stands:
        m.pipe([(p[0], face_y, p[2]), (p[0], p[1], p[2])], 0.015, k["rail"], sides=5, caps=False)


def _lamp(name, centre, radius, material, depth=0.03):
    """A lamp's lens, its own object (`name`) with a plain `material` Godot lights and blinks: a
    disc facing -Y."""
    m = Mesh(name)
    m.cylinder(radius, depth, mats.plain(material, (1.0, 1.0, 1.0)), sides=8, at=centre, rot=(90, 0, 0))
    return m.to_object()


# The hull -----------------------------------------------------------------------------------------

def _side_shell(m, k, holes=()):
    """The side's blanket face between a rib at the top and the bottom, around rectangular `holes`
    (x0, x1, z0, z1), and the ribs at its ends."""
    y = -OUT + 0.04
    z0, z1 = BOTTOM + 0.12, TOP - 0.12
    for z in (BOTTOM + 0.06, TOP - 0.06):
        m.box((WIDTH, OUT - HALF_WALL, 0.12), k["frame"], at=(0, -(OUT + HALF_WALL) / 2, z), bevel=0.012)
    for x in (-WIDTH / 2 + 0.05, WIDTH / 2 - 0.05):
        m.box((0.1, 0.1, TOP - BOTTOM), k["frame"], at=(x, -OUT + 0.03, (TOP + BOTTOM) / 2), bevel=0.01)
    if not holes:
        m.box((WIDTH - 0.2, 0.08, z1 - z0), k["blanket"], at=(0, y, (z0 + z1) / 2))
        return
    for hx0, hx1, hz0, hz1 in holes:
        m.box((WIDTH - 0.2, 0.08, hz0 - z0), k["blanket"], at=(0, y, (z0 + hz0) / 2))
        m.box((WIDTH - 0.2, 0.08, z1 - hz1), k["blanket"], at=(0, y, (hz1 + z1) / 2))
        m.box((hx0 + WIDTH / 2 - 0.1, 0.08, hz1 - hz0), k["blanket"], at=((-WIDTH / 2 + 0.1 + hx0) / 2, y, (hz0 + hz1) / 2))
        m.box((WIDTH / 2 - 0.1 - hx1, 0.08, hz1 - hz0), k["blanket"], at=((hx1 + WIDTH / 2 - 0.1) / 2, y, (hz0 + hz1) / 2))
        # A deep frame round the opening, through to the wall.
        for x in (hx0 - 0.05, hx1 + 0.05):
            m.box((0.1, OUT - HALF_WALL, hz1 - hz0 + 0.2), k["frame"], at=(x, -(OUT + HALF_WALL) / 2, (hz0 + hz1) / 2), bevel=0.01)
        for z in (hz0 - 0.05, hz1 + 0.05):
            m.box((hx1 - hx0 + 0.2, OUT - HALF_WALL, 0.1), k["frame"], at=((hx0 + hx1) / 2, -(OUT + HALF_WALL) / 2, z), bevel=0.01)


def _side_details(m, d, k, dk, texts, holes=(), rail=True, foil=True):
    """The face's furniture: a gold foil blanket over its upper half, quilting on the white, the
    EVA handrail, a relay-blue band with its stencil, rivets down the ribs; all clear of `holes`."""
    def clear(x0, x1, z0, z1):
        return all(x1 < hx0 - 0.1 or x0 > hx1 + 0.1 or z1 < hz0 - 0.1 or z0 > hz1 + 0.1 for hx0, hx1, hz0, hz1 in holes)

    face = -OUT
    if foil and clear(-1.75, 1.75, 1.95, 3.2):
        m.box((3.5, 0.03, 1.25), k["foil"], at=(0, face - 0.005, 2.575), bevel=0.01)
        for x in (-1.0, 0.0, 1.0):
            m.box((0.04, 0.035, 1.25), k["frame"], at=(x, face - 0.01, 2.575))
    if clear(-1.9, 1.9, -0.38, 1.9):
        _quilt(d, dk, Vector((0, face, 0.76)), FRONT, 3.8, 2.28)
    if rail and clear(-1.9, 1.9, 0.9, 1.3):
        ry = face - 0.15
        _rail(m, k, [(-WIDTH / 2 + 0.25, ry, 1.1), (WIDTH / 2 - 0.25, ry, 1.1)], face, [(-1.5, ry, 1.1), (0.0, ry, 1.1), (1.5, ry, 1.1)])
    if clear(-1.9, 1.9, 0.05, 0.35):
        _plate(d, dk["blue"], Vector((0, face, 0.2)), FRONT, 3.8, 0.18)
        texts.append(geo.text("RELAY", 0.11, dk["white"], matrix=frame((-1.1, face, 0.2), FRONT, lift=0.002)))
        texts.append(geo.text("NO STEP", 0.07, dk["white"], matrix=frame((1.2, face, 0.2), FRONT, lift=0.002)))
    for x in (-WIDTH / 2 + 0.05, WIDTH / 2 - 0.05):
        for i in range(10):
            z = BOTTOM + 0.3 + i * 0.37
            d.polygon([(-0.01, -0.01), (0.01, -0.01), (0.01, 0.01), (-0.01, 0.01)], dk["dark"], frame((x, -OUT - 0.021, z), FRONT, lift=0.001))


def _side_colliders(name, holes=()):
    """The plating's outer layer, solid round any opening that's a way through."""
    depth = OUT - HALF_WALL
    y = -(OUT + HALF_WALL) / 2
    if not holes:
        return [_collider(f"{name}_col", (WIDTH, depth, TOP - BOTTOM), (0, y, (TOP + BOTTOM) / 2))]
    hx0, hx1, hz0, hz1 = holes[0]
    return [_collider(f"{name}_col_l", (hx0 + WIDTH / 2, depth, TOP - BOTTOM), ((-WIDTH / 2 + hx0) / 2, y, (TOP + BOTTOM) / 2)),
            _collider(f"{name}_col_r", (WIDTH / 2 - hx1, depth, TOP - BOTTOM), ((hx1 + WIDTH / 2) / 2, y, (TOP + BOTTOM) / 2)),
            _collider(f"{name}_col_t", (hx1 - hx0, depth, TOP - hz1), ((hx0 + hx1) / 2, y, (hz1 + TOP) / 2)),
            _collider(f"{name}_col_b", (hx1 - hx0, depth, hz0 - BOTTOM), ((hx0 + hx1) / 2, y, (BOTTOM + hz0) / 2))]


def _side(name, holes=(), rail=True, foil=True, extra=None, passable=False):
    k = _materials()
    dk = _decals()
    m = Mesh(name)
    d = Mesh(f"{name}_decals")
    texts = []
    _side_shell(m, k, holes)
    _side_details(m, d, k, dk, texts, holes, rail=rail, foil=foil)
    extras = []
    if extra:
        extras = extra(m, d, k, dk, texts) or []
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()] + texts, extras=_side_colliders(name, holes if passable else ()) + extras)


@asset("sh_side", "satellite", texture=256, colors=32, ao=0.45, angles=((-30, 15), (30, 40), (0, 0), (-60, -20)))
def side():
    """Satellite hull side over an exterior wall, a level's deck to the next's: white beta-cloth
    blanket quilted on a grey frame, a gold foil blanket over its upper half, a yellow EVA
    handrail at chest height, a relay-blue band along the bottom stencilled RELAY and NO STEP."""
    return _side("sh_side")


@asset("sh_side_window", "satellite", texture=256, colors=32, ao=0.45, angles=((-30, 15), (30, 40), (0, 0), (-60, -20)))
def side_window():
    """Satellite hull side over a window wall: the port framed deep in the blanket (matches
    sk_wall_window's 2.6 x 1.3 m glass), no foil over it."""
    return _side("sh_side_window", holes=((-1.45, 1.45, 0.86, 2.44),), foil=False)


@asset("sh_side_hatch", "satellite", texture=256, colors=32, ao=0.45, angles=((-30, 15), (30, 40), (0, 0), (-60, -20)))
def side_hatch():
    """The satellite's EVA hatch from outside, where the crew come aboard: a deep collar ring round
    the round hatch, a yellow-and-black hazard ring on the blanket, handrails up both sides and over
    the top, a tether ring to clip to, two floodlights over it lighting the approach (`flood_l`,
    `flood_r`: lenses Godot lights; SOCKET_flood_l, SOCKET_flood_r, where their spots shine from)
    and an amber approach beacon on top (`beacon_lamp`, SOCKET_beacon). EVA HATCH stencilled
    under it, and arrows."""
    def collar(m, d, k, dk, texts):
        cz = HATCH_CZ
        # Up the outside, across its end and down the bore: each face looks the way it's seen from.
        m.lathe([(1.3, 0.0), (1.3, 0.48), (1.17, 0.48), (1.1, 0.42), (1.1, 0.0)], k["frame"], sides=16, at=(0, -OUT + 0.04, cz),
                rot=(90, 0, 0), cap_start=False, cap_end=False)
        normal = FRONT
        for i in range(20):
            a0, a1 = i / 20 * math.tau, (i + 1) / 20 * math.tau
            pts = [(math.cos(a0) * 1.33, math.sin(a0) * 1.33), (math.cos(a1) * 1.33, math.sin(a1) * 1.33),
                   (math.cos(a1) * 1.52, math.sin(a1) * 1.52), (math.cos(a0) * 1.52, math.sin(a0) * 1.52)]
            d.polygon(pts, dk["black"] if i % 2 else dk["yellow"], frame((0, -OUT + 0.0, cz), normal, lift=0.001))
        ry = -OUT - 0.15
        for x in (-1.72, 1.72):
            _rail(m, k, [(x, ry, 0.15), (x, ry, 2.5)], -OUT, [(x, ry, 0.3), (x, ry, 2.35)])
        _rail(m, k, [(-0.9, ry, 2.62), (0.9, ry, 2.62)], -OUT, [(-0.75, ry, 2.62), (0.75, ry, 2.62)])
        # The tether ring, beside the hatch at waist height.
        m.box((0.16, 0.06, 0.16), k["dark"], at=(1.45, -OUT - 0.03, 0.55), bevel=0.01)
        m.lathe([(0.06, -0.012), (0.075, 0.0), (0.06, 0.012), (0.045, 0.0), (0.06, -0.012)], k["steel"], sides=8,
                at=(1.45, -OUT - 0.12, 0.55), rot=(0, 90, 0), cap_start=False, cap_end=False)
        # Floodlights on short arms, angled out and down at the approach; the beacon on top.
        lamps = []
        sockets = []
        for side, x in (("l", -1.55), ("r", 1.55)):
            m.box((0.08, 0.3, 0.08), k["frame"], at=(x, -OUT - 0.15, 3.0), bevel=0.01)
            m.box((0.3, 0.2, 0.22), k["dark"], at=(x, -OUT - 0.38, 3.0), rot=(-20, 0, 0), bevel=0.02)
            lamps.append(_lamp(f"flood_{side}", Vector((x, -OUT - 0.49, 2.96)), 0.09, "sh_flood"))
            sockets.append(_socket(f"flood_{side}", (x, -OUT - 0.52, 2.95)))
        m.cylinder(0.08, 0.12, k["dark"], sides=8, at=(0, -OUT - 0.08, 3.28), rot=(90, 0, 0))
        beacon = Mesh("beacon_lamp")
        beacon.lathe([(0.06, 0.0), (0.06, 0.06), (0.04, 0.1), (0.0, 0.11)], mats.plain("sh_beacon", (1.0, 0.7, 0.2)), sides=8,
                     at=(0, -OUT - 0.08, 3.34))
        sockets.append(_socket("beacon", (0, -OUT - 0.1, 3.42)))
        texts.append(geo.text("EVA HATCH", 0.13, dk["white"], matrix=frame((0, -OUT, -0.25), FRONT, lift=0.002)))
        for x, flip in ((-0.75, 1), (0.75, -1)):
            pts = [(x - 0.1 * flip, -0.32), (x + 0.02 * flip, -0.25), (x - 0.1 * flip, -0.18)]
            d.polygon(pts if flip < 0 else list(reversed(pts)), dk["yellow"], frame((0, -OUT, 0), FRONT, lift=0.002))
        return lamps + [beacon.to_object()] + sockets
    return _side("sh_side_hatch", holes=((-1.1, 1.1, 0.0, 2.25),), rail=False, foil=False, extra=collar, passable=True)


@asset("sh_corner", "satellite", texture=128, colors=24, ao=0.45)
def corner():
    """An outer corner of the satellite's hull: a rounded eight-sided post filling the notch where
    two sides meet, a level's height, grey frame banded in blanket white."""
    k = _materials()
    m = Mesh("sh_corner")
    m.lathe([(0.25, BOTTOM), (0.42, BOTTOM + 0.15), (0.42, TOP - 0.15), (0.25, TOP)], k["frame"], sides=8, angle_offset=math.pi / 8)
    m.lathe([(0.44, 0.3), (0.44, 2.7)], k["blanket"], sides=8, angle_offset=math.pi / 8, cap_start=False, cap_end=False)
    for z in (0.3, 2.7):
        m.lathe([(0.45, z - 0.04), (0.45, z + 0.04)], k["frame"], sides=8, angle_offset=math.pi / 8, cap_start=False, cap_end=False)
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[_collider("sh_corner_col", (0.84, 0.84, TOP - BOTTOM), (0, 0, (TOP + BOTTOM) / 2))])


@asset("sh_roof", "satellite", texture=256, colors=32, ao=0.45, angles=((-30, 40), (150, 50), (0, 70), (90, 25)))
def roof():
    """The satellite's roof over a cell: a white radiator panel in a grey frame (ribbed, it sheds
    the electronics' heat), silver foil strips either side, a handrail across it."""
    k = _materials()
    dk = _decals()
    m = Mesh("sh_roof")
    d = Mesh("sh_roof_decals")
    m.box((WIDTH, WIDTH, ROOF_TOP - ROOF - 0.04), k["frame"], at=(0, 0, (ROOF + ROOF_TOP - 0.04) / 2))
    m.box((2.4, 3.6, 0.04), k["radiator"], at=(0, 0, ROOF_TOP - 0.02))
    for i in range(9):
        m.box((0.03, 3.6, 0.03), k["frame"], at=(-1.2 + i * 0.3, 0, ROOF_TOP + 0.01))
    for x in (-1.55, 1.55):
        m.box((0.6, 3.8, 0.02), k["silver"], at=(x, 0, ROOF_TOP - 0.03))
    ry = 0.15
    _rail(m, k, [(-1.6, 1.75, ROOF_TOP + ry), (1.6, 1.75, ROOF_TOP + ry)], ROOF_TOP, [])
    for x in (-1.4, 1.4):
        m.pipe([(x, 1.75, ROOF_TOP), (x, 1.75, ROOF_TOP + ry)], 0.015, k["rail"], sides=5, caps=False)
    up = Vector((0, 0, 1))
    _plate(d, dk["blue"], Vector((0, -1.85, ROOF_TOP)), up, 3.6, 0.12, up=(0, 1, 0))
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[_collider("sh_roof_col", (WIDTH, WIDTH, ROOF_TOP - ROOF), (0, 0, (ROOF + ROOF_TOP) / 2))])


@asset("sh_belly", "satellite", texture=128, colors=24, ao=0.45, angles=((-30, -40), (150, -50), (0, -70), (90, -25)))
def belly():
    """The satellite's underside under a cell: a gold foil blanket in a grey frame, a keel rib."""
    k = _materials()
    m = Mesh("sh_belly")
    m.box((WIDTH, WIDTH, BELLY - BELLY_BOTTOM - 0.03), k["frame"], at=(0, 0, (BELLY + BELLY_BOTTOM + 0.03) / 2))
    m.box((3.7, 3.7, 0.03), k["foil"], at=(0, 0, BELLY_BOTTOM + 0.015))
    m.box((0.2, WIDTH, 0.08), k["frame"], at=(0, 0, BELLY_BOTTOM - 0.03), bevel=0.01)
    m.subdivide(1.0)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[_collider("sh_belly_col", (WIDTH, WIDTH, BELLY - BELLY_BOTTOM), (0, 0, (BELLY + BELLY_BOTTOM) / 2))])


# On the hull --------------------------------------------------------------------------------------

WING_ROOT = 2.0     # where the panels start, out along the boom
PANEL = (3.1, 2.7)  # each panel's length along the wing, and its height
PANEL_GAP = 0.15


@asset("sh_solar_wing", "satellite", texture=256, colors=32, ao=0.4, angles=((-70, 15), (110, 20), (-90, 0), (-45, 60)))
def solar_wing():
    """A solar wing: a square truss boom off the hull, the drive that turns it, a yoke, and three
    panels of deep blue cells hinged end to end, 11.6 m out in all and standing on edge, cells on
    the -X face (toward the LANTERN, as the satellite's turned), the pale substrate and its wiring
    on the other. A navigation lamp at the tip (`nav_lamp`, SOCKET_nav: Godot colours and blinks it,
    red to the north, green to the south). Built out along -Y (+Z in Godot) from its mount (the
    origin, on the hull's outer face), at its level's middle."""
    k = _materials()
    dk = _decals()
    m = Mesh("sh_solar_wing")
    d = Mesh("sh_solar_wing_decals")
    texts = []
    m.box((0.6, 0.08, 0.6), k["frame"], at=(0, -0.04, 0), bevel=0.01)
    # The boom: four longerons and zig-zag bracing.
    s = 0.14
    for x, z in ((-s, -s), (s, -s), (s, s), (-s, s)):
        m.pipe([(x, -0.05, z), (x, -1.55, z)], 0.025, k["steel"], sides=4)
    for i in range(5):
        y0, y1 = -0.1 - i * 0.29, -0.1 - (i + 1) * 0.29
        for a, b in (((-s, -s), (s, -s)), ((s, s), (-s, s))):
            m.pipe([(a[0], y0, a[1]), (b[0], y1, b[1])], 0.012, k["steel"], sides=4, caps=False)
        for a, b in (((-s, s), (-s, -s)), ((s, -s), (s, s))):
            m.pipe([(a[0], y0, a[1]), (b[0], y1, b[1])], 0.012, k["steel"], sides=4, caps=False)
    # The array drive and the yoke.
    m.cylinder(0.24, 0.3, k["dark"], sides=8, at=(0, -1.7, 0), rot=(90, 0, 0))
    m.cylinder(0.27, 0.05, k["blue"], sides=8, at=(0, -1.58, 0), rot=(90, 0, 0))
    for z in (-1.0, 1.0):
        m.pipe([(0, -1.85, 0), (0, -1.95, z * 0.6), (0, WING_ROOT * -1 + 0.02, z * 1.25)], 0.03, k["frame"], sides=4)
    m.box((0.08, 0.06, 2.7), k["frame"], at=(0, -WING_ROOT + 0.03, 0), bevel=0.01)
    # The panels, on edge.
    length, height = PANEL
    for i in range(3):
        y0 = -WING_ROOT - i * (length + PANEL_GAP)
        cy = y0 - length / 2
        m.box((0.03, length, height), k["substrate"], at=(0.005, cy, 0))
        m.box((0.01, length - 0.1, height - 0.1), k["cells"], at=(-0.016, cy, 0))
        for z in (-height / 2, height / 2):
            m.box((0.05, length, 0.04), k["frame"], at=(0, cy, z))
        for y in (y0 - 0.02, y0 - length + 0.02):
            m.box((0.05, 0.04, height), k["frame"], at=(0, y, 0))
        if i < 2:
            for z in (-0.9, 0.9):
                m.box((0.06, PANEL_GAP + 0.06, 0.12), k["dark"], at=(0, y0 - length - PANEL_GAP / 2, z))
        # The cells' grid: silver bus bars between the strings.
        f = frame((-0.022, cy, 0), (-1, 0, 0), up=(0, 0, 1), lift=0.0)
        for j in range(1, 6):
            yy = -length / 2 + j * length / 6
            d.polygon([(yy - 0.008, -height / 2 + 0.06), (yy + 0.008, -height / 2 + 0.06), (yy + 0.008, height / 2 - 0.06),
                       (yy - 0.008, height / 2 - 0.06)], dk["silver"], f)
        for j in range(1, 8):
            zz = -height / 2 + j * height / 8
            d.polygon([(-length / 2 + 0.06, zz - 0.004), (length / 2 - 0.06, zz - 0.004), (length / 2 - 0.06, zz + 0.004),
                       (-length / 2 + 0.06, zz + 0.004)], dk["dark"], f)
        # The substrate's wiring on the back.
        g = frame((0.021, cy, 0), (1, 0, 0), up=(0, 0, 1), lift=0.0)
        for zz in (-0.8, 0.0, 0.8):
            d.polygon([(-length / 2 + 0.1, zz - 0.012), (length / 2 - 0.1, zz - 0.012), (length / 2 - 0.1, zz + 0.012),
                       (-length / 2 + 0.1, zz + 0.012)], dk["dark"], g)
    tip = -WING_ROOT - 3 * length - 2 * PANEL_GAP
    m.box((0.12, 0.14, 0.14), k["dark"], at=(0, tip - 0.07, height / 2 - 0.1), bevel=0.01)
    lamp = Mesh("nav_lamp")
    lamp.cylinder(0.05, 0.06, mats.plain("sh_nav", (1.0, 1.0, 1.0)), sides=6, at=(0, tip - 0.16, height / 2 - 0.1), rot=(90, 0, 0))
    m.subdivide(2.0)
    low = m.to_object()
    run = 3 * length + 2 * PANEL_GAP
    colliders = [_collider("sh_solar_wing_boom", (0.36, WING_ROOT, 0.36), (0, -WING_ROOT / 2, 0)),
                 _collider("sh_solar_wing_panels", (0.06, run, height), (0, -WING_ROOT - run / 2, 0))]
    return Model(low=low, decals=[d.to_object()] + texts,
                 extras=colliders + [lamp.to_object(), _socket("nav", (0, tip - 0.2, height / 2 - 0.1))])


DISH_R = 2.1
DISH_F = 2.0     # its focal length: the feed's distance out along its axis
DISH_TILT = 50.0  # elevation from straight up, toward its front (-Y)
DISH_AXLE = 1.5  # the elevation axle's height over the roof


@asset("sh_dish", "satellite", texture=256, colors=32, ao=0.45, angles=((-30, 25), (150, 30), (-90, 10), (0, 70)))
def dish():
    """The relay's dish: a 4.2 m white reflector on a two-axis mount, its feed horn held at the
    focus by three struts, its back a grey ribbed frame. It stands on the roof (the origin) and
    looks out and up, its front turned toward the LANTERN's side of the sky."""
    k = _materials()
    dk = _decals()
    reflector = mats.plain("sh_reflector", (0.9, 0.9, 0.88), grime=0.05, variation=0.04)
    m = Mesh("sh_dish")
    d = Mesh("sh_dish_decals")
    m.cylinder(0.5, 0.16, k["frame"], sides=10, at=(0, 0, 0.08))
    m.cylinder(0.4, 0.2, k["dark"], sides=10, at=(0, 0, 0.26))
    m.cylinder(0.16, DISH_AXLE - 0.36, k["frame"], sides=8, at=(0, 0, 0.36 + (DISH_AXLE - 0.36) / 2))
    for x in (-0.42, 0.42):
        m.box((0.08, 0.2, 0.6), k["frame"], at=(x, 0, DISH_AXLE - 0.1), bevel=0.01)
    m.cylinder(0.08, 0.98, k["steel"], sides=8, at=(0, 0, DISH_AXLE), rot=(0, 90, 0))
    # The reflector and everything on it, built about its own axis (+Z), then tipped.
    tilt = place((0, 0, DISH_AXLE), (DISH_TILT, 0, 0))
    profile = [(r, r * r / (4 * DISH_F)) for r in (0.0, 0.5, 1.0, 1.5, DISH_R)]
    base = 0.32  # the reflector's vertex, out from the axle
    # The reflector's profile runs in from the rim, so it looks up its axis at the feed; the back
    # runs out from the middle, looking away.
    face = m.lathe([(r, z + base) for r, z in reversed(profile)], reflector, sides=12, cap_start=False, cap_end=False)
    back = m.lathe([(r, z + base - 0.04) for r, z in profile], k["frame"], sides=12, cap_start=False, cap_end=False)
    rim_z = profile[-1][1] + base
    rim = m.lathe([(DISH_R, rim_z - 0.04), (DISH_R + 0.05, rim_z - 0.02), (DISH_R + 0.05, rim_z + 0.02), (DISH_R, rim_z + 0.01)],
                  k["frame"], sides=12, cap_start=False, cap_end=False)
    m.transform(face + back + rim, tilt)
    parts = []
    for i in range(6):
        a = i / 6 * math.tau
        c, s = math.cos(a), math.sin(a)
        parts += m.pipe([(c * 0.25, s * 0.25, base - 0.06), (c * 1.1, s * 1.1, base + 1.1 ** 2 / (4 * DISH_F) - 0.08),
                         (c * 2.05, s * 2.05, rim_z - 0.08)], 0.025, k["frame"], sides=4)
    for i in range(3):
        a = i / 3 * math.tau + math.pi / 6
        parts += m.pipe([(math.cos(a) * 1.9, math.sin(a) * 1.9, rim_z - 0.02), (0, 0, base + DISH_F - 0.12)], 0.018, k["steel"], sides=4)
    parts += m.box((0.16, 0.16, 0.24), k["dark"], at=(0, 0, base + DISH_F), bevel=0.02)
    parts += m.cylinder(0.1, 0.12, k["blue"], sides=8, at=(0, 0, base + DISH_F - 0.14))
    parts += m.cylinder(0.22, 0.3, k["dark"], sides=8, at=(0, 0, base - 0.14))
    m.transform(parts, tilt)
    m.subdivide(1.2)
    low = m.to_object()
    up = Vector((0, 0, 1))
    _plate(d, dk["blue"], Vector((0, 0, 0.16)), up, 0.5, 0.12, up=(0, 1, 0))
    axis = tilt.to_3x3() @ Vector((0, 0, 1))
    reach = tilt @ Vector((0, 0, base + 0.5))
    colliders = [_collider("sh_dish_mount", (1.0, 1.0, DISH_AXLE), (0, 0, DISH_AXLE / 2)),
                 _collider("sh_dish_body", (3.0, 3.0, 1.2), tuple(reach + axis * 0.1), rot=(DISH_TILT, 0, 0))]
    return Model(low=low, decals=[d.to_object()], extras=colliders)


@asset("sh_mast", "satellite", texture=128, colors=32, ao=0.45)
def mast():
    """A comms mast for the satellite's roof: a slim lattice tower, a helical antenna and two whips,
    and a white strobe on its tip (`beacon_lamp`, SOCKET_beacon: Godot flashes it), so the crew can
    find the satellite in the dark."""
    k = _materials()
    m = Mesh("sh_mast")
    m.box((0.5, 0.5, 0.12), k["frame"], at=(0, 0, 0.06), bevel=0.02)
    for x, y in ((-0.18, -0.18), (0.18, -0.18), (0.18, 0.18), (-0.18, 0.18)):
        m.pipe([(x, y, 0.1), (x * 0.4, y * 0.4, 2.9)], 0.025, k["steel"], sides=4)
    for z in (0.6, 1.2, 1.8, 2.4):
        sz = 0.18 - z * 0.04
        m.pipe([(-sz, -sz, z), (sz, -sz, z), (sz, sz, z), (-sz, sz, z), (-sz, -sz, z)], 0.015, k["steel"], sides=4, caps=False)
    m.box((0.2, 0.2, 0.1), k["dark"], at=(0, 0, 2.95), bevel=0.01)
    helix = []
    for i in range(25):
        a = i / 24 * math.tau * 4
        helix.append((0.22 + math.cos(a) * 0.06, math.sin(a) * 0.06, 1.6 + i * 0.02))
    m.pipe([(0.06, 0, 1.6), (0.22, 0, 1.6)], 0.01, k["steel"], sides=4)
    m.pipe(helix, 0.008, k["rail"], sides=4)
    for x in (-0.07, 0.07):
        m.pipe([(x, 0.06, 2.95), (x, 0.06, 3.9)], 0.008, k["dark"], sides=4)
    beacon = Mesh("beacon_lamp")
    beacon.lathe([(0.07, 0.0), (0.07, 0.08), (0.05, 0.14), (0.0, 0.16)], mats.plain("sh_strobe", (1.0, 1.0, 1.0)), sides=8,
                 at=(0, 0, 3.0))
    low = m.to_object()
    return Model(low=low, decals=[], extras=[beacon.to_object(), _socket("beacon", (0, 0, 3.12)),
                                             _collider("sh_mast_col", (0.4, 0.4, 3.0), (0, 0, 1.5))])


@asset("sh_rcs", "satellite", texture=64, colors=24, ao=0.45)
def rcs():
    """A thruster cluster for an outer corner of the hull, its back to the corner post: an
    armoured block on a bracket with four small nozzles, up, down and to either side, for the relay
    to keep its station. Faces out (-Y) along the corner's diagonal."""
    k = _materials()
    m = Mesh("sh_rcs")
    m.box((0.18, 0.56, 0.18), k["frame"], at=(0, -0.17, 0), bevel=0.02)
    m.box((0.36, 0.3, 0.36), k["dark"], at=(0, -0.55, 0), bevel=0.03)
    m.box((0.38, 0.06, 0.38), k["foil"], at=(0, -0.39, 0), bevel=0.01)
    for rot, at in (((0, 0, 0), (0, -0.55, 0.18)), ((180, 0, 0), (0, -0.55, -0.18)), ((0, 90, 0), (0.18, -0.55, 0)),
                    ((0, -90, 0), (-0.18, -0.55, 0))):
        m.lathe([(0.04, 0.0), (0.05, 0.04), (0.09, 0.16), (0.08, 0.165)], k["steel"], sides=8, at=at, rot=rot, cap_start=False, cap_end=False)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[])


# Inside -------------------------------------------------------------------------------------------

def _console_materials():
    """The bridge's console recipes (bridge.py) in the relay's livery: pale casings, blue-grey."""
    return dict(
        casing=mats.paint("sp_casing", (0.76, 0.78, 0.79), wear=0.08, grime=0.12, under=(0.55, 0.57, 0.6)),
        casing_dark=mats.paint("sp_casing_dark", (0.24, 0.27, 0.31), wear=0.1, grime=0.15),
        bezel=mats.plain("sp_bezel", (0.11, 0.12, 0.14), grime=0.1),
        steel=mats.metal("sp_steel", (0.64, 0.65, 0.66), grime=0.12),
        dark_steel=mats.metal("sp_dark_steel", (0.24, 0.25, 0.27), grime=0.15),
        rubber=mats.plain("sp_rubber", (0.07, 0.07, 0.08), grime=0.1),
        orange=mats.paint("sp_blue", (0.16, 0.42, 0.68), wear=0.1, grime=0.1),
        keycap=mats.plain("sp_keycap", (0.84, 0.85, 0.84), grime=0.15),
        keycap_dark=mats.plain("sp_keycap_dark", (0.2, 0.21, 0.23), grime=0.1),
        dial_face=mats.plain("sp_dial", (0.9, 0.9, 0.88), grime=0.1),
        cable=mats.plain("sp_cable", (0.1, 0.1, 0.12), grime=0.08),
        cable_red=mats.plain("sp_cable_blue", (0.12, 0.3, 0.55), grime=0.08),
        yellow=mats.paint("sp_yellow", (0.9, 0.72, 0.12), wear=0.1, grime=0.1),
        copper=mats.metal("sp_copper", (0.72, 0.45, 0.25), grime=0.1),
        fabric=mats.plain("sp_fabric", (0.86, 0.85, 0.8), grime=0.1, detail_strength=0.3),
        bag=mats.plain("sp_bag", (0.2, 0.32, 0.55), grime=0.08, detail_strength=0.3),
        strap=mats.plain("sp_strap", (0.82, 0.66, 0.15), grime=0.1),
        tank=mats.metal("sp_tank", (0.62, 0.62, 0.6), grime=0.08, brushed=False),
        core=mats.glowing("sp_core_glow", (0.45, 0.85, 1.0), base=(0.2, 0.4, 0.5), flicker=0.15),
        led=mats.glowing("sp_led", (0.45, 1.0, 0.6), base=(0.15, 0.35, 0.2), flicker=0.3),
    )


def _decals_inside():
    dk = br._decals()
    dk.update(yellow=mats.decal("sp_d_yellow", (0.9, 0.72, 0.12)), blue=mats.decal("sp_d_blue", (0.16, 0.42, 0.68)),
              white=mats.decal("sp_d_white", (0.92, 0.92, 0.9)), blue_lit=mats.decal("sp_d_blue_lit", (0.45, 0.8, 1.0), glow=True))
    return dk


def _activity(name, points, normal=FRONT):
    """Activity lamps, their own object (`name`, the plain `sp_activity` material): little squares
    that Godot flickers, so a working machine looks busy."""
    m = Mesh(name)
    for p in points:
        m.polygon([(-0.008, -0.006), (0.008, -0.006), (0.008, 0.006), (-0.008, 0.006)], mats.plain("sp_activity", (0.5, 1.0, 0.6)),
                  frame(p, normal, lift=0.003))
    return m.to_object()


@asset("sp_rack", "satellite", texture=128, colors=32, ao=0.5)
def rack():
    """A rack of relay electronics, 0.9 x 0.6 m and 2.25 m tall, its back to a wall: a blue-grey
    cabinet holding eight pale units with pull handles, status lamps, little green readouts and
    vent slots; a cable loom out of its top into the wall. Some of its lamps flicker with traffic
    (`activity`). Salvage, if crew can get the boards out."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_rack")
    d = Mesh("sp_rack_decals")
    texts = []
    w, depth, h = 0.9, 0.6, 2.25
    m.box((w, depth, 0.1), k["casing_dark"], at=(0, 0, 0.05), bevel=0.01)
    for x in (-w / 2 + 0.03, w / 2 - 0.03):
        m.box((0.06, depth, h - 0.1), k["casing_dark"], at=(x, 0, 0.1 + (h - 0.1) / 2), bevel=0.008)
    m.box((w, depth, 0.12), k["casing_dark"], at=(0, 0, h - 0.06), bevel=0.01)
    m.box((w - 0.12, 0.04, h - 0.22), k["bezel"], at=(0, depth / 2 - 0.02, 0.1 + (h - 0.22) / 2))
    blinks = []
    heights = (0.16, 0.26, 0.2, 0.3, 0.16, 0.22, 0.26, 0.18)
    z = 0.14
    for i, uh in enumerate(heights):
        cz = z + uh / 2
        face_y = 0.02 - (depth - 0.08) / 2
        m.box((w - 0.14, depth - 0.08, uh - 0.015), k["casing"], at=(0, 0.02, cz), bevel=0.006)
        for x in (-0.34, 0.34):
            m.pipe([(x, face_y, cz - uh * 0.25), (x, face_y - 0.035, cz - uh * 0.2), (x, face_y - 0.035, cz + uh * 0.2),
                    (x, face_y, cz + uh * 0.25)], 0.008, k["steel"], sides=4, caps=False)
        # Each unit's face: its lamps, a readout or vent slots.
        for j in range(4):
            colour = dk["green_lit"] if (i + j) % 3 else dk["amber_lit"] if j == 1 else dk["unlit"]
            d.polygon([(-0.008, -0.006), (0.008, -0.006), (0.008, 0.006), (-0.008, 0.006)], colour,
                      frame((-0.24 + j * 0.035, face_y, cz + uh * 0.25), FRONT, lift=0.001))
        if i % 3 == 1:
            _plate(d, dk["black"], Vector((0.06, face_y, cz)), FRONT, 0.26, uh * 0.45)
            _plate(d, dk["green_lit"], Vector((0.06, face_y, cz)), FRONT, 0.22, uh * 0.3, lift=0.0015)
        else:
            for v in range(4):
                _plate(d, dk["black"], Vector((0.1, face_y, cz - uh * 0.2 + v * uh * 0.13)), FRONT, 0.3, 0.012)
        blinks += [Vector((-0.24 + j * 0.035, face_y, cz - uh * 0.2)) for j in range(i % 2, 4, 2)]
        z += uh
    texts.append(geo.text("RELAY  TX/RX", 0.04, dk["white"], matrix=frame((0, -depth / 2, h - 0.06), FRONT, lift=0.002)))
    for x in (-0.2, 0.0, 0.2):
        m.pipe([(x, 0.15, h), (x, 0.22, h + 0.25), (x * 0.6, 0.29, h + 0.55)], 0.022, k["cable"] if x else k["cable_red"], sides=5)
    low = m.to_object()
    collider = br._console_collider("sp_rack", (w, depth, h), (0, 0, h / 2))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider, _activity("activity", blinks)])


@asset("sp_battery", "satellite", texture=128, colors=32, ao=0.5)
def battery():
    """A battery bank, 1.6 m wide, 1.5 m tall, its back to a wall: six cell modules on a plinth,
    terminals and copper bus bars across their tops, a charge gauge and a column of charge lamps,
    HIGH VOLTAGE on a hazard band."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_battery")
    d = Mesh("sp_battery_decals")
    texts = []
    m.box((1.6, 0.55, 0.12), k["casing_dark"], at=(0, 0, 0.06), bevel=0.01)
    m.box((1.6, 0.06, 1.9), k["casing_dark"], at=(0, 0.245, 0.95), bevel=0.01)
    for row in range(2):
        for col in range(3):
            x = -0.5 + col * 0.5
            z0 = 0.12 + row * 0.66
            m.box((0.46, 0.44, 0.6), k["casing"], at=(x, -0.02, z0 + 0.3), bevel=0.012)
            m.box((0.47, 0.45, 0.06), k["yellow"], at=(x, -0.02, z0 + 0.58), bevel=0.006)
            for tx in (-0.12, 0.12):
                m.cylinder(0.025, 0.05, k["copper"], sides=6, at=(x + tx, -0.1, z0 + 0.63))
            _plate(d, dk["black"], Vector((x, -0.241, z0 + 0.32)), FRONT, 0.3, 0.12)
            texts.append(geo.text("%d%d" % (row + 1, col + 1), 0.06, dk["white"], matrix=frame((x, -0.241, z0 + 0.32), FRONT, lift=0.002)))
        m.box((1.36, 0.04, 0.03), k["copper"], at=(0, -0.1, 0.12 + row * 0.66 + 0.665))
    m.box((0.32, 0.12, 0.26), k["casing"], at=(0.0, 0.16, 1.6), bevel=0.01)
    br.dial(m, d, k, dk, Vector((-0.6, 0.215, 1.66)), FRONT, UP, radius=0.07, value=0.82, red_zone=False)
    for i in range(5):
        _plate(d, dk["green_lit"] if i < 4 else dk["unlit"], Vector((0.62, 0.214, 1.53 + i * 0.05)), FRONT, 0.08, 0.03)
    _hazard_band(d, dk, Vector((0, -0.276, 0.06)), 1.56, 0.08)
    texts.append(geo.text("HIGH VOLTAGE", 0.05, dk["white"], matrix=frame((0, 0.214, 1.8), FRONT, lift=0.002)))
    low = m.to_object()
    collider = br._console_collider("sp_battery", (1.6, 0.55, 1.9), (0, 0, 0.95))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


def _hazard_band(d, dk, centre, w, h):
    _plate(d, dk["yellow"], centre, FRONT, w, h)
    f = frame(centre, FRONT, lift=0.0015)
    pitch = 0.12
    for i in range(-int(w / pitch) - 2, int(w / pitch) + 3):
        x = i * pitch
        stripe = [(x, -h / 2), (x + pitch * 0.45, -h / 2), (x + pitch * 0.45 + h * 0.6, h / 2), (x + h * 0.6, h / 2)]
        d.polygon(clip(stripe, -w / 2, w / 2, -h / 2, h / 2), dk["black"], f)


@asset("sp_console", "satellite", texture=256, colors=32, ao=0.5)
def console():
    """The relay's telemetry console under its windows (GDD §8.1): a desk in the relay's livery with
    a live CRT (`screen_telemetry`: what the relay hears and passes on), a bank of toggles, lit
    buttons, a keyboard, a signal-strength gauge, the relay's code plate."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_console")
    d = Mesh("sp_console_decals")
    texts = []
    surface = br.desk(m, k, 1.4, depth=0.7, height=0.8)
    screen = br.crt(m, k, Vector((0.0, 0.12, 1.12)), 0.4, 0.3, tilt=10, depth=0.36, name="screen_telemetry")
    br.toggles(m, d, k, dk, surface, (-0.48, 0.0), 4, 2)
    br.buttons(d, dk, surface, (0.46, 0.0), 3, 2)
    br.keyboard(m, d, k, dk, surface, (0.0, -0.06), width=0.44, depth=0.12)
    m.box((1.4, 0.06, 0.55), k["casing_dark"], at=(0, 0.32, 1.22), bevel=0.01)
    br.dial(m, d, k, dk, Vector((-0.5, 0.29, 1.24)), FRONT, UP, radius=0.06, value=0.7, red_zone=False)
    _plate(d, dk["blue"], Vector((0.5, 0.289, 1.24)), FRONT, 0.26, 0.1)
    texts.append(geo.text("TELEMETRY", 0.035, dk["white"], matrix=frame((0.5, 0.289, 1.24), FRONT, lift=0.002)))
    low = m.to_object()
    collider = br._console_collider("sp_console", (1.4, 0.7, 1.0), (0, 0.0, 0.5))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[screen, collider])


@asset("sp_stowage", "satellite", texture=128, colors=32, ao=0.5)
def stowage():
    """Wall stowage, 1.6 m wide and 1.8 m tall: a grey frame on the wall holding blue cargo bags and
    white transfer bags under a yellow-strapped net, labelled the way an earlier wave's
    quartermaster left them."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_stowage")
    d = Mesh("sp_stowage_decals")
    texts = []
    m.box((1.6, 0.04, 1.8), k["casing_dark"], at=(0, 0.155, 1.0), bevel=0.01)
    for x in (-0.78, 0.78):
        m.box((0.05, 0.3, 1.8), k["steel"], at=(x, 0.03, 1.0), bevel=0.008)
    bags = ((-0.4, 0.4, 0.66, 0.5, "bag"), (0.38, 0.38, 0.7, 0.42, "fabric"), (-0.42, 1.0, 0.62, 0.44, "fabric"),
            (0.36, 0.98, 0.66, 0.5, "bag"), (-0.35, 1.52, 0.74, 0.38, "bag"), (0.4, 1.5, 0.6, 0.4, "fabric"))
    for x, z, bw, bh, cloth in bags:
        m.box((bw, 0.24, bh), k[cloth], at=(x, 0.02, z), bevel=0.05, segments=2)
        _plate(d, dk["white"] if cloth == "bag" else dk["blue"], Vector((x, -0.101, z + bh * 0.15)), FRONT, bw * 0.4, 0.08)
    for z in (0.2, 0.7, 1.25, 1.78):
        m.box((1.56, 0.03, 0.04), k["strap"], at=(0, -0.11, z))
    for x in (-0.6, -0.2, 0.2, 0.6):
        m.box((0.04, 0.03, 1.66), k["strap"], at=(x, -0.115, 1.0))
    texts.append(geo.text("SPARES", 0.05, dk["black"], matrix=frame((0.38, -0.101, 0.44), FRONT, lift=0.002)))
    low = m.to_object()
    collider = br._console_collider("sp_stowage", (1.6, 0.34, 1.8), (0, 0.0, 1.0))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


@asset("sp_tank", "satellite", texture=128, colors=32, ao=0.5)
def tank():
    """A propellant tank: a 1.44 m titanium sphere in a cradle of four legs and an equator band,
    its feed line and valve to the wall behind, a pressure gauge on a bracket, N2H4 and hazard
    stencils."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_tank")
    d = Mesh("sp_tank_decals")
    texts = []
    r = 0.72
    cz = 1.0
    ring = [(math.sin(a) * r, cz - math.cos(a) * r) for a in [i * math.pi / 6 for i in range(7)]]
    m.lathe(ring, k["tank"], sides=10)
    m.lathe([(r + 0.03, cz - 0.05), (r + 0.03, cz + 0.05)], k["casing_dark"], sides=10, cap_start=False, cap_end=False)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        c, s = math.cos(a), math.sin(a)
        m.pipe([(c * (r + 0.02), s * (r + 0.02), cz), (c * 0.8, s * 0.8, 0.05)], 0.035, k["casing_dark"], sides=5)
        m.box((0.16, 0.16, 0.04), k["casing_dark"], at=(c * 0.8, s * 0.8, 0.02))
    m.cylinder(0.08, 0.1, k["steel"], sides=8, at=(0, 0, cz + r + 0.04))
    m.pipe([(0, 0, cz + r + 0.08), (0, 0, cz + r + 0.2), (0, 0.5, cz + r + 0.2), (0, 0.82, cz + r + 0.2)], 0.03, k["steel"], sides=6)
    m.box((0.12, 0.12, 0.16), k["yellow"], at=(0, 0.45, cz + r + 0.2), bevel=0.01)
    m.pipe([(0.62, -0.1, 0.05), (0.62, -0.1, 1.2)], 0.02, k["steel"], sides=5)
    br.dial(m, d, k, dk, Vector((0.62, -0.13, 1.28)), FRONT, UP, radius=0.06, value=0.55)
    f = frame((0, -r - 0.001, cz + 0.22), FRONT, lift=0.002)
    texts.append(geo.text("N2H4", 0.12, dk["black"], matrix=f))
    _hazard_band(d, dk, Vector((0, -r + 0.02, cz - 0.15)), 0.5, 0.06)
    low = m.to_object()
    collider = br._console_collider("sp_tank", (1.5, 1.5, 1.9), (0, 0, 0.95))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


@asset("sp_feed", "satellite", texture=128, colors=32, ao=0.5)
def feed():
    """The antenna's feed: a switching cabinet on the deck and the waveguides that leave it, flanged
    copper ducts rising through bends and a rotary joint into the ceiling, up to the dish. RF HAZARD
    on the cabinet's face."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_feed")
    d = Mesh("sp_feed_decals")
    texts = []
    m.box((0.9, 0.7, 0.85), k["casing"], at=(0, 0, 0.425), bevel=0.015)
    m.box((0.92, 0.72, 0.06), k["casing_dark"], at=(0, 0, 0.85), bevel=0.01)
    for x, y in ((-0.18, -0.1), (0.18, 0.12)):
        m.box((0.12, 0.24, 2.15), k["copper"], at=(x, y, 0.88 + 2.15 / 2))
        for z in (1.1, 1.7, 2.3, 2.85):
            m.box((0.2, 0.32, 0.04), k["copper"], at=(x, y, z), bevel=0.005)
    m.cylinder(0.2, 0.3, k["steel"], sides=8, at=(0, 0, 2.55))
    m.cylinder(0.24, 0.05, k["casing_dark"], sides=8, at=(0, 0, 2.38))
    m.cylinder(0.24, 0.05, k["casing_dark"], sides=8, at=(0, 0, 2.72))
    m.box((0.6, 0.6, 0.06), k["casing_dark"], at=(0, 0, 2.97), bevel=0.01)
    _hazard_band(d, dk, Vector((0, -0.351, 0.7)), 0.8, 0.08)
    texts.append(geo.text("RF HAZARD", 0.05, dk["black"], matrix=frame((0, -0.351, 0.45), FRONT, lift=0.002)))
    for i in range(4):
        _plate(d, dk["green_lit"] if i != 2 else dk["amber_lit"], Vector((-0.3 + i * 0.06, -0.351, 0.25)), FRONT, 0.03, 0.02)
    low = m.to_object()
    colliders = [br._console_collider("sp_feed_cabinet", (0.9, 0.7, 0.9), (0, 0, 0.45)),
                 br._console_collider("sp_feed_guides", (0.5, 0.5, 2.1), (0, 0, 1.95))]
    return Model(low=low, decals=[d.to_object()] + texts, extras=colliders)


@asset("sp_bunk", "satellite", texture=128, colors=32, ao=0.5)
def bunk():
    """A maintenance crew's bunk in weightlessness: a sleeping bag strapped upright to a padded wall
    panel, a pillow strap for the head, a personal locker and a reading lamp. Somebody slept here,
    a long time ago."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_bunk")
    d = Mesh("sp_bunk_decals")
    texts = []
    m.box((0.8, 0.04, 2.0), k["casing_dark"], at=(0, 0.13, 1.05), bevel=0.01)
    m.box((0.62, 0.16, 1.7), k["bag"], at=(0.0, 0.04, 0.98), bevel=0.06, segments=2)
    m.box((0.4, 0.12, 0.22), k["fabric"], at=(0.0, 0.06, 1.88), bevel=0.04, segments=2)
    for z in (0.45, 1.0, 1.5):
        m.box((0.7, 0.03, 0.05), k["strap"], at=(0, -0.045, z))
    m.box((0.2, 0.14, 0.3), k["casing"], at=(0.0, 0.06, 2.22), bevel=0.01)
    m.box((0.08, 0.06, 0.05), k["steel"], at=(0.25, 0.08, 1.95), bevel=0.005)
    _plate(d, dk["white"], Vector((0, -0.121, 1.6)), FRONT, 0.2, 0.06)
    texts.append(geo.text("K.OYELARAN", 0.025, dk["black"], matrix=frame((0, -0.121, 1.6), FRONT, lift=0.002)))
    low = m.to_object()
    collider = br._console_collider("sp_bunk", (0.8, 0.3, 2.0), (0, 0.0, 1.0))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


@asset("sp_core", "satellite", texture=256, colors=32, ao=0.5)
def core():
    """The RELAY CORE (GDD §8.3): the machine the whole satellite serves, 1.4 m across and 2.6 m
    tall in the vault at its far end. A drum of stacked rings on a plinth, cyan light bleeding from
    the gaps between them (`SOCKET_glow`: Godot adds its light), cooling fins down its sides, a
    bank of data core slots behind a hinged panel at chest height, its loom rising into the ceiling.
    It hums."""
    k = _console_materials()
    dk = _decals_inside()
    m = Mesh("sp_core")
    d = Mesh("sp_core_decals")
    texts = []
    m.cylinder(0.75, 0.2, k["casing_dark"], sides=12, at=(0, 0, 0.1))
    z = 0.2
    for i in range(6):
        m.cylinder(0.62, 0.3, k["casing"], sides=12, at=(0, 0, z + 0.15))
        m.cylinder(0.56, 0.06, k["core"], sides=12, at=(0, 0, z + 0.33))
        z += 0.36
    m.cylinder(0.66, 0.12, k["casing_dark"], sides=12, at=(0, 0, z + 0.06))
    for i in range(8):
        a = i / 8 * math.tau + math.pi / 8
        m.box((0.05, 0.22, 1.9), k["casing_dark"], at=(math.cos(a) * 0.68, math.sin(a) * 0.68, 1.2), rot=(0, 0, math.degrees(a) + 90))
    m.box((0.5, 0.12, 0.42), k["casing_dark"], at=(0, -0.64, 1.3), bevel=0.01)
    for row in range(2):
        for col in range(3):
            m.box((0.1, 0.03, 0.12), k["bezel"], at=(-0.14 + col * 0.14, -0.71, 1.2 + row * 0.18))
            _plate(d, dk["blue_lit"] if (row + col) % 2 else dk["green_lit"], Vector((-0.14 + col * 0.14, -0.726, 1.27 + row * 0.18)), FRONT,
                   0.06, 0.012)
    for x in (-0.25, 0.0, 0.25):
        m.pipe([(x, 0.0, z + 0.12), (x * 0.8, 0.0, z + 0.4), (x * 0.5, 0.0, 3.0)], 0.04, k["cable"] if x else k["cable_red"], sides=5)
    m.box((0.6, 0.03, 0.14), k["orange"], at=(0, -0.66, 0.42), bevel=0.005)
    texts.append(geo.text("RELAY CORE", 0.06, dk["white"], matrix=frame((0, -0.676, 0.42), FRONT, lift=0.002)))
    low = m.to_object()
    collider = br._console_collider("sp_core", (1.4, 1.4, 2.6), (0, 0, 1.3))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider, _socket("glow", (0, 0, 1.4))])
