"""The LANTERN's rooms beyond the bridge (GDD §5): the suit room and airlock, the docking port, the
drive room, the workshop, the crew cabins, stores and the med bay. Each prop serves the room's job
in the run: suits and O2 for going outside, the drive and its fuel slots for jumping, the recycler
and fabricator for upgrades. Same language as the bridge (bridge.py): beige casings, dark steel,
safety orange, lit lamps, stencils. Props face -Y in Blender (+Z in Godot).
"""

import math

from mathutils import Vector

import bridge as br
from lib import Model, asset, geo, mats
from lib.geo import Mesh, clip, frame, place

UP = Vector((0, 0, 1))
FRONT = Vector((0, -1, 0))


def _plate(d, colour, centre, normal, w, h, up=(0, 0, 1), lift=0.001):
    d.polygon([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], colour, frame(centre, normal, up=up, lift=lift))


def _stripes(d, dk, centre, normal, w, h, pitch=0.12, up=(0, 0, 1), lift=0.001):
    """A black-on-orange hazard band."""
    _plate(d, dk["orange"], centre, normal, w, h, up=up, lift=lift)
    f = frame(centre, normal, up=up, lift=lift + 0.0005)
    for i in range(-int(w / pitch) - 2, int(w / pitch) + 3):
        x = i * pitch
        stripe = [(x, -h / 2), (x + pitch * 0.45, -h / 2), (x + pitch * 0.45 + h * 0.6, h / 2), (x + h * 0.6, h / 2)]
        d.polygon(clip(stripe, -w / 2, w / 2, -h / 2, h / 2), dk["black"], f)


def _bolts(d, dk, centre, normal, w, h, up=(0, 0, 1), size=0.012):
    u = Vector(up)
    side = u.cross(Vector(normal)).normalized()
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        p = Vector(centre) + side * (sx * w / 2) + u * (sz * h / 2)
        _plate(d, dk["dark"], p, normal, size, size, up=up, lift=0.0015)


# Suit room ---------------------------------------------------------------------------------------


@asset("rm_suit_locker", "rooms", texture=128, colors=32, ao=0.5)
def suit_locker():
    """A crew suit locker (GDD §5, §9): 0.75 m wide, 2.2 m tall. An open cubby on top holds the
    helmet, a dome with a dark visor; below, a door with a tall window where the hanging suit shows
    as a pale shape, vent slots, a name plate and a status lamp. Lockers stand in a row."""
    k = br._materials()
    dk = br._decals()
    visor = mats.glowing("rm_visor", (0.12, 0.22, 0.2), base=(0.05, 0.08, 0.08), flicker=0.0)
    suit = mats.plain("rm_suit_fabric", (0.78, 0.74, 0.62), grime=0.4, detail_strength=0.3)
    m = Mesh("rm_suit_locker")
    d = Mesh("rm_suit_locker_decals")
    texts = []
    w, depth, h = 0.75, 0.6, 2.2
    # Carcass: sides, back, top, a shelf; the cubby is open at the front.
    for x in (-w / 2 + 0.02, w / 2 - 0.02):
        m.box((0.04, depth, h), k["casing"], at=(x, 0, h / 2), bevel=0.008)
    m.box((w, 0.03, h), k["casing_dark"], at=(0, depth / 2 - 0.015, h / 2))
    m.box((w, depth, 0.04), k["casing"], at=(0, 0, h - 0.02), bevel=0.008)
    m.box((w, depth, 0.04), k["casing"], at=(0, 0, 1.68), bevel=0.008)
    m.box((w, depth, 0.08), k["casing_dark"], at=(0, 0, 0.04))
    # The helmet on its shelf: a dome, a dark visor band, a collar ring.
    m.lathe([(0.0, 0.0), (0.13, 0.0), (0.15, 0.05), (0.155, 0.14), (0.13, 0.24), (0.07, 0.29), (0.0, 0.3)],
            suit, sides=10, at=(0, 0.02, 1.7))
    m.box((0.2, 0.04, 0.09), visor, at=(0, -0.13, 1.86), bevel=0.02)
    m.cylinder(0.14, 0.03, k["dark_steel"], sides=10, at=(0, 0.02, 1.715))
    # The door below: a framed panel with a tall window.
    door = m.box((w - 0.06, 0.04, 1.56), k["casing"], at=(0, -depth / 2 + 0.02, 0.87), bevel=0.01)
    front = max(m.faces(among=door, normal=(0, -1, 0), min_dot=0.99), key=lambda f: f.calc_area())
    m.inset([front], thickness=0.05, depth=0.01)
    m.box((0.28, 0.01, 0.9), visor, at=(0, -depth / 2 - 0.002, 1.08))
    # The suit hanging behind the window: shoulders, a chest unit with its lamps, legs.
    wf = frame((0, -depth / 2 - 0.008, 1.08), FRONT)
    d.polygon([(-0.13, 0.3), (0.13, 0.3), (0.12, 0.08), (0.1, -0.12), (-0.1, -0.12), (-0.12, 0.08)], dk["cream"], wf)
    d.polygon([(-0.1, -0.12), (-0.01, -0.12), (-0.02, -0.42), (-0.09, -0.42)], dk["cream"], wf)
    d.polygon([(0.01, -0.12), (0.1, -0.12), (0.09, -0.42), (0.02, -0.42)], dk["cream"], wf)
    wf2 = frame((0, -depth / 2 - 0.008, 1.08), FRONT, lift=0.0015)
    d.polygon([(-0.07, 0.16), (0.07, 0.16), (0.07, 0.04), (-0.07, 0.04)], dk["dark"], wf2)
    d.polygon([(-0.05, 0.13), (-0.03, 0.13), (-0.03, 0.11), (-0.05, 0.11)], dk["green_lit"], frame((0, -depth / 2 - 0.008, 1.08), FRONT, lift=0.002))
    d.polygon([(0.03, 0.13), (0.05, 0.13), (0.05, 0.11), (0.03, 0.11)], dk["amber_lit"], frame((0, -depth / 2 - 0.008, 1.08), FRONT, lift=0.002))
    for i in range(5):
        _plate(d, dk["black"], Vector((0, -depth / 2 - 0.0, 0.36 + i * 0.035)), FRONT, 0.4, 0.012)
    _plate(d, dk["cream"], Vector((0, -depth / 2, 1.6)), FRONT, 0.3, 0.06)
    texts.append(geo.text("EVA SUIT", 0.03, dk["black"], matrix=frame((0, -depth / 2, 1.6), FRONT, lift=0.002)))
    _plate(d, dk["green_lit"], Vector((0.27, -depth / 2, 1.6)), FRONT, 0.03, 0.03)
    m.box((0.04, 0.05, 0.16), k["steel"], at=(0.27, -depth / 2 - 0.035, 0.95), bevel=0.01)  # handle
    low = m.to_object()
    collider = br._console_collider("rm_suit_locker", (w, depth, h), (0, 0, h / 2))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


