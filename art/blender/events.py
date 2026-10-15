"""What taking a derelict's Prize can set off (GDD §8.3): a security system's ceiling sentries and
the alarm beacons over its locked-down doors; the outer wall a depressurization blows out; the heap
a structural breach brings down against a door; the nest an infestation bursts from.
"""

import math

from mathutils import Euler, Vector

import bridge as br
import station_kit as kit
from derelict import FRONT, _socket
from lib import Model, asset, geo, mats
from lib.geo import Mesh, frame

## The sentry's pivots, model space: it turns about Z through the origin, its head pitches about X
## through SENTRY_PITCH.
SENTRY_PITCH = (0.0, 0.0, -0.44)


@asset("dk_sentry", "derelict", texture=128, colors=32, ao=0.5, angles=((-35, -25), (145, -20), (90, -5), (-20, -60)))
def sentry():
    """A security sentry (GDD §8.3): a ceiling turret an earlier wave's security wakes when its Prize
    is taken. Folded flat against the ceiling till then, its head swings down, turns to whoever it
    sees, paints them with its sight and fires bursts.

    Purpose: the security event's teeth, in the Prize's section: crew get out of its sight, run, or
    knock it out (a crowbar's blows, a prod's jolt).
    Size: hangs 0.62 m from the ceiling (z = 0, hanging down), a 0.46 m mounting plate; its head
    0.24 x 0.36 x 0.2 m.
    Silhouette: a round ceiling plate, a drum housing, a yoke, a blunt head with twin barrels out
    of its front and a single red eye between them.
    Parts (split after baking): `dk_sentry` the mount (plate and drum), fixed; `sentry_yaw` the
    collar and yoke, turning about Z through the origin; `sentry_head` the head and barrels,
    pitching about X through SOCKET_pitch. Its eye is a separate mesh (`sentry_eye`, under the
    head) Godot lights red. SOCKET_muzzle at the barrels' tips.
    Palette: the derelict kit's dark casing, an orange-and-black hazard ring, gunmetal barrels.
    """
    c = br._materials()
    dk = br._decals()
    gun = mats.metal("dk_gunmetal", (0.18, 0.19, 0.2), grime=0.45, detail="Metal009")
    m = Mesh("dk_sentry")
    d = Mesh("dk_sentry_decals")
    texts = []
    px, py, pz = SENTRY_PITCH
    # The mount: a round plate on the ceiling, its hazard ring, bolts; the drum the yoke turns in.
    m.cylinder(0.23, 0.04, c["casing_dark"], sides=12, at=(0, 0, -0.02))
    m.cylinder(0.25, 0.012, c["orange"], sides=12, at=(0, 0, -0.046))
    for i in range(6):
        a = i / 6 * math.tau
        m.cylinder(0.014, 0.012, c["steel"], sides=6, at=(math.cos(a) * 0.205, math.sin(a) * 0.205, -0.046))
    m.cylinder(0.11, 0.15, c["casing"], sides=10, at=(0, 0, -0.125))
    m.cylinder(0.12, 0.02, c["dark_steel"], sides=10, at=(0, 0, -0.19))
    m.pipe([(0.08, 0.06, -0.08), (0.17, 0.12, -0.05), (0.2, 0.15, -0.002)], 0.016, c["cable"], sides=5)
    # The yoke: a collar under the drum, two arms down either side of the head, hubs at the pivot.
    m.cylinder(0.1, 0.06, c["dark_steel"], sides=10, at=(0, 0, -0.23))
    m.box((0.36, 0.08, 0.04), c["dark_steel"], at=(0, 0, -0.27), bevel=0.008)
    for side in (-1, 1):
        m.box((0.035, 0.08, 0.22), c["casing_dark"], at=(side * 0.16, 0, -0.36), bevel=0.008)
        m.cylinder(0.045, 0.03, c["steel"], sides=8, at=(side * 0.155, 0, pz), rot=(0, 90, 0))
    # The head: a blunt body, a sloped brow, vents along its flanks, twin barrels with shrouds out
    # of its front (-Y), the eye's bezel between them.
    m.box((0.24, 0.3, 0.17), c["casing"], at=(0, 0.02, pz), bevel=0.02)
    m.prism([(-0.12, 0.0), (0.12, 0.0), (0.1, 0.05), (-0.1, 0.05)], 0.22, c["casing_dark"], at=(0, -0.01, pz + 0.085),
            rot=(0, 0, 0))
    m.box((0.2, 0.06, 0.12), c["dark_steel"], at=(0, -0.15, pz), bevel=0.012)
    for x in (-0.06, 0.06):
        m.cylinder(0.026, 0.12, gun, sides=8, at=(x, -0.22, pz - 0.015), rot=(90, 0, 0))
        m.cylinder(0.016, 0.1, gun, sides=6, at=(x, -0.32, pz - 0.015), rot=(90, 0, 0))
        m.cylinder(0.02, 0.025, c["dark_steel"], sides=6, at=(x, -0.37, pz - 0.015), rot=(90, 0, 0))
    m.cylinder(0.03, 0.02, c["bezel"], sides=8, at=(0, -0.185, pz + 0.035), rot=(90, 0, 0))
    for i in range(4):
        for side in (-1, 1):
            d.polygon([(-0.03, -0.006), (0.03, -0.006), (0.03, 0.006), (-0.03, 0.006)], dk["black"],
                      frame((side * 0.121, 0.03, pz - 0.03 + i * 0.02), Vector((side, 0, 0)), lift=0.001))
    texts.append(geo.text("SEC", 0.03, dk["cream"], matrix=frame((0.0, 0.171, pz), Vector((0, 1, 0)), lift=0.002)))
    # Hazard stripes round the plate's rim.
    for i in range(12):
        a = i / 12 * math.tau
        d.polygon([(-0.02, -0.006), (0.02, -0.006), (0.0, 0.006), (-0.035, 0.006)], dk["black"],
                  frame((math.cos(a) * 0.24, math.sin(a) * 0.24, -0.053), Vector((0, 0, -1)), lift=0.001))
    low = m.to_object()
    eye = Mesh("sentry_eye")
    eye.cylinder(0.02, 0.02, mats.plain("lk_lamp", (0.9, 0.15, 0.1)), sides=8, at=(0, -0.198, pz + 0.035), rot=(90, 0, 0))
    eye_object = eye.to_object()

    def split(model):
        def in_head(p):
            return abs(p.x) < 0.135 and p.z < -0.31
        def in_yaw(p):
            return p.z < -0.2 and not in_head(p)
        parts = geo.split_object(model.low, {"dk_sentry": lambda p: p.z >= -0.2, "sentry_yaw": in_yaw, "sentry_head": in_head})
        model.low = parts[0]
        model.extras.extend(parts[1:])

    sockets = [_socket("pitch", SENTRY_PITCH), _socket("muzzle", (0.0, -0.385, pz - 0.015))]
    return Model(low=low, decals=[d.to_object()] + texts, extras=[eye_object] + sockets, after_bake=split)


