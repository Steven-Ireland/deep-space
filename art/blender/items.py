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


# Tools and pickups (GDD §9, §13). Held in first person, so they're hero props up close: 128-256 px.

def _k():
    return dict(
        steel=mats.metal("it_steel", (0.58, 0.58, 0.56), grime=0.35),
        dark=mats.metal("it_dark", (0.2, 0.21, 0.22), grime=0.4),
        rubber=mats.plain("it_rubber", (0.07, 0.07, 0.08), grime=0.25),
        orange=mats.paint("it_orange", (0.86, 0.42, 0.1), wear=0.5, grime=0.35, under=(0.55, 0.55, 0.52)),
        yellow=mats.paint("it_yellow", (0.9, 0.72, 0.12), wear=0.5, grime=0.35, under=(0.55, 0.55, 0.52)),
        red=mats.paint("it_red", (0.68, 0.1, 0.07), wear=0.55, grime=0.35, under=(0.6, 0.6, 0.58)),
        cream=mats.paint("it_cream", (0.8, 0.77, 0.68), wear=0.35, grime=0.4),
        green=mats.paint("it_green", (0.18, 0.42, 0.26), wear=0.4, grime=0.35),
    )


def _dk():
    return dict(
        black=mats.decal("it_d_black", (0.05, 0.05, 0.05)),
        white=mats.decal("it_d_white", (0.88, 0.87, 0.82)),
        cream=mats.decal("it_d_cream", (0.84, 0.8, 0.68)),
        orange=mats.decal("it_d_orange", (0.86, 0.42, 0.1)),
        yellow=mats.decal("it_d_yellow", (0.95, 0.78, 0.12)),
        green_lit=mats.decal("it_d_green_lit", (0.4, 1.0, 0.5), glow=True),
        amber_lit=mats.decal("it_d_amber_lit", (1.0, 0.7, 0.2), glow=True),
        cyan_lit=mats.decal("it_d_cyan_lit", (0.35, 0.9, 1.0), glow=True),
        red_lit=mats.decal("it_d_red_lit", (1.0, 0.25, 0.15), glow=True),
    )


@asset("it_flashlight", "items", texture=128, colors=32, ao=0.5)
def flashlight():
    """The crew flashlight (GDD §9.3): the main light, held in the right hand. 0.27 m: a knurled
    rubber grip, a battery tube, a flared head with an orange bezel and a lens (`lens`, separate:
    Godot lights it when on), a battery LED on top, a lanyard loop at the tail. Points along -Y."""
    k = _k()
    dk = _dk()
    m = Mesh("it_flashlight")
    d = Mesh("it_flashlight_decals")
    m.lathe([(0.0, 0.0), (0.017, 0.0), (0.019, 0.006), (0.019, 0.12), (0.021, 0.13), (0.021, 0.17), (0.033, 0.22),
             (0.036, 0.25), (0.036, 0.262), (0.031, 0.266)], k["dark"], sides=8, rot=(90, 0, 0), cap_start=False, cap_end=False)
    m.lathe([(0.0205, 0.02), (0.0205, 0.11)], k["rubber"], sides=8, rot=(90, 0, 0), cap_start=False, cap_end=False)
    m.lathe([(0.0375, 0.24), (0.0375, 0.262)], k["orange"], sides=8, rot=(90, 0, 0), cap_start=False, cap_end=False)
    m.box((0.012, 0.03, 0.012), k["steel"], at=(0, 0.0, -0.015), bevel=0.003)
    m.box((0.016, 0.03, 0.01), k["rubber"], at=(0, -0.15, 0.022), bevel=0.003)  # the switch
    for i in range(6):
        d.polygon([(-0.022, -0.002), (0.022, -0.002), (0.022, 0.002), (-0.022, 0.002)], dk["black"],
                  frame((0, -0.03 - i * 0.014, 0.021), (0, 0, 1), up=(0, 1, 0), lift=0.0005))
    d.polygon([(-0.003, -0.003), (0.003, -0.003), (0.003, 0.003), (-0.003, 0.003)], dk["green_lit"],
              frame((0, -0.18, 0.0215), (0, 0, 1), up=(0, 1, 0)))
    low = m.to_object()
    lens = Mesh("lens")
    lens.cylinder(0.031, 0.004, mats.plain("it_lens", (0.9, 0.9, 0.8)), sides=8, at=(0, -0.264, 0), rot=(90, 0, 0))
    lens_obj = lens.to_object()
    sockets = [_socket("light", (0, -0.27, 0)), _socket("grip", (0, -0.06, 0))]
    return Model(low=low, decals=[d.to_object()], extras=[lens_obj] + sockets)