@asset("rm_o2_rack", "rooms", texture=128, colors=32, ao=0.5)
def o2_rack():
    """The O2 refill rack (GDD §5, §9): wall-mounted, three tall green-and-white oxygen bottles in
    clamps on a backing plate, a manifold pipe across their valves, a coiled refill hose on a hook,
    a pressure dial, and a big O2 stencil. Crew refill their suits here."""
    k = br._materials()
    dk = br._decals()
    green = mats.paint("rm_o2_green", (0.18, 0.42, 0.26), wear=0.35, grime=0.35)
    white = mats.paint("rm_o2_white", (0.85, 0.84, 0.8), wear=0.3, grime=0.35)
    m = Mesh("rm_o2_rack")
    d = Mesh("rm_o2_rack_decals")
    texts = []
    m.box((1.6, 0.05, 1.6), k["casing_dark"], at=(0, 0.15, 1.1), bevel=0.01)
    for i in range(3):
        x = -0.4 + i * 0.4
        m.lathe([(0.0, 0.0), (0.11, 0.0), (0.12, 0.04), (0.12, 0.98), (0.1, 1.06), (0.04, 1.1), (0.0, 1.1)],
                green, sides=10, at=(x, 0.0, 0.42))
        m.cylinder(0.122, 0.12, white, sides=10, at=(x, 0.0, 1.38))
        m.cylinder(0.03, 0.08, k["steel"], sides=6, at=(x, 0.0, 1.56))
        for z in (0.7, 1.2):
            m.box((0.28, 0.06, 0.04), k["dark_steel"], at=(x, 0.07, z), bevel=0.006)
    m.pipe([(-0.55, 0.0, 1.62), (0.55, 0.0, 1.62)], 0.025, k["steel"], sides=6)
    # The refill hose: from the manifold, coiled on a hook at the side.
    hose = [(0.55, 0.0, 1.62), (0.62, -0.02, 1.55)]
    for i in range(10):
        a = i / 9 * math.tau * 1.0
        hose.append((0.62 + 0.09 * math.sin(a), -0.08, 1.35 - 0.1 * (1 - math.cos(a)) - i * 0.006))
    m.pipe(hose, 0.016, k["rubber"], sides=5)
    m.box((0.05, 0.12, 0.04), k["steel"], at=(0.62, -0.03, 1.36))
    br.dial(m, d, k, dk, Vector((-0.68, 0.12, 1.1)), FRONT, UP, radius=0.06, value=0.75)
    texts.append(geo.text("O2", 0.11, dk["cream"], matrix=frame((-0.68, 0.124, 1.55), FRONT, lift=0.002)))
    _stripes(d, dk, Vector((0, 0.124, 0.34)), FRONT, 1.58, 0.06)
    low = m.to_object()
    collider = br._console_collider("rm_o2_rack", (1.6, 0.35, 1.6), (0, 0.05, 1.1))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


@asset("rm_bench", "rooms", texture=64, colors=24, ao=0.5)
def bench():
    """A steel bench for suiting up: perforated seat on two legs, a kick rail."""
    k = br._materials()
    dk = br._decals()
    m = Mesh("rm_bench")
    d = Mesh("rm_bench_decals")
    m.box((1.8, 0.42, 0.05), k["dark_steel"], at=(0, 0, 0.45), bevel=0.01)
    for x in (-0.75, 0.75):
        m.box((0.06, 0.36, 0.43), k["casing_dark"], at=(x, 0, 0.215), bevel=0.008)
    m.pipe([(-0.75, 0.0, 0.12), (0.75, 0.0, 0.12)], 0.02, k["steel"], sides=6)
    for i in range(16):
        for j in range(3):
            _plate(d, dk["black"], Vector((-0.8 + i * 0.107, -0.12 + j * 0.12, 0.475)), UP, 0.03, 0.03, up=(0, 1, 0))
    low = m.to_object()
    collider = br._console_collider("rm_bench", (1.8, 0.42, 0.47), (0, 0, 0.235))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


