"""The LANTERN station kit (GDD §5, §14; TECH §5): the modular pieces every deck is built from, on a
4 m grid with 3 m ceilings. Walls stand on cell edges and are finished on both faces, so any wall
can divide two rooms. Pieces are built facing -Y in Blender (+Z in Godot).

Visual language, cassette futurism: cream wall panels set proud of a dark backing so the seams
read in 3D, a dark steel kick plate, a steel grab rail at hip height, a safety-orange trim band,
and the classic sloped chamfer where wall meets ceiling, with vent grilles. Decks are diamond
plate with bolted seams; ceilings carry recessed warm light fixtures. Derelicts re-bake the same
pieces with decayed recipes (later).
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


def _materials():
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


def _decal_materials():
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
        geo_text.append(geo.text("LTN", 0.07, k["orange"], matrix=frame((centres[0] - pw * 0.25, face_y, 1.62), normal, lift=0.002)))
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


@asset("lk_floor", "station", texture=256, colors=32, ao=0.4)
def floor():
    """LANTERN deck plate, 4 x 4 m: diamond-plate panels on a 1 m grid with dark seams and corner
    bolts, a darker drainage strip around the edge where it meets the walls."""
    k = _materials()
    dm = _decal_materials()
    deck = mats.metal("lk_deck", (0.3, 0.32, 0.34), grime=0.5, brushed=False, detail="DiamondPlate008A")
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
    tile = mats.paint("lk_ceiling", (0.56, 0.57, 0.55), wear=0.1, grime=0.35)
    light = mats.glowing("lk_light", (1.0, 0.84, 0.6), base=(0.9, 0.85, 0.75), flicker=0.1)
    m = Mesh("lk_ceiling")
    faces = m.box((WIDTH, WIDTH, 0.1), tile, at=(0, 0, HEIGHT + 0.05))
    bottom = m.faces(among=faces, normal=(0, 0, -1), min_dot=0.99)
    # Recess the fixture: inset the bottom face to a 2.2 x 0.7 m opening, then push it up.
    m.box((2.3, 0.8, 0.1), k["frame"], at=(0, 0, HEIGHT - 0.03), bevel=0.01)
    m.box((2.1, 0.6, 0.02), light, at=(0, 0, HEIGHT - 0.085))
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
        f = frame((x, 0, HEIGHT - 0.095), down, up=(0, 1, 0), lift=0.001)
        d.polygon([(-0.015, -0.3), (0.015, -0.3), (0.015, 0.3), (-0.015, 0.3)], dm["dark"], f)
    collider = _collider("lk_ceiling_col", (WIDTH, WIDTH, 0.1), (0, 0, HEIGHT + 0.05))
    return Model(low=low, decals=[d.to_object()], extras=[collider])
