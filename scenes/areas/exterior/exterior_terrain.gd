@tool
class_name ExteriorTerrain
extends Node3D
## Terreno del exterior: colinas suaves onduladas alrededor de la habitación (que está en
## el origen). Malla radial generada por código, con celdas finas cerca de la casa y cada
## vez más grandes hacia el horizonte, y colisión con la misma geometría hasta cierto
## radio. La altura se consulta con height_at() para colocar hierba, flores y árboles.

@export_tool_button("Reconstruir terreno") var rebuild_action: Callable = _build

@export_group("Malla")
@export var inner_radius: float = 2.0
@export var outer_radius: float = 1600.0
@export_range(16, 512) var angular_segments: int = 256
@export_range(8, 256) var ring_count: int = 110
@export var terrain_material: Material
@export var with_collision: bool = true
@export var collision_radius: float = 400.0

@export_group("Colinas")
@export var noise_seed: int = 7
@export var hill_height: float = 6.0          # Amplitud de las colinas de fondo (m)
@export var hill_wavelength: float = 240.0    # Tamaño típico de las colinas (m)
@export var near_dip: float = 1.8             # Cuánto baja el prado delante de la casa (m)
@export var far_rise: float = 12.0            # Cuánto sube el terreno hacia el horizonte (m)
@export_range(0.0, 360.0, 0.5) var main_hill_angle_deg: float = 358.0
@export var main_hill_distance: float = 140.0
@export var main_hill_radius: float = 80.0
@export var main_hill_height: float = 12.0

@export_group("Plataforma bajo la sala")
@export var plateau_height: float = -0.3
@export var building_half_size: Vector2 = Vector2(8.6, 7.1)
@export_range(0.0, 360.0, 0.5) var pocket_angle_deg: float = 225.0
@export var pocket_extra: float = 7.5        # Cuánto sobresale el entrante (m)
@export var plateau_margin: float = 1.5
@export var plateau_blend: float = 24.0

const META_GENERATED := &"exterior_terrain_generated"

var _noise: FastNoiseLite


func _ready() -> void:
	_build()


## Altura del terreno en (x, z), en coordenadas del exterior (la sala en el origen).
func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z)
	var r := p.length()
	var h := _noise.get_noise_2d(x, z) * hill_height
	h -= near_dip * (1.0 - smoothstep(25.0, 130.0, r))
	h += far_rise * smoothstep(250.0, 1300.0, r)
	var hill_dir := Vector2(cos(deg_to_rad(main_hill_angle_deg)), sin(deg_to_rad(main_hill_angle_deg)))
	var d_hill := p.distance_to(hill_dir * main_hill_distance)
	var sigma := main_hill_radius * 0.5
	h += main_hill_height * exp(-d_hill * d_hill / (2.0 * sigma * sigma))
	# Plataforma lisa bajo la habitación y el entrante
	var w := 1.0 - smoothstep(plateau_margin, plateau_margin + plateau_blend, _building_distance(p))
	return lerpf(h, plateau_height, w)


func normal_at(x: float, z: float) -> Vector3:
	var e := maxf(0.4, Vector2(x, z).length() * 0.01)
	var dx := height_at(x - e, z) - height_at(x + e, z)
	var dz := height_at(x, z - e) - height_at(x, z + e)
	return Vector3(dx, 2.0 * e, dz).normalized()


## Radio aproximado de la casa en la dirección theta (radianes).
func building_radius(theta: float) -> float:
	return 1.0 - _building_distance(Vector2(cos(theta), sin(theta)))


## Distancia aproximada al contorno de la casa (superelipse más el lóbulo del entrante).
func _building_distance(p: Vector2) -> float:
	var r := p.length()
	if r < 0.001:
		return -building_half_size.x
	var th := atan2(p.y, p.x)
	var c := absf(cos(th))
	var s := absf(sin(th))
	var rb := pow(pow(c / building_half_size.x, 4.0) + pow(s / building_half_size.y, 4.0), -0.25)
	rb += pow(maxf(cos(th - deg_to_rad(pocket_angle_deg)), 0.0), 10.0) * pocket_extra
	return r - rb


func _ensure_noise() -> void:
	if _noise:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0 / hill_wavelength
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3


func _build() -> void:
	_noise = null
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	# Vértice central y anillos
	verts.append(Vector3(0.0, height_at(0.0, 0.0), 0.0))
	norms.append(Vector3.UP)
	var growth := pow(outer_radius / inner_radius, 1.0 / float(ring_count - 1))
	var radii := PackedFloat32Array()
	for k in ring_count:
		var r := inner_radius * pow(growth, float(k))
		radii.append(r)
		for i in angular_segments:
			var th := TAU * float(i) / float(angular_segments)
			var x := cos(th) * r
			var z := sin(th) * r
			verts.append(Vector3(x, height_at(x, z), z))
			norms.append(normal_at(x, z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in verts.size():
		st.set_normal(norms[k])
		st.add_vertex(verts[k])
	var faces := PackedVector3Array()
	var n := angular_segments
	for i in n:
		_add_tri(st, verts, norms, 0, 1 + i, 1 + (i + 1) % n, faces, true)
	for k in ring_count - 1:
		var a0 := 1 + k * n
		var b0 := 1 + (k + 1) * n
		var collide := radii[k + 1] <= collision_radius
		for i in n:
			var i2 := (i + 1) % n
			_add_tri(st, verts, norms, a0 + i, a0 + i2, b0 + i2, faces, collide)
			_add_tri(st, verts, norms, a0 + i, b0 + i2, b0 + i, faces, collide)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	if terrain_material:
		mi.material_override = terrain_material
	_add_generated(mi)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "TerrainBody"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		_add_generated(body)


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


## Triángulo orientado según las normales (en Godot las caras frontales van en sentido
## horario); si collide, se guarda también para la colisión con el mismo orden.
func _add_tri(st: SurfaceTool, verts: PackedVector3Array, norms: PackedVector3Array, a: int, b: int, c: int,
		faces: PackedVector3Array, collide: bool) -> void:
	var geo := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if geo.length_squared() < 1e-12:
		return
	var order := [a, c, b] if geo.dot(norms[a] + norms[b] + norms[c]) > 0.0 else [a, b, c]
	for idx in order:
		st.add_index(idx)
		if collide:
			faces.append(verts[idx])
