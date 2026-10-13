"""Builds game models from their generators (TECH §5).

    Blender -b --factory-startup -P art/blender/build.py -- [targets...] [--no-preview]

A target is a generator module (`items` builds everything in art/blender/items.py) or a model
name (`fuel_cell`); with none, everything is built. Each model goes: build -> bake -> .blend ->
.glb + .tres -> preview sheet, and prints a line of stats to check against its budget.
"""

import importlib
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402

import lib  # noqa: E402
from lib import bake, output, preview  # noqa: E402


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    targets = [a for a in args if not a.startswith("--")]
    for path in sorted(Path(__file__).parent.glob("*.py")):
        if path.stem != "build":
            importlib.import_module(path.stem)
    specs = [s for s in lib.ASSETS.values() if not targets or s.name in targets or s.module in targets]
    if not specs:
        sys.exit(f"Nothing matches {targets}. Known: {sorted(lib.ASSETS)}")
    for spec in specs:
        started = time.time()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        model = spec.build()
        triangles = sum(len(p.vertices) - 2 for p in model.low.data.polygons)
        dimensions = tuple(round(d, 3) for d in model.low.dimensions)
        textures = lib.ROOT / "assets" / "textures"
        textures.mkdir(parents=True, exist_ok=True)
        albedo, glow, palette = bake.bake_model(model.low, model.decals, spec.texture, spec.colors,
                                                spec.ao, spec.dither, out_dir=str(textures), name=spec.name)
        for decal in model.decals:
            bpy.data.objects.remove(decal)
        output.save_blend(spec.name)
        output.export_glb(spec, model)
        output.write_material(spec, albedo, glow)
        if "--no-preview" not in args:
            preview.render(spec.name, [model.low])
        stats = dict(name=spec.name, triangles=triangles, dimensions=dimensions,
                     texture=spec.texture, palette=palette, glow=glow is not None,
                     seconds=round(time.time() - started, 1))
        print("BUILT " + json.dumps(stats))


main()
