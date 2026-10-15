"""Writing a built model out: the .blend (for hand tweaks), the glTF for Godot, and the Godot
ShaderMaterial (psx_lit) its import swaps in by name (TECH §5)."""

import json
import struct

import bpy
import numpy as np

from . import ROOT


def save_blend(name):
    path = ROOT / "art" / "source" / f"{name}.blend"
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True, check_existing=False)
    return path


def export_glb(spec, model, keep_uvs=False):
    """Exports the model to assets/models/<category>/<name>.glb. With `keep_uvs` (a rebuild that
    keeps its bake, build.py --keep-texture), the UVs the texture was baked on are carried over from
    the .glb already there: Blender's unwrap is repeatable on one machine but packs islands
    differently on another, so a fresh unwrap wouldn't match the texture."""
    path = ROOT / "assets" / "models" / spec.category / f"{spec.name}.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    before = path.read_bytes() if keep_uvs and path.exists() else None
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
    if keep_uvs:
        if before is None:
            raise RuntimeError(f"--keep-texture: no {path.name} to keep the UVs of")
        path.write_bytes(_carry_uvs(before, path.read_bytes(), spec.name))
    return path


# Carrying UVs between two exports of the same mesh ----------------------------------------------

_TYPES = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def _carry_uvs(old, new, name):
    """`new` (a .glb's bytes) with every primitive's TEXCOORD_0 taken from `old`'s, which must be
    the same mesh: the same vertices, normals, skin and triangles, in the same order."""
    old_doc, old_blob = _glb(old)
    new_doc, new_blob = _glb(new)
    blob = bytearray(new_blob)
    old_meshes = {m["name"]: m for m in old_doc.get("meshes", [])}
    for mesh in new_doc.get("meshes", []):
        before = old_meshes.get(mesh["name"])
        if before is None or len(before["primitives"]) != len(mesh["primitives"]):
            raise RuntimeError(f"--keep-texture: {name}'s mesh {mesh['name']} changed; bake it again")
        for was, now in zip(before["primitives"], mesh["primitives"]):
            for key in ["POSITION", "NORMAL", "JOINTS_0", "WEIGHTS_0", None]:
                if key is not None and (key in was["attributes"]) != (key in now["attributes"]):
                    raise RuntimeError(f"--keep-texture: {name}'s {key} changed; bake it again")
                if key is not None and key not in now["attributes"]:
                    continue
                a = _read(old_doc, old_blob, was["attributes"][key] if key else was["indices"])
                b = _read(new_doc, new_blob, now["attributes"][key] if key else now["indices"])
                if a.shape != b.shape or not np.allclose(a, b, atol=1e-5):
                    raise RuntimeError(f"--keep-texture: {name}'s {key or 'triangles'} changed; bake it again")
            if "TEXCOORD_0" in now["attributes"]:
                uv = _read(old_doc, old_blob, was["attributes"]["TEXCOORD_0"])
                _write(new_doc, blob, now["attributes"]["TEXCOORD_0"], uv)
    return _glb_bytes(new, bytes(blob))


def _glb(data):
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    at = 20 + length
    size = struct.unpack_from("<I", data, at)[0]
    return doc, data[at + 8:at + 8 + size]


def _glb_bytes(data, blob):
    """`data` (a .glb) with its binary chunk replaced by `blob` (the same size)."""
    length = struct.unpack_from("<I", data, 12)[0]
    at = 20 + length + 8
    return data[:at] + blob + data[at + len(blob):]


def _slot(doc, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    dtype = np.dtype(_TYPES[acc["componentType"]])
    width = _WIDTH[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 0) or dtype.itemsize * width
    return acc["count"], dtype, width, start, stride


def _read(doc, blob, index):
    count, dtype, width, start, stride = _slot(doc, index)
    rows = [np.frombuffer(blob, dtype=dtype, count=width, offset=start + i * stride) for i in range(count)]
    return np.array(rows, dtype=np.float64).reshape(count, width)


def _write(doc, blob, index, values):
    count, dtype, width, start, stride = _slot(doc, index)
    if values.shape != (count, width):
        raise RuntimeError("--keep-texture: the UVs don't fit")
    for i in range(count):
        blob[start + i * stride:start + i * stride + dtype.itemsize * width] = values[i].astype(dtype).tobytes()


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
