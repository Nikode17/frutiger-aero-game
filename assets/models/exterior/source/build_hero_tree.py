# Construye tree_hero.glb (versión de juego del Jacaranda Tree de Poly Haven, CC0):
# tronco LOD1, ramas sin las ramitas más finas y diezmadas, y racimos de hojas reducidos,
# con normales de copa suaves. Necesita el .blend original (no está en el repositorio):
#   https://dl.polyhaven.org/file/ph-assets/Models/blend/1k/jacaranda_tree/jacaranda_tree_1k.blend
# Uso (Blender en segundo plano; por MCP el cálculo bloquea la interfaz):
#   blender -b jacaranda_tree_1k.blend --python build_hero_tree.py -- <salida.glb> <salida.blend>
#       <densidad> <tamaño racimos> <diezmado ramas> <escala> <radio ramitas>
# Valores usados: 0.4 2.2 0.45 0.72 0.012
import bpy, bmesh, math, sys, time
from mathutils import Vector, Matrix

T0 = time.time()
def log(*a):
    print("[%6.1fs]" % (time.time() - T0), *a, flush=True)

argv = sys.argv[sys.argv.index("--") + 1:]
OUT_GLB, OUT_BLEND = argv[0], argv[1]
DENS = float(argv[2]) if len(argv) > 2 else 0.25     # fracción de la densidad original de racimos
SIZE = float(argv[3]) if len(argv) > 3 else 1.6      # escala de los racimos para compensar
DECIMATE = float(argv[4]) if len(argv) > 4 else 0.2  # proporción de polígonos que se quedan en las ramas
SCALE = float(argv[5]) if len(argv) > 5 else 0.62    # escala final del árbol

# Fuera los objetos realizados de millones de polígonos: no se usan
for name in ("jacaranda_tree_LOD0", "jacaranda_tree_LOD1", "jacaranda_tree_trunk_LOD0"):
    ob = bpy.data.objects.get(name)
    if ob:
        bpy.data.objects.remove(ob, do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
log("limpio; argumentos", argv)

src = bpy.data.objects["jacaranda_tree_geometry_nodes"]
branch_mesh = src.data
n_base = len(branch_mesh.polygons)
log("ramas base:", n_base, "polígonos")
# Las caras de las ramas se marcan para poder quitarlas del resultado (solo queremos hojas)
attr = branch_mesh.attributes.new("is_base", 'INT', 'FACE')
attr.data.foreach_set("value", [1] * n_base)
mods = list(src.modifiers)
scene = bpy.context.scene

def evaluated_copy(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    ev = ob.evaluated_get(dg)
    return bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)

pieces = []   # mallas en el espacio local del árbol
for k, mod in enumerate(mods):
    for j, other in enumerate(mods):
        other.show_viewport = (j == k)
    mod["Input_4"] = mod["Input_4"] * DENS
    mod["Input_5"] = mod["Input_5"] * SIZE
    mod["Input_6"] = mod["Input_6"] * SIZE
    branch_mesh.update()
    me = evaluated_copy(src)
    # Solo hojas: fuera las caras con material de ramas (las ramas de entrada y los
    # tallitos de los racimos; las ramitas ya van en la malla de ramas diezmada)
    leaf_slot = [i for i, m in enumerate(me.materials) if m and m.name == "jacaranda_tree_leaves"][0]
    bm = bmesh.new()
    bm.from_mesh(me)
    kill = [f for f in bm.faces if f.material_index != leaf_slot]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(me)
    bm.free()
    log("hojas", mod.name, len(me.polygons), "polígonos (quitadas", len(kill), "de ramas)")
    pieces.append(me)
src.modifiers.clear()

# Ramas: fuera las ramitas más finas (quedan cubiertas por las hojas) y diezmado suave del
# resto para que las puntas no queden dentadas
import numpy as np
TWIG_RADIUS = float(argv[6]) if len(argv) > 6 else 0.012
bmesh_src = branch_mesh.copy()
r = np.empty(len(bmesh_src.vertices), dtype=np.float32)
bmesh_src.attributes["radius"].data.foreach_get("value", r)
pv = np.empty(len(bmesh_src.loops), dtype=np.int32); bmesh_src.loops.foreach_get("vertex_index", pv)
lstart = np.empty(len(bmesh_src.polygons), dtype=np.int32); bmesh_src.polygons.foreach_get("loop_start", lstart)
face_r = np.maximum.reduceat(r[pv], lstart)
thin = set(np.nonzero(face_r < TWIG_RADIUS)[0].tolist())
bm = bmesh.new()
bm.from_mesh(bmesh_src)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in thin], context='FACES')
bm.to_mesh(bmesh_src)
bm.free()
log("ramitas finas quitadas:", len(thin), "quedan", len(bmesh_src.polygons))
ob = bpy.data.objects.new("branches_tmp", bmesh_src)
scene.collection.objects.link(ob)
dec = ob.modifiers.new("dec", 'DECIMATE')
dec.ratio = DECIMATE
me = evaluated_copy(ob)
log("ramas diezmadas (ratio %.3f, modo %s)" % (dec.ratio, dec.decimate_type), len(me.polygons), "polígonos")
pieces.append(me)
bpy.data.objects.remove(ob, do_unlink=True)

