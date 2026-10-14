"""The LANTERN station kit (GDD §5, §14; TECH §5): the modular pieces every deck is built from, on a
4 m grid with 3 m ceilings. Walls stand on cell edges and are finished on both faces, so any wall
can divide two rooms. Pieces are built facing -Y in Blender (+Z in Godot).

Visual language, cassette futurism: cream wall panels set proud of a dark backing so the seams
read in 3D, a dark steel kick plate, a steel grab rail at hip height, a safety-orange trim band,
and the classic sloped chamfer where wall meets ceiling, with vent grilles. Decks are diamond
plate with bolted seams; ceilings carry recessed warm light fixtures. Derelicts re-bake the same
pieces with decayed recipes (dk_*), and a working relay satellite with clean ones in its own livery
(sk_*): cool white panels, relay-blue trim, yellow-and-black hazard marks, cold white light. A
satellite's levels join through hatchways: a floor with a round opening and a ceiling with one,
its short trunk rising to the next level's floor (sk_floor_hatch, sk_ceiling_hatch).
"""

import math

import bpy
from mathutils import Vector

from lib import Model, asset, geo, mats
from lib.geo import Mesh, clip, frame

WIDTH = 4.0
HEIGHT = 3.0
THICK = 0.3
HALF = THICK / 2
CHAMFER_START = 2.55
CHAMFER_DEPTH = 0.32
DOOR_W = 2.2
DOOR_H = 2.45


# The kit's three looks: the LANTERN's ("station"), a derelict's ("derelict"): the same geometry,
# re-baked with decayed recipes (discoloured paint eaten by rust, heavy grime and streaks, dead lamps),
# and a working relay's ("relay"): clean, cool and blue.
STYLE = {"name": "station"}
# The stencil on a wall's first panel, by look.
WALL_MARK = {"station": "LTN", "derelict": "LTN", "relay": "RLY"}
# Each look's kit prefix.
PREFIX = {"station": "lk", "derelict": "dk", "relay": "sk"}


def _materials():
    if STYLE["name"] == "derelict":
        return _derelict_materials()
    if STYLE["name"] == "relay":
        return _relay_materials()
    return dict(
        panel=mats.paint("lk_panel", (0.78, 0.74, 0.64), wear=0.2, grime=0.3, streaks=0.15,
                         under=(0.55, 0.55, 0.52), detail_strength=0.25),
        backing=mats.paint("lk_backing", (0.16, 0.17, 0.18), wear=0.0, grime=0.2),
        kick=mats.metal("lk_kick", (0.34, 0.35, 0.36), grime=0.55, detail="DiamondPlate008A"),
        trim=mats.paint("lk_trim", (0.86, 0.42, 0.1), wear=0.35, grime=0.3),
        chamfer=mats.paint("lk_chamfer", (0.6, 0.61, 0.59), wear=0.15, grime=0.35),
        vent=mats.metal("lk_vent", (0.12, 0.12, 0.13), grime=0.2),
        steel=mats.metal("lk_steel", (0.6, 0.6, 0.58), grime=0.3),
        frame=mats.paint("lk_frame", (0.3, 0.32, 0.34), wear=0.4, grime=0.4),
    )


def _derelict_materials():
    return dict(
        panel=mats.paint("dk_panel", (0.56, 0.53, 0.45), wear=0.55, grime=0.75, streaks=0.8, under=(0.4, 0.38, 0.35),
                         detail="PaintedMetal013", detail_strength=0.4, rust=0.55),
        backing=mats.paint("dk_backing", (0.1, 0.1, 0.1), wear=0.0, grime=0.4),
        kick=mats.metal("dk_kick", (0.26, 0.24, 0.22), grime=0.8, detail="Metal021"),
        trim=mats.paint("dk_trim", (0.5, 0.28, 0.12), wear=0.7, grime=0.6, rust=0.4),
        chamfer=mats.paint("dk_chamfer", (0.38, 0.38, 0.36), wear=0.4, grime=0.7, streaks=0.6, rust=0.35),
        vent=mats.metal("dk_vent", (0.08, 0.07, 0.07), grime=0.3),
        steel=mats.metal("dk_steel", (0.4, 0.37, 0.33), grime=0.6, detail="Metal021"),
        frame=mats.paint("dk_frame", (0.2, 0.2, 0.21), wear=0.6, grime=0.6, rust=0.5),
    )


def _relay_materials():
    return dict(
        panel=mats.paint("sk_panel", (0.8, 0.82, 0.83), wear=0.08, grime=0.12, under=(0.6, 0.62, 0.64),
                         detail="PaintedMetal013", detail_strength=0.18),
        backing=mats.paint("sk_backing", (0.13, 0.15, 0.18), wear=0.0, grime=0.1),
        kick=mats.metal("sk_kick", (0.42, 0.44, 0.47), grime=0.25, detail="DiamondPlate008A"),
        trim=mats.paint("sk_trim", (0.16, 0.42, 0.68), wear=0.1, grime=0.1),
        chamfer=mats.paint("sk_chamfer", (0.66, 0.68, 0.7), wear=0.06, grime=0.15),
        vent=mats.metal("sk_vent", (0.1, 0.11, 0.13), grime=0.15),
        steel=mats.metal("sk_steel", (0.66, 0.67, 0.68), grime=0.15),
        frame=mats.paint("sk_frame", (0.24, 0.27, 0.31), wear=0.12, grime=0.15),
    )


def _decal_materials():
    if STYLE["name"] == "relay":
        return dict(
            black=mats.decal("sk_d_black", (0.06, 0.06, 0.07)),
            orange=mats.decal("sk_d_yellow", (0.9, 0.72, 0.12)),
            cream=mats.decal("sk_d_white", (0.9, 0.91, 0.9)),
            dark=mats.decal("sk_d_dark", (0.14, 0.15, 0.17)),
            bolt=mats.decal("sk_d_bolt", (0.6, 0.62, 0.64)),
            green=mats.decal("sk_d_green", (0.4, 1.0, 0.6), glow=True),
            red=mats.decal("sk_d_red", (1.0, 0.25, 0.15), glow=True),
            blue=mats.decal("sk_d_blue", (0.16, 0.42, 0.68)),
        )
    if STYLE["name"] == "derelict":
        return dict(
            black=mats.decal("dk_d_black", (0.05, 0.05, 0.05)),
            orange=mats.decal("dk_d_orange", (0.5, 0.28, 0.12)),
            cream=mats.decal("dk_d_cream", (0.55, 0.52, 0.45)),
            dark=mats.decal("dk_d_dark", (0.1, 0.1, 0.1)),
            bolt=mats.decal("dk_d_bolt", (0.38, 0.34, 0.3)),
            green=mats.decal("dk_d_dead", (0.12, 0.13, 0.12)),
            red=mats.decal("dk_d_red", (0.9, 0.12, 0.08), glow=True),
        )
    return dict(
        black=mats.decal("lk_d_black", (0.06, 0.06, 0.06)),
        orange=mats.decal("lk_d_orange", (0.86, 0.42, 0.1)),
        cream=mats.decal("lk_d_cream", (0.85, 0.82, 0.72)),
        dark=mats.decal("lk_d_dark", (0.14, 0.15, 0.16)),
        bolt=mats.decal("lk_d_bolt", (0.68, 0.68, 0.64)),
        green=mats.decal("lk_d_green", (0.35, 1.0, 0.45), glow=True),
        red=mats.decal("lk_d_red", (1.0, 0.25, 0.15), glow=True),
    )