@asset("dk_beacon", "derelict", texture=64, colors=16, ao=0.5)
def beacon():
    """An alarm beacon (GDD §8.3): a red dome on a bracket over a door, dead till a security system
    wakes; then it turns, throwing its light round the walls. Wall-mounted (the wall at +Y), its
    dome a separate mesh (`beacon_lens`) Godot lights."""
    c = br._materials()
    m = Mesh("dk_beacon")
    m.box((0.2, 0.03, 0.12), c["casing_dark"], at=(0, -0.015, 0), bevel=0.006)
    m.box((0.12, 0.12, 0.03), c["dark_steel"], at=(0, -0.08, -0.03), bevel=0.006)
    m.cylinder(0.06, 0.03, c["orange"], sides=10, at=(0, -0.09, 0.0))
    for i in range(4):
        a = i / 4 * math.tau + math.pi / 4
        m.pipe([(math.cos(a) * 0.062, -0.09 + math.sin(a) * 0.062, 0.012), (math.cos(a) * 0.062, -0.09 + math.sin(a) * 0.062, 0.1),
                (0, -0.09, 0.13)], 0.005, c["steel"], sides=4)
    for x in (-0.07, 0.07):
        m.cylinder(0.01, 0.01, c["steel"], sides=6, at=(x, -0.032, 0.0), rot=(90, 0, 0))
    low = m.to_object()
    lens = Mesh("beacon_lens")
    lens.lathe([(0.05, 0.0), (0.05, 0.05), (0.035, 0.1), (0.0, 0.115)], mats.plain("lk_lamp", (0.9, 0.15, 0.1)), sides=10,
               at=(0, -0.09, 0.015))
    return Model(low=low, decals=[], extras=[lens.to_object()])