@asset("rm_cycle_panel", "rooms", texture=128, colors=32, ao=0.5)
def cycle_panel():
    """The airlock cycle panel (GDD §5, §11): wall-mounted beside the inner door. A pressure dial,
    PRESSURIZED / VACUUM lamps, a small readout CRT (`screen_airlock`) and the big striped CYCLE
    lever under a hinged guard. Reading this before opening a door is how crews stay alive."""
    k = br._materials()
    dk = br._decals()
    m = Mesh("rm_cycle_panel")
    d = Mesh("rm_cycle_panel_decals")
    texts = []
    m.box((0.52, 0.12, 0.86), k["casing"], at=(0, 0.06, 1.3), bevel=0.015)
    m.box((0.46, 0.02, 0.8), k["casing_dark"], at=(0, -0.005, 1.3), bevel=0.006)
    screen = br.crt(m, k, Vector((0, -0.04, 1.55)), 0.24, 0.18, tilt=0, depth=0.12, name="screen_airlock", bezel=0.025)
    br.dial(m, d, k, dk, Vector((-0.12, -0.015, 1.28)), FRONT, UP, radius=0.05, value=0.85)
    _plate(d, dk["green_lit"], Vector((0.12, -0.016, 1.33)), FRONT, 0.12, 0.035)
    _plate(d, dk["unlit"], Vector((0.12, -0.016, 1.27)), FRONT, 0.12, 0.035)
    texts.append(geo.text("PRESS", 0.018, dk["black"], matrix=frame((0.12, -0.016, 1.33), FRONT, lift=0.002)))
    texts.append(geo.text("VACUUM", 0.018, dk["black"], matrix=frame((0.12, -0.016, 1.27), FRONT, lift=0.002)))
    # The CYCLE lever: a striped plate, a red handle, a steel guard over it.
    _stripes(d, dk, Vector((0, -0.016, 1.04)), FRONT, 0.4, 0.2, pitch=0.08)
    m.box((0.06, 0.08, 0.18), k["dark_steel"], at=(0, -0.05, 1.04), bevel=0.008)
    m.box((0.2, 0.05, 0.04), br.mats.paint("rm_lever_red", (0.75, 0.12, 0.08), wear=0.5), at=(0, -0.1, 1.1), bevel=0.012)
    m.pipe([(-0.17, -0.02, 0.96), (-0.17, -0.14, 0.98), (0.17, -0.14, 0.98), (0.17, -0.02, 0.96)], 0.008, k["steel"], sides=5, caps=False)
    texts.append(geo.text("CYCLE", 0.025, dk["cream"], matrix=frame((0, -0.016, 1.18), FRONT, lift=0.002)))
    low = m.to_object()
    collider = br._console_collider("rm_cycle_panel", (0.52, 0.16, 0.86), (0, 0.04, 1.3))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[screen, collider])


# Drive room --------------------------------------------------------------------------------------


@asset("rm_drive_core", "rooms", texture=256, colors=32, ao=0.5)
def drive_core():
    """The JUMP DRIVE (GDD §5, §6): the drive room's hero machine, 2.3 m across and 2.9 m tall,
    floor to ceiling. A heavy plinth; a stack of copper-wound field coils banded in orange; between
    them, slit windows onto the radium-green core; fat feed pipes into the deck and the ceiling; a
    walkway ring around its base with hazard edging; JUMP DRIVE stencilled on the plinth."""
    k = br._materials()
    dk = br._decals()
    copper = mats.metal("rm_copper", (0.62, 0.36, 0.2), grime=0.45, brushed=False)
    core = mats.glowing("rm_core", (0.72, 1.0, 0.32), base=(0.2, 0.3, 0.1), flicker=0.35, streaks=0.6)
    m = Mesh("rm_drive_core")
    d = Mesh("rm_drive_core_decals")
    texts = []
    sides = 12
    m.lathe([(1.15, 0.0), (1.15, 0.22), (1.05, 0.3), (0.95, 0.3)], k["casing_dark"], sides=sides, cap_end=False)
    m.lathe([(0.95, 0.3), (0.95, 0.42), (0.85, 0.48)], k["casing"], sides=sides, cap_start=False, cap_end=False)
    # The core column, glowing, seen between the coils.
    m.cylinder(0.42, 2.3, core, sides=sides, at=(0, 0, 1.6))
    # Coils: copper-wound rings with orange retaining bands.
    for i in range(4):
        z = 0.65 + i * 0.52
        m.lathe([(0.48, z - 0.16), (0.78, z - 0.16), (0.82, z - 0.12), (0.82, z + 0.12), (0.78, z + 0.16), (0.48, z + 0.16)],
                copper, sides=sides, cap_start=False, cap_end=False)
        m.lathe([(0.835, z - 0.035), (0.835, z + 0.035)], k["orange"], sides=sides, cap_start=False, cap_end=False)
    # Struts between the coils, so the windows onto the core are slits.
    for j in range(6):
        a = j / 6 * math.tau
        m.box((0.12, 0.14, 2.1), k["dark_steel"], at=(math.cos(a) * 0.62, math.sin(a) * 0.62, 1.58), rot=(0, 0, math.degrees(a)), bevel=0.01)
    # Cap and feed pipes up into the ceiling and down into the deck.
    m.lathe([(0.85, 2.72), (0.95, 2.78), (0.95, 2.9)], k["casing_dark"], sides=sides, cap_end=False)
    for j in range(4):
        a = j / 4 * math.tau + math.pi / 4
        x, y = math.cos(a) * 0.7, math.sin(a) * 0.7
        m.pipe([(x, y, 2.82), (x * 1.1, y * 1.1, 3.0)], 0.07, k["steel"], sides=6, caps=False)
        m.pipe([(x * 1.45, y * 1.45, 0.0), (x * 1.45, y * 1.45, 0.25), (x * 1.25, y * 1.25, 0.36)], 0.06, k["steel"], sides=6)
    for j in range(sides):
        a = (j + 0.5) / sides * math.tau
        n = Vector((math.cos(a), math.sin(a), 0))
        hw = 1.15 * math.sin(math.pi / sides)
        _stripes(d, dk, n * 1.15 * math.cos(math.pi / sides) + Vector((0, 0, 0.11)), n, hw * 2, 0.16, pitch=0.12)
    front = Vector((0, -1, 0))
    texts.append(geo.text("JUMP DRIVE", 0.06, dk["cream"], matrix=frame(front * 0.95 * math.cos(math.pi / sides) + Vector((0, 0, 0.38)), front, lift=0.004)))
    m.subdivide(0.8)
    low = m.to_object()
    collider = br._console_collider("rm_drive_core", (2.0, 2.0, 2.9), (0, 0, 1.45))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


