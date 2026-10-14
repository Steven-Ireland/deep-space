"""The LANTERN's bridge stations (GDD §5, §10): the consoles the crew fly, scan and keep each other
alive with. Hero props in the station's cassette-futurist language: beige 1970s computer casings,
dark bezels, chunky CRTs with live terminal faces (`screen_*` meshes, not baked), banks of toggles
and lit push buttons, analog dials, keyboards with fat keys, cable runs underneath.

Consoles face -Y in Blender (+Z in Godot): the operator stands on that side.
"""

import math

import bpy
from mathutils import Matrix, Vector

from lib import Model, asset, geo, mats
from lib.geo import Mesh, clip, frame, place


def _materials():
    return dict(
        casing=mats.paint("br_casing", (0.74, 0.69, 0.58), wear=0.25, grime=0.35, under=(0.5, 0.5, 0.48),
                          detail="Concrete034", detail_strength=0.18),
        casing_dark=mats.paint("br_casing_dark", (0.3, 0.29, 0.27), wear=0.3, grime=0.4),
        bezel=mats.plain("br_bezel", (0.13, 0.13, 0.14), grime=0.25),
        steel=mats.metal("br_steel", (0.58, 0.58, 0.56), grime=0.3),
        dark_steel=mats.metal("br_dark_steel", (0.25, 0.26, 0.27), grime=0.45),
        rubber=mats.plain("br_rubber", (0.07, 0.07, 0.08), grime=0.2),
        orange=mats.paint("br_orange", (0.86, 0.42, 0.1), wear=0.4, grime=0.3),
        keycap=mats.plain("br_keycap", (0.82, 0.79, 0.7), grime=0.45),
        keycap_dark=mats.plain("br_keycap_dark", (0.24, 0.23, 0.22), grime=0.3),
        dial_face=mats.plain("br_dial", (0.88, 0.85, 0.74), grime=0.3),
        cable=mats.plain("br_cable", (0.1, 0.1, 0.11), grime=0.15),
        cable_red=mats.plain("br_cable_red", (0.5, 0.1, 0.07), grime=0.2),
        leather=mats.plain("br_leather", (0.2, 0.13, 0.09), grime=0.3, detail_strength=0.35),
    )


def _decals():
    return dict(
        black=mats.decal("br_d_black", (0.06, 0.06, 0.06)),
        dark=mats.decal("br_d_dark", (0.16, 0.16, 0.16)),
        cream=mats.decal("br_d_cream", (0.88, 0.85, 0.75)),
        orange=mats.decal("br_d_orange", (0.86, 0.42, 0.1)),
        red=mats.decal("br_d_red", (0.75, 0.12, 0.08)),
        green_lit=mats.decal("br_d_green_lit", (0.4, 1.0, 0.5), glow=True),
        amber_lit=mats.decal("br_d_amber_lit", (1.0, 0.7, 0.2), glow=True),
        red_lit=mats.decal("br_d_red_lit", (1.0, 0.25, 0.15), glow=True),
        white_lit=mats.decal("br_d_white_lit", (0.95, 0.95, 0.85), glow=True),
        unlit=mats.decal("br_d_unlit", (0.3, 0.28, 0.25)),
    )


# Parts -------------------------------------------------------------------------------------------


def desk(m, k, width, depth=0.8, height=0.78, slant_rise=0.16, cx=0.0):
    """The console's base: a cabinet with a recessed kick space and a slanted control surface
    rising toward the back. Returns the control surface's frame (centre, normal, up) for parts."""
    y0, y1 = -depth / 2, depth / 2
    # Cabinet, with a dark kick recess at the bottom front.
    m.box((width, depth - 0.12, height - 0.1), k["casing"], at=(cx, 0.06, 0.1 + (height - 0.1) / 2), bevel=0.012)
    m.box((width - 0.04, depth - 0.2, 0.1), k["casing_dark"], at=(cx, 0.1, 0.05))
    # The slanted surface: a wedge from the front lip up to the back.
    lip = height + 0.03
    outline = [(y0 - 0.04, height - 0.02), (y1, height - 0.02), (y1, lip + slant_rise), (y0 - 0.04, lip)]
    m.prism(outline, width, k["casing"], at=(cx, 0, 0), rot=(0, 0, 90), bevel=0.01)
    # A dark rubber bumper along the front edge, where wrists rest.
    m.box((width, 0.05, 0.035), k["rubber"], at=(cx, y0 - 0.02, lip - 0.012), bevel=0.01)
    angle = math.atan2(slant_rise, y1 - y0 + 0.04)
    normal = Vector((0, -math.sin(angle), math.cos(angle)))
    centre = Vector((cx, (y0 + y1) / 2 - 0.02, lip + slant_rise / 2))
    up = Vector((0, math.cos(angle), math.sin(angle)))
    return centre, normal, up