## The blowout's hole in the wall: its sides and its sill and head, model space.
HOLE = (-1.0, 1.0, 0.42, 2.25)


@asset("dk_wall_blowout", "derelict", texture=256, colors=32, ao=0.55)
def wall_blowout():
    """A derelict's outer wall blown out (GDD §8.3: depressurization): what's left of the wall
    round a ragged hole through to space, the hull plating peeled out from it in petals, cables
    and a duct dragged out after the air. The room's face is -Y; space is beyond +Y (Godot frees
    the hull plating behind it). Only the wall round the hole is solid."""
    kit.STYLE["name"] = "derelict"
    try:
        k = kit._materials()
        dm = kit._decal_materials()
        hull = mats.paint("dk_hull_skin", (0.32, 0.31, 0.3), wear=0.6, grime=0.6, rust=0.5, under=(0.22, 0.2, 0.18))
        burn = mats.plain("dk_scorch", (0.06, 0.05, 0.05), grime=0.2)
        m = Mesh("dk_wall_blowout")
        d = Mesh("dk_wall_blowout_decals")
        kit.geo_text.clear()
        x0, x1, z0, z1 = HOLE
        w, h, t = kit.WIDTH, kit.HEIGHT, kit.THICK
        # The wall's core round the hole: either side, under it, over it.
        m.box((w / 2 + x0, t, h), k["backing"], at=((-w / 2 + x0) / 2, 0, h / 2))
        m.box((w / 2 - x1, t, h), k["backing"], at=((w / 2 + x1) / 2, 0, h / 2))
        m.box((x1 - x0, t, z0), k["backing"], at=(0, 0, z0 / 2))
        m.box((x1 - x0, t, h - z1), k["backing"], at=(0, 0, (z1 + h) / 2))
        # The room's face either side of the hole, intact; under and over it, what's left.
        kit._wall_side(m, k, -w / 2, x0, -1, rail=False)
        kit._wall_side(m, k, x1, w / 2, -1, rail=False)
        kit._chamfer(m, k, -w / 2, w / 2, -1)
        y = -kit.HALF
        m.box((x1 - x0, 0.04, 0.32), k["kick"], at=(0, y - 0.02, 0.16), bevel=0.008)
        m.box((x1 - x0, 0.035, 0.07), k["trim"], at=(0, y - 0.0175, kit.CHAMFER_START - 0.035), bevel=0.006)
        m.box((x1 - x0, 0.025, kit.CHAMFER_START - 0.07 - z1), k["panel"], at=(0, y - 0.0125, (z1 + kit.CHAMFER_START - 0.07) / 2),
              bevel=0.006)
        kit._wall_decals(d, dm, -w / 2, x0, -1)
        kit._wall_decals(d, dm, x1, w / 2, -1, markings=False)
        # Shards of the wall's skin round the hole's edge, torn and bent out the way the air went:
        # slivers along the edges, and big jagged plates across the corners so it isn't square.
        rim = []
        for i in range(9):
            u = (i + 0.5) / 9
            rim.append(((x0 + (x1 - x0) * u, z0), (0, 1)))
            rim.append(((x0 + (x1 - x0) * u, z1), (0, -1)))
        for i in range(7):
            v = (i + 0.5) / 7
            rim.append(((x0, z0 + (z1 - z0) * v), (1, 0)))
            rim.append(((x1, z0 + (z1 - z0) * v), (-1, 0)))
        shard_mats = (k["chamfer"], k["frame"], k["chamfer"], k["backing"])
        for i, ((rx, rz), (nx, nz)) in enumerate(rim):
            size = 0.14 + (i * 37 % 7) * 0.035
            lean = 20 + (i * 13 % 5) * 12
            yaw = math.degrees(math.atan2(nx, nz))
            skew = ((i * 7) % 3 - 1) * 0.35
            face = -kit.HALF + 0.02 if i % 2 else kit.HALF - 0.02
            m.prism([(-size * 0.35, 0.0), (size * 0.35, 0.0), (size * skew, size)], 0.02, shard_mats[i % 4],
                    at=(rx, face, rz), rot=(-lean, yaw, 0))
        for (cx, cz), (nx, nz) in (((x0, z0), (1, 1)), ((x1, z0), (-1, 1)), ((x0, z1), (1, -1)), ((x1, z1), (-1, -1))):
            yaw = math.degrees(math.atan2(nx, nz))
            m.prism([(-0.45, 0.0), (0.4, 0.0), (0.12, 0.48), (-0.05, 0.62)], 0.025, k["chamfer"],
                    at=(cx, -kit.HALF + 0.015, cz), rot=(-18, yaw, 0))
            m.prism([(-0.35, 0.0), (0.3, 0.0), (-0.1, 0.5)], 0.025, k["frame"], at=(cx, kit.HALF - 0.015, cz), rot=(-40, yaw, 0))
        # The hull peeled out beyond: petals of skin and frame hinged at the hole's edge.
        petals = [((x0, z1), (-1, 1), 0.9), ((0.0, z1), (0, 1), 1.0), ((x1, z1), (1, 1), 0.85), ((x1, (z0 + z1) / 2), (1, 0), 1.0),
                  ((x1, z0), (1, -1), 0.7), ((0.0, z0), (0, -1), 0.8), ((x0, z0), (-1, -1), 0.75), ((x0, (z0 + z1) / 2), (-1, 0), 0.95)]
        for i, ((px, pz), (nx, nz), size) in enumerate(petals):
            out = Vector((nx, 0, nz)).normalized()
            lean = 55 + i * 9 % 25
            hinge = Vector((px, t / 2, pz))
            yaw = math.degrees(math.atan2(out.x, out.z))
            turn = Euler((math.radians(-lean), math.radians(yaw), 0.0)).to_matrix()
            m.prism([(-size * 0.45, 0.0), (size * 0.45, 0.0), (size * 0.25, size * 0.8), (-size * 0.1, size * 0.95)], 0.03,
                    hull if i % 2 else k["chamfer"], at=tuple(hinge), rot=(-lean, yaw, 0))
            # Scorched along its inner face, where the blast went past.
            m.box((0.08, 0.012, size * 0.6), burn, at=tuple(hinge + turn @ Vector((0.0, -0.02, size * 0.4))), rot=(-lean, yaw, 0))
        # Dragged out after the air: a cable loom and a duct, through the hole into space.
        for i, (cx, col) in enumerate(((-0.4, "cable"), (-0.25, "cable_red"), (0.3, "cable"))):
            br_m = br._materials()
            m.pipe([(cx, -0.1, z1 + 0.15), (cx * 0.8, 0.2, z1 - 0.3), (cx * 0.6 + 0.1 * i, 0.9, z1 - 0.6 - 0.1 * i),
                    (cx * 0.4 + 0.2 * i, 1.6, z1 - 0.3 - 0.2 * i)], 0.02, br_m[col], sides=4)
        m.box((0.3, 0.9, 0.22), k["vent"], at=(0.55, 0.55, z0 + 0.2), rot=(12, 0, -20), bevel=0.01)
        low = m.to_object()
        decals = [d.to_object()] + kit.geo_text
        kit.geo_text.clear()
        colliders = [kit._collider("dk_wall_blowout_col_l", (w / 2 + x0, t, h), ((-w / 2 + x0) / 2, 0, h / 2)),
                     kit._collider("dk_wall_blowout_col_r", (w / 2 - x1, t, h), ((w / 2 + x1) / 2, 0, h / 2)),
                     kit._collider("dk_wall_blowout_col_b", (x1 - x0, t, z0), (0, 0, z0 / 2)),
                     kit._collider("dk_wall_blowout_col_t", (x1 - x0, t, h - z1), (0, 0, (z1 + h) / 2))]
        return Model(low=low, decals=decals, extras=colliders)
    finally:
        kit.STYLE["name"] = "station"


