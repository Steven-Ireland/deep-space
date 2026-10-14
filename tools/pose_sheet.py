"""Renders a rigged model's clips at chosen moments on one sheet, for checking animation by eye.

    Blender -b art/source/ch_suit.blend -P tools/pose_sheet.py -- <out.png> <view> <clip:t,t,...>...
        [--hold=<model>[:tilt]] [--carry=<model>] [--focus=<bone>] [--lens=<mm>] [--size=<px>]

<view> is azimuth,elevation[,distance[,height]] in degrees and metres (0 looks at the model's
front, 90 at its left side), or "camera" for a first-person rig seen from the origin looking -Y.
Each clip's moments are 0..1 through it, e.g. walk:0,0.125,0.25,0.375. Rows are clips, columns
moments. `--hold` puts art/source/<model>.blend in the rig's hand as the game does (Items.hold):
its SOCKET_grip on the rig's, pitched up `tilt` degrees; `--carry` puts a big thing between the
hands the same way (its SOCKET_grip on the rig's SOCKET_carry). `--focus` looks at a bone instead (its
middle, as posed at each moment): the orbit views circle it, "camera" turns from the eye to it;
with `--lens` (mm; 50 by default) to close in, e.g. `0,20,0.4 cuff:0 --focus=hand.L --lens=70`.
`--size` sets each tile's height (240).
"""

import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "art" / "blender"))

from lib import preview  # noqa: E402

TILE = (240, 240)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    options = [a for a in args if a.startswith("--")]
    args = [a for a in args if not a.startswith("--")]
    out, view, clips = args[0], args[1], args[2:]
    scene = bpy.context.scene
    global TILE
    focus, lens = None, None
    for option in options:
        if option.startswith("--hold="):
            _hold(scene, option.removeprefix("--hold="))
        elif option.startswith("--carry="):
            _hold(scene, option.removeprefix("--carry="), "SOCKET_carry")
        elif option.startswith("--focus="):
            focus = option.removeprefix("--focus=")
        elif option.startswith("--lens="):
            lens = float(option.removeprefix("--lens="))
        elif option.startswith("--size="):
            TILE = (int(option.removeprefix("--size=")),) * 2
    rig = next(o for o in scene.objects if o.type == "ARMATURE")
    meshes = [o for o in scene.objects if o.type == "MESH" and not o.name.endswith("-colonly")]
    for o in meshes:
        o.hide_render = False
    preview.render.__globals__["VIEW"] = TILE
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = TILE
    scene.view_settings.view_transform = "Standard"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("sheet")
    scene.world.color = (0.05, 0.055, 0.06)
    lights = preview._lights(Vector(), 1.0)
    camera = bpy.data.objects.new("sheet_camera", bpy.data.cameras.new("sheet_camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.clip_start = 0.01
    if view == "camera":
        camera.data.sensor_fit = "VERTICAL"
        camera.data.angle_y = math.radians(75)
        scene.render.resolution_x = int(TILE[1] * 16 / 9)
    if lens is not None:
        camera.data.lens = lens
    _place(camera, view, None)
    rows = []
    for spec in clips:
        name, moments = spec.split(":")
        action = bpy.data.actions.get(name) or bpy.data.actions.get(name + "-loop")
        rig.animation_data.action = action
        if hasattr(rig.animation_data, "action_slot") and action.slots:
            rig.animation_data.action_slot = action.slots[0]
        start, end = action.frame_range
        for bone in rig.pose.bones:
            bone.rotation_euler = (0, 0, 0)
            bone.location = (0, 0, 0)
        tiles = []
        for t in moments.split(","):
            scene.frame_set(int(round(start + float(t) * (end - start))))
            if focus is not None:
                bone = rig.pose.bones[focus]
                _place(camera, view, rig.matrix_world @ ((bone.head + bone.tail) / 2))
            tiles.append(preview._render_tile())
        rows.append(np.concatenate(tiles, axis=1))
    width = max(r.shape[1] for r in rows)
    rows = [np.pad(r, ((0, 0), (0, width - r.shape[1]), (0, 0))) for r in rows]
    sheet = np.concatenate(rows[::-1], axis=0)
    h, w, _ = sheet.shape
    image = bpy.data.images.new("sheet", w, h, alpha=False)
    image.pixels.foreach_set(sheet.astype(np.float32).ravel())
    image.filepath_raw = out
    image.file_format = "PNG"
    image.save()
    print(f"Pose sheet: {out}")


def _place(camera, view, focus):
    """Puts the camera for `view`, looking at `focus` (a point) if given."""
    if view == "camera":
        camera.location = (0, -0.02, -0.06)  # the view model sits 6 cm up, 2 cm back (player.tscn)
        if focus is None:
            camera.rotation_euler = (math.radians(90), 0, math.radians(180))
        else:
            camera.rotation_euler = (focus - camera.location).to_track_quat("-Z", "Y").to_euler()
        return
    values = [float(v) for v in view.split(",")] + [3.6, 0.95][len(view.split(",")) - 2:]
    azimuth, elevation = math.radians(values[0]), math.radians(values[1])
    centre = focus if focus is not None else Vector((0, 0, values[3]))
    offset = Vector((math.sin(azimuth) * math.cos(elevation), -math.cos(azimuth) * math.cos(elevation), math.sin(elevation)))
    camera.location = centre + offset * values[2]
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()


def _hold(scene, spec, socket_name="SOCKET_grip"):
    name, _, tilt = spec.partition(":")
    hand = scene.objects[socket_name]
    path = Path(__file__).resolve().parents[1] / "art" / "source" / f"{name}.blend"
    with bpy.data.libraries.load(str(path)) as (source, loaded):
        loaded.objects = list(source.objects)
    # The item's own grip: renamed SOCKET_grip.001 or so on loading, as the rig has one already. Its
    # sockets are unparented empties, so its location is where it is.
    socket = next((o for o in loaded.objects if o.name.split(".")[0] == "SOCKET_grip"), None)
    offset = socket.location.copy() if socket is not None else Vector()
    held = bpy.data.objects.new("held", None)
    scene.collection.objects.link(held)
    held.parent = hand
    turn = Matrix.Rotation(math.radians(-float(tilt or 0)), 4, "X")
    held.matrix_basis = turn @ Matrix.Translation(-offset)
    for o in loaded.objects:
        scene.collection.objects.link(o)
        if o.parent is None:
            o.parent = held
        o.hide_render = o.type != "MESH"


main()