def crt(m, k, centre, width, height, tilt=8.0, depth=0.4, name="screen", bezel=0.05):
    """A CRT monitor housing at `centre` (the screen's middle), tilted back `tilt` degrees, its
    face `width` x `height`. Returns the screen object (a `screen_*` mesh with 0..1 UVs)."""
    rot = (-tilt, 0, 0)
    t = place(centre, rot)
    # Housing: a deep box tapering back (the tube), a thick bezel around the face.
    m.box((width + bezel * 2 + 0.04, depth * 0.55, height + bezel * 2 + 0.04), k["casing"],
          at=centre, rot=rot, bevel=0.02)
    back = t @ Vector((0, depth * 0.45, 0))
    m.box((width * 0.8, depth * 0.5, height * 0.8), k["casing"], at=back, rot=rot, bevel=0.03)
    front = t @ Vector((0, -depth * 0.275, 0))
    m.box((width + bezel * 2, 0.03, height + bezel * 2), k["bezel"], at=front, rot=rot, bevel=0.012)
    face = place(t @ Vector((0, -depth * 0.275 - 0.016, 0)), rot)
    return geo.screen(name, width, height, face, bulge=min(width, height) * 0.035)


def toggles(m, d, k, dk, surface, origin, cols, rows, pitch=0.05, lit_every=3):
    """A bank of toggle switches on a control surface: dark plate, steel bats, a lamp above each
    (some lit), stencil tick marks."""
    centre, normal, up = surface
    side = up.cross(normal).normalized()
    base = centre + side * origin[0] + up * origin[1]
    plate_w, plate_h = cols * pitch + 0.03, rows * pitch * 1.5 + 0.02
    f = frame(base, normal, up=up, lift=0.0)
    m.box((plate_w, 0.012, plate_h), k["casing_dark"], at=base + normal * 0.004,
          rot=_rot_of(f), bevel=0.003)
    for r in range(rows):
        for c in range(cols):
            p = base + side * ((c - (cols - 1) / 2) * pitch) + up * ((r - (rows - 1) / 2) * pitch * 1.5)
            m.box((0.009, 0.028, 0.009), k["steel"], at=p + normal * 0.024, rot=_rot_of(frame(p, normal, up=up)))
            lamp = dk["green_lit"] if (r * cols + c) % lit_every == 0 else (dk["amber_lit"] if (r * cols + c) % 5 == 1 else dk["unlit"])
            q = p + up * pitch * 0.55
            d.polygon([(-0.006, -0.004), (0.006, -0.004), (0.006, 0.004), (-0.006, 0.004)], lamp,
                      frame(q, normal, up=up, lift=0.012))


def buttons(d, dk, surface, origin, cols, rows, pitch=0.045, pattern=(0, 1, 2, 3, 4)):
    """A grid of square push buttons as decals, a pattern of lit colours and dark caps."""
    centre, normal, up = surface
    side = up.cross(normal).normalized()
    base = centre + side * origin[0] + up * origin[1]
    colours = [dk["green_lit"], dk["amber_lit"], dk["unlit"], dk["red_lit"], dk["white_lit"], dk["unlit"], dk["unlit"]]
    for r in range(rows):
        for c in range(cols):
            p = base + side * ((c - (cols - 1) / 2) * pitch) + up * ((r - (rows - 1) / 2) * pitch)
            d.polygon([(-0.017, -0.017), (0.017, -0.017), (0.017, 0.017), (-0.017, 0.017)], dk["black"],
                      frame(p, normal, up=up, lift=0.001))
            colour = colours[pattern[(r * cols + c) % len(pattern)] % len(colours)]
            d.polygon([(-0.013, -0.013), (0.013, -0.013), (0.013, 0.013), (-0.013, 0.013)], colour,
                      frame(p, normal, up=up, lift=0.002))


def keyboard(m, d, k, dk, surface, origin, width=0.46, depth=0.16):
    """A chunky keyboard: a dark slab with rows of cream and dark keycaps."""
    centre, normal, up = surface
    side = up.cross(normal).normalized()
    base = centre + side * origin[0] + up * origin[1]
    f = frame(base, normal, up=up)
    m.box((width, 0.025, depth), k["casing_dark"], at=base + normal * 0.012, rot=_rot_of(f), bevel=0.006)
    pitch = 0.032
    cols = int((width - 0.03) / pitch)
    for r in range(4):
        for c in range(cols):
            p = base + side * ((c - (cols - 1) / 2) * pitch) + up * ((r - 1.5) * pitch)
            cap = dk["dark"] if (c in (0, cols - 1) or r == 0) else dk["cream"]
            d.polygon([(-0.012, -0.012), (0.012, -0.012), (0.012, 0.012), (-0.012, 0.012)], cap,
                      frame(p, normal, up=up, lift=0.027))


