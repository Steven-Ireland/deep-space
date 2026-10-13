"""Writing a built model out: the .blend (for hand tweaks), the glTF for Godot, and the Godot
ShaderMaterial (psx_lit) its import swaps in by name (TECH §5)."""

import bpy

from . import ROOT


def save_blend(name):
    path = ROOT / "art" / "source" / f"{name}.blend"
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True, check_existing=False)
    return path


def export_glb(spec, model):
    path = ROOT / "assets" / "models" / spec.category / f"{spec.name}.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    model.low.select_set(True)
    for obj in model.extras:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = model.low
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_vertex_color="ACTIVE",
        export_extras=True,
        export_animations=bool(bpy.data.actions),
    )
    return path


def write_material(spec, albedo_path, glow_path):
    """assets/materials/<name>.tres: the PSX material Godot's import gives the model."""
    path = ROOT / "assets" / "materials" / f"{spec.name}.tres"
    path.parent.mkdir(parents=True, exist_ok=True)
    resources = ['[ext_resource type="Shader" path="res://game/rendering/psx_lit.gdshader" id="shader"]',
                 f'[ext_resource type="Texture2D" path="{_res(albedo_path)}" id="albedo"]']
    params = ['shader_parameter/albedo_texture = ExtResource("albedo")']
    if glow_path:
        resources.append(f'[ext_resource type="Texture2D" path="{_res(glow_path)}" id="glow"]')
        params.append('shader_parameter/emission_texture = ExtResource("glow")')
    params += [f"shader_parameter/roughness = {spec.roughness}",
               f"shader_parameter/metallic = {spec.metallic}",
               f"shader_parameter/specular = {spec.specular}"]
    text = "\n".join([
        '[gd_resource type="ShaderMaterial" format=3]',
        "",
        *resources,
        "",
        "[resource]",
        f'resource_name = "{spec.name}"',
        'shader = ExtResource("shader")',
        *params,
        "",
    ])
    path.write_text(text)
    return path


def _res(path):
    return "res://" + str(path).replace(str(ROOT) + "/", "")