@asset("rm_fuel_rack", "rooms", texture=256, colors=32, ao=0.5)
def fuel_rack():
    """The fuel cell rack (GDD §5, §6): three armoured bays at hip height, each a cradle a fuel
    cell (fuel_cell) stands in, a clamp ring, a coupling socket, a status lamp and a bay number.
    Cells are carried here by hand and dropped in; the drive won't jump on an empty bay.
    Sockets `SOCKET_bay_1..3` mark where a loaded cell stands."""
    k = br._materials()
    dk = br._decals()
    m = Mesh("rm_fuel_rack")
    d = Mesh("rm_fuel_rack_decals")
    texts = []
    m.box((2.0, 0.7, 0.32), k["casing_dark"], at=(0, 0, 0.16), bevel=0.015)
    m.box((2.0, 0.2, 1.3), k["casing"], at=(0, 0.3, 0.97), bevel=0.015)
    sockets = []
    for i in range(3):
        x = -0.62 + i * 0.62
        # Cradle: a low octagonal cup, a clamp ring at mid-height on posts.
        m.lathe([(0.24, 0.32), (0.24, 0.42), (0.2, 0.44), (0.2, 0.36)], k["dark_steel"], sides=8,
                at=(x, -0.02, 0.0), angle_offset=math.pi / 8, cap_start=False, cap_end=False)
        m.lathe([(0.215, 0.66), (0.215, 0.72)], k["orange"], sides=8, at=(x, -0.02, 0.0), angle_offset=math.pi / 8,
                cap_start=False, cap_end=False)
        for px in (-0.22, 0.22):
            m.box((0.04, 0.04, 0.4), k["steel"], at=(x + px, -0.02, 0.52))
        # Coupling socket above the bay, where the cell's boss mates.
        m.cylinder(0.09, 0.12, k["dark_steel"], sides=8, at=(x, -0.02, 1.22))
        m.box((0.24, 0.24, 0.06), k["casing_dark"], at=(x, 0.1, 1.28), bevel=0.01)
        _plate(d, dk["amber_lit"], Vector((x, 0.199, 1.45)), FRONT, 0.06, 0.03)
        texts.append(geo.text(str(i + 1), 0.08, dk["cream"], matrix=frame((x, 0.199, 1.52), FRONT, lift=0.002)))
        sockets.append(_socket(f"bay_{i + 1}", (x, -0.02, 0.36)))
        _stripes(d, dk, Vector((x, -0.351, 0.16)), FRONT, 0.5, 0.18, pitch=0.1)
    texts.append(geo.text("FUEL CELLS", 0.05, dk["cream"], matrix=frame((0, 0.199, 1.48), FRONT, lift=0.002)
                          @ place((0, 0, 0.0))))
    low = m.to_object()
    collider = br._console_collider("rm_fuel_rack", (2.0, 0.7, 0.32), (0, 0, 0.16))
    back = br._console_collider("rm_fuel_rack_back", (2.0, 0.2, 1.3), (0, 0.3, 0.97))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider, back] + sockets)


def _socket(name, at):
    import bpy
    empty = bpy.data.objects.new(f"SOCKET_{name}", None)
    empty.location = at
    bpy.context.scene.collection.objects.link(empty)
    return empty


# Workshop ----------------------------------------------------------------------------------------


@asset("rm_recycler", "rooms", texture=256, colors=32, ao=0.5)
def recycler():
    """The recycler hopper (GDD §5, §13): salvage goes in the top and comes out as credit. A squat
    armoured machine with a wide intake chute under a hazard-striped lip, heavy crusher rollers seen
    through a grille, a mechanical counter readout (`screen_salvage`) and a feed lamp."""
    k = br._materials()
    dk = br._decals()
    m = Mesh("rm_recycler")
    d = Mesh("rm_recycler_decals")
    texts = []
    m.box((1.3, 1.0, 1.0), k["casing"], at=(0, 0.05, 0.5), bevel=0.02)
    m.box((1.34, 1.04, 0.12), k["casing_dark"], at=(0, 0.05, 0.06), bevel=0.01)
    # Intake: a funnel of sloped plates front and back, upright cheeks at the sides.
    for y, tilt in ((-0.38, 35), (0.48, -35)):
        m.box((1.2, 0.04, 0.5), k["dark_steel"], at=(0, y, 1.15), rot=(tilt, 0, 0), bevel=0.008)
    for x in (-0.6, 0.6):
        m.box((0.04, 0.9, 0.36), k["dark_steel"], at=(x, 0.05, 1.12), bevel=0.008)
    m.box((1.0, 0.6, 0.04), k["bezel"], at=(0, 0.05, 1.0))
    # Rollers inside the mouth.
    for x in (-0.18, 0.18):
        m.cylinder(0.14, 0.9, k["steel"], sides=8, at=(x, 0.05, 0.92), rot=(90, 0, 0))
    _stripes(d, dk, Vector((0, -0.452, 0.88)), FRONT, 1.28, 0.1, pitch=0.12)
    screen = br.crt(m, k, Vector((0.4, -0.5, 0.58)), 0.22, 0.12, tilt=0, depth=0.12, name="screen_salvage", bezel=0.025)
    _plate(d, dk["amber_lit"], Vector((-0.45, -0.451, 0.62)), FRONT, 0.06, 0.06)
    texts.append(geo.text("RECYCLER", 0.06, dk["black"], matrix=frame((-0.15, -0.451, 0.4), FRONT, lift=0.002)))
    texts.append(geo.text("SALVAGE IN", 0.025, dk["cream"], matrix=frame((0.4, -0.451, 0.43), FRONT, lift=0.002)))
    for i in range(6):
        _plate(d, dk["black"], Vector((-0.2 + i * 0.08, -0.451, 0.22)), FRONT, 0.04, 0.18)
    low = m.to_object()
    collider = br._console_collider("rm_recycler", (1.3, 1.0, 1.05), (0, 0.05, 0.52))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[screen, collider])


