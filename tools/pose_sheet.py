"""Renders a rigged model's clips at chosen moments on one sheet, for checking animation by eye.

    Blender -b art/source/ch_suit.blend -P tools/pose_sheet.py -- <out.png> <view> <clip:t,t,...>...
        [--hold=<model>[:tilt]] [--size=<px>]

<view> is azimuth,elevation[,distance[,height]] in degrees and metres (0 looks at the model's
front, 90 at its left side), or "camera" for a first-person rig seen from the origin looking -Y.
Each clip's moments are 0..1 through it, e.g. walk:0,0.125,0.25,0.375. Rows are clips, columns
moments. `--hold` puts art/source/<model>.blend in the rig's hand as the game does (Items.hold):
its SOCKET_grip on the rig's, pitched up `tilt` degrees. `--size` sets each tile's height (240).
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
    for option in options:
        if option.startswith("--hold="):
            _hold(scene, option.removeprefix("--hold="))
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
    if view == "camera":
        camera.data.sensor_fit = "VERTICAL"
        camera.data.angle_y = math.radians(75)
        camera.data.clip_start = 0.02
        camera.location = (0, -0.02, -0.06)  # the view model sits 6 cm up, 2 cm back (player.tscn)
        camera.rotation_euler = (math.radians(90), 0, math.radians(180))
        scene.render.resolution_x = int(TILE[1] * 16 / 9)
    else:
        values = [float(v) for v in view.split(",")] + [3.6, 0.95][len(view.split(",")) - 2:]
        azimuth, elevation = math.radians(values[0]), math.radians(values[1])
        camera.data.lens = 50
        centre = Vector((0, 0, values[3]))
        offset = Vector((math.sin(azimuth) * math.cos(elevation), -math.cos(azimuth) * math.cos(elevation), math.sin(elevation)))
        camera.location = centre + offset * values[2]
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
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


def _hold(scene, spec):
    name, _, tilt = spec.partition(":")
    hand = scene.objects["SOCKET_grip"]
    path = Path(__file__).resolve().parents[1] / "art" / "source" / f"{name}.blend"
    with bpy.data.libraries.load(str(path)) as (source, loaded):
        loaded.objects = list(source.objects)
    socket = next((o for o in loaded.objects if o.name.startswith("SOCKET_grip")), None)
    offset = socket.matrix_world.translation.copy() if socket is not None else Vector()
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
