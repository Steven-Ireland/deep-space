"""Builds game models from their generators (TECH §5).

    Blender -b --factory-startup -P art/blender/build.py -- [targets...] [--no-preview] [--keep-texture]

A target is a generator module (`items` builds everything in art/blender/items.py) or a model
name (`fuel_cell`); with none, everything is built. Each model goes: build -> bake -> .blend ->
.glb + .tres -> (a belt icon, for things carried) -> preview sheet, and prints a line of stats to
check against its budget.

--keep-texture rebuilds and exports the model (its mesh, rig and clips: a new clip, say) without
baking: the texture, glow and material already in assets/ stay as they are, so the photo scans
aren't needed. Only for changes that leave the mesh and its UVs alone; no icon or preview.
"""

import importlib
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402

import lib  # noqa: E402
from lib import bake, icon, mats, output, preview  # noqa: E402


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    targets = [a for a in args if not a.startswith("--")]
    keep = "--keep-texture" in args
    lib.KEEP_TEXTURE = keep
    for path in sorted(Path(__file__).parent.glob("*.py")):
        if path.stem != "build":
            importlib.import_module(path.stem)
    specs = [s for s in lib.ASSETS.values() if not targets or s.name in targets or s.module in targets]
    if not specs:
        sys.exit(f"Nothing matches {targets}. Known: {sorted(lib.ASSETS)}")
    for spec in specs:
        started = time.time()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        mats.STAND_INS.clear()
        model = spec.build()
        for extra in model.extras:  # colliders and sockets: exported, never baked or rendered
            extra.hide_render = True
        triangles = sum(len(p.vertices) - 2 for p in model.low.data.polygons)
        dimensions = tuple(round(d, 3) for d in model.low.dimensions)
        textures = lib.ROOT / "assets" / "textures"
        textures.mkdir(parents=True, exist_ok=True)
        if keep:
            albedo, glow, palette = bake.keep_baked(model.low, out_dir=str(textures), name=spec.name)
        else:
            albedo, glow, palette = bake.bake_model(model.low, model.decals, spec.texture, spec.colors,
                                                    spec.ao, spec.dither, out_dir=str(textures), name=spec.name)
        for decal in model.decals:
            bpy.data.objects.remove(decal)
        if model.after_bake:
            model.after_bake(model)
        output.save_blend(spec.name)
        output.export_glb(spec, model, keep_uvs=keep)
        if not keep:
            output.write_material(spec, albedo, glow)
        shown = [model.low] + [e for e in model.extras if e.type == "MESH" and not e.name.endswith("-colonly")]
        if spec.category in ("items", "weapons") and not keep:
            icon.render(spec.name, shown)
        if "--no-preview" not in args and not keep:
            preview.render(spec.name, shown, spec.angles)
        stats = dict(name=spec.name, triangles=triangles, dimensions=dimensions,
                     texture=spec.texture, palette=palette, glow=glow is not None,
                     seconds=round(time.time() - started, 1))
        if mats.STAND_INS:
            # Baked over stand-ins for missing photo scans (lib/mats.py): a placeholder texture.
            stats["stand_ins"] = sorted(mats.STAND_INS)
        print("BUILT " + json.dumps(stats))


main()