@asset("rm_fabricator", "rooms", texture=256, colors=32, ao=0.5)
def fabricator():
    """The fabricator (GDD §5, §13): a tall printer cabinet where salvage becomes tools, upgrades
    and the crew's precious energy cartridges. A big window onto the print chamber (a print bed and
    the gantry head over it, lit inside), its terminal (`screen_fab`) and keyboard, an output tray
    with a hazard lip."""
    k = br._materials()
    dk = br._decals()
    lamp = mats.glowing("rm_fab_light", (1.0, 0.85, 0.6), base=(0.6, 0.55, 0.45), flicker=0.05)
    m = Mesh("rm_fabricator")
    d = Mesh("rm_fabricator_decals")
    texts = []
    # The cabinet is a frame around the print chamber, so the window looks into real space.
    cx, cw, z0, z1 = -0.15, 1.0, 0.9, 1.8
    m.box((1.5, 0.9, z0), k["casing"], at=(0, 0.05, z0 / 2), bevel=0.02)
    m.box((1.5, 0.9, 2.1 - z1), k["casing"], at=(0, 0.05, (z1 + 2.1) / 2), bevel=0.02)
    m.box((cx - cw / 2 + 0.75, 0.9, z1 - z0), k["casing"], at=((-0.75 + cx - cw / 2) / 2, 0.05, (z0 + z1) / 2), bevel=0.02)
    m.box((0.75 - cx - cw / 2, 0.9, z1 - z0), k["casing"], at=((0.75 + cx + cw / 2) / 2, 0.05, (z0 + z1) / 2), bevel=0.02)
    m.box((cw, 0.1, z1 - z0), k["bezel"], at=(cx, 0.45, (z0 + z1) / 2))
    # Inside: a lit strip along the ceiling, the print bed, the gantry rail and its head.
    m.box((cw - 0.08, 0.6, 0.03), lamp, at=(cx, 0.1, z1 - 0.03))
    m.box((0.8, 0.5, 0.06), k["dark_steel"], at=(cx, 0.1, z0 + 0.06), bevel=0.008)
    m.box((cw - 0.04, 0.05, 0.05), k["steel"], at=(cx, 0.05, 1.55))
    m.box((0.12, 0.14, 0.16), k["orange"], at=(cx + 0.1, 0.05, 1.47), bevel=0.01)
    m.box((0.02, 0.02, 0.18), k["steel"], at=(cx + 0.1, 0.05, 1.3))
    m.box((0.18, 0.14, 0.06), k["casing_dark"], at=(cx - 0.12, 0.12, z0 + 0.12), bevel=0.006)
    glass = Mesh("glass")
    glass.box((0.94, 0.01, 0.84), mats.plain("lk_glass", (0.3, 0.4, 0.45)), at=(-0.15, -0.41, 1.35))
    glass_obj = glass.to_object()
    screen = br.crt(m, k, Vector((0.53, -0.44, 1.52)), 0.26, 0.2, tilt=8, depth=0.18, name="screen_fab", bezel=0.03)
    surface = (Vector((0.53, -0.47, 1.17)), Vector((0, -0.4, 0.92)).normalized(), Vector((0, 0.92, 0.4)).normalized())
    m.box((0.32, 0.2, 0.06), k["casing"], at=(0.53, -0.47, 1.14), bevel=0.01)
    br.buttons(d, dk, surface, (0, 0), 4, 2, pitch=0.05, pattern=(0, 2, 2, 1))
    # Output tray at the bottom front.
    m.box((1.0, 0.3, 0.25), k["casing_dark"], at=(-0.15, -0.48, 0.32), bevel=0.012)
    m.box((0.9, 0.24, 0.04), k["bezel"], at=(-0.15, -0.48, 0.43))
    _stripes(d, dk, Vector((-0.15, -0.631, 0.32)), FRONT, 0.98, 0.12, pitch=0.12)
    texts.append(geo.text("FABRICATOR", 0.09, dk["black"], matrix=frame((-0.15, -0.401, 1.95), FRONT, lift=0.002)))
    for i in range(8):
        _plate(d, dk["black"], Vector((0.62, -0.401, 0.5 + i * 0.05)), FRONT, 0.2, 0.015)
    low = m.to_object()
    collider = br._console_collider("rm_fabricator", (1.5, 0.95, 2.1), (0, 0.03, 1.05))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[screen, glass_obj, collider])


