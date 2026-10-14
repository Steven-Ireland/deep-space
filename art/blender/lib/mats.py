"""Material recipes: the detailed surfaces a model is painted with before being baked down to its
low-res PSX texture (TECH §5). Each recipe is a Cycles node graph that *emits* its colour, so the
bake captures exact colours with no lighting in them. A Value node named PASS chooses what it
emits for each bake pass:

    0  albedo   the surface colour (paint, wear, grime)
    1  glow     what it emits in game (screens, lamps), black for most surfaces
    2  mask     white on decals, black elsewhere (which texels a decal covered)

Recipes return their material's name, for geo.Mesh parts. Colours are sRGB tuples.
"""

import bpy

from . import ROOT

PASS_NODE = "PASS"
SCANS = ROOT / "art" / "textures_src"  # CC0 photo scans (tools/fetch_textures.sh)
GRIME = (0.09, 0.075, 0.06)


def srgb(c):
    """An sRGB colour as Blender's linear RGBA."""
    def lin(x):
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1.0)


def set_pass(index):
    for material in bpy.data.materials:
        if material.node_tree and PASS_NODE in material.node_tree.nodes:
            material.node_tree.nodes[PASS_NODE].outputs[0].default_value = float(index)


class Graph:
    """A small helper for wiring node graphs without the boilerplate."""

    def __init__(self, material):
        self.material = material
        self.tree = material.node_tree
        self.tree.nodes.clear()
        self.x = 0

    def node(self, kind, **props):
        node = self.tree.nodes.new(kind)
        node.location = (self.x, 0)
        self.x += 200
        for key, value in props.items():
            setattr(node, key, value)
        return node

    def link(self, output, node, socket):
        self.tree.links.new(output, self._input(node, socket))

    def set(self, node, socket, value):
        self._input(node, socket).default_value = value

    def feed(self, node, socket, value):
        """Links `value` if it's a socket, else sets it."""
        if isinstance(value, bpy.types.NodeSocket):
            self.link(value, node, socket)
        else:
            self.set(node, socket, value)

    @staticmethod
    def _input(node, socket):
        if isinstance(socket, int):
            return node.inputs[socket]
        for s in node.inputs:
            if s.name == socket and s.enabled:
                return s
        raise KeyError(f"{node.bl_idname} has no enabled input {socket!r}")

    @staticmethod
    def out(node, socket=0):
        if isinstance(socket, int):
            return node.outputs[socket]
        for s in node.outputs:
            if s.name == socket and s.enabled:
                return s
        raise KeyError(f"{node.bl_idname} has no enabled output {socket!r}")

    # Building blocks --------------------------------------------------------------------------

    def coords(self):
        return self.out(self.node("ShaderNodeTexCoord"), "Object")

    def noise(self, scale, detail=4.0, roughness=0.55, stretch=(1, 1, 1), seed=0.0):
        vec = self.coords()
        if stretch != (1, 1, 1) or seed:
            mapping = self.node("ShaderNodeMapping")
            self.link(vec, mapping, "Vector")
            self.set(mapping, "Scale", stretch)
            self.set(mapping, "Location", (seed * 13.1, seed * 7.7, seed * 3.3))
            vec = self.out(mapping)
        n = self.node("ShaderNodeTexNoise")
        self.link(vec, n, "Vector")
        self.set(n, "Scale", scale)
        self.set(n, "Detail", detail)
        self.set(n, "Roughness", roughness)
        return self.out(n, "Factor")

    def math(self, op, a, b=0.0, clamp=False):
        m = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.feed(m, 0, a)
        self.feed(m, 1, b)
        return self.out(m)

    def compare(self, a, b):
        """1 where `a` equals `b` (to within 0.1), else 0."""
        m = self.node("ShaderNodeMath", operation="COMPARE")
        self.feed(m, 0, a)
        self.set(m, 1, b)
        self.set(m, 2, 0.1)
        return self.out(m)

    def ramp(self, value, lo, hi):
        """`value` mapped from [lo, hi] to [0, 1], clamped: a soft threshold."""
        r = self.node("ShaderNodeMapRange", clamp=True)
        self.feed(r, "Value", value)
        self.set(r, "From Min", lo)
        self.set(r, "From Max", hi)
        return self.out(r)

    def mix(self, factor, a, b, blend="MIX"):
        m = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_result=True)
        self.feed(m, "Factor", factor)
        self.feed(m, "A", a)
        self.feed(m, "B", b)
        return self.out(m, "Result")

    def edges(self, radius=0.012):
        """1 on convex edges, 0 on flat faces: where paint chips first."""
        bevel = self.node("ShaderNodeBevel", samples=8)
        self.set(bevel, "Radius", radius)
        geometry = self.node("ShaderNodeNewGeometry")
        dot = self.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        self.link(self.out(bevel), dot, 0)
        self.link(self.out(geometry, "Normal"), dot, 1)
        return self.ramp(self.math("SUBTRACT", 1.0, self.out(dot, "Value")), 0.002, 0.06)

    def cavity(self, distance=0.15):
        """1 in crevices and corners, 0 in the open: where grime collects."""
        ao = self.node("ShaderNodeAmbientOcclusion", samples=16)
        self.set(ao, "Distance", distance)
        return self.math("SUBTRACT", 1.0, self.out(ao, "AO"))

    def emission(self, color, strength=1.0):
        e = self.node("ShaderNodeEmission")
        self.feed(e, "Color", color)
        self.set(e, "Strength", strength)
        return self.out(e)

    def photo(self, scan, scale=1.0, colour=False):
        """A CC0 photo scan box-projected over the object at `scale` repeats per metre: its
        luminance (or colour), for real scratches and mottling under the authored colour."""
        image = bpy.data.images.load(str(SCANS / f"{scan}_Color.jpg"), check_existing=True)
        mapping = self.node("ShaderNodeMapping")
        self.link(self.coords(), mapping, "Vector")
        self.set(mapping, "Scale", (scale, scale, scale))
        tex = self.node("ShaderNodeTexImage", image=image, projection="BOX", projection_blend=0.25)
        self.link(self.out(mapping), tex, "Vector")
        if colour:
            return self.out(tex, "Color")
        grey = self.node("ShaderNodeRGBToBW")
        self.link(self.out(tex, "Color"), grey, 0)
        return self.out(grey)

    def detail(self, colour, scan, strength, scale):
        """`colour` with a photo scan's light and dark overlaid at `strength`."""
        if not scan or strength <= 0:
            return colour
        return self.mix(strength, colour, self._grey(self.photo(scan, scale)), blend="OVERLAY")

    def _grey(self, value):
        combine = self.node("ShaderNodeCombineColor")
        for i in range(3):
            self.link(value, combine, i)
        return self.out(combine)

    def finish(self, albedo, glow=None, mask=0.0):
        """Wires the three passes to the output, switched by the PASS value."""
        self.material["glows"] = glow is not None
        pass_value = self.node("ShaderNodeValue", name=PASS_NODE, label=PASS_NODE)
        pass_value.outputs[0].default_value = 0.0
        p = self.out(pass_value)
        is_glow = self.compare(p, 1.0)
        is_mask = self.compare(p, 2.0)
        glow_shader = self.emission(glow if glow is not None else (0, 0, 0, 1))
        mask_shader = self.emission((mask, mask, mask, 1.0))
        first = self.node("ShaderNodeMixShader")
        self.link(is_glow, first, 0)
        self.link(self.emission(albedo), first, 1)
        self.link(glow_shader, first, 2)
        second = self.node("ShaderNodeMixShader")
        self.link(is_mask, second, 0)
        self.link(self.out(first), second, 1)
        self.link(mask_shader, second, 2)
        output = self.node("ShaderNodeOutputMaterial")
        self.link(self.out(second), output, "Surface")


