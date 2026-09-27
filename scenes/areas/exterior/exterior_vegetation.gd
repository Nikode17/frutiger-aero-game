@tool
class_name ExteriorVegetation
extends Node3D
## Vegetación del exterior: briznas de hierba (MultiMesh, solo delante de las ventanas),
## flores (margaritas, rosas y amarillas; más densas bajo la ventana grande del living),
## el árbol destacado y grupos de árboles sencillos hacia el horizonte (MultiMesh).
## Las mallas de briznas y flores se generan aquí con colores de vértice.

@export_tool_button("Reconstruir vegetación") var rebuild_action: Callable = _build

@export var terrain_path: NodePath = ^"../Terrain"
@export var random_seed: int = 42

@export_group("Hierba")
@export var grass_material: Material
## Zonas de briznas: x = ángulo (grados), y = semiapertura (grados), z = distancia máxima
## desde la pared (m), w = número de briznas
@export var grass_zones: Array[Vector4] = [Vector4(342.0, 26.0, 28.0, 18000.0), Vector4(285.0, 24.0, 14.0, 6000.0)]
@export var grass_height_range: Vector2 = Vector2(0.14, 0.34)

@export_group("Flores")
@export var flower_material: Material
## Zonas de flores: x = ángulo, y = semiapertura, z = distancia máxima desde la pared, w = número
@export var flower_zones: Array[Vector4] = [Vector4(342.0, 24.0, 32.0, 3200.0), Vector4(285.0, 22.0, 14.0, 700.0), Vector4(0.0, 180.0, 60.0, 1400.0)]
@export var flower_scale_range: Vector2 = Vector2(0.8, 1.25)
@export var flower_mix: Vector3 = Vector3(0.45, 0.3, 0.25)   # margaritas, rosas, amarillas

@export_group("Árboles")
@export var featured_tree: PackedScene = preload("res://assets/models/exterior/tree_featured.glb")
@export_range(0.0, 360.0, 0.5) var featured_angle_deg: float = 353.0
@export var featured_distance: float = 38.0
@export var far_tree: PackedScene = preload("res://assets/models/exterior/tree_far.glb")
## Grupos: x = ángulo, y = distancia (m), z = dispersión (m), w = número de árboles
@export var tree_groups: Array[Vector4] = [
	Vector4(348.0, 235.0, 70.0, 20.0), Vector4(300.0, 170.0, 45.0, 12.0), Vector4(22.0, 150.0, 45.0, 14.0),
	Vector4(272.0, 75.0, 20.0, 6.0), Vector4(290.0, 130.0, 30.0, 9.0), Vector4(60.0, 110.0, 35.0, 10.0),
	Vector4(140.0, 140.0, 50.0, 12.0), Vector4(200.0, 160.0, 50.0, 12.0),
]
@export var horizon_tree_count: int = 70
@export var horizon_distance_range: Vector2 = Vector2(380.0, 750.0)
## Sector sin árboles de horizonte (donde está la ciudad): x = ángulo, y = semiapertura
@export var horizon_gap: Vector2 = Vector2(333.0, 9.0)

const META_GENERATED := &"exterior_vegetation_generated"

var _rng := RandomNumberGenerator.new()
var _terrain: ExteriorTerrain


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	_terrain = get_node_or_null(terrain_path) as ExteriorTerrain
	if _terrain == null:
		push_warning("ExteriorVegetation: no se encontró el terreno en '%s'." % terrain_path)
		return
	_rng.seed = random_seed
	_build_grass()
	_build_flowers()
	_build_trees()


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


## Punto al azar en una zona delante de una ventana (más denso cerca de la pared).
func _zone_point(zone: Vector4, bias: float) -> Vector3:
	var th := deg_to_rad(zone.x + _rng.randf_range(-zone.y, zone.y))
	var r := _terrain.building_radius(th) + 0.6 + pow(_rng.randf(), bias) * zone.z
	var x := cos(th) * r
	var z := sin(th) * r
	return Vector3(x, _terrain.height_at(x, z), z)


