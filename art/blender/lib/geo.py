"""The modelling toolkit the asset generators build with (TECH §5).

A Mesh is a bmesh that parts are added to: boxes, cylinders, lathed profiles, extruded outlines,
swept pipes and flat quads. Every part takes a material (a name from mats) and a placement, and
returns its faces so they can be inset, extruded or bevelled further. Units are metres; +Z is up,
-Y is the model's front (Blender's convention, which the glTF exporter turns into Godot's).
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def place(at=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """A transform: translate `at`, rotate `rot` (Euler XYZ, degrees), scale `scale`."""
    rx, ry, rz = (math.radians(a) for a in rot)
    rotation = (Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X"))
    s = Matrix.Diagonal((*scale, 1.0))
    return Matrix.Translation(Vector(at)) @ rotation @ s


def frame(centre, normal, up=(0, 0, 1), lift=0.002):
    """A placement on a surface: local X runs along it (right), Z up it, and -Y points out of it
    along `normal`, lifted `lift` off it. For decals and anything mounted flat on a face."""
    n = Vector(normal).normalized()
    u = Vector(up)
    u = (u - n * u.dot(n)).normalized()
    t = u.cross(n).normalized()
    m = Matrix.Identity(4)
    m.col[0][:3] = t
    m.col[1][:3] = -n
    m.col[2][:3] = u
    m.col[3][:3] = Vector(centre) + n * lift
    return m


def clip(points, x0, x1, z0, z1):
    """`points` (an (x, z) polygon) clipped to the rectangle [x0, x1] x [z0, z1], so stripes and
    marks stop at the edge of the face they're on."""
    def cut(pts, inside, cross):
        out = []
        for i, p in enumerate(pts):
            q = pts[i - 1]
            if inside(p):
                if not inside(q):
                    out.append(cross(q, p))
                out.append(p)
            elif inside(q):
                out.append(cross(q, p))
        return out

    def at_x(x):
        return lambda a, b: (x, a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0]))

    def at_z(z):
        return lambda a, b: (a[0] + (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]), z)

    pts = list(points)
    for inside, cross in ((lambda p: p[0] >= x0, at_x(x0)), (lambda p: p[0] <= x1, at_x(x1)),
                          (lambda p: p[1] >= z0, at_z(z0)), (lambda p: p[1] <= z1, at_z(z1))):
        pts = cut(pts, inside, cross)
        if not pts:
            break
    return pts