def _material(name):
    material = bpy.data.materials.get(name)
    if material is not None:
        return None
    material = bpy.data.materials.new(name)
    if hasattr(material, "use_nodes"):
        material.use_nodes = True
    return Graph(material)


def paint(name, color, wear=0.3, grime=0.35, under=(0.42, 0.42, 0.4), variation=0.07, scale=1.0,
          glow=None, streaks=0.0, detail="Metal009", detail_strength=0.35, detail_scale=0.6, rust=0.0):
    """Painted metal: colour with low-frequency variation and photo-scan detail, chipped back to
    `under` on worn edges, darkened with grime in crevices (and optionally in vertical streaks),
    and for derelicts, eaten by `rust` in patches and crevices."""
    g = _material(name)
    if g is None:
        return name
    base = srgb(color)
    dark = tuple(c * (1 - variation * 2) for c in base[:3]) + (1.0,)
    light = tuple(min(1.0, c * (1 + variation * 2)) for c in base[:3]) + (1.0,)
    varied = g.mix(g.noise(4.0 * scale, detail=3.0), dark, light)
    # A second, finer blotch layer so large faces never read as flat.
    varied = g.mix(g.ramp(g.noise(18.0 * scale, detail=6.0, seed=3), 0.35, 0.75), varied,
                   tuple(c * 0.93 for c in base[:3]) + (1.0,))
    colour = g.detail(varied, detail, detail_strength, detail_scale * scale)
    if wear > 0:
        chips = g.math("MULTIPLY", g.edges(), g.noise(26.0 * scale, detail=8.0, roughness=0.7, seed=1))
        chip_mask = g.ramp(chips, 0.55 - wear * 0.45, 0.62 - wear * 0.45)
        colour = g.mix(chip_mask, colour, srgb(under))
    if grime > 0:
        dirt = g.math("MULTIPLY", g.cavity(), g.math("ADD", 0.45, g.noise(7.0 * scale, seed=2)))
        if streaks > 0:
            streak = g.ramp(g.noise(9.0 * scale, detail=2.0, stretch=(1.0, 1.0, 0.08), seed=4), 0.5, 0.75)
            dirt = g.math("ADD", dirt, g.math("MULTIPLY", streak, streaks))
        colour = g.mix(g.math("MULTIPLY", g.ramp(dirt, 0.05, 0.9), grime), colour, srgb(GRIME))
    if rust > 0:
        patches = g.math("ADD", g.math("MULTIPLY", g.cavity(0.25), 0.8), g.noise(3.0 * scale, detail=6.0, seed=7))
        rust_mask = g.ramp(patches, 1.05 - rust * 0.5, 1.2 - rust * 0.5)
        # The scan gives rust its texture; a tint gives it its colour, from orange-brown to near-black.
        rust_colour = g.mix(1.0, g._grey(g.math("MULTIPLY", g.photo("Metal021", 0.8 * scale), 1.6)), srgb((0.72, 0.36, 0.16)),
                            blend="MULTIPLY")
        colour = g.mix(rust_mask, colour, rust_colour)
    g.finish(colour, glow=srgb(glow) if glow else None)
    return name