# --- Hierba -------------------------------------------------------------------------

func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := [0.0, 0.4, 0.75, 1.0]
	var ws := [0.035, 0.028, 0.016, 0.0]
	var idx := 0
	for k in hs.size():
		var h: float = hs[k]
		var bend := 0.18 * h * h
		for side in [-1.0, 1.0]:
			if ws[k] == 0.0 and side > 0.0:
				continue
			st.set_uv(Vector2(0.5 + 0.5 * side, h))
			st.set_normal(Vector3(0.0, 0.3, 1.0).normalized())
			st.add_vertex(Vector3(ws[k] * side, h, bend))
			idx += 1
	# 0-1, 2-3, 4-5, 6 (punta)
	for k in 2:
		var a := k * 2
		st.add_index(a); st.add_index(a + 1); st.add_index(a + 3)
		st.add_index(a); st.add_index(a + 3); st.add_index(a + 2)
	st.add_index(4); st.add_index(5); st.add_index(6)
	return st.commit()


func _build_grass() -> void:
	var mesh := _blade_mesh()
	for zi in grass_zones.size():
		var zone := grass_zones[zi]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = int(zone.w)
		for k in mm.instance_count:
			var p := _zone_point(zone, 1.6)
			var h := _rng.randf_range(grass_height_range.x, grass_height_range.y)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.0, h, 1.0))
			basis = basis.rotated(Vector3(1, 0, 0).rotated(Vector3.UP, _rng.randf() * TAU), _rng.randf_range(-0.15, 0.15))
			mm.set_instance_transform(k, Transform3D(basis, p))
			var v := _rng.randf_range(0.82, 1.12)
			mm.set_instance_color(k, Color(v, v * _rng.randf_range(0.97, 1.03), v))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Grass%d" % zi
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if grass_material:
			mmi.material_override = grass_material
		_add_generated(mmi)


# --- Flores -------------------------------------------------------------------------

## Flor: tallo cruzado, disco central y pétalos; la cabeza mira hacia arriba algo inclinada.
func _flower_mesh(petals: int, petal_len: float, petal_w: float, petal_col: Color, center_col: Color, stem_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color(0.25, 0.62, 0.15).srgb_to_linear()
	var total_h := stem_h + 0.03
	# Tallo: dos cintas cruzadas
	for rot in [0.0, PI * 0.5]:
		var d := Vector3(cos(rot), 0.0, sin(rot)) * 0.006
		_quad(st, [-d, d, d + Vector3(0, stem_h, 0), -d + Vector3(0, stem_h, 0)], green, total_h)
	var head_basis := Basis(Vector3(1, 0, 0), deg_to_rad(28.0))
	var head_pos := Vector3(0.0, stem_h, 0.0)
	var pc := petal_col.srgb_to_linear()
	var cc := center_col.srgb_to_linear()
	for k in petals:
		var a := TAU * float(k) / float(petals)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		var lift := Vector3(0.0, 0.004, 0.0)
		var pts := [
			dir * 0.012,
			dir * petal_len * 0.5 + side * petal_w * 0.5 + lift,
			dir * petal_len * 0.9 + side * petal_w * 0.35 + lift,
			dir * petal_len + lift,
			dir * petal_len * 0.9 - side * petal_w * 0.35 + lift,
			dir * petal_len * 0.5 - side * petal_w * 0.5 + lift,
		]
		for i in range(1, pts.size() - 1):
			_tri(st, head_pos + head_basis * pts[0], head_pos + head_basis * pts[i], head_pos + head_basis * pts[i + 1], pc, total_h)
	# Disco central abombado
	var segs := 10
	var top := head_pos + head_basis * Vector3(0.0, 0.012, 0.0)
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		var p0 := head_pos + head_basis * (Vector3(cos(a0), 0.0, sin(a0)) * 0.016 + Vector3(0, 0.005, 0))
		var p1 := head_pos + head_basis * (Vector3(cos(a1), 0.0, sin(a1)) * 0.016 + Vector3(0, 0.005, 0))
		_tri(st, top, p0, p1, cc, total_h)
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, total_h: float) -> void:
	for p in [a, b, c]:
		st.set_color(col)
		st.set_uv(Vector2(0.0, clampf(p.y / total_h, 0.0, 1.0)))
		st.add_vertex(p)