class Mesh:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.materials = []
        self.groups = []      # vertex group names, for rigid parts bound to bones (rig.py)
        self._group = None

    # Parts --------------------------------------------------------------------------------------

    def box(self, size, material, at=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, segments=1):
        """A box `size` (x, y, z) centred on `at`, edges optionally bevelled."""
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        bmesh.ops.scale(self.bm, vec=Vector(size), verts=verts)
        faces = self._finish(self._faces_of(verts), material, place(at, rot))
        return self._bevel(faces, verts, bevel, segments)

    def cylinder(self, radius, depth, material, sides=8, at=(0, 0, 0), rot=(0, 0, 0), radius_top=None,
                 caps=True):
        """A cylinder (or cone, with `radius_top`) along Z, centred on `at`. Flat-sided: PSX."""
        geom = bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=sides,
                                     radius1=radius, radius2=radius if radius_top is None else radius_top,
                                     depth=depth)
        faces = self._faces_of(geom["verts"])
        return self._finish(faces, material, place(at, rot))

    def lathe(self, profile, material, sides=8, at=(0, 0, 0), rot=(0, 0, 0), cap_start=True, cap_end=True,
              angle_offset=None):
        """A surface of revolution around Z from `profile`, a list of (radius, z) from bottom to top.
        Ends with a radius above zero are capped with an n-gon."""
        offset = math.pi / sides if angle_offset is None else angle_offset
        rings = []
        for r, z in profile:
            ring = []
            for i in range(sides):
                a = offset + 2 * math.pi * i / sides
                ring.append(self.bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
            rings.append(ring)
        faces = []
        for lower, upper in zip(rings, rings[1:]):
            for i in range(sides):
                j = (i + 1) % sides
                faces.append(self.bm.faces.new((lower[i], lower[j], upper[j], upper[i])))
        if cap_start and profile[0][0] > 0:
            faces.append(self.bm.faces.new(list(reversed(rings[0]))))
        if cap_end and profile[-1][0] > 0:
            faces.append(self.bm.faces.new(rings[-1]))
        return self._finish(faces, material, place(at, rot))

    def prism(self, outline, depth, material, at=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, segments=1):
        """An outline of (x, z) points (counter-clockwise, seen from the front) extruded `depth`
        along Y and centred on it: brackets, consoles' side profiles, silhouettes."""
        front = [self.bm.verts.new((x, -depth / 2, z)) for x, z in outline]
        back = [self.bm.verts.new((x, depth / 2, z)) for x, z in outline]
        n = len(outline)
        faces = [self.bm.faces.new(front), self.bm.faces.new(list(reversed(back)))]
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new((front[j], front[i], back[i], back[j])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        faces = self._finish(faces, material, place(at, rot))
        return self._bevel(faces, front + back, bevel, segments)

    def pipe(self, points, radius, material, sides=6, caps=True):
        """A tube swept through `points` (world positions), mitred at the joints: pipes, cables.
        Its cross-section is carried along by parallel transport, so it never twists."""
        points = [Vector(p) for p in points]
        n = len(points)
        rings = []
        side = None
        prev_dir = None
        for i, p in enumerate(points):
            d_in = (p - points[i - 1]).normalized() if i > 0 else None
            d_out = (points[i + 1] - p).normalized() if i < n - 1 else None
            direction = (d_in + d_out).normalized() if d_in and d_out else (d_out or d_in)
            if side is None:
                helper = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
                side = direction.cross(helper).normalized()
            else:
                side = prev_dir.rotation_difference(direction) @ side
                side = (side - direction * side.dot(direction)).normalized()
            up = direction.cross(side).normalized()
            prev_dir = direction
            # Stretch the joint's ring within the bend plane so the tube keeps its radius.
            bend_axis, stretch = None, 1.0
            if d_in and d_out and d_in.cross(d_out).length > 1e-6:
                bend_axis = d_in.cross(d_out).normalized().cross(direction).normalized()
                stretch = 1.0 / max(math.cos(d_in.angle(d_out) / 2), 0.5)
            ring = []
            for k in range(sides):
                a = 2 * math.pi * k / sides
                offset = (side * math.cos(a) + up * math.sin(a)) * radius
                if bend_axis is not None:
                    offset += bend_axis * offset.dot(bend_axis) * (stretch - 1.0)
                ring.append(self.bm.verts.new(p + offset))
            rings.append(ring)
        faces = []
        for lower, upper in zip(rings, rings[1:]):
            for k in range(sides):
                j = (k + 1) % sides
                faces.append(self.bm.faces.new((lower[k], lower[j], upper[j], upper[k])))
        if caps:
            faces.append(self.bm.faces.new(list(reversed(rings[0]))))
            faces.append(self.bm.faces.new(rings[-1]))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return self._finish(faces, material, None)

    def quad(self, width, height, material, at=(0, 0, 0), rot=(0, 0, 0)):
        """A flat quad facing -Y (the front), `width` along X and `height` along Z."""
        w, h = width / 2, height / 2
        verts = [self.bm.verts.new(v) for v in ((-w, 0, -h), (w, 0, -h), (w, 0, h), (-w, 0, h))]
        return self._finish([self.bm.faces.new(verts)], material, place(at, rot))

    def polygon(self, points, material, matrix=None):
        """A flat n-gon from (x, z) points (counter-clockwise seen from the front), in the XZ plane
        facing -Y, placed by `matrix` (e.g. frame()). Stripes, plates, warning marks."""
        if len(points) < 3:
            return []
        verts = [self.bm.verts.new((x, 0.0, z)) for x, z in points]
        face = self.bm.faces.new(verts)
        if face.normal.y > 0:
            face.normal_flip()
        return self._finish([face], material, matrix)

    def bone(self, name):
        """Parts added after this belong wholly to bone `name` (PSX-style rigid segments)."""
        if name not in self.groups:
            self.groups.append(name)
        self._group = self.groups.index(name)
        return self

    # Operations on faces ------------------------------------------------------------------------

    def inset(self, faces, thickness, depth=0.0, material=None, individual=True):
        """Insets `faces` (panel lines, screens, vents), optionally pushed in by `depth`. Returns the
        inner faces; the rims keep their material, the inner faces take `material` if given."""
        op = bmesh.ops.inset_individual if individual else bmesh.ops.inset_region
        kwargs = dict(faces=faces, thickness=thickness, depth=-depth, use_even_offset=True)
        if not individual:
            kwargs["use_boundary"] = True
        op(self.bm, **kwargs)
        faces = [f for f in faces if f.is_valid]
        if material is not None:
            self.paint(faces, material)
        return faces

    def extrude(self, faces, distance, material=None):
        """Pushes `faces` out along their normals by `distance` (in if negative). Returns the caps."""
        result = bmesh.ops.extrude_discrete_faces(self.bm, faces=faces)
        caps = result["faces"]
        for f in caps:
            bmesh.ops.translate(self.bm, vec=f.normal * distance, verts=list(f.verts))
        for f in faces:
            if f.is_valid:
                self.bm.faces.remove(f)
        if material is not None:
            self.paint(caps, material)
        return caps

    def paint(self, faces, material):
        index = self._slot(material)
        for f in faces:
            f.material_index = index

    def faces(self, among=None, normal=None, min_dot=0.9, where=None):
        """Faces (of `among`, or all) facing `normal` and/or passing `where(face_centre)`."""
        result = []
        for f in (among if among is not None else self.bm.faces):
            if not f.is_valid:
                continue
            if normal is not None and f.normal.dot(Vector(normal).normalized()) < min_dot:
                continue
            if where is not None and not where(f.calc_center_median()):
                continue
            result.append(f)
        return result

    def transform(self, faces, matrix):
        verts = list({v for f in faces for v in f.verts})
        bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)

    def mirror(self, faces=None, axis="X"):
        """Adds a copy of `faces` (or everything) mirrored across the plane through the origin
        normal to `axis`: build one side of a symmetrical model, mirror it to the other."""
        faces = faces or list(self.bm.faces)
        result = bmesh.ops.duplicate(self.bm, geom=faces)
        new_faces = [g for g in result["geom"] if isinstance(g, bmesh.types.BMFace)]
        verts = list({v for f in new_faces for v in f.verts})
        flip = {"X": (-1, 1, 1), "Y": (1, -1, 1), "Z": (1, 1, -1)}[axis]
        bmesh.ops.scale(self.bm, vec=flip, verts=verts)
        bmesh.ops.reverse_faces(self.bm, faces=new_faces)
        return new_faces

    def mirror_x(self, faces=None):
        return self.mirror(faces, "X")

    def subdivide(self, max_edge=1.0):
        """Splits edges longer than `max_edge`, so big faces don't swim too far under affine
        texturing (PSX games did the same)."""
        for _ in range(6):
            long = [e for e in self.bm.edges if e.calc_length() > max_edge * 1.01]
            if not long:
                return
            bmesh.ops.subdivide_edges(self.bm, edges=long, cuts=1, use_grid_fill=True)

    # Output -------------------------------------------------------------------------------------

    def to_object(self, collection=None):
        """The finished mesh as an object, flat-shaded, with its materials (created by mats)."""
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        data = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(data)
        self.bm.free()
        for name in self.materials:
            data.materials.append(bpy.data.materials[name])
        for polygon in data.polygons:
            polygon.use_smooth = False
        obj = bpy.data.objects.new(self.name, data)
        (collection or bpy.context.scene.collection).objects.link(obj)
        for name in self.groups:
            obj.vertex_groups.new(name=name)
        return obj

    # Internals ----------------------------------------------------------------------------------

    def _bevel(self, faces, verts, width, segments):
        """Bevels the edges of a finished part. New faces inherit material and placement from the
        faces they grow out of, so this runs after _finish."""
        if width <= 0:
            return faces
        edges = list({e for f in faces for e in f.edges})
        result = bmesh.ops.bevel(self.bm, geom=edges, offset=width, segments=segments,
                                 affect="EDGES", profile=0.5, clamp_overlap=True)
        verts = [v for v in verts if v.is_valid] + list(result["verts"])
        return self._faces_of(verts)

    def _slot(self, material):
        if material not in self.materials:
            self.materials.append(material)
        return self.materials.index(material)

    def _faces_of(self, verts):
        return list({f for v in verts for f in v.link_faces})

    def _finish(self, faces, material, matrix):
        index = self._slot(material)
        for f in faces:
            f.material_index = index
            f.smooth = False
        if self._group is not None:
            deform = self.bm.verts.layers.deform.verify()
            for v in {v for f in faces for v in f.verts}:
                v[deform].clear()
                v[deform][self._group] = 1.0
        if matrix is not None:
            self.transform(faces, matrix)
        return faces


def text(body, size, material, at=(0, 0, 0), rot=(0, 0, 0), matrix=None, align="CENTER", collection=None,
         extrude=0.0):
    """Stencil-style text as mesh geometry (a decal source, baked into a texture): `size` is the
    cap height in metres. Lies in the XZ plane facing -Y, placed by `at`/`rot` or by `matrix`
    (e.g. frame(), to sit on any face)."""
    curve = bpy.data.curves.new("text", "FONT")
    curve.body = body
    curve.size = size / 0.7
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.extrude = extrude
    obj = bpy.data.objects.new("text", curve)
    (collection or bpy.context.scene.collection).objects.link(obj)
    obj.data.materials.append(bpy.data.materials[material])
    upright = Matrix.Rotation(math.radians(90), 4, "X")
    obj.matrix_world = (matrix if matrix is not None else place(at, rot)) @ upright
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    mesh_obj = bpy.data.objects.new("text_mesh", mesh)
    mesh_obj.matrix_world = obj.matrix_world
    (collection or bpy.context.scene.collection).objects.link(mesh_obj)
    bpy.data.objects.remove(obj)
    bpy.context.view_layer.update()
    return mesh_obj


def split_object(obj, parts):
    """Splits `obj` into one object per entry of `parts` ({name: predicate(face_centre)}), keeping
    UVs and materials: e.g. a baked door into leaves Godot can slide apart. Removes `obj`."""
    result = []
    for name, keep in parts.items():
        data = obj.data.copy()
        bm = bmesh.new()
        bm.from_mesh(data)
        doomed = [f for f in bm.faces if not keep(f.calc_center_median())]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(data)
        bm.free()
        part = bpy.data.objects.new(name, data)
        part.matrix_world = obj.matrix_world
        for collection in obj.users_collection:
            collection.objects.link(part)
        result.append(part)
    bpy.data.objects.remove(obj)
    for name, part in zip(parts, result):
        part.name = name
        part.data.name = name
    return result


def screen(name, width, height, matrix, material="crt_screen", bulge=0.012, grid=(4, 3)):
    """A CRT face: a slightly bulged grid `width` x `height` facing -Y in its own frame, placed by
    `matrix`, with UVs running 0..1 across it so Godot can show a terminal's SubViewport on it
    exactly. Not baked: it keeps the `crt_screen` material for the terminal to replace."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    cols, rows = grid
    verts = {}
    for j in range(rows + 1):
        for i in range(cols + 1):
            u, v = i / cols, j / rows
            x, z = (u - 0.5) * width, (v - 0.5) * height
            # A gentle dome toward the viewer, deepest in the middle.
            dome = bulge * (1 - (2 * u - 1) ** 2) * (1 - (2 * v - 1) ** 2)
            verts[i, j] = (bm.verts.new((x, -dome, z)), (u, v))
    for j in range(rows):
        for i in range(cols):
            quad = [verts[i, j], verts[i + 1, j], verts[i + 1, j + 1], verts[i, j + 1]]
            face = bm.faces.new([q[0] for q in quad])
            for loop, (_, coords) in zip(face.loops, quad):
                loop[uv].uv = coords
            if face.normal.y > 0:
                face.normal_flip()
    bmesh.ops.transform(bm, matrix=matrix, verts=list(bm.verts))
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()
    mat = bpy.data.materials.get(material) or bpy.data.materials.new(material)
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def screen_round(name, radius, matrix, material="crt_screen", sides=16, bulge=0.01):
    """A round CRT face (a scanner scope): a domed disc facing -Y, UVs planar 0..1 across its
    bounding square, so the terminal draws a round display into the middle of its viewport."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    centre = bm.verts.new((0, -bulge, 0))
    ring = [bm.verts.new((radius * math.cos(2 * math.pi * i / sides), 0, radius * math.sin(2 * math.pi * i / sides)))
            for i in range(sides)]
    for i in range(sides):
        face = bm.faces.new((centre, ring[i], ring[(i + 1) % sides]))
        if face.normal.y > 0:
            face.normal_flip()
        for loop in face.loops:
            x, _, z = loop.vert.co
            loop[uv].uv = (x / (2 * radius) + 0.5, z / (2 * radius) + 0.5)
    bmesh.ops.transform(bm, matrix=matrix, verts=list(bm.verts))
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()
    data.materials.append(bpy.data.materials.get(material) or bpy.data.materials.new(material))
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj
