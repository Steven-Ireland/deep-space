"""Baking a model's detailed materials down to its PSX texture (TECH §5).

The model is unwrapped, then Cycles bakes at 4x the final size:
    albedo  the recipes' surface colour (mats PASS 0)
    ao      ambient occlusion, multiplied in for painted-on depth
    glow    what emits in game (PASS 1), if anything does
    decals  stencils, stripes and marks: separate geometry baked selected-to-active, with a
            coverage mask (PASS 2), composited over the albedo
The result is box-filtered down to size, quantized to a small palette with a light ordered
dither, and saved as PNGs. The model's materials are then replaced by one material using them.
"""

import math
import os

import bpy
import numpy as np

from . import mats

SUPERSAMPLE = 4
SENTINEL = np.array([1.0, 0.0, 1.0], dtype=np.float32)  # texels no UV island covers


def setup_cycles(samples=32):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for device in prefs.devices:
            device.use = True
        scene.cycles.device = "GPU"
    except Exception:
        scene.cycles.device = "CPU"
    scene.render.bake.margin = 2 * SUPERSAMPLE
    scene.render.bake.margin_type = "EXTEND"


def unwrap(obj, margin=0.02):
    """Smart-projects `obj`'s UVs with even texel density, packed to fill the texture."""
    _select_only(obj)
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj],
                                   selected_editable_objects=[obj]):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin,
                                 area_weight=1.0, scale_to_bounds=False)
        bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(margin=margin, rotate=True, shape_method="CONCAVE")
        bpy.ops.object.mode_set(mode="OBJECT")


def bake_model(obj, decals, size, colors=32, ao_strength=0.55, dither=0.6, out_dir=None, name=None):
    """Bakes `obj` (with `decals`) into `<name>_albedo.png` and, if anything glows,
    `<name>_glow.png` in `out_dir`. Returns (albedo_path, glow_path or None, palette size)."""
    name = name or obj.name
    big = size * SUPERSAMPLE
    setup_cycles()
    if not obj.data.uv_layers:
        unwrap(obj)

    albedo = _bake_pass(obj, "EMIT", 0, big, decals=[])
    covered = ~np.all(np.isclose(albedo, SENTINEL, atol=1e-3), axis=-1)
    for d in decals:
        d.hide_render = True
    ao = _bake_pass(obj, "AO", 0, big, decals=[], non_color=True)[..., 0]
    for d in decals:
        d.hide_render = False
    shade = (1.0 - ao_strength * (1.0 - np.clip(ao, 0, 1)))[..., None]
    glows = _has_glow([obj] + decals)
    glow = _bake_pass(obj, "EMIT", 1, big, decals=[]) if glows else None

    albedo_small, keep = _downsample(albedo * shade, covered, SUPERSAMPLE)
    glow_small = _downsample(glow, covered, SUPERSAMPLE)[0] if glows else None
    crisp = np.zeros(keep.shape, dtype=bool)
    if decals:
        # Decals land as whole texels in their own colour, like hand-placed pixel lettering: a
        # texel takes a decal's colour if the decal covers most of it, and is never dithered.
        mask = _bake_pass(obj, "EMIT", 2, big, decals=decals, background=(0, 0, 0))[..., 0] * covered
        colour = _bake_pass(obj, "EMIT", 0, big, decals=decals, background=(0, 0, 0))
        decal_small, _ = _downsample(colour * shade, mask > 0.5, SUPERSAMPLE)
        coverage = mask.reshape(size, SUPERSAMPLE, size, SUPERSAMPLE).mean(axis=(1, 3))
        crisp = (coverage >= 0.45) & keep
        albedo_small = np.where(crisp[..., None], decal_small, albedo_small)
        if glows:
            decal_glow = _bake_pass(obj, "EMIT", 1, big, decals=decals, background=(0, 0, 0))
            decal_glow_small, _ = _downsample(decal_glow, mask > 0.5, SUPERSAMPLE)
            glow_small = np.where(crisp[..., None], decal_glow_small, glow_small)

    albedo_small, palette = _quantize(albedo_small, keep, colors, dither, no_dither=crisp)
    albedo_path = f"{out_dir}/{name}_albedo.png"
    _save(albedo_small, albedo_path)

    glow_path = None
    if glows:
        glow_small = np.where(keep[..., None], glow_small, 0.0)
        glow_small, _ = _quantize(glow_small, keep, max(8, colors // 2), 0.0)
        glow_path = f"{out_dir}/{name}_glow.png"
        _save(glow_small, glow_path)

    _use_baked_material(obj, name, albedo_path, glow_path)
    return albedo_path, glow_path, palette


def bake_vertex_ao(obj, strength=0.45):
    """Bakes ambient occlusion into `obj`'s vertex colours (for kit pieces whose texture tiles)."""
    setup_cycles(samples=64)
    if not obj.data.color_attributes:
        obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    obj.data.color_attributes.active_color = obj.data.color_attributes[0]
    scene = bpy.context.scene
    scene.render.bake.target = "VERTEX_COLORS"
    _select_only(obj)
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj]):
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    scene.render.bake.target = "IMAGE_TEXTURES"
    data = obj.data.color_attributes[0].data
    values = np.empty(len(data) * 4, dtype=np.float32)
    data.foreach_get("color", values)
    values = values.reshape(-1, 4)
    values[:, :3] = 1.0 - strength * (1.0 - values[:, :3])
    data.foreach_set("color", values.ravel())


# Passes ----------------------------------------------------------------------------------------