def metal(name, color=(0.5, 0.5, 0.48), grime=0.4, brushed=True, scale=1.0, detail="Metal009",
          detail_strength=0.5):
    """Bare or brushed metal: streaky variation and scratches, grime in crevices, bright worn edges."""
    g = _material(name)
    if g is None:
        return name
    base = srgb(color)
    stretch = (1.0, 1.0, 14.0) if brushed else (1, 1, 1)
    streak = g.noise(30.0 * scale, detail=4.0, stretch=stretch)
    colour = g.mix(streak, tuple(c * 0.8 for c in base[:3]) + (1.0,), tuple(min(1, c * 1.15) for c in base[:3]) + (1.0,))
    colour = g.detail(colour, detail, detail_strength, 1.2 * scale)
    colour = g.mix(g.math("MULTIPLY", g.edges(), 0.6), colour, tuple(min(1, c * 1.45) for c in base[:3]) + (1.0,))
    if grime > 0:
        dirt = g.math("MULTIPLY", g.cavity(), g.math("ADD", 0.4, g.noise(6.0 * scale, seed=5)))
        colour = g.mix(g.math("MULTIPLY", g.ramp(dirt, 0.05, 0.9), grime), colour, srgb(GRIME))
    g.finish(colour)
    return name


def plain(name, color, grime=0.25, variation=0.05, scale=1.0, detail="Concrete034", detail_strength=0.2):
    """Plastic, rubber, fabric: no chipping, gentle variation, a fine mottle, and grime."""
    return paint(name, color, wear=0.0, grime=grime, variation=variation, scale=scale, detail=detail,
                 detail_strength=detail_strength, detail_scale=2.0)