@asset("rm_workbench", "rooms", texture=128, colors=32, ao=0.5)
def workbench():
    """A workbench: a scarred steel top on a drawer cabinet and a leg, a bench vise, a pegboard
    back with tools hanging on it (wrench, hammer, cutters as painted silhouettes), a work lamp."""
    k = br._materials()
    dk = br._decals()
    lamp = mats.glowing("rm_bench_lamp", (1.0, 0.8, 0.5), base=(0.7, 0.6, 0.4))
    m = Mesh("rm_workbench")
    d = Mesh("rm_workbench_decals")
    m.box((2.0, 0.75, 0.06), k["dark_steel"], at=(0, 0, 0.9), bevel=0.01)
    m.box((0.6, 0.68, 0.86), k["casing"], at=(0.66, 0.0, 0.43), bevel=0.012)
    for i in range(4):
        faces = m.box((0.54, 0.02, 0.18), k["casing"], at=(0.66, -0.345, 0.12 + i * 0.205), bevel=0.006)
        _plate(d, dk["dark"], Vector((0.66, -0.356, 0.17 + i * 0.205)), FRONT, 0.12, 0.02)
    m.box((0.06, 0.6, 0.86), k["casing_dark"], at=(-0.95, 0.0, 0.43))
    m.box((2.0, 0.04, 1.0), k["casing_dark"], at=(0, 0.36, 1.43), bevel=0.008)
    # Pegboard holes and tool silhouettes.
    for i in range(18):
        for j in range(8):
            _plate(d, dk["black"], Vector((-0.92 + i * 0.108, 0.339, 1.0 + j * 0.11)), FRONT, 0.012, 0.012)
    pf = frame((-0.6, 0.338, 1.5), FRONT, lift=0.002)
    d.polygon([(-0.02, -0.3), (0.02, -0.3), (0.02, 0.18), (0.06, 0.24), (0.04, 0.3), (-0.04, 0.3), (-0.06, 0.24), (-0.02, 0.18)], dk["unlit"], pf)
    pf = frame((-0.3, 0.338, 1.5), FRONT, lift=0.002)
    d.polygon([(-0.015, -0.28), (0.015, -0.28), (0.015, 0.16), (0.09, 0.16), (0.09, 0.26), (-0.09, 0.26), (-0.09, 0.16), (-0.015, 0.16)], dk["red"], pf)
    pf = frame((0.05, 0.338, 1.5), FRONT, lift=0.002)
    d.polygon([(-0.05, -0.25), (-0.02, -0.25), (0.0, 0.05), (0.02, -0.25), (0.05, -0.25), (0.02, 0.2), (-0.02, 0.2)], dk["orange"], pf)
    # Bench vise.
    m.box((0.18, 0.2, 0.08), k["dark_steel"], at=(-0.6, -0.25, 0.97), bevel=0.01)
    m.box((0.16, 0.06, 0.12), k["dark_steel"], at=(-0.6, -0.38, 1.0), bevel=0.01)
    m.pipe([(-0.6, -0.45, 0.99), (-0.6, -0.55, 0.99)], 0.012, k["steel"], sides=5)
    m.pipe([(-0.68, -0.55, 0.99), (-0.52, -0.55, 0.99)], 0.008, k["steel"], sides=5)
    # Work lamp on an arm.
    m.pipe([(0.85, 0.3, 0.93), (0.85, 0.3, 1.6), (0.7, 0.05, 1.75)], 0.012, k["steel"], sides=5, caps=False)
    m.cylinder(0.08, 0.1, k["orange"], sides=8, at=(0.7, 0.03, 1.72), radius_top=0.04, rot=(180, 0, 0))
    m.cylinder(0.07, 0.01, lamp, sides=8, at=(0.7, 0.03, 1.665))
    low = m.to_object()
    collider = br._console_collider("rm_workbench", (2.0, 0.8, 0.95), (0, 0.0, 0.47))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


# Cabins ------------------------------------------------------------------------------------------


@asset("rm_bunk", "rooms", texture=128, colors=32, ao=0.5)
def bunk():
    """A crew bunk (GDD §5): a steel frame with a thin mattress, a rumpled blanket folded back, a
    pillow, a reading lamp clamped to the head, a storage drawer below. Someone sleeps here."""
    k = br._materials()
    dk = br._decals()
    blanket = mats.plain("rm_blanket", (0.32, 0.36, 0.3), grime=0.35, detail_strength=0.4)
    sheet = mats.plain("rm_sheet", (0.78, 0.76, 0.7), grime=0.4, detail_strength=0.3)
    lamp = mats.glowing("rm_reading_lamp", (1.0, 0.82, 0.55), base=(0.7, 0.6, 0.4))
    m = Mesh("rm_bunk")
    d = Mesh("rm_bunk_decals")
    m.box((2.05, 0.95, 0.1), k["casing_dark"], at=(0, 0, 0.42), bevel=0.012)
    m.box((2.0, 0.9, 0.36), k["casing"], at=(0, 0, 0.18), bevel=0.012)
    faces = m.box((1.0, 0.02, 0.22), k["casing"], at=(0.35, -0.45, 0.2), bevel=0.006)
    _plate(d, dk["dark"], Vector((0.35, -0.461, 0.26)), FRONT, 0.16, 0.025)
    m.box((1.95, 0.86, 0.1), sheet, at=(0, 0, 0.52), bevel=0.03)
    m.box((0.44, 0.62, 0.1), sheet, at=(-0.72, 0.0, 0.61), rot=(0, -4, 0), bevel=0.04)
    m.box((1.2, 0.9, 0.06), blanket, at=(0.35, 0.0, 0.59), bevel=0.02)
    m.box((0.3, 0.92, 0.08), blanket, at=(-0.18, 0.0, 0.62), rot=(0, 12, 0), bevel=0.03)
    for x in (-1.0, 1.0):
        m.box((0.06, 0.95, 0.5), k["casing_dark"], at=(x, 0, 0.55), bevel=0.01)
    m.pipe([(-0.98, 0.35, 0.8), (-0.85, 0.35, 1.05), (-0.7, 0.3, 1.1)], 0.01, k["steel"], sides=5, caps=False)
    m.cylinder(0.06, 0.07, k["orange"], sides=8, at=(-0.68, 0.3, 1.08), radius_top=0.035, rot=(180, 0, 0))
    m.cylinder(0.05, 0.01, lamp, sides=8, at=(-0.68, 0.3, 1.04))
    low = m.to_object()
    collider = br._console_collider("rm_bunk", (2.05, 0.95, 0.62), (0, 0, 0.31))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