def _bake_pass(obj, kind, pass_index, size, decals, non_color=False, background=None):
    image = bpy.data.images.new(f"bake_{kind}_{pass_index}", size, size, alpha=False, float_buffer=True)
    image.colorspace_settings.name = "Non-Color" if non_color else "Linear Rec.709"
    fill = background if background is not None else SENTINEL
    image.generated_color = (*fill, 1.0)
    nodes = []
    for slot in obj.material_slots:
        tree = slot.material.node_tree
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        tree.nodes.active = node
        nodes.append((tree, node))
    mats.set_pass(pass_index)
    selected = [obj] + list(decals)
    _select_only(obj, extra=decals)
    kwargs = dict(type=kind, margin=bpy.context.scene.render.bake.margin)
    if decals:
        kwargs.update(use_selected_to_active=True, cage_extrusion=0.015, max_ray_distance=0.03, margin=0)
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=selected,
                                   selected_editable_objects=selected):
        bpy.ops.object.bake(**kwargs)
    pixels = np.empty(size * size * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    for tree, node in nodes:
        tree.nodes.remove(node)
    bpy.data.images.remove(image)
    mats.set_pass(0)
    rgb = pixels.reshape(size, size, 4)[..., :3]
    # Bakes come out linear; the texture is stored and quantized as sRGB.
    rgb = rgb if non_color else _to_srgb(rgb)
    debug = os.environ.get("DS_DEBUG_PASSES")
    if debug:  # DS_DEBUG_PASSES=<dir> saves every raw pass for inspection
        _save(rgb, f"{debug}/{obj.name}_{kind}_{pass_index}_{'decals' if decals else 'base'}.png")
    return rgb


def _has_glow(objects):
    """Whether any recipe on `objects` emits in game (mats marks those that do)."""
    return any(slot.material and slot.material.get("glows", False)
               for obj in objects for slot in obj.material_slots)


# Image processing ------------------------------------------------------------------------------


def _to_srgb(rgb):
    rgb = np.clip(rgb, 0.0, 1.0)
    return np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(rgb, 1 / 2.4) - 0.055)


def _downsample(image, covered, factor):
    """Box-filters `image` down by `factor`, averaging only covered texels."""
    h, w, _ = image.shape
    weights = covered.astype(np.float32).reshape(h // factor, factor, w // factor, factor)
    blocks = image.reshape(h // factor, factor, w // factor, factor, 3)
    total = weights.sum(axis=(1, 3))
    summed = (blocks * weights[..., None]).sum(axis=(1, 3))
    keep = total > 0
    small = np.where(keep[..., None], summed / np.maximum(total, 1e-6)[..., None], 0.0)
    return small, keep


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32)


def _quantize(image, keep, colors, dither, no_dither=None):
    """Reduces `image` to at most `colors` colours (k-means over covered texels, seeded so builds
    repeat exactly), with an ordered dither of `dither` palette steps."""
    pixels = image[keep]
    if len(pixels) == 0:
        return image, 0
    rng = np.random.default_rng(0)
    k = min(colors, len(np.unique(np.round(pixels, 3), axis=0)))
    centres = pixels[rng.choice(len(pixels), size=k, replace=False)]
    for _ in range(16):
        distance = ((pixels[:, None, :] - centres[None, :, :]) ** 2).sum(-1)
        nearest = distance.argmin(1)
        for i in range(k):
            members = pixels[nearest == i]
            if len(members):
                centres[i] = members.mean(0)
    h, w, _ = image.shape
    if dither > 0 and k > 1:
        spacing = np.sort(np.sqrt(((centres[:, None] - centres[None]) ** 2).sum(-1)) + np.eye(k) * 9, axis=1)[:, 0]
        step = float(np.median(spacing))
        threshold = (BAYER4[np.arange(h)[:, None] % 4, np.arange(w)[None, :] % 4] + 0.5) / 16 - 0.5
        if no_dither is not None:
            threshold = np.where(no_dither, 0.0, threshold)
        image = image + threshold[..., None] * step * dither
    flat = image.reshape(-1, 3)
    distance = ((flat[:, None, :] - centres[None, :, :]) ** 2).sum(-1)
    result = centres[distance.argmin(1)].reshape(h, w, 3)
    result = np.where(keep[..., None], result, 0.0)
    return result, k


def _save(rgb, path):
    h, w, _ = rgb.shape
    image = bpy.data.images.new("save", w, h, alpha=False)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1), dtype=np.float32)], axis=-1)
    image.pixels.foreach_set(rgba.astype(np.float32).ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


# Materials -------------------------------------------------------------------------------------


def _use_baked_material(obj, name, albedo_path, glow_path):
    """Swaps `obj`'s recipes for one material showing the baked textures: what the glTF carries
    (by name, for Godot's import to replace with its PSX material) and what previews render."""
    clash = bpy.data.materials.get(name)
    if clash is not None:  # a recipe named like the model: keep the model's name for Godot
        clash.name = name + "_recipe"
    material = bpy.data.materials.new(name)
    if hasattr(material, "use_nodes"):
        material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.8
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    tree.links.new(bsdf.outputs[0], output.inputs["Surface"])
    albedo = tree.nodes.new("ShaderNodeTexImage")
    albedo.image = bpy.data.images.load(albedo_path)
    albedo.interpolation = "Closest"
    tree.links.new(albedo.outputs["Color"], bsdf.inputs["Base Color"])
    if glow_path:
        glow = tree.nodes.new("ShaderNodeTexImage")
        glow.image = bpy.data.images.load(glow_path)
        glow.interpolation = "Closest"
        tree.links.new(glow.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.material_index = 0


def _select_only(obj, extra=()):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    for o in extra:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj
