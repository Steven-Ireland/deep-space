"""Review renders of a built model (TECH §5): four low-res views on one contact sheet, at
art/previews/<name>.png, lit by a simple key/fill/rim rig with unfiltered textures."""

import math

import bpy
import numpy as np
from mathutils import Vector

from . import ROOT

VIEW = (320, 240)
SCALE = 2
# (azimuth, elevation) in degrees; azimuth 0 looks at the model's front (-Y).
ANGLES = [(-35, 18), (145, 22), (90, 4), (-20, 58)]


def render(name, objects, angles=()):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = VIEW
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("preview") if scene.world is None else scene.world
    scene.world = world
    world.color = (0.02, 0.022, 0.026)
    if world.node_tree:
        background = world.node_tree.nodes.get("Background")
        if background:
            background.inputs["Color"].default_value = (0.02, 0.022, 0.026, 1)
            background.inputs["Strength"].default_value = 1.0

    hidden = {obj.name: obj.hide_render for obj in objects}
    for obj in objects:
        obj.hide_render = False
        # Godot draws only the side a face looks out of: so does the preview, so a face turned the
        # wrong way shows up here as a hole (the .blend and .glb are written before this).
        for slot in getattr(obj, "material_slots", []):
            if slot.material is not None:
                slot.material.use_backface_culling = True
    centre, radius = _bounds(objects)
    rig = _lights(centre, radius)
    camera_data = bpy.data.cameras.new("preview")
    camera_data.lens = 40
    camera = bpy.data.objects.new("preview_camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    fov = 2 * math.atan(camera_data.sensor_width / 2 / camera_data.lens) * VIEW[1] / VIEW[0]
    distance = radius / math.sin(fov / 2) * 0.95
    camera_data.clip_end = distance * 4

    tiles = []
    for azimuth, elevation in (angles or ANGLES):
        a, e = math.radians(azimuth), math.radians(elevation)
        offset = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        camera.location = centre + offset * distance
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        tiles.append(_render_tile())

    sheet = np.concatenate([np.concatenate(tiles[2:], axis=1), np.concatenate(tiles[:2], axis=1)], axis=0)
    sheet = sheet.repeat(SCALE, axis=0).repeat(SCALE, axis=1)
    path = ROOT / "art" / "previews" / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    h, w, _ = sheet.shape
    image = bpy.data.images.new("sheet", w, h, alpha=False)
    image.pixels.foreach_set(sheet.astype(np.float32).ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    for obj in rig + [camera]:
        bpy.data.objects.remove(obj)
    for obj in objects:
        obj.hide_render = hidden.get(obj.name, obj.hide_render)
    return path


def _render_tile():
    scene = bpy.context.scene
    path = str(ROOT / "art" / "previews" / "_tile.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(path)
    w, h = image.size
    pixels = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    (ROOT / "art" / "previews" / "_tile.png").unlink()
    return pixels.reshape(h, w, 4)


def _bounds(objects):
    points = []
    for obj in objects:
        if obj.type == "MESH":
            points += [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return (lo + hi) / 2, (hi - lo).length / 2


def _lights(centre, radius):
    rig = []
    for name, energy, direction, colour in [
        ("key", 3.2, (-0.6, -0.8, 0.9), (1.0, 0.95, 0.88)),
        ("fill", 0.9, (0.9, -0.4, 0.3), (0.75, 0.82, 1.0)),
        ("rim", 2.2, (0.3, 1.0, 0.6), (1.0, 1.0, 1.0)),
    ]:
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.color = colour
        light = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(light)
        light.rotation_euler = (-Vector(direction)).to_track_quat("-Z", "Y").to_euler()
        rig.append(light)
    return rig