@asset("rm_cabin_desk", "rooms", texture=128, colors=32, ao=0.5)
def cabin_desk():
    """A cabin's fold-down desk with its log terminal (`screen_log`): a compact CRT, a keyboard,
    a mug, a photo pinned to the wall panel above. Logs and the save point live here."""
    k = br._materials()
    dk = br._decals()
    mug = mats.plain("rm_mug", (0.75, 0.32, 0.18), grime=0.3)
    m = Mesh("rm_cabin_desk")
    d = Mesh("rm_cabin_desk_decals")
    texts = []
    m.box((1.1, 0.6, 0.05), k["casing"], at=(0, 0.0, 0.76), bevel=0.01)
    for x in (-0.5, 0.5):
        m.pipe([(x, 0.28, 0.74), (x, -0.05, 0.4), (x, 0.28, 0.4)], 0.012, k["steel"], sides=5, caps=False)
    m.box((1.1, 0.05, 0.8), k["casing_dark"], at=(0, 0.3, 1.2), bevel=0.008)
    screen = br.crt(m, k, Vector((0.12, 0.08, 1.02)), 0.28, 0.21, tilt=5, depth=0.26, name="screen_log", bezel=0.03)
    br.keyboard(m, d, k, dk, (Vector((0.08, -0.15, 0.785)), UP, Vector((0, 1, 0))), (0, 0), width=0.34, depth=0.12)
    m.cylinder(0.035, 0.09, mug, sides=8, at=(-0.38, -0.05, 0.83))
    m.pipe([(-0.345, -0.05, 0.86), (-0.31, -0.05, 0.84), (-0.345, -0.05, 0.81)], 0.008, mug, sides=4, caps=False)
    # A faded photo and a crew notice on the panel above.
    _plate(d, dk["cream"], Vector((-0.32, 0.274, 1.35)), FRONT, 0.14, 0.1)
    _plate(d, dk["dark"], Vector((-0.32, 0.274, 1.35)), FRONT, 0.11, 0.07, lift=0.0015)
    _plate(d, dk["cream"], Vector((0.4, 0.274, 1.42)), FRONT, 0.16, 0.2)
    for i in range(5):
        _plate(d, dk["dark"], Vector((0.4, 0.274, 1.48 - i * 0.03)), FRONT, 0.12, 0.008, lift=0.0015)
    low = m.to_object()
    collider = br._console_collider("rm_cabin_desk", (1.1, 0.6, 0.8), (0, 0.02, 0.4))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[screen, collider])


# Stores and med bay ------------------------------------------------------------------------------


@asset("rm_crate", "rooms", texture=128, colors=32, ao=0.5)
def crate():
    """A cargo crate, 0.8 m: ribbed steel with corner guards, a stencilled code and a hazard band
    on its lid. Used aboard and in derelicts."""
    k = br._materials()
    dk = br._decals()
    body = mats.paint("rm_crate", (0.42, 0.45, 0.36), wear=0.45, grime=0.45, under=(0.55, 0.55, 0.52))
    m = Mesh("rm_crate")
    d = Mesh("rm_crate_decals")
    texts = []
    s = 0.8
    m.box((s - 0.04, s - 0.04, s - 0.04), body, at=(0, 0, s / 2), bevel=0.01)
    for x in (-1, 1):
        for y in (-1, 1):
            m.box((0.08, 0.08, s), k["dark_steel"], at=(x * (s / 2 - 0.03), y * (s / 2 - 0.03), s / 2), bevel=0.008)
    for z in (0.18, 0.62):
        m.box((s + 0.005, s + 0.005, 0.05), k["dark_steel"], at=(0, 0, z), bevel=0.006)
    for normal in (Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0))):
        texts.append(geo.text("LTN 7", 0.07, dk["cream"], matrix=frame(normal * (s / 2 - 0.02) + Vector((0, 0, 0.4)), normal, lift=0.003)))
    _stripes(d, dk, Vector((0, 0, s - 0.02)), UP, 0.6, 0.12, up=(0, 1, 0), lift=0.002)
    low = m.to_object()
    collider = br._console_collider("rm_crate", (s, s, s), (0, 0, s / 2))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[collider])