def _collider(name, size, at):
    """A box collider for Godot (its -colonly suffix makes a StaticBody shape, no mesh)."""
    m = Mesh(f"{name}-colonly")
    m.box(size, mats.plain("collider", (1, 0, 1)), at=at)
    return m.to_object()


PANEL_BOTTOM = 0.35
PANEL_TOP = CHAMFER_START - 0.07


def _panel_columns(x0, x1):
    """The x-centres and width of the proud panels between x0 and x1 (about 1.95 m each)."""
    count = max(1, round((x1 - x0) / 1.95))
    pw = (x1 - x0) / count
    return [x0 + pw * (i + 0.5) for i in range(count)], pw


def _wall_side(m, k, x0, x1, side, rail=True, conduit=True):
    """One face of a wall between x0 and x1 (side -1 is the -Y face): kick plate, proud framed
    panels, trim band, grab rail, a conduit bundle under the chamfer. The chamfer is separate."""
    y = side * HALF
    w = x1 - x0
    cx = (x0 + x1) / 2
    m.box((w, 0.04, 0.32), k["kick"], at=(cx, y + side * 0.02, 0.16), bevel=0.008)
    centres, pw = _panel_columns(x0, x1)
    height = PANEL_TOP - PANEL_BOTTOM
    for px in centres:
        faces = m.box((pw - 0.06, 0.025, height), k["panel"], at=(px, y + side * 0.0125, PANEL_BOTTOM + height / 2),
                      bevel=0.006)
        front = max(m.faces(among=faces, normal=(0, side, 0), min_dot=0.99), key=lambda f: f.calc_area())
        m.inset([front], thickness=0.075, depth=0.012)
    m.box((w, 0.035, 0.07), k["trim"], at=(cx, y + side * 0.0175, CHAMFER_START - 0.035), bevel=0.006)
    if conduit:
        for i, (dy, dz, r) in enumerate(((0.07, 2.66, 0.035), (0.13, 2.74, 0.028))):
            m.pipe([(x0, y + side * dy, dz), (x1, y + side * dy, dz)], r, k["steel" if i else "frame"], sides=6, caps=False)
    if rail and w > 1.0:
        ry = y + side * 0.085
        m.pipe([(x0 + 0.25, ry, 1.05), (x1 - 0.25, ry, 1.05)], 0.022, k["steel"], sides=6)
        for sx in (x0 + 0.35, x1 - 0.35):
            m.pipe([(sx, y + side * 0.02, 1.05), (sx, ry, 1.05)], 0.014, k["steel"], sides=6, caps=False)


def _chamfer(m, k, x0, x1, side, vents=True):
    """The sloped panel from the wall's top to the ceiling, with vent grilles."""
    y0 = side * HALF
    y1 = side * (HALF + CHAMFER_DEPTH)
    faces = m.prism([(y0, CHAMFER_START), (y1, HEIGHT), (y0, HEIGHT)], x1 - x0, k["chamfer"],
                    at=((x0 + x1) / 2, 0, 0), rot=(0, 0, 90))
    if vents:
        _vents(m, k, x0, x1, side)
    return faces


def _vents(m, k, x0, x1, side):
    """Recessed vent grilles on the chamfer: dark boxes set into the slope."""
    angle = math.degrees(math.atan2(HEIGHT - CHAMFER_START, CHAMFER_DEPTH))
    mid_y = side * (HALF + CHAMFER_DEPTH * 0.5)
    mid_z = (CHAMFER_START + HEIGHT) / 2
    w = x1 - x0
    for u in (0.25, 0.75) if w > 2 else (0.5,):
        vx = x0 + w * u
        m.box((0.7, 0.012, 0.2), k["vent"], at=(vx, mid_y, mid_z), rot=(-side * (90 - angle), 0, 0))


def _wall_decals(d, k, x0, x1, side, markings=True):
    """Bolts along the kick plate, rivet rows on the panel frames, and markings: an LTN plate on
    the first panel and a caution sticker on the second, so a run of walls doesn't read as tiled."""
    normal = Vector((0, side, 0))
    rivet = [(-0.01, -0.01), (0.01, -0.01), (0.01, 0.01), (-0.01, 0.01)]
    for x in [x0 + 0.15 + i * 0.5 for i in range(int((x1 - x0) / 0.5))]:
        d.polygon([(-0.012, -0.012), (0.012, -0.012), (0.012, 0.012), (-0.012, 0.012)], k["bolt"],
                  frame((x, side * (HALF + 0.04), 0.27), normal, lift=0.001))
    centres, pw = _panel_columns(x0, x1)
    face_y = side * (HALF + 0.025)
    for px in centres:
        for z in (PANEL_BOTTOM + 0.035, PANEL_TOP - 0.035):
            for i in range(int((pw - 0.2) / 0.3) + 1):
                x = px - (pw - 0.2) / 2 + i * 0.3
                d.polygon(rivet, k["dark"], frame((x, face_y, z), normal, lift=0.001))
    if not markings:
        return
    face_y = side * (HALF + 0.025 - 0.012)  # the panels' recessed centres
    if centres:
        f = frame((centres[0] - pw * 0.25, face_y, 1.62), normal, lift=0.001)
        d.polygon([(-0.16, -0.06), (0.16, -0.06), (0.16, 0.06), (-0.16, 0.06)], k["dark"], f)
        geo_text.append(geo.text(WALL_MARK[STYLE["name"]], 0.07, k["orange"], matrix=frame((centres[0] - pw * 0.25, face_y, 1.62), normal, lift=0.002)))
    if len(centres) > 1:
        f = frame((centres[1] + pw * 0.28, face_y, 1.45), normal, lift=0.001)
        d.polygon([(-0.07, -0.05), (0.07, -0.05), (0.07, 0.05), (-0.07, 0.05)], k["black"], f)
        for i in range(-2, 3):
            x = i * 0.035
            stripe = [(x - 0.008, -0.04), (x + 0.008, -0.04), (x + 0.028, 0.04), (x + 0.012, 0.04)]
            d.polygon(clip(stripe, -0.06, 0.06, -0.04, 0.04), k["orange"], frame((centres[1] + pw * 0.28, face_y, 1.45), normal, lift=0.0015))


geo_text = []  # text decals made while building the current piece