def dial(m, d, k, dk, centre, normal, up, radius=0.045, value=0.6, red_zone=True):
    """A round analog gauge: steel rim, cream face, tick marks, a needle at `value` (0..1)."""
    f = frame(centre, normal, up=up, lift=0.0)
    rot = _rot_of(f)
    m.cylinder(radius + 0.008, 0.03, k["steel"], sides=10, at=centre + normal * 0.012, rot=_rot_of(f, axis_to_normal=True))
    m.cylinder(radius, 0.004, k["dial_face"], sides=10, at=centre + normal * 0.028, rot=_rot_of(f, axis_to_normal=True))
    face = frame(centre + normal * 0.03, normal, up=up, lift=0.001)
    for i in range(9):
        a = math.radians(-135 + i * 270 / 8)
        x, z = math.sin(a) * radius * 0.8, math.cos(a) * radius * 0.8
        tick = dk["red"] if (red_zone and i >= 7) else dk["black"]
        d.polygon([(x - 0.003, z - 0.003), (x + 0.003, z - 0.003), (x + 0.003, z + 0.003), (x - 0.003, z + 0.003)], tick, face)
    a = math.radians(-135 + value * 270)
    tip = (math.sin(a) * radius * 0.75, math.cos(a) * radius * 0.75)
    perp = (math.cos(a) * 0.004, -math.sin(a) * 0.004)
    d.polygon([(-perp[0], -perp[1]), (perp[0], perp[1]), (tip[0] + perp[0] * 0.3, tip[1] + perp[1] * 0.3),
               (tip[0] - perp[0] * 0.3, tip[1] - perp[1] * 0.3)], dk["black"], frame(centre + normal * 0.03, normal, up=up, lift=0.002))


def back_panel(m, d, k, dk, x0, x1, z0, z1, y, stencil=None, texts=None):
    """The service side of a console (+Y): two bolted access hatches, vent slats, a stencil. The
    bridge's consoles stand in the room, so their backs are seen as much as their faces."""
    normal = Vector((0, 1, 0))
    w = x1 - x0
    for i in range(2):
        hx = x0 + w * (0.27 + 0.46 * i)
        faces = m.box((w * 0.36, 0.015, (z1 - z0) * 0.62), k["casing"], at=(hx, y + 0.0075, z0 + (z1 - z0) * 0.45), bevel=0.006)
        front = max(m.faces(among=faces, normal=(0, 1, 0), min_dot=0.99), key=lambda f: f.calc_area())
        m.inset([front], thickness=0.03, depth=0.006)
        for bx, bz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = Vector((hx + bx * w * 0.16, y + 0.016, z0 + (z1 - z0) * (0.45 + bz * 0.27)))
            d.polygon([(-0.01, -0.01), (0.01, -0.01), (0.01, 0.01), (-0.01, 0.01)], dk["dark"], frame(p, normal, lift=0.001))
    # Vent slats across the top.
    for i in range(6):
        z = z1 - 0.05 - i * 0.025
        d.polygon([(-w * 0.4, -0.006), (w * 0.4, -0.006), (w * 0.4, 0.006), (-w * 0.4, 0.006)], dk["black"],
                  frame(((x0 + x1) / 2, y, z), normal, lift=0.001))
    if stencil and texts is not None:
        texts.append(geo.text(stencil, 0.035, dk["dark"], matrix=frame((x0 + w * 0.27, y + 0.016, z0 + (z1 - z0) * 0.45), normal, lift=0.002)))


def cables(m, k, points_list, radius=0.018):
    for i, points in enumerate(points_list):
        m.pipe(points, radius, k["cable_red"] if i % 3 == 2 else k["cable"], sides=5)


def label(dk, text, size, colour, surface_or_frame):
    return geo.text(text, size, dk[colour], matrix=surface_or_frame)


def _rot_of(f, axis_to_normal=False):
    """Euler rotation (degrees) of a frame() matrix, for placing parts with Mesh(at, rot). With
    `axis_to_normal`, the part's Z axis (a cylinder's axis) is turned to the frame's normal."""
    m3 = f.to_3x3()
    if axis_to_normal:
        m3 = m3 @ Matrix.Rotation(math.radians(90), 3, "X")
    e = m3.to_euler("XYZ")
    return (math.degrees(e.x), math.degrees(e.y), math.degrees(e.z))


# Stations ----------------------------------------------------------------------------------------