@asset("rm_shelf", "rooms", texture=256, colors=32, ao=0.5)
def shelf():
    """Stores shelving (GDD §5): a steel rack of four shelves stocked with spares: O2 canisters,
    lamp cells in trays, sealant tubes, folded blankets, a labelled bin on each shelf."""
    k = br._materials()
    dk = br._decals()
    green = mats.paint("rm_o2_green", (0.18, 0.42, 0.26), wear=0.35, grime=0.35)
    bin_mat = mats.plain("rm_bin", (0.62, 0.48, 0.2), grime=0.35)
    blanket = mats.plain("rm_blanket", (0.32, 0.36, 0.3), grime=0.35, detail_strength=0.4)
    m = Mesh("rm_shelf")
    d = Mesh("rm_shelf_decals")
    for x in (-0.95, 0.95):
        for y in (-0.22, 0.22):
            m.box((0.04, 0.04, 2.0), k["dark_steel"], at=(x, y, 1.0))
    for i, z in enumerate((0.15, 0.65, 1.15, 1.65)):
        m.box((1.94, 0.48, 0.03), k["steel"], at=(0, 0, z), bevel=0.004)
        # Stock: a different load on each shelf.
        if i == 0:
            for j in range(4):
                m.cylinder(0.08, 0.42, green, sides=8, at=(-0.7 + j * 0.2, 0.0, 0.17 + 0.08), rot=(90, 0, 0))
            m.box((0.5, 0.4, 0.28), bin_mat, at=(0.55, 0.0, 0.31), bevel=0.01)
        elif i == 1:
            for j in range(3):
                m.box((0.3, 0.36, 0.1), k["casing_dark"], at=(-0.6 + j * 0.34, 0.0, 0.715), bevel=0.008)
            m.box((0.5, 0.4, 0.28), bin_mat, at=(0.55, 0.0, 0.81), bevel=0.01)
        elif i == 2:
            for j in range(3):
                m.box((0.42, 0.38, 0.1 - j * 0.0), blanket, at=(-0.5, 0.0, 1.21 + j * 0.1), rot=(0, 0, j * 3), bevel=0.02)
            for j in range(6):
                m.cylinder(0.03, 0.18, k["orange"], sides=6, at=(0.15 + j * 0.08, -0.05, 1.255))
        else:
            for j in range(3):
                m.box((0.5, 0.4, 0.3), bin_mat, at=(-0.6 + j * 0.6, 0.0, 1.815), bevel=0.01)
    for i, z in enumerate((0.31, 0.81, 1.81)):
        _plate(d, dk["cream"], Vector((0.55, -0.201, z)), FRONT, 0.2, 0.06)
    low = m.to_object()
    collider = br._console_collider("rm_shelf", (2.0, 0.5, 2.0), (0, 0, 1.0))
    return Model(low=low, decals=[d.to_object()], extras=[collider])


@asset("rm_med_pod", "rooms", texture=256, colors=32, ao=0.5)
def med_pod():
    """The med bay's pod (GDD §5, §11): a horizontal capsule on a plinth where the dead are brought
    back, offline until it's upgraded. A tinted glass canopy over a padded bed, a side console with
    its own screen (`screen_med`), feed tubes into the floor, a red OFFLINE lamp."""
    k = br._materials()
    dk = br._decals()
    pad = mats.plain("rm_med_pad", (0.7, 0.75, 0.72), grime=0.35)
    m = Mesh("rm_med_pod")
    d = Mesh("rm_med_pod_decals")
    texts = []
    m.box((2.3, 1.0, 0.5), k["casing"], at=(0, 0, 0.25), bevel=0.03)
    m.box((2.4, 1.1, 0.08), k["casing_dark"], at=(0, 0, 0.04), bevel=0.01)
    m.box((2.1, 0.8, 0.12), pad, at=(0, 0, 0.56), bevel=0.04)
    # Canopy frame: ribs over the bed; the glass between them is a separate mesh.
    for x in (-1.05, -0.35, 0.35, 1.05):
        m.pipe([(x, -0.44, 0.52), (x, -0.4, 0.86), (x, 0.0, 1.0), (x, 0.4, 0.86), (x, 0.44, 0.52)], 0.03, k["dark_steel"], sides=5, caps=False)
    m.pipe([(-1.1, 0.0, 1.0), (1.1, 0.0, 1.0)], 0.03, k["dark_steel"], sides=6)
    glass = Mesh("glass")
    gl = mats.plain("lk_glass", (0.3, 0.4, 0.45))
    glass.prism([(-0.44, 0.52), (-0.4, 0.86), (0.0, 1.0), (0.4, 0.86), (0.44, 0.52), (0.42, 0.52), (0.38, 0.84), (0.0, 0.98),
                 (-0.38, 0.84), (-0.42, 0.52)], 2.1, gl, rot=(0, 0, 90))
    glass_obj = glass.to_object()
    screen = br.crt(m, k, Vector((1.35, -0.3, 1.0)), 0.24, 0.18, tilt=10, depth=0.2, name="screen_med", bezel=0.03)
    m.box((0.36, 0.3, 0.9), k["casing"], at=(1.35, -0.2, 0.45), bevel=0.015)
    for i in range(3):
        m.pipe([(-1.15, 0.2 - i * 0.2, 0.35), (-1.35, 0.25 - i * 0.2, 0.2), (-1.4, 0.3 - i * 0.2, 0.0)], 0.03,
               k["cable_red"] if i == 1 else k["cable"], sides=5)
    _plate(d, dk["red_lit"], Vector((1.35, -0.351, 0.75)), FRONT, 0.1, 0.04)
    texts.append(geo.text("OFFLINE", 0.03, dk["red"], matrix=frame((1.35, -0.351, 0.68), FRONT, lift=0.002)))
    texts.append(geo.text("MED POD", 0.07, dk["black"], matrix=frame((-0.4, -0.501, 0.28), FRONT, lift=0.002)))
    _stripes(d, dk, Vector((0, -0.501, 0.08)), FRONT, 2.3, 0.08)
    low = m.to_object()
    collider = br._console_collider("rm_med_pod", (2.4, 1.1, 1.0), (0.1, 0, 0.5))
    return Model(low=low, decals=[d.to_object()] + texts, extras=[screen, glass_obj, collider])