func _quad(st: SurfaceTool, pts: Array, col: Color, total_h: float) -> void:
	_tri(st, pts[0], pts[1], pts[2], col, total_h)
	_tri(st, pts[0], pts[2], pts[3], col, total_h)


func _build_flowers() -> void:
	var meshes := [
		_flower_mesh(14, 0.09, 0.022, Color(0.98, 0.98, 0.95), Color(1.0, 0.8, 0.1), 0.3),    # margarita
		_flower_mesh(6, 0.08, 0.05, Color(1.0, 0.45, 0.72), Color(1.0, 0.85, 0.2), 0.34),     # rosa
		_flower_mesh(5, 0.065, 0.05, Color(1.0, 0.86, 0.15), Color(1.0, 0.55, 0.1), 0.26),    # amarilla
	]
	var weights := [flower_mix.x, flower_mix.y, flower_mix.z]
	var total_w: float = flower_mix.x + flower_mix.y + flower_mix.z
	var transforms: Array = [[], [], []]
	for zone in flower_zones:
		for k in int(zone.w):
			var pick := _rng.randf() * total_w
			var kind := 0 if pick < weights[0] else (1 if pick < weights[0] + weights[1] else 2)
			var p := _zone_point(zone, 2.4)
			var s := _rng.randf_range(flower_scale_range.x, flower_scale_range.y)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
			transforms[kind].append(Transform3D(basis, p))
	for kind in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[kind]
		mm.instance_count = transforms[kind].size()
		for k in mm.instance_count:
			mm.set_instance_transform(k, transforms[kind][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["Daisies", "PinkFlowers", "YellowFlowers"][kind]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if flower_material:
			mmi.material_override = flower_material
		_add_generated(mmi)


# --- Árboles ------------------------------------------------------------------------

func _build_trees() -> void:
	if featured_tree:
		var tree: Node3D = featured_tree.instantiate()
		tree.name = "FeaturedTree"
		var th := deg_to_rad(featured_angle_deg)
		var x := cos(th) * featured_distance
		var z := sin(th) * featured_distance
		tree.position = Vector3(x, _terrain.height_at(x, z), z)
		tree.rotation.y = 0.6
		_add_generated(tree)
	if far_tree == null:
		return
	var mesh := _first_mesh(far_tree)
	if mesh == null:
		return
	var xforms: Array[Transform3D] = []
	for g in tree_groups:
		for k in int(g.w):
			var th := deg_to_rad(g.x)
			var center := Vector2(cos(th), sin(th)) * g.y
			var off := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * g.z
			xforms.append(_tree_xform(center + off, _rng.randf_range(0.8, 1.6)))
	var placed := 0
	while placed < horizon_tree_count:
		var a := _rng.randf() * 360.0
		if absf(angle_difference(deg_to_rad(a), deg_to_rad(horizon_gap.x))) < deg_to_rad(horizon_gap.y):
			continue
		var r := _rng.randf_range(horizon_distance_range.x, horizon_distance_range.y)
		xforms.append(_tree_xform(Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * r, _rng.randf_range(1.2, 2.2)))
		placed += 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "TreeGroups"
	mmi.multimesh = mm
	_add_generated(mmi)


func _tree_xform(p: Vector2, s: float) -> Transform3D:
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
	return Transform3D(basis, Vector3(p.x, _terrain.height_at(p.x, p.y), p.y))


func _first_mesh(scene: PackedScene) -> Mesh:
	var inst := scene.instantiate()
	var found: Mesh = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		found = (mi as MeshInstance3D).mesh
		break
	inst.free()
	return found