@asset("lk_wall", "station", texture=256, colors=32, ao=0.5)
def wall():
    """LANTERN wall, 4 x 3 m, finished on both faces.

    Purpose: the default divider and hull wall. Most-seen surface in the game, so it carries the
    tech language: cream panels proud of a dark backing (the seams are real gaps), a kick plate,
    a grab rail on stand-offs, an orange trim band, the sloped vent chamfer to the ceiling.
    """
    k = _materials()
    dm = _decal_materials()
    m = Mesh("lk_wall")
    m.box((WIDTH, THICK, CHAMFER_START), k["backing"], at=(0, 0, CHAMFER_START / 2))
    m.box((WIDTH, THICK, HEIGHT - CHAMFER_START), k["backing"], at=(0, 0, (CHAMFER_START + HEIGHT) / 2))
    d = Mesh("lk_wall_decals")
    geo_text.clear()
    for side in (-1, 1):
        _wall_side(m, k, -WIDTH / 2, WIDTH / 2, side)
        _chamfer(m, k, -WIDTH / 2, WIDTH / 2, side)
        _wall_decals(d, dm, -WIDTH / 2, WIDTH / 2, side)
    m.subdivide(1.0)
    low = m.to_object()
    decals = [d.to_object()] + geo_text
    geo_text.clear()
    collider = _collider("lk_wall_col", (WIDTH, THICK, HEIGHT), (0, 0, HEIGHT / 2))
    return Model(low=low, decals=decals, extras=[collider])


# Openings -----------------------------------------------------------------------------------------

DOOR_W = 2.2
DOOR_H = 2.3
JAMB = 0.2


def _wall_backing_around(m, k, x_left, x_right, z_bottom, z_top):
    """The wall's dark core everywhere except the opening [x_left, x_right] x [z_bottom, z_top]."""
    if x_left > -WIDTH / 2:
        w = x_left + WIDTH / 2
        m.box((w, THICK, HEIGHT), k["backing"], at=(-WIDTH / 2 + w / 2, 0, HEIGHT / 2))
    if x_right < WIDTH / 2:
        w = WIDTH / 2 - x_right
        m.box((w, THICK, HEIGHT), k["backing"], at=(WIDTH / 2 - w / 2, 0, HEIGHT / 2))
    ow = x_right - x_left
    if z_top < HEIGHT:
        m.box((ow, THICK, HEIGHT - z_top), k["backing"], at=((x_left + x_right) / 2, 0, (z_top + HEIGHT) / 2))
    if z_bottom > 0:
        m.box((ow, THICK, z_bottom), k["backing"], at=((x_left + x_right) / 2, 0, z_bottom / 2))


def _ring_flange(m, material, radius, half, cz, y, sides=16):
    """Flat plates on both faces (at ±y) filling a square opening (±half, centred at height cz)
    out from a ring of `sides` sides (as Mesh.lathe turns them, half a side off the axes) whose
    outer corners are at `radius`."""
    def ring(a):
        return (math.cos(a) * radius, math.sin(a) * radius)

    def square(a):
        c, s = math.cos(a), math.sin(a)
        reach = half / max(abs(c), abs(s))
        return (c * reach, s * reach)

    corners = [math.pi / 4 + i * math.pi / 2 for i in range(4)]
    for side in (-1, 1):
        # The ring is symmetric side to side, so the frame's mirroring on the +Y face doesn't matter.
        f = frame((0, side * y, cz), Vector((0, side, 0)), lift=0.0)
        for i in range(sides):
            a0 = math.pi / sides + i / sides * math.tau
            a1 = a0 + math.tau / sides
            pts = [ring(a0), square(a0)]
            pts += [(math.copysign(half, math.cos(c)), math.copysign(half, math.sin(c))) for c in corners if a0 < c < a1]
            pts += [square(a1), ring(a1)]
            m.polygon(pts, material, f)


def _hazard_column(d, k, x, y, z0, z1, side, width):
    """Bold black-on-orange diagonal stripes up a jamb face."""
    normal = Vector((0, side, 0))
    f = frame((x, y, (z0 + z1) / 2), normal, lift=0.001)
    h = (z1 - z0) / 2
    d.polygon([(-width / 2, -h), (width / 2, -h), (width / 2, h), (-width / 2, h)], k["orange"], f)
    f2 = frame((x, y, (z0 + z1) / 2), normal, lift=0.0015)
    pitch = 0.3
    for i in range(-int(h / pitch) - 2, int(h / pitch) + 3):
        z = i * pitch
        stripe = [(-width / 2, z), (width / 2, z + 0.12), (width / 2, z + 0.26), (-width / 2, z + 0.14)]
        d.polygon(clip(stripe, -width / 2, width / 2, -h, h), k["black"], f2)


@asset("lk_wall_door", "station", texture=256, colors=32, ao=0.5)
def wall_door():
    """LANTERN door wall, 4 x 3 m with a 2.2 x 2.3 m opening for the sliding door (lk_door).

    A heavy dark frame with hazard-striped jambs and a header carrying a status lamp (a separate
    `status_lamp` mesh the door recolours: green open, red sealed). Panels and chamfer continue
    either side, so a run of walls reads continuous.
    """
    k = _materials()
    dm = _decal_materials()
    m = Mesh("lk_wall_door")
    d = Mesh("lk_wall_door_decals")
    geo_text.clear()
    left, right = -DOOR_W / 2 - JAMB, DOOR_W / 2 + JAMB
    _wall_backing_around(m, k, left, right, 0.0, DOOR_H + 0.18)
    for side in (-1, 1):
        for x0, x1 in ((-WIDTH / 2, left), (right, WIDTH / 2)):
            _wall_side(m, k, x0, x1, side, rail=False)
            _wall_decals(d, dm, x0, x1, side, markings=False)
        # Above the door: trim and conduit continue.
        m.box((right - left, 0.035, 0.07), k["trim"], at=(0, side * (HALF + 0.0175), CHAMFER_START - 0.035), bevel=0.006)
        for i, (dy, dz, r) in enumerate(((0.07, 2.66, 0.035), (0.13, 2.74, 0.028))):
            m.pipe([(left, side * (HALF + dy), dz), (right, side * (HALF + dy), dz)], r, k["steel" if i else "frame"],
                   sides=6, caps=False)
        _chamfer(m, k, -WIDTH / 2, WIDTH / 2, side)
        # Jambs and header, proud of the wall on both faces.
        for x in (-DOOR_W / 2 - JAMB / 2, DOOR_W / 2 + JAMB / 2):
            _hazard_column(d, dm, x, side * (HALF + 0.07), 0.05, DOOR_H - 0.05, side, JAMB - 0.04)
        m.box((0.16, 0.06, 0.08), k["vent"], at=(0, side * (HALF + 0.09), DOOR_H + 0.12), bevel=0.01)
    for x in (-DOOR_W / 2 - JAMB / 2, DOOR_W / 2 + JAMB / 2):
        m.box((JAMB, THICK + 0.14, DOOR_H), k["frame"], at=(x, 0, DOOR_H / 2), bevel=0.02)
    m.box((DOOR_W + 2 * JAMB, THICK + 0.14, 0.18), k["frame"], at=(0, 0, DOOR_H + 0.09), bevel=0.02)
    # The floor track the leaves run in.
    m.box((DOOR_W, THICK, 0.02), k["vent"], at=(0, 0, 0.01))
    m.subdivide(1.0)
    low = m.to_object()
    # Status lamps: separate meshes Godot recolours.
    lamp = Mesh("status_lamp")
    for side in (-1, 1):
        lamp.box((0.12, 0.02, 0.05), mats.plain("lk_lamp", (0.2, 0.9, 0.3)), at=(0, side * (HALF + 0.125), DOOR_H + 0.12))
    lamp_obj = lamp.to_object()
    decals = [d.to_object()] + geo_text
    geo_text.clear()
    colliders = [_collider("lk_wall_door_col_l", (WIDTH / 2 - DOOR_W / 2, THICK, HEIGHT), (-(WIDTH / 2 + DOOR_W / 2) / 2, 0, HEIGHT / 2)),
                 _collider("lk_wall_door_col_r", (WIDTH / 2 - DOOR_W / 2, THICK, HEIGHT), ((WIDTH / 2 + DOOR_W / 2) / 2, 0, HEIGHT / 2)),
                 _collider("lk_wall_door_col_top", (DOOR_W, THICK, HEIGHT - DOOR_H), (0, 0, (HEIGHT + DOOR_H) / 2))]
    return Model(low=low, decals=decals, extras=colliders + [lamp_obj])