def glowing(name, color, base=None, flicker=0.15, streaks=0.0):
    """A screen, lamp lens or fuel window: dim `base` (default: a dark version of `color`) as
    albedo, `color` as glow, unevenly bright by `flicker`, with vertical `streaks` (a liquid)."""
    g = _material(name)
    if g is None:
        return name
    glow = srgb(color)
    albedo = srgb(base) if base else tuple(c * 0.35 for c in glow[:3]) + (1.0,)
    dim = tuple(c * (1 - flicker) for c in glow[:3]) + (1.0,)
    uneven = g.mix(g.ramp(g.noise(8.0, detail=2.0), 0.3, 0.8), dim, glow)
    if streaks > 0:
        streak = g.ramp(g.noise(22.0, detail=3.0, stretch=(1.0, 1.0, 0.12), seed=6), 0.4, 0.7)
        uneven = g.mix(g.math("MULTIPLY", streak, streaks), uneven,
                       tuple(min(1.0, c * 1.25 + 0.08) for c in glow[:3]) + (1.0,))
    g.finish(albedo, glow=uneven)
    return name


def decal(name, color, glow=False):
    """A flat-colour decal (stencil text, stripes, warning marks), baked on top of the surface
    under it. `glow` makes it light up in game too (screen text, indicator lamps)."""
    g = _material(name)
    if g is None:
        return name
    c = srgb(color)
    g.finish(c, glow=c if glow else None, mask=1.0)
    return name


def foil(name, color, scale=1.0):
    """Metallised film, a satellite's insulation blanket (gold, or silver): a crinkled sheet whose
    creases break the light into bright and dark facets, with a few glints along the folds."""
    g = _material(name)
    if g is None:
        return name
    base = srgb(color)
    # Creases: ridges where a noise field crosses its middle (|n - 0.5|), at two scales.
    coarse = g.math("ABSOLUTE", g.math("SUBTRACT", g.noise(9.0 * scale, detail=2.0, roughness=0.4), 0.5))
    fine = g.math("ABSOLUTE", g.math("SUBTRACT", g.noise(31.0 * scale, detail=1.0, roughness=0.3, seed=2), 0.5))
    facet = g.math("ADD", g.math("MULTIPLY", coarse, 1.3), g.math("MULTIPLY", fine, 0.7))
    dark = tuple(c * 0.42 for c in base[:3]) + (1.0,)
    light = tuple(min(1.0, c * 1.3 + 0.04) for c in base[:3]) + (1.0,)
    colour = g.mix(g.ramp(facet, 0.02, 0.55), light, dark)
    glint = g.ramp(g.math("SUBTRACT", 0.05, fine), 0.0, 0.04)
    colour = g.mix(g.math("MULTIPLY", glint, 0.6), colour, tuple(min(1.0, c * 1.6 + 0.15) for c in base[:3]) + (1.0,))
    g.finish(colour)
    return name