@asset("br_helm", "bridge", texture=256, colors=32, ao=0.5)
def helm():
    """HELM station: where the crew plots its route and jumps (GDD §5, §6).

    A 2 m desk whose big centre CRT is the Nav Chart (`screen_nav`), flanked by toggle banks and a
    keyboard on the slant. To its right, on its own armoured pedestal, the JUMP LEVER: a red T
    handle in a guarded slot with hazard banding (`jump_lever`, a separate mesh that animates; the
    crew holds it for two seconds to jump). Cable runs drop from under the desk into the deck.
    """
    k = _materials()
    dk = _decals()
    m = Mesh("br_helm")
    d = Mesh("br_helm_decals")
    texts = []
    surface = desk(m, k, 1.9, cx=-0.15)
    # Upright monitor bank along the back of the desk.
    m.box((1.9, 0.42, 0.62), k["casing"], at=(-0.15, 0.2, 1.24), bevel=0.02)
    m.box((1.86, 0.06, 0.05), k["orange"], at=(-0.15, -0.02, 1.54), bevel=0.006)
    nav = crt(m, k, Vector((-0.15, -0.06, 1.27)), 0.56, 0.42, tilt=6, depth=0.36, name="screen_nav")
    # Toggle banks either side of the nav screen, on the bank face.
    for x in (-0.82, 0.52):
        bank = (Vector((x, -0.015, 1.24)), Vector((0, -1, 0)), Vector((0, 0, 1)))
        toggles(m, d, k, dk, bank, (0, 0.1), 5, 2, pitch=0.05)
        buttons(d, dk, bank, (0, -0.12), 5, 2, pattern=(2, 0, 2, 1, 2, 2, 4, 2, 3, 2))
    keyboard(m, d, k, dk, surface, (0.0, -0.2))
    toggles(m, d, k, dk, surface, (-0.62, -0.12), 4, 2, pitch=0.045, lit_every=2)
    buttons(d, dk, surface, (0.52, -0.12), 4, 2, pattern=(1, 2, 2, 0))
    # The service side: the bank's back, the cabinet's back, a cable trunk down into the deck.
    back_panel(m, d, k, dk, -1.08, 0.78, 0.95, 1.53, 0.41, stencil="LTN-HLM-01", texts=texts)
    back_panel(m, d, k, dk, -1.08, 0.78, 0.15, 0.7, 0.4)
    m.box((0.12, 0.08, 1.4), k["dark_steel"], at=(0.62, 0.46, 0.7), bevel=0.01)
    # Stencilled station name over the left bank.
    texts.append(label(dk, "HELM", 0.05, "cream", frame((-0.82, -0.012, 1.47), (0, -1, 0))))

    # The jump lever pedestal.
    px = 1.15
    m.box((0.36, 0.42, 0.95), k["casing_dark"], at=(px, 0.0, 0.475), bevel=0.02)
    m.box((0.4, 0.46, 0.06), k["steel"], at=(px, 0.0, 0.98), bevel=0.01)
    m.box((0.1, 0.32, 0.03), k["rubber"], at=(px, 0.0, 1.005))  # the slot
    for gx in (-0.165, 0.165):
        m.box((0.03, 0.42, 0.12), k["orange"], at=(px + gx, 0.0, 1.07), bevel=0.008)  # guard rails
    for i in range(4):
        stripe = [(-0.18, -0.48 + i * 0.24), (0.18, -0.38 + i * 0.24), (0.18, -0.3 + i * 0.24), (-0.18, -0.4 + i * 0.24)]
        d.polygon(clip(stripe, -0.18, 0.18, -0.47, 0.47), dk["black"], frame((px, -0.211, 0.475), (0, -1, 0)))
    d.polygon([(-0.18, -0.47), (0.18, -0.47), (0.18, 0.47), (-0.18, 0.47)], dk["orange"],
              frame((px, -0.2105, 0.475), (0, -1, 0), lift=0.0))
    texts.append(label(dk, "JUMP", 0.045, "black", frame((px, -0.213, 0.82), (0, -1, 0))))
    # The lever itself: baked with the console, split off after (jump_lever) so it can be pulled.
    lk = mats.paint("br_lever", (0.75, 0.12, 0.08), wear=0.5, grime=0.3, under=(0.6, 0.6, 0.58))
    m.box((0.04, 0.04, 0.3), k["steel"], at=(px, 0.0, 1.17))
    m.cylinder(0.024, 0.24, lk, sides=8, at=(px, 0.0, 1.33), rot=(0, 90, 0))
    # Cable runs from under the desk into the deck.
    cables(m, k, [[(-0.9, 0.3, 0.1), (-0.95, 0.42, 0.04), (-1.0, 0.5, -0.02)],
                  [(-0.6, 0.32, 0.12), (-0.62, 0.48, 0.03), (-0.66, 0.6, -0.02)],
                  [(0.6, 0.3, 0.1), (0.72, 0.42, 0.03), (0.84, 0.5, -0.02)]])
    m.subdivide(0.6)
    low = m.to_object()

    def split(model):
        in_lever = lambda c: abs(c.x - px) < 0.14 and abs(c.y) < 0.06 and c.z > 1.025
        console, lever = geo.split_object(model.low, {"br_helm": lambda c: not in_lever(c), "jump_lever": in_lever})
        model.low = console
        model.extras.append(lever)

    collider = _console_collider("br_helm", (2.3, 0.85, 1.6), (0.0, 0.05, 0.8))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[nav, collider], after_bake=split)


def _console_collider(name, size, at):
    m = Mesh(f"{name}_col-colonly")
    m.box(size, mats.plain("collider", (1, 0, 1)), at=at)
    return m.to_object()