@asset("lk_door", "station", texture=256, colors=32, ao=0.5)
def door():
    """LANTERN sliding bulkhead door: two leaves meeting in the middle of a 2.2 x 2.3 m opening.

    Split after baking into `leaf_left` and `leaf_right` so Godot slides them into the wall. Dark
    steel leaves with a raised frame and two inset panels, an orange band at chest height, a narrow
    window slit, and bold black/orange chevrons down the meeting edges that close into a V. Both
    faces are finished.
    """
    k = _materials()
    dm = _decal_materials()
    glass = mats.glowing("lk_slit", (0.05, 0.07, 0.08), base=(0.05, 0.06, 0.07), flicker=0.0)
    leaf_w = DOOR_W / 2
    leaf_t = 0.1
    m = Mesh("lk_door")
    d = Mesh("lk_door_decals")
    for sign in (-1, 1):
        cx = sign * leaf_w / 2
        m.box((leaf_w - 0.01, leaf_t, DOOR_H - 0.02), k["frame"], at=(cx, 0, DOOR_H / 2), bevel=0.012)
        for side in (-1, 1):
            face_y = side * (leaf_t / 2 + 0.008)
            # Two raised panels, below and above the band.
            for z0, z1 in ((0.12, 1.08), (1.42, DOOR_H - 0.12)):
                faces = m.box((leaf_w - 0.36, 0.016, z1 - z0), k["frame"], at=(cx - sign * 0.08, face_y, (z0 + z1) / 2), bevel=0.006)
                front = max(m.faces(among=faces, normal=(0, side, 0), min_dot=0.99), key=lambda f: f.calc_area())
                m.inset([front], thickness=0.05, depth=0.008)
            m.box((leaf_w - 0.02, 0.02, 0.24), k["trim"], at=(cx, side * (leaf_t / 2 + 0.01), 1.25), bevel=0.004)
            m.box((0.09, 0.02, 0.55), glass, at=(cx - sign * 0.08, side * (leaf_t / 2 + 0.012), 1.85), bevel=0.004)
            # Chevrons down the meeting edge: stripes slope toward the centre line, so the two leaves
            # together draw a column of V's.
            normal = Vector((0, side, 0))
            band_x = sign * 0.15
            hw = 0.15
            f = frame((band_x, side * (leaf_t / 2), 0.6), normal, lift=0.001)
            d.polygon([(-hw, -0.48), (hw, -0.48), (hw, 0.48), (-hw, 0.48)], dm["orange"], f)
            f2 = frame((band_x, side * (leaf_t / 2), 0.6), normal, lift=0.0015)
            toward_centre = -sign * side  # +1: the centre line is to the frame's right
            for i in range(-3, 4):
                z = i * 0.26
                drop = 0.1 * toward_centre
                stripe = [(-hw, z + drop), (hw, z - drop), (hw, z - drop + 0.11), (-hw, z + drop + 0.11)]
                d.polygon(clip(stripe, -hw, hw, -0.48, 0.48), dm["black"], f2)
            for bz in (0.07, DOOR_H - 0.07):
                for bx in (sign * 0.06, sign * (leaf_w - 0.06)):
                    d.polygon([(-0.015, -0.015), (0.015, -0.015), (0.015, 0.015), (-0.015, 0.015)], dm["bolt"],
                              frame((bx, side * (leaf_t / 2), bz), normal, lift=0.001))
    m.subdivide(1.0)
    low = m.to_object()

    def split(model):
        left, right = geo.split_object(model.low, {"leaf_left": lambda c: c.x < 0, "leaf_right": lambda c: c.x >= 0})
        model.low = left
        model.extras.append(right)

    return Model(low=low, decals=[d.to_object()], extras=[], after_bake=split)


def _window_wall(name, win_w, z0, z1, struts=0):
    k = _materials()
    dm = _decal_materials()
    m = Mesh(name)
    d = Mesh(f"{name}_decals")
    geo_text.clear()
    frame_w = 0.14
    left, right = -win_w / 2 - frame_w, win_w / 2 + frame_w
    _wall_backing_around(m, k, left, right, z0 - frame_w, z1 + frame_w)
    for side in (-1, 1):
        if left > -WIDTH / 2 + 0.3:
            for x0, x1 in ((-WIDTH / 2, left), (right, WIDTH / 2)):
                _wall_side(m, k, x0, x1, side, rail=False)
        m.box((WIDTH, 0.04, 0.32), k["kick"], at=(0, side * (HALF + 0.02), 0.16), bevel=0.008)
        if z0 - frame_w > 0.4:
            m.box((right - left, 0.025, z0 - frame_w - PANEL_BOTTOM), k["panel"],
                  at=(0, side * (HALF + 0.0125), (PANEL_BOTTOM + z0 - frame_w) / 2), bevel=0.006)
        m.box((WIDTH, 0.035, 0.07), k["trim"], at=(0, side * (HALF + 0.0175), CHAMFER_START - 0.035), bevel=0.006)
        _chamfer(m, k, -WIDTH / 2, WIDTH / 2, side)
        # A deep sill on each face.
        m.box((win_w + 2 * frame_w, 0.16, 0.06), k["frame"], at=(0, side * (HALF + 0.05), z0 - frame_w / 2), bevel=0.01)
    # The frame: a thick dark surround through the wall's depth.
    depth = THICK + 0.08
    for x in (left + frame_w / 2, right - frame_w / 2):
        m.box((frame_w, depth, z1 - z0 + 2 * frame_w), k["frame"], at=(x, 0, (z0 + z1) / 2), bevel=0.015)
    for z in (z0 - frame_w / 2, z1 + frame_w / 2):
        m.box((win_w + 2 * frame_w, depth, frame_w), k["frame"], at=(0, 0, z), bevel=0.015)
    for i in range(struts):
        x = -win_w / 2 + win_w * (i + 1) / (struts + 1)
        m.box((0.08, depth - 0.04, z1 - z0), k["frame"], at=(x, 0, (z0 + z1) / 2), bevel=0.01)
    m.subdivide(1.0)
    low = m.to_object()
    g = Mesh("glass")
    g.box((win_w, 0.02, z1 - z0), mats.plain("lk_glass", (0.3, 0.4, 0.45)), at=(0, 0, (z0 + z1) / 2))
    glass = g.to_object()
    decals = [d.to_object()] + geo_text
    geo_text.clear()
    colliders = [_collider(f"{name}_col", (WIDTH, THICK, HEIGHT), (0, 0, HEIGHT / 2))]
    return Model(low=low, decals=decals, extras=colliders + [glass])


