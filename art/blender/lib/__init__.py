"""Shared library for the Blender asset generators (TECH §5).

A generator module (art/blender/<family>.py) registers each model it can build with @asset; the
builder returns a Model: the game mesh, the decal geometry baked onto it, and extras exported
beside it (sockets, colliders). build.py runs the rest of the pipeline.
"""

from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ASSETS = {}
## Set by build.py --keep-texture: models are rebuilt and exported (mesh, rig, clips) without
## baking, keeping the textures and material already in assets/; the recipes' photo scans aren't
## needed then.
KEEP_TEXTURE = False


@dataclass
class Spec:
    name: str
    category: str
    build: object
    module: str
    texture: int = 128       # final texture size (square), px
    colors: int = 32         # palette size after quantizing
    ao: float = 0.55         # how much baked AO darkens the texture
    dither: float = 0.6      # ordered dither strength, in palette steps
    roughness: float = 0.85  # Godot material parameters
    metallic: float = 0.0
    specular: float = 0.3
    angles: tuple = ()       # preview (azimuth, elevation) pairs; default views if empty


@dataclass
class Model:
    low: object                                  # the game mesh
    decals: list = field(default_factory=list)   # geometry baked on top of it, then discarded
    extras: list = field(default_factory=list)   # exported with it: SOCKET_* empties, colliders
    after_bake: object = None                    # fn(model), e.g. to split the baked mesh in parts


def asset(name, category, **options):
    """Registers the decorated function as the builder of model `name`, exported to
    assets/models/<category>/<name>.glb."""
    def register(fn):
        ASSETS[name] = Spec(name=name, category=category, build=fn, module=fn.__module__, **options)
        return fn
    return register