@asset("br_science", "bridge", texture=256, colors=32, ao=0.5)
def science():
    """SCIENCE station: the long-range scanner and the planet survey (GDD §6, §7).

    A desk with two displays on its upright bank: a round green scope in a heavy ring bezel (the
    long-range scanner, `screen_scan`) and a rectangular survey CRT (`screen_survey`). A keyboard,
    a bank of lit push buttons, a pair of tuning knobs under the scope. Back finished.
    """
    k = _materials()
    dk = _decals()
    m = Mesh("br_science")
    d = Mesh("br_science_decals")
    texts = []
    surface = desk(m, k, 1.9)
    m.box((1.9, 0.42, 0.66), k["casing"], at=(0, 0.2, 1.26), bevel=0.02)
    m.box((1.86, 0.06, 0.05), k["orange"], at=(0, -0.02, 1.58), bevel=0.006)
    # The scope: a deep ring bezel around a round tube face.
    sx, sz = -0.42, 1.25
    m.cylinder(0.25, 0.12, k["bezel"], sides=16, at=(sx, -0.05, sz), rot=(90, 0, 0))
    m.cylinder(0.27, 0.04, k["steel"], sides=16, at=(sx, -0.1, sz), rot=(90, 0, 0))
    scan = geo.screen_round("screen_scan", 0.21, place((sx, -0.125, sz)), bulge=0.015)
    for kx in (-0.12, 0.12):
        m.cylinder(0.025, 0.04, k["rubber"], sides=8, at=(sx + kx, -0.03, 0.97), rot=(90, 0, 0))
    survey = crt(m, k, Vector((0.38, -0.05, 1.27)), 0.46, 0.34, tilt=5, depth=0.34, name="screen_survey")
    keyboard(m, d, k, dk, surface, (0.15, -0.2))
    buttons(d, dk, surface, (-0.55, -0.15), 6, 2, pattern=(0, 2, 2, 1, 2, 4))
    bank = (Vector((0.82, -0.015, 1.3)), Vector((0, -1, 0)), Vector((0, 0, 1)))
    buttons(d, dk, bank, (0, 0), 1, 5, pattern=(0, 2, 1, 2, 3))
    texts.append(label(dk, "SCIENCE", 0.045, "cream", frame((-0.42, -0.012, 1.54), (0, -1, 0))))
    texts.append(label(dk, "SCAN", 0.03, "cream", frame((-0.42, -0.012, 0.99), (0, -1, 0))))
    back_panel(m, d, k, dk, -0.92, 0.92, 0.95, 1.57, 0.41, stencil="LTN-SCI-02", texts=texts)
    back_panel(m, d, k, dk, -0.92, 0.92, 0.15, 0.7, 0.4)
    cables(m, k, [[(-0.7, 0.3, 0.1), (-0.75, 0.45, 0.03), (-0.8, 0.55, -0.02)],
                  [(0.5, 0.32, 0.12), (0.55, 0.48, 0.03), (0.6, 0.58, -0.02)]])
    m.subdivide(0.6)
    low = m.to_object()
    collider = _console_collider("br_science", (1.95, 0.85, 1.62), (0.0, 0.05, 0.81))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[scan, survey, collider])


@asset("br_ops", "bridge", texture=256, colors=32, ao=0.5)
def ops():
    """OPS station: the crew's vitals and the ship's eyes and voice (GDD §5, §10, §11).

    Stands against a wall. A heavy frame above the desk holds the Vitals board: four CRT tiles, one
    per crew member (`screen_vitals_1`..`4`), each with a name plate. On the desk: a station camera
    monitor (`screen_cams`), a keyboard, and the PA microphone on a gooseneck with a red talk key.
    """
    k = _materials()
    dk = _decals()
    m = Mesh("br_ops")
    d = Mesh("br_ops_decals")
    texts = []
    surface = desk(m, k, 2.0)
    # The vitals board: a dark frame on stand-offs, four tiles in a row.
    m.box((2.0, 0.2, 0.62), k["casing_dark"], at=(0, 0.3, 1.62), bevel=0.02)
    m.box((2.04, 0.22, 0.05), k["orange"], at=(0, 0.3, 1.95), bevel=0.006)
    screens = []
    for i in range(4):
        x = -0.72 + i * 0.48
        m.box((0.42, 0.04, 0.34), k["bezel"], at=(x, 0.19, 1.65), bevel=0.01)
        screens.append(geo.screen(f"screen_vitals_{i + 1}", 0.36, 0.27, place((x, 0.165, 1.65)), bulge=0.008))
        d.polygon([(-0.1, -0.022), (0.1, -0.022), (0.1, 0.022), (-0.1, 0.022)], dk["cream"],
                  frame((x, 0.2, 1.4), (0, -1, 0), lift=0.001))
        texts.append(label(dk, f"CREW {i + 1}", 0.026, "black", frame((x, 0.2, 1.4), (0, -1, 0), lift=0.002)))
    # Below it, a low bank with the camera monitor.
    m.box((2.0, 0.36, 0.3), k["casing"], at=(0, 0.22, 1.06), bevel=0.015)
    cams = crt(m, k, Vector((0.55, -0.02, 1.08)), 0.3, 0.22, tilt=8, depth=0.28, name="screen_cams")
    toggles(m, d, k, dk, (Vector((-0.45, 0.035, 1.06)), Vector((0, -1, 0)), Vector((0, 0, 1))), (0, 0), 8, 1, pitch=0.05)
    keyboard(m, d, k, dk, surface, (0.2, -0.2))
    # The PA microphone: a weighted base, a gooseneck, a grilled head, a red talk key.
    mx = -0.6
    m.cylinder(0.07, 0.03, k["dark_steel"], sides=8, at=(mx, -0.05, 0.9))
    m.pipe([(mx, -0.05, 0.9), (mx, -0.05, 1.02), (mx - 0.02, -0.1, 1.12), (mx - 0.03, -0.18, 1.16)], 0.008, k["steel"], sides=5, caps=False)
    m.cylinder(0.022, 0.06, k["rubber"], sides=8, at=(mx - 0.035, -0.21, 1.17), rot=(70, 0, 0))
    buttons(d, dk, surface, (-0.45, -0.18), 1, 1, pattern=(3,))
    texts.append(label(dk, "OPS", 0.05, "cream", frame((-0.8, 0.19, 1.88), (0, -1, 0), lift=0.002)))
    texts.append(label(dk, "VITALS", 0.035, "cream", frame((0.0, 0.19, 1.88), (0, -1, 0), lift=0.002)))
    m.subdivide(0.6)
    low = m.to_object()
    collider = _console_collider("br_ops", (2.05, 0.85, 1.25), (0.0, 0.05, 0.62))
    return Model(low=low, decals=[d.to_object()] + texts, extras=screens + [cams, collider])