@asset("it_crowbar", "items", texture=128, colors=24, ao=0.5)
def crowbar():
    """A crowbar (GDD §13, Tier 0): pry hatches, smash things. 0.76 m of hex bar, red paint worn
    back to steel, a flattened claw bent at one end, a wedge at the other, black tape at the grip."""
    k = _k()
    dk = _dk()
    m = Mesh("it_crowbar")
    m.pipe([(0, 0.0, 0.0), (0, -0.56, 0.0), (0, -0.66, 0.03), (0, -0.71, 0.09), (0, -0.715, 0.13)], 0.013, k["red"], sides=6)
    m.pipe([(0, 0.0, 0.0), (0, 0.06, -0.012)], 0.012, k["steel"], sides=6)
    m.prism([(-0.016, 0.0), (0.016, 0.0), (0.004, 0.035), (-0.004, 0.035)], 0.008, k["steel"], at=(0, -0.715, 0.12), rot=(0, 0, 0))
    m.pipe([(0, -0.08, 0.0), (0, -0.24, 0.0)], 0.0145, k["rubber"], sides=6)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[_socket("grip", (0, -0.16, 0))])


@asset("it_flare", "items", texture=64, colors=24, ao=0.5)
def flare():
    """A signal flare (GDD §9.3): a red paper tube with a white striker cap and a printed band.
    Lit, it burns ~60 s, hisses, and draws attention. Points along -Y; held a third of the way up."""
    k = _k()
    dk = _dk()
    m = Mesh("it_flare")
    d = Mesh("it_flare_decals")
    m.lathe([(0.0, 0.0), (0.018, 0.0), (0.018, 0.25), (0.012, 0.26), (0.0, 0.26)], k["red"], sides=8, rot=(90, 0, 0))
    m.lathe([(0.0195, 0.2), (0.0195, 0.262), (0.0, 0.262)], k["cream"], sides=8, rot=(90, 0, 0), cap_start=False)
    m.lathe([(0.0185, 0.07), (0.0185, 0.12)], k["cream"], sides=8, rot=(90, 0, 0), cap_start=False, cap_end=False)
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[_socket("flame", (0, -0.265, 0)), _socket("grip", (0, -0.085, 0))])


@asset("it_o2_canister", "items", texture=128, colors=24, ao=0.5)
def o2_canister():
    """A portable O2 canister (GDD §9.2): 0.42 m green bottle with a white shoulder, a valve with a
    steel guard, a carry handle, O2 stencilled. Refills a suit."""
    k = _k()
    dk = _dk()
    m = Mesh("it_o2_canister")
    m.lathe([(0.0, 0.0), (0.07, 0.0), (0.075, 0.02), (0.075, 0.3), (0.06, 0.35), (0.025, 0.37), (0.0, 0.37)], k["green"], sides=10)
    m.lathe([(0.0765, 0.27), (0.0765, 0.32)], k["cream"], sides=10, cap_start=False, cap_end=False)
    m.cylinder(0.018, 0.04, k["steel"], sides=6, at=(0, 0, 0.39))
    m.box((0.05, 0.02, 0.02), k["dark"], at=(0.03, 0, 0.4))
    m.pipe([(-0.05, 0, 0.33), (-0.05, 0, 0.42), (0.05, 0, 0.42), (0.05, 0, 0.33)], 0.008, k["dark"], sides=5, caps=False)
    low = m.to_object()
    text = geo.text("O2", 0.06, dk["white"], matrix=frame((0, -0.075, 0.17), (0, -1, 0), lift=0.003))
    return Model(low=low, decals=[text], extras=[_socket("grip", (0, 0, 0.42))])