@asset("lk_wall_window", "station", texture=256, colors=32, ao=0.5)
def wall_window():
    """LANTERN window wall: a 2.6 x 1.3 m port at eye height in a deep dark frame, for rooms that
    look out (the Docking Port, the Suit Room). The glass is a separate mesh."""
    return _window_wall("lk_wall_window", 2.6, 1.0, 2.3)


@asset("lk_wall_viewport", "station", texture=256, colors=32, ao=0.5)
def wall_viewport():
    """LANTERN viewport wall for the bridge: glass nearly floor to ceiling between heavy struts, so
    three side by side make the forward viewport onto the system."""
    return _window_wall("lk_wall_viewport", 3.5, 0.55, 2.4, struts=1)


@asset("lk_corner", "station", texture=128, colors=24, ao=0.5)
def corner():
    """LANTERN corner post: covers the junction where walls meet at an angle or end, and caps the
    crossing of their chamfers. A dark steel column with a bevelled head block and a bolted base."""
    k = _materials()
    dm = _decal_materials()
    m = Mesh("lk_corner")
    m.box((0.5, 0.5, HEIGHT), k["frame"], at=(0, 0, HEIGHT / 2), bevel=0.04)
    m.box((0.62, 0.62, 0.3), k["kick"], at=(0, 0, 0.15), bevel=0.02)
    m.box((0.9, 0.9, HEIGHT - CHAMFER_START), k["chamfer"], at=(0, 0, (HEIGHT + CHAMFER_START) / 2 + 0.02), bevel=0.05)
    m.box((0.54, 0.54, 0.07), k["trim"], at=(0, 0, CHAMFER_START - 0.035), bevel=0.006)
    d = Mesh("lk_corner_decals")
    for normal in ((0, -1, 0), (0, 1, 0), (1, 0, 0), (-1, 0, 0)):
        n = Vector(normal)
        _hazard_column(d, dm, n.x * 0.25, n.y * 0.25, 0.4, 1.6, 1, 0.3) if False else None
        f = frame(n * 0.25 + Vector((0, 0, 1.0)), n, lift=0.001)
        for z in (-0.6, 0.6):
            d.polygon([(-0.015, z - 0.015), (0.015, z - 0.015), (0.015, z + 0.015), (-0.015, z + 0.015)], dm["bolt"], f)
    m.subdivide(1.0)
    low = m.to_object()
    collider = _collider("lk_corner_col", (0.5, 0.5, HEIGHT), (0, 0, HEIGHT / 2))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


def _deck():
    """Each look's deck plate."""
    if STYLE["name"] == "derelict":
        return mats.metal("dk_deck", (0.22, 0.21, 0.2), grime=0.85, brushed=False, detail="Metal021")
    if STYLE["name"] == "relay":
        return mats.metal("sk_deck", (0.38, 0.4, 0.43), grime=0.2, brushed=False, detail="DiamondPlate008A")
    return mats.metal("lk_deck", (0.3, 0.32, 0.34), grime=0.5, brushed=False, detail="DiamondPlate008A")


def _ceiling_materials():
    """Each look's ceiling tile and its light fixture's diffuser: warm sodium aboard the LANTERN,
    dead in a derelict, cold white in a working relay."""
    if STYLE["name"] == "derelict":
        return (mats.paint("dk_ceiling", (0.34, 0.34, 0.32), wear=0.3, grime=0.7, streaks=0.5, rust=0.3),
                mats.plain("dk_light_dead", (0.32, 0.31, 0.28), grime=0.6))
    if STYLE["name"] == "relay":
        return (mats.paint("sk_ceiling", (0.7, 0.72, 0.74), wear=0.05, grime=0.12),
                mats.glowing("sk_light", (0.82, 0.93, 1.0), base=(0.76, 0.82, 0.88), flicker=0.05))
    return (mats.paint("lk_ceiling", (0.56, 0.57, 0.55), wear=0.1, grime=0.35),
            mats.glowing("lk_light", (1.0, 0.84, 0.6), base=(0.9, 0.85, 0.75), flicker=0.1))


@asset("lk_floor", "station", texture=256, colors=32, ao=0.4)
def floor():
    """LANTERN deck plate, 4 x 4 m: diamond-plate panels on a 1 m grid with dark seams and corner
    bolts, a darker drainage strip around the edge where it meets the walls."""
    k = _materials()
    dm = _decal_materials()
    deck = _deck()
    m = Mesh("lk_floor")
    m.box((WIDTH, WIDTH, 0.1), deck, at=(0, 0, -0.05))
    m.subdivide(1.0)
    low = m.to_object()
    d = Mesh("lk_floor_decals")
    up = Vector((0, 0, 1))
    seam = dm["dark"]
    for i in range(5):
        x = -WIDTH / 2 + i
        f = frame((x, 0, 0), up, up=(0, 1, 0), lift=0.001)
        d.polygon(clip([(-0.012, -2), (0.012, -2), (0.012, 2), (-0.012, 2)], -2, 2, -2, 2), seam, f)
        f = frame((0, x, 0), up, up=(0, 1, 0), lift=0.001)
        d.polygon(clip([(-2, -0.012), (2, -0.012), (2, 0.012), (-2, 0.012)], -2, 2, -2, 2), seam, f)
    for i in range(5):
        for j in range(5):
            for ox, oy in ((0.06, 0.06), (-0.06, 0.06), (0.06, -0.06), (-0.06, -0.06)):
                x, y = -2 + i + ox, -2 + j + oy
                if abs(x) < 2 and abs(y) < 2:
                    d.polygon([(-0.014, -0.014), (0.014, -0.014), (0.014, 0.014), (-0.014, 0.014)], dm["bolt"],
                              frame((x, y, 0), up, up=(0, 1, 0), lift=0.0015))
    collider = _collider("lk_floor_col", (WIDTH, WIDTH, 0.1), (0, 0, -0.05))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