@asset("br_engineering", "bridge", texture=256, colors=32, ao=0.5)
def engineering():
    """ENGINEERING station: power and drive, read at a glance (GDD §5).

    Stands against a wall. An angled gauge bank of six analog dials (drive charge, reactor, hull
    pressure...) over a small power CRT (`screen_power`); on the slant, a row of four heavy breaker
    levers with lit status lamps, and a striped master breaker that only engineers touch.
    """
    k = _materials()
    dk = _decals()
    m = Mesh("br_engineering")
    d = Mesh("br_engineering_decals")
    texts = []
    surface = desk(m, k, 1.9)
    m.box((1.9, 0.4, 0.72), k["casing"], at=(0, 0.2, 1.3), bevel=0.02)
    m.box((1.86, 0.06, 0.05), k["orange"], at=(0, -0.02, 1.65), bevel=0.006)
    face = Vector((0, -1, 0))
    for i, value in enumerate((0.7, 0.45, 0.9, 0.35, 0.6, 0.8)):
        x = -0.78 + i * 0.16 if i < 3 else 0.46 + (i - 3) * 0.16
        dial(m, d, k, dk, Vector((x, -0.0, 1.42)), face, Vector((0, 0, 1)), radius=0.055, value=value)
    power = crt(m, k, Vector((0.0, -0.05, 1.28)), 0.36, 0.27, tilt=6, depth=0.3, name="screen_power")
    for i in range(6):
        x = -0.78 + i * 0.16 if i < 3 else 0.46 + (i - 3) * 0.16
        d.polygon([(-0.05, -0.014), (0.05, -0.014), (0.05, 0.014), (-0.05, 0.014)], dk["cream"], frame((x, -0.012, 1.31), face, lift=0.001))
    # Breaker levers on the slant: steel bases, black handles, a lamp above each.
    centre, normal, up = surface
    side = Vector((1, 0, 0))
    for i in range(4):
        p = centre + side * (-0.6 + i * 0.22) + up * -0.05
        m.box((0.1, 0.04, 0.14), k["dark_steel"], at=p + normal * 0.02, rot=_rot_of(frame(p, normal, up=up)), bevel=0.008)
        m.box((0.03, 0.12, 0.03), k["rubber"], at=p + normal * 0.09 + up * 0.03, rot=_rot_of(frame(p, normal, up=up)), bevel=0.006)
        lamp = dk["green_lit"] if i != 2 else dk["red_lit"]
        d.polygon([(-0.015, -0.01), (0.015, -0.01), (0.015, 0.01), (-0.015, 0.01)], lamp, frame(p + up * 0.11, normal, up=up, lift=0.001))
    # The master breaker: bigger, striped, on its own plate.
    p = centre + side * 0.55 + up * -0.05
    m.box((0.22, 0.04, 0.2), k["orange"], at=p + normal * 0.02, rot=_rot_of(frame(p, normal, up=up)), bevel=0.01)
    m.box((0.05, 0.16, 0.05), k["rubber"], at=p + normal * 0.11 + up * 0.03, rot=_rot_of(frame(p, normal, up=up)), bevel=0.008)
    for j in range(3):
        stripe = [(-0.11 + j * 0.08, -0.1), (-0.07 + j * 0.08, -0.1), (-0.11 + j * 0.08 + 0.06, 0.1), (-0.15 + j * 0.08 + 0.06, 0.1)]
        d.polygon(clip(stripe, -0.11, 0.11, -0.1, 0.1), dk["black"], frame(p + normal * 0.04, normal, up=up, lift=0.001))
    texts.append(label(dk, "ENGINEERING", 0.04, "cream", frame((0.0, -0.012, 1.58), face)))
    texts.append(label(dk, "MASTER", 0.025, "cream", frame(centre + side * 0.55 + up * 0.09, normal, up=up, lift=0.002)))
    m.subdivide(0.6)
    low = m.to_object()
    collider = _console_collider("br_engineering", (1.95, 0.85, 1.67), (0.0, 0.05, 0.83))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[power, collider])