@asset("it_power_cell", "items", texture=128, colors=32, ao=0.5)
def power_cell():
    """A portable power cell (GDD §8.3): carried into a dead derelict section to bring it back.
    0.38 m armoured box with a steel carry handle, contact terminals on one end, a row of charge
    lamps, hazard stripes and PWR stencilled. Two-handed? No: heavy, but one hand."""
    k = _k()
    dk = _dk()
    m = Mesh("it_power_cell")
    d = Mesh("it_power_cell_decals")
    texts = []
    m.box((0.38, 0.22, 0.24), k["yellow"], at=(0, 0, 0.12), bevel=0.012)
    for x in (-0.17, 0.17):
        m.box((0.04, 0.24, 0.26), k["dark"], at=(x, 0, 0.13), bevel=0.008)
    m.pipe([(-0.12, 0, 0.24), (-0.12, 0, 0.32), (0.12, 0, 0.32), (0.12, 0, 0.24)], 0.012, k["steel"], sides=6, caps=False)
    for z in (0.08, 0.16):
        m.cylinder(0.018, 0.03, k["steel"], sides=6, at=(0.205, 0, z), rot=(0, 90, 0))
    front = Vector((0, -1, 0))
    for i in range(4):
        d.polygon([(-0.012, -0.008), (0.012, -0.008), (0.012, 0.008), (-0.012, 0.008)], dk["green_lit"] if i < 3 else dk["black"],
                  frame((-0.06 + i * 0.04, -0.11, 0.19), front))
    for i in range(-3, 4):
        x = i * 0.05
        stripe = [(x, -0.03), (x + 0.02, -0.03), (x + 0.05, 0.03), (x + 0.03, 0.03)]
        d.polygon(clip(stripe, -0.13, 0.13, -0.03, 0.03), dk["black"], frame((0, -0.11, 0.06), front))
    texts.append(geo.text("PWR", 0.035, dk["black"], matrix=frame((0, -0.111, 0.125), front, lift=0.002)))
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()] + texts, extras=[_socket("grip", (0, 0, 0.32))])


@asset("it_data_core", "items", texture=64, colors=24, ao=0.5)
def data_core():
    """A data core (GDD §7): an earlier wave's memory, worth Survey Data and lore. A 0.2 m steel
    cylinder with ribbed end caps and a glowing cyan band, its wave's serial on a label."""
    k = _k()
    dk = _dk()
    band = mats.glowing("it_core_band", (0.35, 0.9, 1.0), base=(0.1, 0.25, 0.3), flicker=0.2)
    m = Mesh("it_data_core")
    m.lathe([(0.0, 0.0), (0.035, 0.0), (0.04, 0.01), (0.04, 0.05), (0.034, 0.055), (0.034, 0.145), (0.04, 0.15),
             (0.04, 0.19), (0.035, 0.2), (0.0, 0.2)], k["steel"], sides=8)
    m.lathe([(0.0355, 0.075), (0.0355, 0.125)], band, sides=8, cap_start=False, cap_end=False)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[])


@asset("it_sealant", "items", texture=64, colors=24, ao=0.5)
def sealant():
    """A sealant can (GDD §9.2): patches a breached suit. An orange aerosol can with a black nozzle
    trigger and a white instruction band."""
    k = _k()
    dk = _dk()
    m = Mesh("it_sealant")
    m.lathe([(0.0, 0.0), (0.03, 0.0), (0.032, 0.01), (0.032, 0.15), (0.022, 0.17), (0.0, 0.17)], k["orange"], sides=8)
    m.lathe([(0.0325, 0.05), (0.0325, 0.1)], k["cream"], sides=8, cap_start=False, cap_end=False)
    m.box((0.02, 0.04, 0.03), k["rubber"], at=(0, -0.01, 0.185), bevel=0.004)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[])