# Tronco LOD1 (en su propio espacio, que coincide con el del árbol)
trunk = bpy.data.objects["jacaranda_tree_trunk_LOD1"]
me = trunk.data.copy()
me.transform(trunk.matrix_world)
pieces.append(me)
log("tronco", len(me.polygons), "polígonos")

# Unir todo en una malla con los materiales renombrados
rename = {"jacaranda_tree_trunk": "jac_bark", "jacaranda_tree_branches": "jac_branches", "jacaranda_tree_leaves": "jac_leaves"}
order = ["jac_bark", "jac_branches", "jac_leaves"]
mats = []
for name in order:
    src_name = [k for k, v in rename.items() if v == name][0]
    mat = bpy.data.materials.get(src_name)
    mat.name = name
    mats.append(mat)
bm = bmesh.new()
for me in pieces:
    remap = [order.index(rename.get(m.name, m.name)) if m else 0 for m in me.materials]
    for poly in me.polygons:
        poly.material_index = remap[poly.material_index] if remap else 0
    bm.from_mesh(me)
out = bpy.data.meshes.new("TreeHero")
bm.to_mesh(out)
bm.free()
for m in mats:
    out.materials.append(m)
log("unido", len(out.polygons), "polígonos")

# Escala y origen en la base del tronco
out.transform(Matrix.Scale(SCALE, 4))
zs = [v.co.z for v in out.vertices]
xs = [v.co.x for v in out.vertices]
ys = [v.co.y for v in out.vertices]
zmin = min(zs)
trunk_verts = [v.co for v in out.vertices if v.co.z < zmin + 0.4]
cx = sum(c.x for c in trunk_verts) / len(trunk_verts)
cy = sum(c.y for c in trunk_verts) / len(trunk_verts)
out.transform(Matrix.Translation((-cx, -cy, -zmin - 0.15)))
log("tamaño: %.1f x %.1f x %.1f m" % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))

# Normales de copa: las hojas se iluminan como un volumen redondeado (mezcla de la normal
# de la tarjeta con la dirección desde el centro de la copa)
leaf_idx = order.index("jac_leaves")
leaf_verts = set()
for poly in out.polygons:
    if poly.material_index == leaf_idx:
        leaf_verts.update(poly.vertices)
pts = [out.vertices[i].co for i in leaf_verts]
center = Vector((sum(p.x for p in pts) / len(pts), sum(p.y for p in pts) / len(pts), sum(p.z for p in pts) / len(pts)))
lo = min(p.z for p in pts)
center.z = lo + (max(p.z for p in pts) - lo) * 0.45
log("centro de copa", tuple(round(c, 2) for c in center))
import numpy as np
nl = len(out.loops)
loop_vi = np.empty(nl, dtype=np.int32); out.loops.foreach_get("vertex_index", loop_vi)
co = np.empty(len(out.vertices) * 3, dtype=np.float32); out.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
vn = np.empty(len(out.vertices) * 3, dtype=np.float32); out.vertices.foreach_get("normal", vn); vn = vn.reshape(-1, 3)
pn = np.empty(len(out.polygons) * 3, dtype=np.float32); out.polygons.foreach_get("normal", pn); pn = pn.reshape(-1, 3)
pm = np.empty(len(out.polygons), dtype=np.int32); out.polygons.foreach_get("material_index", pm)
ls = np.empty(len(out.polygons), dtype=np.int32); out.polygons.foreach_get("loop_start", ls)
lt = np.empty(len(out.polygons), dtype=np.int32); out.polygons.foreach_get("loop_total", lt)
loop_poly = np.repeat(np.arange(len(out.polygons)), lt)
d = co[loop_vi] - np.array(center, dtype=np.float32)
d[:, 2] *= 1.3
d /= np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
leaf_n = pn[loop_poly] * 0.35 + d * 0.65
leaf_n /= np.maximum(np.linalg.norm(leaf_n, axis=1, keepdims=True), 1e-6)
is_leaf = (pm[loop_poly] == leaf_idx)[:, None]
normals = np.where(is_leaf, leaf_n, vn[loop_vi]).tolist()
out.normals_split_custom_set(normals)
log("normales listas")

# Objeto final, exportación y .blend ligero
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
hero = bpy.data.objects.new("TreeHero", out)
scene.collection.objects.link(hero)
tris = sum(len(p.vertices) - 2 for p in out.polygons)
per_mat = [0, 0, 0]
for p in out.polygons:
    per_mat[p.material_index] += len(p.vertices) - 2
log("triángulos:", tris, "por material", dict(zip(order, per_mat)))
bpy.ops.object.select_all(action='DESELECT')
hero.select_set(True)
bpy.context.view_layer.objects.active = hero
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', use_selection=True, export_yup=True,
                          export_apply=False, export_materials='EXPORT', export_image_format='NONE')
log("exportado", OUT_GLB)
bpy.data.orphans_purge(do_recursive=True)
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
log("guardado", OUT_BLEND)
