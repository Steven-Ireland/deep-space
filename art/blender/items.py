"""Items the crew carries (GDD §13): tools, pickups and resources."""

import math

import bpy
from mathutils import Vector

from lib import Model, asset, geo, mats
from lib.geo import Mesh, clip, frame


def _socket(name, at):
    empty = bpy.data.objects.new(f"SOCKET_{name}", None)
    empty.location = at
    empty.empty_display_size = 0.03
    bpy.context.scene.collection.objects.link(empty)
    return empty


@asset("fuel_cell", "items", texture=256, colors=32, roughness=0.7, specular=0.4)
def fuel_cell():
    """WARP FUEL CELL, CLASS IV.

    Purpose: the run's lifeblood (GDD §6, §13). One cell per jump; carried two-handed to the Drive
    Room and slotted in. It must read instantly in a dark derelict as precious and dangerous.
    Size: 0.78 m tall, 0.30 m octagonal body, 0.36 m bumper caps; about 30 kg in the fiction.
    Silhouette: a stout octagonal canister between chunky chamfered bumper caps, a coupling boss
    on top, two vertical grab handles on its flanks.
    Details: glowing radium-green fuel visible through recessed windows front and back, a
    segmented charge gauge beside the front window, hazard banding on the caps, a cream FUEL
    plate, a warning diamond, a pressure dial on the top cap.
    Palette: gunmetal body, safety-orange caps (heavily chipped), bare steel handles with black
    rubber grips, radium green-yellow glow.
    """
    body = mats.paint("fc_body", (0.25, 0.28, 0.3), wear=0.45, grime=0.45, under=(0.58, 0.58, 0.55), streaks=0.35)
    cap = mats.paint("fc_cap", (0.86, 0.4, 0.08), wear=0.55, grime=0.4, under=(0.45, 0.44, 0.42))
    steel = mats.metal("fc_steel", (0.56, 0.56, 0.54), grime=0.35)
    dark_steel = mats.metal("fc_dark_steel", (0.3, 0.31, 0.32), grime=0.5)
    rubber = mats.plain("fc_rubber", (0.07, 0.07, 0.075), grime=0.2)
    fuel = mats.glowing("fc_fuel", (0.72, 1.0, 0.32), base=(0.2, 0.3, 0.1), flicker=0.3, streaks=0.8)
    dial_face = mats.plain("fc_dial", (0.86, 0.83, 0.72), grime=0.3)

    m = Mesh("fuel_cell")
    octagon = math.pi / 8  # flat faces toward +-X and +-Y
    # Bumper caps: chamfered octagonal rings, the bottom one mirrored to the top.
    cap_profile = [(0.135, 0.0), (0.172, 0.008), (0.18, 0.026), (0.18, 0.098), (0.168, 0.112), (0.152, 0.12)]
    m.lathe(cap_profile, cap, sides=8, angle_offset=octagon, cap_end=False)
    m.lathe([(r, 0.78 - z) for r, z in reversed(cap_profile)], cap, sides=8, angle_offset=octagon, cap_start=False)
    # Body, with a slight waist so it doesn't read as a plain tube.
    body_faces = m.lathe([(0.152, 0.12), (0.15, 0.2), (0.148, 0.39), (0.15, 0.58), (0.152, 0.66)], body,
                         sides=8, angle_offset=octagon, cap_start=False, cap_end=False)
    # Fuel windows: the front and back faces of the middle bands, recessed, glowing.
    for normal in ((0, -1, 0), (0, 1, 0)):
        window = m.faces(among=body_faces, normal=normal, min_dot=0.95,
                         where=lambda c: 0.2 < c.z < 0.58)
        m.inset(window, thickness=0.024, depth=0.016, material=fuel, individual=False)
    # Steel straps hooping the body above and below the windows.
    strap = [(0.149, 0.0), (0.157, 0.004), (0.157, 0.03), (0.149, 0.034)]
    for z in (0.152, 0.594):
        m.lathe([(r, z + dz) for r, dz in strap], dark_steel, sides=8, angle_offset=octagon,
                cap_start=False, cap_end=False)
    # Coupling boss on top: a steel neck, a dark collar, a flat contact face.
    m.cylinder(0.065, 0.03, dark_steel, sides=8, at=(0, 0, 0.795), rot=(0, 0, 22.5))
    m.cylinder(0.055, 0.04, steel, sides=8, at=(0, 0, 0.83), rot=(0, 0, 22.5))
    m.cylinder(0.062, 0.012, cap, sides=8, at=(0, 0, 0.845), rot=(0, 0, 22.5))
    # Pressure dial set into the top cap, off-centre toward the front.
    m.cylinder(0.022, 0.016, dark_steel, sides=8, at=(0.071, -0.071, 0.785))
    m.cylinder(0.017, 0.004, dial_face, sides=8, at=(0.071, -0.071, 0.795))
    # Grab handles on +-X: steel stand-offs and bar, a rubber sleeve on the grip.
    for side in (-1, 1):
        x0, x1 = side * 0.146, side * 0.212
        m.pipe([(x0, 0, 0.27), (x1, 0, 0.3), (x1, 0, 0.52), (x0, 0, 0.55)], 0.013, steel, sides=6)
        m.pipe([(x1, 0, 0.33), (x1, 0, 0.49)], 0.018, rubber, sides=6)
        m.box((0.04, 0.05, 0.03), dark_steel, at=(side * 0.152, 0, 0.27))
        m.box((0.04, 0.05, 0.03), dark_steel, at=(side * 0.152, 0, 0.55))
    low = m.to_object()

    # Decals ------------------------------------------------------------------------------------
    black = mats.decal("fc_black", (0.05, 0.05, 0.05))
    cream = mats.decal("fc_cream", (0.84, 0.8, 0.68))
    yellow = mats.decal("fc_yellow", (0.95, 0.78, 0.12))
    led_on = mats.decal("fc_led_on", (0.8, 1.0, 0.38), glow=True)
    led_off = mats.decal("fc_led_off", (0.1, 0.13, 0.08))
    red = mats.decal("fc_red", (0.75, 0.1, 0.06))
    d = Mesh("fuel_cell_decals")

    half_width = 0.18 * math.sin(math.pi / 8)
    for k in range(8):
        a = 2 * math.pi * k / 8
        normal = Vector((math.cos(a), math.sin(a), 0))
        for z0 in (0.026, 0.78 - 0.098):
            centre = normal * 0.18 * math.cos(math.pi / 8) + Vector((0, 0, z0 + 0.036))
            f = frame(centre, normal)
            # Diagonal hazard stripes across the cap band.
            for i in range(-3, 3):
                x = i * 0.05
                stripe = [(x - 0.012, -0.034), (x + 0.012, -0.034), (x + 0.042, 0.034), (x + 0.018, 0.034)]
                d.polygon(clip(stripe, -half_width, half_width, -0.036, 0.036), black, f)

    face_offset = 0.15 * math.cos(math.pi / 8)
    front = Vector((0, -1, 0))
    # Charge gauge: five segments beside the front window, four lit.
    for i in range(5):
        f = frame(front * face_offset + Vector((0.045, 0, 0.27 + i * 0.06)), front)
        d.polygon([(-0.006, -0.022), (0.006, -0.022), (0.006, 0.022), (-0.006, 0.022)], led_on if i < 4 else led_off, f)
    # Fill line and graduation ticks on both windows: the cell is about four-fifths full.
    window_offset = 0.148 * math.cos(math.pi / 8) - 0.016  # the windows sit recessed in the waist
    for normal in (Vector((0, -1, 0)), Vector((0, 1, 0))):
        f = frame(normal * window_offset + Vector((0, 0, 0.39)), normal, lift=0.001)
        d.polygon([(-0.036, 0.11), (0.036, 0.11), (0.036, 0.19), (-0.036, 0.19)], led_off, f)
        for k in range(7):
            z = -0.15 + k * 0.045
            d.polygon([(-0.034, z - 0.003), (-0.02, z - 0.003), (-0.02, z + 0.003), (-0.034, z + 0.003)], cream, f)
    # Bolts on the straps: one per face, catching the light.
    bolt = mats.decal("fc_bolt", (0.62, 0.62, 0.58))
    for z in (0.169, 0.611):
        for k in range(8):
            a = 2 * math.pi * k / 8
            normal = Vector((math.cos(a), math.sin(a), 0))
            f = frame(normal * 0.157 * math.cos(math.pi / 8) + Vector((0, 0, z)), normal)
            d.polygon([(-0.007, -0.007), (0.007, -0.007), (0.007, 0.007), (-0.007, 0.007)], bolt, f)
    # FUEL plate on the front-left diagonal, text running up it.
    diagonal = Vector((-math.sqrt(0.5), -math.sqrt(0.5), 0))
    f = frame(diagonal * face_offset + Vector((0, 0, 0.39)), diagonal)
    d.polygon([(-0.042, -0.15), (0.042, -0.15), (0.042, 0.15), (-0.042, 0.15)], cream, f)
    letters = geo.text("FUEL", 0.06, black, matrix=frame(diagonal * (face_offset + 0.002) + Vector((0, 0, 0.39)), diagonal)
                       @ geo.place(rot=(0, -90, 0)))
    # Warning diamond on the front-right diagonal.
    diagonal = Vector((math.sqrt(0.5), -math.sqrt(0.5), 0))
    f = frame(diagonal * face_offset + Vector((0, 0, 0.44)), diagonal)
    d.polygon([(0, -0.05), (0.05, 0), (0, 0.05), (-0.05, 0)], black, f)
    d.polygon([(0, -0.04), (0.04, 0), (0, 0.04), (-0.04, 0)], yellow, frame(diagonal * (face_offset + 0.001) + Vector((0, 0, 0.44)), diagonal))
    mark = geo.text("!", 0.045, black, matrix=frame(diagonal * (face_offset + 0.002) + Vector((0, 0, 0.44)), diagonal))
    # Dial needle and red zone on the top dial.
    up = Vector((0, 0, 1))
    dial = frame(Vector((0.071, -0.071, 0.797)), up, up=(0, 1, 0), lift=0.001)
    d.polygon([(-0.002, -0.004), (0.002, -0.004), (0.012, 0.014), (0.009, 0.016)], black, dial)
    d.polygon([(0.012, 0.0), (0.019, 0.0), (0.017, 0.009), (0.011, 0.007)], red, dial)
    decals = d.to_object()

    # Stencilled serial and class on the back diagonals, running up them.
    stencils = []
    for body_text, normal in (("0447", Vector((-math.sqrt(0.5), math.sqrt(0.5), 0))),
                              ("IV", Vector((math.sqrt(0.5), math.sqrt(0.5), 0)))):
        stencils.append(geo.text(body_text, 0.05, cream, matrix=frame(normal * face_offset + Vector((0, 0, 0.39)), normal)
                                 @ geo.place(rot=(0, -90, 0))))

    sockets = [_socket("grip_l", (-0.212, 0, 0.41)), _socket("grip_r", (0.212, 0, 0.41)),
               _socket("coupling", (0, 0, 0.85))]
    return Model(low=low, decals=[decals, letters, mark, *stencils], extras=sockets)