@asset("it_cartridge", "items", texture=64, colors=24, ao=0.5)
def cartridge():
    """An energy cartridge (GDD §13): every weapon's ammunition, scarce and dear. A 0.12 m steel
    cylinder with a glowing amber charge window and brass contacts at one end."""
    k = _k()
    brass = mats.metal("it_brass", (0.7, 0.55, 0.25), grime=0.3)
    charge = mats.glowing("it_charge", (1.0, 0.7, 0.2), base=(0.4, 0.25, 0.08), flicker=0.15)
    m = Mesh("it_cartridge")
    m.lathe([(0.0, 0.0), (0.02, 0.0), (0.022, 0.006), (0.022, 0.114), (0.018, 0.12), (0.0, 0.12)], k["dark"], sides=8)
    m.lathe([(0.0225, 0.03), (0.0225, 0.09)], charge, sides=8, cap_start=False, cap_end=False)
    m.cylinder(0.01, 0.012, brass, sides=6, at=(0, 0, 0.126))
    low = m.to_object()
    return Model(low=low, decals=[], extras=[])


def _salvage(name, build):
    k = _k()
    m = Mesh(name)
    build(m, k)
    low = m.to_object()
    return Model(low=low, decals=[], extras=[])


@asset("it_salvage_pipes", "items", texture=64, colors=24, ao=0.5)
def salvage_pipes():
    """Salvage: a bundle of cut pipe lengths strapped together."""
    def build(m, k):
        for i, (x, z) in enumerate(((0, 0.04), (0.05, 0.04), (0.025, 0.083), (-0.05, 0.04), (-0.025, 0.083))):
            m.pipe([(x, -0.22, z), (x, 0.22, z)], 0.024, k["steel"] if i % 2 else k["dark"], sides=6)
        for y in (-0.12, 0.12):
            m.box((0.16, 0.02, 0.12), k["orange"], at=(0, y, 0.06), bevel=0.004)
    return _salvage("it_salvage_pipes", build)


@asset("it_salvage_board", "items", texture=64, colors=32, ao=0.5)
def salvage_board():
    """Salvage: a pulled circuit block, green board with chips and a ribbon of wire."""
    def build(m, k):
        board = mats.paint("it_board", (0.12, 0.32, 0.18), wear=0.3, grime=0.4)
        m.box((0.3, 0.2, 0.02), board, at=(0, 0, 0.01))
        for i in range(5):
            m.box((0.05, 0.03, 0.015), k["dark"], at=(-0.1 + i * 0.05, -0.04 + (i % 2) * 0.07, 0.027))
        m.box((0.06, 0.06, 0.04), k["steel"], at=(0.09, 0.05, 0.04), bevel=0.004)
        m.pipe([(0.15, 0.0, 0.02), (0.22, 0.02, 0.01), (0.27, -0.03, 0.0)], 0.006, k["orange"], sides=4)
    return _salvage("it_salvage_board", build)


@asset("it_salvage_plates", "items", texture=64, colors=24, ao=0.5)
def salvage_plates():
    """Salvage: a stack of scrap armour plates, wired together."""
    def build(m, k):
        for i in range(4):
            m.box((0.34 - i * 0.02, 0.26 - i * 0.015, 0.02), k["steel"] if i % 2 else k["dark"],
                  at=(i * 0.01, -i * 0.008, 0.01 + i * 0.022), rot=(0, 0, i * 6), bevel=0.003)
    return _salvage("it_salvage_plates", build)


# Weapons (GDD §13): tier 0 improvised, tier 1 industrial. All point along -Y; `grip` sockets sit
# where the hand holds them.