@asset("lk_ceiling", "station", texture=256, colors=32, ao=0.5, angles=((-35, -25), (145, -30), (90, -8), (-20, -60)))
def ceiling():
    """LANTERN ceiling panel, 4 x 4 m: grey panels on a 2 m grid around a recessed light fixture,
    a warm fluorescent panel behind a steel grille (Godot adds the light itself)."""
    k = _materials()
    dm = _decal_materials()
    tile, light = _ceiling_materials()
    m = Mesh("lk_ceiling")
    faces = m.box((WIDTH, WIDTH, 0.1), tile, at=(0, 0, HEIGHT + 0.05))
    bottom = m.faces(among=faces, normal=(0, 0, -1), min_dot=0.99)
    # Recess the fixture: inset the bottom face to a 2.2 x 0.7 m opening, then push it up.
    # A shallow steel frame, and a frosted diffuser box below it that glows on every face, so the
    # fixture reads as a light from across a room, not just from underneath.
    m.box((2.3, 0.8, 0.04), k["frame"], at=(0, 0, HEIGHT - 0.01), bevel=0.01)
    m.box((2.1, 0.6, 0.09), light, at=(0, 0, HEIGHT - 0.075), bevel=0.01)
    for x in (-1.08, 1.08):
        m.box((0.06, 0.64, 0.11), k["frame"], at=(x, 0, HEIGHT - 0.075), bevel=0.008)
    m.subdivide(1.0)
    low = m.to_object()
    d = Mesh("lk_ceiling_decals")
    down = Vector((0, 0, -1))
    for x in (-2, 0, 2):
        f = frame((x, 0, HEIGHT), down, up=(0, 1, 0), lift=0.001)
        d.polygon([(-0.012, -2), (0.012, -2), (0.012, 2), (-0.012, 2)], dm["dark"], f)
    for y in (-2, 0, 2):
        f = frame((0, y, HEIGHT), down, up=(0, 1, 0), lift=0.001)
        d.polygon([(-2, -0.012), (2, -0.012), (2, 0.012), (-2, 0.012)], dm["dark"], f)
    # Grille bars across the fixture.
    for i in range(9):
        x = -1.0 + i * 0.25
        f = frame((x, 0, HEIGHT - 0.12), down, up=(0, 1, 0), lift=0.001)
        d.polygon([(-0.015, -0.3), (0.015, -0.3), (0.015, 0.3), (-0.015, 0.3)], dm["dark"], f)
    collider = _collider("lk_ceiling_col", (WIDTH, WIDTH, 0.1), (0, 0, HEIGHT + 0.05))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


@asset("lk_wall_hatch", "station", texture=256, colors=32, ao=0.5)
def wall_hatch():
    """LANTERN pressure hatch wall: the airlock's outer door and the docking collar's mouth. A round
    1.6 m hatch (`hatch_door`, a separate mesh that swings) in a deep ring frame with locking dogs,
    a hazard ring painted around it, and an amber warning beacon above. Finished on both faces; the
    outer face meets vacuum."""
    k = _materials()
    dm = _decal_materials()
    m = Mesh("lk_wall_hatch")
    d = Mesh("lk_wall_hatch_decals")
    geo_text.clear()
    r = 0.8
    cz = 1.15
    # The wall around a square opening, the ring frame filling it down to the round hatch.
    _wall_backing_around(m, k, -1.1, 1.1, cz - 1.1, cz + 1.1)
    for side in (-1, 1):
        for x0, x1 in ((-WIDTH / 2, -1.1), (1.1, WIDTH / 2)):
            _wall_side(m, k, x0, x1, side, rail=False)
        m.box((WIDTH, 0.035, 0.07), k["trim"], at=(0, side * (HALF + 0.0175), CHAMFER_START - 0.035), bevel=0.006)
        _chamfer(m, k, -WIDTH / 2, WIDTH / 2, side)
    # The ring round the hatch, its faces looking the way they're seen from (a lathe's faces look out
    # from its axis along a profile run upward): its outside, its bore in toward the opening (its
    # profile run down), and its ends out of the wall on either side.
    m.lathe([(r + 0.3, -0.22), (r + 0.3, 0.22)], k["frame"], sides=16, at=(0, 0, cz), rot=(90, 0, 0), cap_start=False, cap_end=False)
    m.lathe([(r, 0.22), (r, -0.22)], k["frame"], sides=16, at=(0, 0, cz), rot=(90, 0, 0), cap_start=False, cap_end=False)
    for side in (-1, 1):
        m.lathe([(r + 0.3, side * 0.22), (r, side * 0.22)] if side > 0 else [(r, side * 0.22), (r + 0.3, side * 0.22)],
                k["frame"], sides=16, at=(0, 0, cz), rot=(90, 0, 0), cap_start=False, cap_end=False)
        # Locking dogs around the ring.
        for i in range(8):
            a = i / 8 * math.tau
            m.box((0.1, 0.06, 0.06), k["steel"], at=(math.cos(a) * (r + 0.12), side * 0.25, cz + math.sin(a) * (r + 0.12)),
                  rot=(0, -math.degrees(a), 0), bevel=0.01)
        # Beacon above.
        m.box((0.16, 0.08, 0.06), k["frame"], at=(0, side * (HALF + 0.04), cz + r + 0.45), bevel=0.01)
    # A flange plate filling the square opening out from the ring, flush with the wall's core on
    # both faces: its inner edge follows the ring's sixteen sides, its outer edge the opening (each
    # side's piece reaches out along its corners' rays; the four that span a corner take it in).
    _ring_flange(m, k["frame"], r + 0.3, 1.1, cz, HALF)
    # The hatch itself: baked with the wall, split off after (hatch_door) so it can swing open.
    m.cylinder(r - 0.03, 0.16, k["frame"], sides=16, at=(0, 0, cz), rot=(90, 0, 0))
    for side in (-1, 1):
        m.cylinder(r * 0.6, 0.02, k["panel"], sides=16, at=(0, side * 0.09, cz), rot=(90, 0, 0))
        m.cylinder(0.14, 0.06, k["steel"], sides=8, at=(0, side * 0.11, cz), rot=(90, 0, 0))
        for i in range(4):
            a = i / 4 * math.tau + math.pi / 4
            m.box((0.42, 0.04, 0.04), k["steel"], at=(math.cos(a) * 0.2, side * 0.14, cz + math.sin(a) * 0.2), rot=(0, -math.degrees(a), 0))
    m.subdivide(1.0)
    low = m.to_object()
    # Hazard ring decal on both faces.
    for side in (-1, 1):
        normal = Vector((0, side, 0))
        for i in range(16):
            a0 = i / 16 * math.tau
            a1 = (i + 1) / 16 * math.tau
            colour = dm["black"] if i % 2 else dm["orange"]
            f = frame((0, side * 0.221, cz), normal, lift=0.001)
            pts = [(math.cos(a0) * (r + 0.02), math.sin(a0) * (r + 0.02)), (math.cos(a1) * (r + 0.02), math.sin(a1) * (r + 0.02)),
                   (math.cos(a1) * (r + 0.28), math.sin(a1) * (r + 0.28)), (math.cos(a0) * (r + 0.28), math.sin(a0) * (r + 0.28))]
            if side > 0:
                pts = [(-x, z) for x, z in pts]
            d.polygon(pts, colour, f)
    lamp = Mesh("status_lamp")
    for side in (-1, 1):
        lamp.cylinder(0.06, 0.08, mats.plain("lk_lamp", (0.2, 0.9, 0.3)), sides=8, at=(0, side * (HALF + 0.1), cz + r + 0.45), rot=(90, 0, 0))
    lamp_obj = lamp.to_object()
    decals = [d.to_object()] + geo_text
    geo_text.clear()
    colliders = [_collider("lk_wall_hatch_col_l", (WIDTH / 2 - 1.1, THICK, HEIGHT), (-(WIDTH / 2 + 1.1) / 2, 0, HEIGHT / 2)),
                 _collider("lk_wall_hatch_col_r", (WIDTH / 2 - 1.1, THICK, HEIGHT), ((WIDTH / 2 + 1.1) / 2, 0, HEIGHT / 2)),
                 _collider("lk_wall_hatch_col_t", (2.2, THICK, HEIGHT - cz - 1.1), (0, 0, (HEIGHT + cz + 1.1) / 2))]
    def split(model):
        # The door stands 3 cm inside the ring's bore, so the bore's faces stay in the wall.
        def in_hatch(c):
            return math.hypot(c.x, c.z - cz) < r - 0.025 and abs(c.y) < 0.17
        wall, hatch = geo.split_object(model.low, {"lk_wall_hatch": lambda c: not in_hatch(c), "hatch_door": in_hatch})
        model.low = wall
        model.extras.append(hatch)

    return Model(low=low, decals=decals, extras=colliders + [lamp_obj], after_bake=split)