@asset("br_chair", "bridge", texture=128, colors=32, ao=0.5)
def chair():
    """The captain's chair: a heavy padded seat on a steel pedestal, high back with a headrest,
    armrests with small button panels. Dark oxblood leather over beige shells. Faces -Y."""
    k = _materials()
    dk = _decals()
    m = Mesh("br_chair")
    d = Mesh("br_chair_decals")
    m.cylinder(0.32, 0.06, k["dark_steel"], sides=8, at=(0, 0, 0.03))
    m.cylinder(0.08, 0.36, k["steel"], sides=8, at=(0, 0, 0.24))
    m.box((0.6, 0.58, 0.1), k["casing"], at=(0, 0.02, 0.45), bevel=0.02)
    m.box((0.54, 0.52, 0.1), k["leather"], at=(0, 0.0, 0.53), bevel=0.035)
    # Back: a shell with a padded face, tilted back a little.
    m.box((0.58, 0.1, 0.78), k["casing"], at=(0, 0.3, 0.92), rot=(-8, 0, 0), bevel=0.02)
    m.box((0.5, 0.08, 0.66), k["leather"], at=(0, 0.25, 0.9), rot=(-8, 0, 0), bevel=0.03)
    m.box((0.34, 0.1, 0.18), k["leather"], at=(0, 0.3, 1.4), rot=(-8, 0, 0), bevel=0.04)
    for sx in (-1, 1):
        m.box((0.1, 0.5, 0.06), k["casing"], at=(sx * 0.33, 0.02, 0.72), bevel=0.015)
        m.box((0.06, 0.06, 0.2), k["steel"], at=(sx * 0.33, 0.2, 0.6))
        m.box((0.08, 0.16, 0.012), k["casing_dark"], at=(sx * 0.33, -0.12, 0.756))
        buttons(d, dk, (Vector((sx * 0.33, -0.12, 0.763)), Vector((0, 0, 1)), Vector((0, 1, 0))), (0, 0), 1, 3,
                pitch=0.045, pattern=(0, 2, 1) if sx < 0 else (2, 3, 2))
    low = m.to_object()
    collider = _console_collider("br_chair", (0.7, 0.7, 1.2), (0, 0.05, 0.6))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


@asset("br_chart_table", "bridge", texture=256, colors=32, ao=0.5, angles=((-35, 30), (145, 30), (90, 10), (-20, 70)))
def chart_table():
    """The chart table at the bridge's heart (GDD §5, §6), standing on the deck: the sector chart
    for the whole crew to stand round. A low octagonal table (its glass at 0.8 m, to look down on)
    on a dark column flaring out from a steel plinth; a beige band and a rubber bumper round its
    rim. Its top is a dark glass well with etched range rings, a glowing green emitter ring at its
    edge and the projector's lens at its centre; the hologram itself is the game's (`SOCKET_holo`,
    on the lens). Push buttons on the rim's aft side and a stencil, CHART, on its aft face. Faces
    -Y like the consoles (aft in the game), where the crew comes up from the corridor.
    """
    k = _materials()
    dk = _decals()
    glass = mats.plain("br_chart_glass", (0.05, 0.07, 0.07), grime=0.15)
    m = Mesh("br_chart_table")
    d = Mesh("br_chart_table_decals")
    texts = []
    eighth = math.pi / 8
    top = 0.8
    # Plinth, column and the skirt flaring out under the top.
    m.lathe([(0.56, 0.0), (0.56, 0.07), (0.5, 0.1), (0.34, 0.1)], k["dark_steel"], sides=8, angle_offset=eighth,
            cap_start=False, cap_end=False)
    m.lathe([(0.34, 0.1), (0.3, 0.14), (0.3, top - 0.35), (0.34, top - 0.31)], k["casing_dark"], sides=8,
            angle_offset=eighth, cap_start=False, cap_end=False)
    m.lathe([(0.34, top - 0.31), (0.84, top - 0.13), (0.9, top - 0.11)], k["casing"], sides=8, angle_offset=eighth,
            cap_start=False, cap_end=False)
    # The rim: a casing band with an orange stripe, the rubber bumper over it.
    m.lathe([(0.9, top - 0.11), (0.9, top - 0.03)], k["casing"], sides=8, angle_offset=eighth, cap_start=False,
            cap_end=False)
    m.lathe([(0.905, top - 0.085), (0.905, top - 0.055)], k["orange"], sides=8, angle_offset=eighth, cap_start=False,
            cap_end=False)
    m.lathe([(0.9, top - 0.03), (0.94, top - 0.015), (0.94, top + 0.015), (0.9, top + 0.03), (0.8, top + 0.03),
             (0.78, top)], k["rubber"], sides=8, angle_offset=eighth, cap_start=False, cap_end=False)
    # The glass well, and the lens in its middle.
    m.lathe([(0.78, top), (0.0, top)], glass, sides=8, angle_offset=eighth, cap_start=False, cap_end=False)
    m.lathe([(0.15, top), (0.15, top + 0.03), (0.12, top + 0.035), (0.1, top + 0.02)], k["steel"], sides=8,
            angle_offset=eighth, cap_start=False, cap_end=False)
    # What glows is modelled, not a decal: too fine for the texture. The lens, and the emitter ring
    # round the glass's edge, a band of 16 segments.
    emitter = mats.glowing("br_chart_emitter", (0.4, 1.0, 0.5), base=(0.12, 0.3, 0.16), flicker=0.1)
    m.lathe([(0.1, top + 0.02), (0.0, top + 0.012)], emitter, sides=8, angle_offset=eighth, cap_start=False, cap_end=False)
    m.lathe([(0.7, top + 0.004), (0.735, top + 0.004)], emitter, sides=16, cap_start=False, cap_end=False)
    up = Vector((0, 0, 1))
    north = Vector((0, 1, 0))
    # Range rings etched in the glass, and ticks every eighth.
    for radius, colour, width in ((0.3, dk["dark"], 0.01), (0.5, dk["dark"], 0.01)):
        for i in range(32):
            a0 = i / 32 * math.tau
            a1 = (i + 1) / 32 * math.tau
            r0, r1 = radius - width / 2, radius + width / 2
            d.polygon([(math.cos(a0) * r0, math.sin(a0) * r0), (math.cos(a1) * r0, math.sin(a1) * r0),
                       (math.cos(a1) * r1, math.sin(a1) * r1), (math.cos(a0) * r1, math.sin(a0) * r1)],
                      colour, frame((0, 0, top), up, up=north, lift=0.001))
    for i in range(8):
        a = i / 8 * math.tau
        tick = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-tick.y, tick.x, 0))
        p0, p1 = tick * 0.56, tick * 0.68
        corners = [p0 - side * 0.006, p1 - side * 0.006, p1 + side * 0.006, p0 + side * 0.006]
        d.polygon([(c.x, c.y) for c in corners], dk["dark"], frame((0, 0, top), up, up=north, lift=0.001))
    # Push buttons on the rim's aft flat, either side of the middle; the stencil on the band below.
    slope = Vector((0, -0.4, 1)).normalized()
    for x in (-0.24, 0.24):
        rim = (Vector((x, -0.865, top + 0.022)), slope, Vector((0, 1, 0.4)).normalized())
        buttons(d, dk, rim, (0, 0), 4, 1, pitch=0.042, pattern=(0, 2, 1, 2) if x < 0 else (2, 4, 2, 0))
    face = 0.9 * math.cos(eighth)
    texts.append(label(dk, "CHART", 0.035, "cream", frame((0, -face - 0.001, top - 0.07), (0, -1, 0))))
    # Cables from the column down into the deck.
    cables(m, k, [[(0.2, -0.22, 0.3), (0.32, -0.3, 0.1), (0.42, -0.36, 0.0)],
                  [(-0.22, 0.2, 0.34), (-0.34, 0.3, 0.12), (-0.46, 0.34, 0.0)]])
    m.subdivide(0.6)
    low = m.to_object()
    collider = Mesh("br_chart_table_col-colonly")
    collider.lathe([(0.0, 0.0), (0.92, 0.0), (0.92, top + 0.03), (0.0, top + 0.03)], mats.plain("collider", (1, 0, 1)), sides=8,
                   angle_offset=eighth, cap_start=False, cap_end=False)
    holo = _socket("holo", (0, 0, top + 0.03))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider.to_object(), holo])