## Where a nest's sac sits, and how big it is: its middle on the floor, radius and height.
NEST_SAC = (0.32, 0.8)


@asset("dk_nest", "derelict", texture=128, colors=32, ao=0.6, angles=((-35, 30), (145, 35), (90, 10), (-20, 65)))
def nest():
    """A nest (GDD §8.3: infestation): a mound of growth where something has curled up to wait,
    sealed in a tall veined sac that glows from inside, a crater in the mound round it. Quiet until
    the Prize is taken; then the sac swells, splits, and a Crawler comes out of it.
    Parts: the sac (`nest_sac`) is split off after baking, for Godot to pulse and burst.
    About 1.7 m across; the sac 0.64 m wide, 0.8 m tall."""
    k = dict(
        flesh=mats.plain("cr_flesh", (0.6, 0.48, 0.46), grime=0.5, variation=0.12, detail="PaintedMetal013", detail_strength=0.25),
        wet=mats.paint("cr_wet", (0.45, 0.2, 0.2), wear=0.0, grime=0.3, variation=0.15),
        bone=mats.plain("cr_bone", (0.86, 0.82, 0.72), grime=0.4, variation=0.06),
        sac=mats.glowing("cr_sac", (0.35, 0.9, 1.0), base=(0.15, 0.3, 0.35), flicker=0.4),
        skin=mats.plain("cr_sac_skin", (0.7, 0.62, 0.55), grime=0.35, variation=0.2, detail="PaintedMetal013", detail_strength=0.3),
    )
    r, tall = NEST_SAC
    m = Mesh("dk_nest")
    # The mound: lobes round a crater, low enough to stay under the sac's foot.
    for i in range(7):
        a = i / 7 * math.tau + 0.3
        far = 0.5 + (i % 3) * 0.08
        m.lathe([(0.3, 0.0), (0.27, 0.08), (0.16, 0.15), (0.0, 0.17)], k["flesh"] if i % 2 else k["wet"], sides=7,
                at=(math.cos(a) * far, math.sin(a) * far, 0), scale=(1.0, 0.8, 1.0))
    m.lathe([(r + 0.1, 0.0), (r + 0.06, 0.12), (r + 0.01, 0.16), (r - 0.01, 0.1)], k["wet"], sides=10, cap_start=False, cap_end=False)
    # Ribs of bone curling up out of it round the sac, and veins out across the deck.
    for i in range(5):
        a = i / 5 * math.tau + 0.6
        m.pipe([(math.cos(a) * 0.42, math.sin(a) * 0.42, 0.1), (math.cos(a) * 0.48, math.sin(a) * 0.48, 0.35),
                (math.cos(a + 0.15) * 0.42, math.sin(a + 0.15) * 0.42, 0.55)], 0.022, k["bone"], sides=4)
    for i in range(9):
        a = i / 9 * math.tau
        m.pipe([(math.cos(a) * 0.65, math.sin(a) * 0.55, 0.03), (math.cos(a + 0.2) * 1.0, math.sin(a + 0.2) * 0.85, 0.012),
                (math.cos(a + 0.1) * 1.45, math.sin(a + 0.1) * 1.25, 0.005)], 0.016, k["wet"], sides=3)
    for i in range(5):
        a = i / 5 * math.tau + 1.1
        m.lathe([(0.0, 0.0), (0.04, 0.02), (0.045, 0.06), (0.0, 0.09)], k["sac"], sides=5,
                at=(math.cos(a) * 0.62, math.sin(a) * 0.5, 0.1))
    # The sac: a tall ovoid of skin, glowing seams down it.
    m.lathe([(r * 0.7, 0.16), (r * 0.95, 0.3), (r, 0.45), (r * 0.9, 0.62), (r * 0.6, 0.74), (r * 0.2, tall), (0.0, tall + 0.01)],
            k["skin"], sides=9)
    for i in range(6):
        a = i / 6 * math.tau
        m.pipe([(math.cos(a) * r * 0.82, math.sin(a) * r * 0.82, 0.24), (math.cos(a + 0.1) * r * 1.02, math.sin(a + 0.1) * r * 1.02, 0.45),
                (math.cos(a + 0.2) * r * 0.66, math.sin(a + 0.2) * r * 0.66, 0.72)], 0.014, k["sac"], sides=3)
    low = m.to_object()

    def split(model):
        def in_sac(p):
            return Vector((p.x, p.y)).length < r * 1.12 and p.z > 0.17
        base, sac = geo.split_object(model.low, {"dk_nest": lambda p: not in_sac(p), "nest_sac": in_sac})
        model.low = base
        model.extras.append(sac)

    return Model(low=low, decals=[], extras=[], after_bake=split)