# Hatchways: the way between one level and the next, through a round opening in the floor above and
# the ceiling below, a short trunk between them (RoomLayout.PITCH: 4 m from deck to deck, so the
# trunk runs from the ceiling's top, 3.1, to the next floor's underside, 3.9).
HATCHWAY_R = 0.8
LEVEL = 4.0


def _holed_plate(m, material, radius, half, z, facing, sides=16):
    """A flat square plate (±half) at height z, facing up (+1) or down (-1), with a round opening
    of `radius` in its middle: a ring of `sides` sides, as Mesh.lathe turns them (half a side off
    the axes), so a lathed rim meets it exactly."""
    def ring(a):
        return (math.cos(a) * radius, math.sin(a) * radius)

    def square(a):
        c, s = math.cos(a), math.sin(a)
        reach = half / max(abs(c), abs(s))
        return (c * reach, s * reach)

    corners = [math.pi / 4 + i * math.pi / 2 for i in range(4)]
    f = frame((0, 0, z), (0, 0, facing), up=(0, 1, 0), lift=0.0)
    for i in range(sides):
        a0 = math.pi / sides + i / sides * math.tau
        a1 = a0 + math.tau / sides
        pts = [ring(a0), square(a0)]
        pts += [(math.copysign(half, math.cos(c)), math.copysign(half, math.sin(c))) for c in corners if a0 < c < a1]
        pts += [square(a1), ring(a1)]
        # The same winding either way up: the frame turns it to face `facing` (the outline's
        # symmetric, so the frame's mirroring of a downward face changes nothing else).
        m.polygon(pts, material, f)


def _hazard_ring(d, dm, z, facing, r0, r1, count=20):
    """Black and yellow (or orange) segments round a hatchway's opening, flat on a floor or ceiling."""
    f = frame((0, 0, z), (0, 0, facing), up=(0, 1, 0), lift=0.001)
    for i in range(count):
        a0, a1 = i / count * math.tau, (i + 1) / count * math.tau
        pts = [(math.cos(a0) * r0, math.sin(a0) * r0), (math.cos(a1) * r0, math.sin(a1) * r0),
               (math.cos(a1) * r1, math.sin(a1) * r1), (math.cos(a0) * r1, math.sin(a0) * r1)]
        d.polygon(pts, dm["black"] if i % 2 else dm["orange"], f)


def _hole_colliders(name, z0, z1, hole):
    """A slab's colliders round a square hole `hole` wide: four boxes, the cell's full width."""
    t = z1 - z0
    side = (WIDTH - hole) / 2
    mid = (z0 + z1) / 2
    return [_collider(f"{name}_n", (WIDTH, side, t), (0, -(hole + side) / 2, mid)),
            _collider(f"{name}_s", (WIDTH, side, t), (0, (hole + side) / 2, mid)),
            _collider(f"{name}_w", (side, hole, t), (-(hole + side) / 2, 0, mid)),
            _collider(f"{name}_e", (side, hole, t), ((hole + side) / 2, 0, mid))]


def floor_hatch():
    """A deck plate, 4 x 4 m, with a hatchway down through its middle: a round 1.6 m opening in a
    raised coaming ring, a hazard ring painted round it, four grab handles to haul through by, the
    deck's seams and bolts round it. The level below's ceiling_hatch trunk meets its underside."""
    k = _materials()
    dm = _decal_materials()
    deck = _deck()
    name = PREFIX[STYLE["name"]] + "_floor_hatch"
    m = Mesh(name)
    d = Mesh(f"{name}_decals")
    geo_text.clear()
    r = HATCHWAY_R
    _holed_plate(m, deck, r, WIDTH / 2, 0.0, 1)
    _holed_plate(m, deck, r, WIDTH / 2, -0.1, -1)
    m.lathe([(r, 0.0), (r, -0.1)], k["frame"], sides=16, cap_start=False, cap_end=False)
    # The coaming: up from the deck outside, across, and down into the opening.
    m.lathe([(r + 0.2, 0.0), (r + 0.18, 0.08), (r + 0.03, 0.08), (r, 0.0)], k["frame"], sides=16, cap_start=False, cap_end=False)
    # Grab handles at the diagonals.
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        c, s_ = math.cos(a), math.sin(a)
        tx, ty = -s_ * 0.18, c * 0.18
        bx, by = c * 1.32, s_ * 1.32
        m.pipe([(bx - tx, by - ty, 0.0), (bx - tx, by - ty, 0.13), (bx + tx, by + ty, 0.13), (bx + tx, by + ty, 0.0)], 0.018, k["steel"], sides=6)
    m.subdivide(1.0)
    low = m.to_object()
    up = Vector((0, 0, 1))
    _hazard_ring(d, dm, 0.0, 1, r + 0.22, r + 0.4)
    for i in range(5):
        x = -WIDTH / 2 + i
        for a, b in ((-2.0, -1.25), (1.25, 2.0)) if abs(x) < 1.25 else ((-2.0, 2.0),):
            f = frame((x, 0, 0), up, up=(0, 1, 0), lift=0.001)
            d.polygon([(-0.012, a), (0.012, a), (0.012, b), (-0.012, b)], dm["dark"], f)
            f = frame((0, x, 0), up, up=(0, 1, 0), lift=0.001)
            d.polygon([(a, -0.012), (b, -0.012), (b, 0.012), (a, 0.012)], dm["dark"], f)
    for i in range(5):
        for j in range(5):
            for ox, oy in ((0.06, 0.06), (-0.06, 0.06), (0.06, -0.06), (-0.06, -0.06)):
                x, y = -2 + i + ox, -2 + j + oy
                if abs(x) < 2 and abs(y) < 2 and math.hypot(x, y) > 1.3:
                    d.polygon([(-0.014, -0.014), (0.014, -0.014), (0.014, 0.014), (-0.014, 0.014)], dm["bolt"],
                              frame((x, y, 0), up, up=(0, 1, 0), lift=0.0015))
    geo_text.append(geo.text("DECK BELOW", 0.09, dm["cream"], matrix=frame((0, 1.62, 0), up, up=(0, -1, 0), lift=0.002)))
    decals = [d.to_object()] + geo_text
    geo_text.clear()
    return Model(low=low, decals=decals, extras=_hole_colliders(f"{name}_col", -0.1, 0.0, 1.7))