def _socket(name, at):
    empty = bpy.data.objects.new(f"SOCKET_{name}", None)
    empty.location = at
    bpy.context.scene.collection.objects.link(empty)
    return empty


@asset("br_dais", "bridge", texture=256, colors=24, ao=0.45, angles=((-35, 30), (145, 30), (90, 10), (-20, 70)))
def dais():
    """The command dais at the bridge's heart: a low octagonal platform with a steel step edge
    and hazard banding, so nobody trips in the dark, and a ring of floor lamps."""
    k = _materials()
    dk = _decals()
    deck = mats.metal("br_dais_deck", (0.32, 0.33, 0.35), grime=0.45, brushed=False, detail="DiamondPlate008A")
    m = Mesh("br_dais")
    m.lathe([(1.7, 0.0), (1.7, 0.12), (1.62, 0.16), (0.0, 0.16)], deck, sides=8, angle_offset=math.pi / 8,
            cap_start=False, cap_end=False)
    d = Mesh("br_dais_decals")
    for i in range(8):
        a = 2 * math.pi * i / 8
        n = Vector((math.cos(a), math.sin(a), 0))
        f = frame(n * 1.7 * math.cos(math.pi / 8) + Vector((0, 0, 0.06)), n, lift=0.001)
        hw = 1.7 * math.sin(math.pi / 8)
        d.polygon([(-hw, -0.05), (hw, -0.05), (hw, 0.05), (-hw, 0.05)], dk["orange"], f)
        for j in range(-4, 5):
            x = j * 0.14
            stripe = [(x - 0.03, -0.05), (x + 0.02, -0.05), (x + 0.07, 0.05), (x + 0.02, 0.05)]
            d.polygon(clip(stripe, -hw, hw, -0.05, 0.05), dk["black"], frame(n * 1.7 * math.cos(math.pi / 8) + Vector((0, 0, 0.06)), n, lift=0.0015))
        lamp = Vector((math.cos(a + math.pi / 8), math.sin(a + math.pi / 8), 0)) * 1.45
        d.polygon([(-0.03, -0.03), (0.03, -0.03), (0.03, 0.03), (-0.03, 0.03)], dk["amber_lit"],
                  frame(lamp + Vector((0, 0, 0.16)), (0, 0, 1), up=(0, 1, 0), lift=0.001))
    m.subdivide(1.0)
    low = m.to_object()
    collider = _console_collider("br_dais", (3.2, 3.2, 0.16), (0, 0, 0.08))
    return Model(low=low, decals=[d.to_object()], extras=[collider])