@asset("dk_heap", "derelict", texture=256, colors=32, ao=0.6, angles=((-35, 30), (145, 30), (90, 10), (-20, 60)))
def heap():
    """A heap of fallen ceiling against a door (GDD §8.3: structural breach): a slab of ceiling
    plate leaning on the door (at -Y), a bent beam across it, a light fitting and duct torn down
    with it, chunks piled at its foot, cables hanging over it. 2.4 m wide, 2.3 m tall at the door,
    1.5 m out from it (its origin 0.75 m out). Solid: there's no getting past."""
    kit.STYLE["name"] = "derelict"
    try:
        k = kit._materials()
    finally:
        kit.STYLE["name"] = "station"
    c = br._materials()
    m = Mesh("dk_heap")
    # The slab: two ceiling plates leaning on the door, cracked apart.
    m.box((1.25, 0.08, 2.4), k["chamfer"], at=(-0.55, -0.2, 1.05), rot=(-28, 4, -6), bevel=0.01)
    m.box((1.15, 0.08, 2.2), k["panel"], at=(0.6, -0.15, 0.95), rot=(-33, -5, 8), bevel=0.01)
    # A beam bent across it.
    m.pipe([(-1.25, 0.15, 0.25), (-0.3, -0.25, 1.35), (0.45, -0.45, 1.85), (1.2, -0.62, 2.25)], 0.07, k["steel"], sides=4)
    m.box((0.5, 0.2, 0.2), k["steel"], at=(-1.1, 0.25, 0.12), rot=(0, 0, 30), bevel=0.015)
    # Chunks and fragments piled at its foot, a light fitting in among them.
    for i, (x, y, sx, sy, sz, a) in enumerate(((-0.9, 0.45, 0.6, 0.4, 0.35, 20), (-0.2, 0.55, 0.5, 0.35, 0.28, -15),
                                               (0.5, 0.5, 0.55, 0.45, 0.4, 35), (1.0, 0.3, 0.4, 0.4, 0.5, -25),
                                               (0.1, 0.0, 0.7, 0.4, 0.55, 10), (-0.6, 0.05, 0.5, 0.5, 0.6, -5))):
            m.box((sx, sy, sz), k["chamfer"] if i % 2 else k["frame"], at=(x, y, sz / 2), rot=(i * 7 % 15, -(i * 11 % 20), a), bevel=0.02)
    m.box((1.1, 0.3, 0.12), c["casing_dark"], at=(0.2, 0.7, 0.62), rot=(18, -12, 24), bevel=0.01)
    m.box((1.0, 0.2, 0.02), mats.plain("dk_diffuser_cracked", (0.55, 0.6, 0.62), grime=0.4), at=(0.2, 0.7, 0.55),
          rot=(18, -12, 24))
    m.box((0.35, 1.1, 0.3), k["vent"], at=(-1.05, -0.1, 1.3), rot=(20, 0, -50), bevel=0.01)
    for i in range(6):
        sx = -0.8 + i * 0.3
        m.box((0.18, 0.12, 0.02), k["panel"], at=(sx, 0.9 + (i % 2) * 0.12, 0.02), rot=(3, -2, i * 33), bevel=0.004)
    # Cables over it, down from where the ceiling was.
    for i, (x, col) in enumerate(((-0.7, "cable"), (-0.1, "cable_red"), (0.4, "cable"), (0.9, "cable"))):
        m.pipe([(x, -0.75, 2.95), (x + 0.05, -0.4, 2.3 - i * 0.08), (x - 0.05, 0.05, 1.5 - i * 0.1), (x + 0.1, 0.4, 0.9 - i * 0.1)],
               0.016, c[col], sides=4)
    low = m.to_object()
    collider = kit._collider("dk_heap_col", (2.5, 1.5, 2.3), (0, 0.0, 1.15))
    return Model(low=low, decals=[], extras=[collider])
