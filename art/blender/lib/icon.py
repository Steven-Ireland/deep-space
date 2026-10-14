"""Belt icons for things the crew carries (GDD §9.4, §10): a 16 px silhouette of the model seen
side-on with its nose raised 45°, a solid outline round a faint fill, white on clear so the visor
tints it its phosphor colour. Written to assets/icons/<name>.png."""

import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

from . import ROOT

SIZE = 16
SUPERSAMPLE = 6


def render(name, objects):
    scene = bpy.context.scene
    meshes = [o for o in objects if o.type == "MESH" and not o.name.endswith("-colonly")]
    saved = {o.name: (o.matrix_world.copy(), o.hide_render) for o in scene.objects}
    for o in scene.objects:
        o.hide_render = o not in meshes
    # Nose up 45° about the model's centre.
    points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    centre = sum(points, Vector()) / len(points)
    turn = Matrix.Translation(centre) @ Matrix.Rotation(math.radians(-45), 4, "X") @ Matrix.Translation(-centre)
    for o in meshes:
        if o.parent is None or o.parent not in meshes:
            o.matrix_world = turn @ o.matrix_world
    bpy.context.view_layer.update()
    points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))

    camera = bpy.data.objects.new("icon_camera", bpy.data.cameras.new("icon_camera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(hi.y - lo.y, hi.z - lo.z) * 1.08
    middle = (lo + hi) / 2
    # From the model's right (-X), so its nose points right and up.
    camera.location = (lo.x - 2.0, middle.y, middle.z)
    camera.rotation_euler = (math.radians(90), 0, math.radians(-90))
    camera.data.clip_end = (hi.x - lo.x) + 4.0
    scene.camera = camera

    render_settings = scene.render
    saved_render = (render_settings.engine, render_settings.resolution_x, render_settings.resolution_y,
                    render_settings.film_transparent, render_settings.resolution_percentage)
    render_settings.engine = "BLENDER_WORKBENCH"
    render_settings.resolution_x = render_settings.resolution_y = SIZE * SUPERSAMPLE
    render_settings.resolution_percentage = 100
    render_settings.film_transparent = True
    shading = scene.display.shading
    shading.light = "FLAT"
    shading.color_type = "SINGLE"
    shading.single_color = (1, 1, 1)
    path = ROOT / "art" / "previews" / "_icon.png"
    render_settings.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(str(path))
    w, h = image.size
    pixels = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    path.unlink()

    alpha = pixels.reshape(h, w, 4)[:, :, 3]
    cover = alpha.reshape(SIZE, SUPERSAMPLE, SIZE, SUPERSAMPLE).mean(axis=(1, 3))
    mask = cover > 0.35
    padded = np.pad(mask, 1)
    inside = padded[:-2, 1:-1] & padded[2:, 1:-1] & padded[1:-1, :-2] & padded[1:-1, 2:]
    edge = mask & ~inside
    out = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
    out[mask] = (1, 1, 1, 0.4)
    out[edge] = (1, 1, 1, 1)
    target = ROOT / "assets" / "icons" / f"{name}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    icon = bpy.data.images.new("icon", SIZE, SIZE, alpha=True)
    icon.pixels.foreach_set(out.ravel())
    icon.filepath_raw = str(target)
    icon.file_format = "PNG"
    icon.save()
    bpy.data.images.remove(icon)

    bpy.data.objects.remove(camera)
    (render_settings.engine, render_settings.resolution_x, render_settings.resolution_y,
     render_settings.film_transparent, render_settings.resolution_percentage) = saved_render
    for o in scene.objects:
        if o.name in saved:
            o.matrix_world, o.hide_render = saved[o.name]
    return target