@asset("wp_shock_prod", "weapons", texture=128, colors=32, ao=0.5)
def shock_prod():
    """SHOCK PROD (Tier 0): a 0.62 m stun baton. A rubber grip with a trigger guard, a yellow
    battery pod with charge lamps, a black-and-yellow insulated shaft, two steel prongs at the
    tip with a blue arc lamp between them. Stuns, briefly; recharges at the station."""
    k = _k()
    dk = _dk()
    arc = mats.glowing("wp_arc", (0.55, 0.75, 1.0), base=(0.2, 0.25, 0.35), flicker=0.4)
    m = Mesh("wp_shock_prod")
    d = Mesh("wp_shock_prod_decals")
    m.pipe([(0, 0.06, 0), (0, -0.1, 0)], 0.019, k["rubber"], sides=8)
    m.box((0.05, 0.12, 0.07), k["yellow"], at=(0, -0.16, 0.01), bevel=0.01)
    m.pipe([(0, -0.22, 0), (0, -0.54, 0)], 0.013, k["dark"], sides=8)
    for i in range(4):
        m.pipe([(0, -0.25 - i * 0.07, 0), (0, -0.28 - i * 0.07, 0)], 0.0135, k["yellow"], sides=8, caps=False)
    m.box((0.04, 0.03, 0.03), k["dark"], at=(0, -0.55, 0), bevel=0.006)
    for x in (-0.012, 0.012):
        m.pipe([(x, -0.56, 0), (x, -0.62, 0)], 0.004, k["steel"], sides=4)
    m.box((0.015, 0.012, 0.012), arc, at=(0, -0.6, 0))
    m.pipe([(0, -0.02, -0.02), (0, -0.04, -0.045), (0, -0.09, -0.04)], 0.004, k["dark"], sides=4, caps=False)
    for i in range(3):
        d.polygon([(-0.005, -0.004), (0.005, -0.004), (0.005, 0.004), (-0.005, 0.004)], dk["green_lit"],
                  frame((0, -0.13 - i * 0.02, 0.0455), (0, 0, 1), up=(0, 1, 0)))
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[_socket("grip", (0, 0.0, 0)), _socket("tip", (0, -0.62, 0))])


@asset("wp_plasma_cutter", "weapons", texture=256, colors=32, ao=0.5)
def plasma_cutter():
    """PLASMA CUTTER (Tier 1): a mining tool pressed into service. A boxy orange body, a wide
    emitter head with three emitter nubs and a dark shroud, a pistol grip with a guarded trigger,
    a top carry rail, a cartridge bay with a glowing amber window, charge lamps on the back. Cuts
    sealed hatches; slow, precise, deadly. About 0.42 m."""
    k = _k()
    dk = _dk()
    charge = mats.glowing("it_charge", (1.0, 0.7, 0.2), base=(0.4, 0.25, 0.08), flicker=0.15)
    emitter = mats.glowing("wp_emitter", (0.55, 0.8, 1.0), base=(0.15, 0.2, 0.3), flicker=0.2)
    m = Mesh("wp_plasma_cutter")
    d = Mesh("wp_plasma_cutter_decals")
    texts = []
    m.box((0.08, 0.26, 0.1), k["orange"], at=(0, -0.08, 0.05), bevel=0.012)
    m.box((0.07, 0.06, 0.08), k["dark"], at=(0, 0.075, 0.045), bevel=0.01)
    # Emitter head: a wide dark shroud with three nubs.
    m.box((0.16, 0.06, 0.06), k["dark"], at=(0, -0.24, 0.055), bevel=0.01)
    for x in (-0.05, 0.0, 0.05):
        m.cylinder(0.012, 0.03, k["steel"], sides=6, at=(x, -0.285, 0.055), rot=(90, 0, 0))
        m.cylinder(0.008, 0.004, emitter, sides=6, at=(x, -0.302, 0.055), rot=(90, 0, 0))
    # Grip and trigger.
    m.box((0.035, 0.05, 0.12), k["rubber"], at=(0, 0.02, -0.055), rot=(-14, 0, 0), bevel=0.008)
    m.pipe([(0, -0.02, 0.0), (0, -0.045, -0.04), (0, -0.01, -0.07)], 0.004, k["dark"], sides=4, caps=False)
    m.box((0.008, 0.012, 0.025), k["steel"], at=(0, -0.022, -0.015))
    # Carry rail and cartridge bay.
    m.pipe([(0, 0.03, 0.1), (0, 0.03, 0.13), (0, -0.16, 0.13), (0, -0.16, 0.1)], 0.007, k["steel"], sides=5, caps=False)
    m.box((0.085, 0.07, 0.035), k["dark"], at=(0, -0.1, -0.012), bevel=0.006)
    m.box((0.086, 0.04, 0.012), charge, at=(0, -0.1, -0.02))
    back = Vector((0, 1, 0))
    for i in range(4):
        d.polygon([(-0.006, -0.004), (0.006, -0.004), (0.006, 0.004), (-0.006, 0.004)], dk["green_lit"] if i < 3 else dk["black"],
                  frame((-0.024 + i * 0.016, 0.105, 0.07), back))
    side = Vector((1, 0, 0))
    for i in range(-3, 3):
        x = i * 0.04
        stripe = [(x, -0.02), (x + 0.015, -0.02), (x + 0.035, 0.02), (x + 0.02, 0.02)]
        d.polygon(clip(stripe, -0.1, 0.1, -0.02, 0.02), dk["black"], frame((0.0405, -0.1, 0.07), side))
    texts.append(geo.text("CUT", 0.018, dk["black"], matrix=frame((0.0405, -0.12, 0.035), side, lift=0.002)))
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()] + texts, extras=[_socket("grip", (0, 0.02, -0.06)), _socket("muzzle", (0, -0.305, 0.055))])