def ceiling_hatch():
    """A ceiling panel, 4 x 4 m, with a hatchway up through its middle: a round 1.6 m opening with a
    hazard ring painted round it, its trunk rising 0.8 m to the next level's floor, ribbed, with
    two rungs to haul up by and a cold light band round it; the room's light fixtures stand either
    side of the opening."""
    k = _materials()
    dm = _decal_materials()
    tile, light = _ceiling_materials()
    name = PREFIX[STYLE["name"]] + "_ceiling_hatch"
    m = Mesh(name)
    d = Mesh(f"{name}_decals")
    geo_text.clear()
    r = HATCHWAY_R
    top = LEVEL - 0.1  # the next level's floor's underside
    _holed_plate(m, tile, r, WIDTH / 2, HEIGHT, -1)
    m.lathe([(r, HEIGHT + 0.1), (r, HEIGHT)], k["frame"], sides=16, cap_start=False, cap_end=False)
    # The trunk, seen from inside: its wall, two ribs and the light band (each profile runs down,
    # so its faces look in).
    m.lathe([(r, top), (r, HEIGHT + 0.1)], k["panel"], sides=16, cap_start=False, cap_end=False)
    for z in (HEIGHT + 0.22, top - 0.08):
        m.lathe([(r, z + 0.04), (r - 0.035, z + 0.03), (r - 0.035, z - 0.03), (r, z - 0.04)], k["frame"], sides=16,
                cap_start=False, cap_end=False)
    mid = (HEIGHT + 0.1 + top) / 2
    m.lathe([(r, mid + 0.06), (r - 0.02, mid + 0.05), (r - 0.02, mid - 0.05), (r, mid - 0.06)], light, sides=16,
            cap_start=False, cap_end=False)
    # Rungs on the east side, on stand-offs.
    for z in (HEIGHT + 0.36, HEIGHT + 0.62):
        m.pipe([(r - 0.01, -0.3, z), (r - 0.14, -0.3, z), (r - 0.14, 0.3, z), (r - 0.01, 0.3, z)], 0.016, k["steel"], sides=6)
    # The fixtures either side: a frame and a cold diffuser, as the plain ceiling's.
    for x in (-1.2, 1.2):
        m.box((0.42, 2.1, 0.04), k["frame"], at=(x, 0, HEIGHT - 0.01), bevel=0.01)
        m.box((0.3, 1.9, 0.09), light, at=(x, 0, HEIGHT - 0.075), bevel=0.01)
    m.subdivide(1.0)
    low = m.to_object()
    down = Vector((0, 0, -1))
    _hazard_ring(d, dm, HEIGHT, -1, r + 0.02, r + 0.17)
    for x in (-2, 2):
        f = frame((x, 0, HEIGHT), down, up=(0, 1, 0), lift=0.001)
        d.polygon([(-0.012, -2), (0.012, -2), (0.012, 2), (-0.012, 2)], dm["dark"], f)
    for y in (-2, 2):
        f = frame((0, y, HEIGHT), down, up=(0, 1, 0), lift=0.001)
        d.polygon([(-2, -0.012), (2, -0.012), (2, 0.012), (-2, 0.012)], dm["dark"], f)
    for x in (-1.2, 1.2):
        for i in range(7):
            y = -0.9 + i * 0.3
            f = frame((x, y, HEIGHT - 0.12), down, up=(0, 1, 0), lift=0.001)
            d.polygon([(-0.15, -0.015), (0.15, -0.015), (0.15, 0.015), (-0.15, 0.015)], dm["dark"], f)
    geo_text.append(geo.text("HATCHWAY", 0.08, dm["cream"], matrix=frame((0, -1.25, HEIGHT), down, up=(0, 1, 0), lift=0.002)))
    decals = [d.to_object()] + geo_text
    geo_text.clear()
    trunk = r + 0.1
    colliders = _hole_colliders(f"{name}_col", HEIGHT, HEIGHT + 0.1, 1.7) + [
        _collider(f"{name}_trunk_n", (2 * trunk + 0.1, 0.1, top - HEIGHT - 0.1), (0, -trunk, (HEIGHT + 0.1 + top) / 2)),
        _collider(f"{name}_trunk_s", (2 * trunk + 0.1, 0.1, top - HEIGHT - 0.1), (0, trunk, (HEIGHT + 0.1 + top) / 2)),
        _collider(f"{name}_trunk_w", (0.1, 2 * trunk, top - HEIGHT - 0.1), (-trunk, 0, (HEIGHT + 0.1 + top) / 2)),
        _collider(f"{name}_trunk_e", (0.1, 2 * trunk, top - HEIGHT - 0.1), (trunk, 0, (HEIGHT + 0.1 + top) / 2))]
    return Model(low=low, decals=decals, extras=colliders)


# Derelict variants: every kit piece re-baked in the derelict style, as dk_* in assets/models/derelict.
def _derelict(build):
    def variant():
        STYLE["name"] = "derelict"
        try:
            return build()
        finally:
            STYLE["name"] = "station"
    return variant


import lib as _lib  # noqa: E402

for _name in ("lk_wall", "lk_wall_door", "lk_door", "lk_wall_window", "lk_corner", "lk_floor", "lk_ceiling", "lk_wall_hatch"):
    _spec = _lib.ASSETS[_name]
    asset("dk" + _name[2:], "derelict", texture=_spec.texture, colors=_spec.colors, ao=_spec.ao, angles=_spec.angles)(_derelict(_spec.build))


# The relay satellite's kit (GDD §8.1): every piece re-baked clean in the relay's livery, as sk_* in
# assets/models/satellite, and its hatchways.
def _styled(build, look):
    def variant():
        STYLE["name"] = look
        try:
            return build()
        finally:
            STYLE["name"] = "station"
    return variant


for _name in ("lk_wall", "lk_wall_door", "lk_door", "lk_wall_window", "lk_corner", "lk_floor", "lk_ceiling", "lk_wall_hatch"):
    _spec = _lib.ASSETS[_name]
    asset("sk" + _name[2:], "satellite", texture=_spec.texture, colors=_spec.colors, ao=_spec.ao, angles=_spec.angles)(_styled(_spec.build, "relay"))
asset("sk_floor_hatch", "satellite", texture=256, colors=32, ao=0.45, angles=((-35, 40), (145, 45), (0, 75), (60, 20)))(_styled(floor_hatch, "relay"))
asset("sk_ceiling_hatch", "satellite", texture=256, colors=32, ao=0.5, angles=((-35, -25), (145, -30), (0, -75), (60, -12)))(_styled(ceiling_hatch, "relay"))