@asset("wp_rivet_driver", "weapons", texture=256, colors=32, ao=0.5)
def rivet_driver():
    """RIVET DRIVER (Tier 1): a hull-repair rivet gun. A long yellow body over a pneumatic
    cylinder, a narrow nose with a sprung pressure foot, a pistol grip, a stick magazine of fat
    rivets angled down in front of the grip, an air line stub at the back. Single heavy bolts;
    loud. About 0.5 m."""
    k = _k()
    dk = _dk()
    m = Mesh("wp_rivet_driver")
    d = Mesh("wp_rivet_driver_decals")
    m.box((0.07, 0.3, 0.09), k["yellow"], at=(0, -0.06, 0.05), bevel=0.014)
    m.cylinder(0.04, 0.16, k["dark"], sides=8, at=(0, 0.09, 0.05), rot=(90, 0, 0))
    m.cylinder(0.018, 0.16, k["steel"], sides=6, at=(0, -0.29, 0.055), rot=(90, 0, 0))
    for x in (-0.022, 0.022):
        m.pipe([(x, -0.33, 0.055), (x, -0.38, 0.055)], 0.005, k["steel"], sides=4)
    m.box((0.06, 0.01, 0.04), k["dark"], at=(0, -0.385, 0.055))
    m.box((0.035, 0.05, 0.13), k["rubber"], at=(0, 0.06, -0.06), rot=(-16, 0, 0), bevel=0.008)
    m.pipe([(0, 0.02, 0.0), (0, 0.0, -0.04), (0, 0.035, -0.075)], 0.004, k["dark"], sides=4, caps=False)
    m.box((0.03, 0.04, 0.16), k["dark"], at=(0, -0.13, -0.05), rot=(18, 0, 0), bevel=0.006)
    for i in range(5):
        m.cylinder(0.009, 0.034, k["steel"], sides=6, at=(0, -0.155 + i * 0.006, -0.0 - i * 0.028), rot=(90, 0, 0))
    m.pipe([(0, 0.17, 0.05), (0, 0.21, 0.04), (0, 0.24, 0.0)], 0.01, k["rubber"], sides=5)
    side = Vector((1, 0, 0))
    for i in range(-4, 4):
        x = i * 0.04
        stripe = [(x, -0.025), (x + 0.015, -0.025), (x + 0.04, 0.025), (x + 0.025, 0.025)]
        d.polygon(clip(stripe, -0.14, 0.14, -0.025, 0.025), dk["black"], frame((0.0355, -0.06, 0.05), side))
    low = m.to_object()
    return Model(low=low, decals=[d.to_object()], extras=[_socket("grip", (0, 0.06, -0.06)), _socket("muzzle", (0, -0.39, 0.055))])
