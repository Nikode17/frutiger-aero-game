extends Node3D
## Vida del exterior: mariposas genéricas que revolotean cerca de las flores delante de las
## ventanas y pompas de jabón iridiscentes que suben y derivan despacio. Se crean al
## arrancar; las mallas se generan aquí.

@export var terrain_path: NodePath = ^"../Terrain"
@export var random_seed: int = 77
@export var butterfly_shader: Shader = preload("res://assets/shaders/exterior_butterfly.gdshader")
@export var bubble_shader: Shader = preload("res://assets/shaders/soap_bubble.gdshader")
## Zonas: x = ángulo (grados), y = semiapertura (grados), z = distancia máxima desde la pared, w = número
@export var butterfly_zones: Array[Vector4] = [Vector4(342.0, 20.0, 14.0, 9.0), Vector4(285.0, 18.0, 10.0, 4.0)]
@export var bubble_zones: Array[Vector4] = [Vector4(342.0, 22.0, 16.0, 8.0), Vector4(285.0, 20.0, 12.0, 4.0)]
@export var butterfly_colors: Array[Color] = [Color(0.35, 0.75, 1.0), Color(1.0, 0.65, 0.2), Color(1.0, 0.92, 0.35), Color(0.95, 0.55, 0.85), Color(1.0, 1.0, 1.0)]
@export var butterfly_size: float = 0.16
@export var bubble_size_range: Vector2 = Vector2(0.07, 0.2)
@export var bubble_top: float = 7.0

var _rng := RandomNumberGenerator.new()
var _terrain: ExteriorTerrain
var _time: float = 0.0
var _butterflies: Array = []
var _bubbles: Array = []


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as ExteriorTerrain
	if _terrain == null:
		push_warning("ExteriorLife: no se encontró el terreno en '%s'." % terrain_path)
		return
	_rng.seed = random_seed
	var bmesh := _butterfly_mesh()
	var bmat := ShaderMaterial.new()
	bmat.shader = butterfly_shader
	for zone in butterfly_zones:
		for k in int(zone.w):
			var mi := MeshInstance3D.new()
			mi.mesh = bmesh
			mi.material_override = bmat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.set_instance_shader_parameter("flap_phase", _rng.randf() * TAU)
			mi.set_instance_shader_parameter("wing_color", butterfly_colors[_rng.randi() % butterfly_colors.size()])
			_butterflies.append({"node": mi, "home": _zone_point(zone), "phase": Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU), "speed": _rng.randf_range(0.5, 0.9)})
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var smat := ShaderMaterial.new()
	smat.shader = bubble_shader
	for zone in bubble_zones:
		for k in int(zone.w):
			var mi := MeshInstance3D.new()
			mi.mesh = sphere
			mi.material_override = smat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = Vector3.ONE * _rng.randf_range(bubble_size_range.x, bubble_size_range.y)
			add_child(mi)
			mi.set_instance_shader_parameter("swirl_phase", _rng.randf() * 10.0)
			var p := _zone_point(zone)
			p.y += _rng.randf_range(0.3, bubble_top)
			_bubbles.append({"node": mi, "zone": zone, "pos": p, "phase": _rng.randf() * TAU, "rise": _rng.randf_range(0.08, 0.18)})


func _process(delta: float) -> void:
	if _terrain == null:
		return
	_time += delta
	for b in _butterflies:
		_update_butterfly(b)
	for b in _bubbles:
		_update_bubble(b, delta)


func _zone_point(zone: Vector4) -> Vector3:
	var th := deg_to_rad(zone.x + _rng.randf_range(-zone.y, zone.y))
	var r := _terrain.building_radius(th) + 1.5 + _rng.randf() * zone.z
	var x := cos(th) * r
	var z := sin(th) * r
	return Vector3(x, _terrain.height_at(x, z), z)


## Vuelo errático: suma de senos alrededor de su punto de partida, cerca de las flores.
func _update_butterfly(b: Dictionary) -> void:
	var ph: Vector3 = b["phase"]
	var s: float = b["speed"]
	var t := _time * s
	var home: Vector3 = b["home"]
	var off := Vector3(sin(t * 0.7 + ph.x) * 2.2 + sin(t * 1.9 + ph.y) * 0.6, 0.0, cos(t * 0.6 + ph.y) * 2.2 + sin(t * 1.7 + ph.z) * 0.6)
	var p := home + off
	p.y = _terrain.height_at(p.x, p.z) + 1.0 + 0.4 * sin(t * 1.3 + ph.z) + 0.15 * sin(t * 4.1 + ph.x)
	var node: Node3D = b["node"]
	var prev := node.position
	node.position = p
	var vel := p - prev
	vel.y = 0.0
	if vel.length_squared() > 1e-8:
		node.basis = Basis.looking_at(vel.normalized(), Vector3.UP, true).scaled(Vector3.ONE * butterfly_size / 0.09)


## Pompa: sube despacio con deriva lateral; al llegar arriba vuelve a salir cerca del suelo.
func _update_bubble(b: Dictionary, delta: float) -> void:
	var pos: Vector3 = b["pos"]
	var ph: float = b["phase"]
	pos.y += b["rise"] * delta
	pos.x += sin(_time * 0.4 + ph) * 0.12 * delta
	pos.z += cos(_time * 0.33 + ph) * 0.12 * delta
	if pos.y > _terrain.height_at(pos.x, pos.z) + bubble_top:
		pos = _zone_point(b["zone"])
		pos.y += 0.3
	b["pos"] = pos
	var node: Node3D = b["node"]
	node.position = pos + Vector3(0.0, sin(_time * 1.2 + ph) * 0.08, 0.0)


## Mariposa genérica: cuerpo fino y dos pares de alas; el color de vértice marca el dibujo
## (blanco = color del ala por instancia, oscuro = bordes y manchas). Mira hacia +Z.
func _butterfly_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := Color(0.0, 0.0, 0.0)
	var wing := Color(1.0, 1.0, 1.0)
	# Cuerpo: rombo alargado a lo largo de Z
	var body := [Vector3(0, 0, 0.035), Vector3(0.004, 0, 0), Vector3(0, 0.004, 0), Vector3(-0.004, 0, 0), Vector3(0, -0.004, 0), Vector3(0, 0, -0.03)]
	for k in 4:
		var a: Vector3 = body[1 + k]
		var c: Vector3 = body[1 + (k + 1) % 4]
		_tri(st, body[0], a, c, dark)
		_tri(st, body[5], c, a, dark)
	# Alas: abanicos con el borde oscuro y el centro del color del ala
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 0.003, 0, 0.005)
		var fore := [Vector3(0.02, 0, 0.03), Vector3(0.05, 0, 0.035), Vector3(0.075, 0, 0.02), Vector3(0.08, 0, 0.0), Vector3(0.06, 0, -0.01), Vector3(0.02, 0, -0.005)]
		var hind := [Vector3(0.02, 0, -0.005), Vector3(0.05, 0, -0.012), Vector3(0.06, 0, -0.03), Vector3(0.045, 0, -0.05), Vector3(0.02, 0, -0.045), Vector3(0.005, 0, -0.02)]
		for pts in [fore, hind]:
			var center := Vector3.ZERO
			for p in pts:
				center += p
			center /= float(pts.size())
			center.x *= side
			for k in pts.size() - 1:
				var p0: Vector3 = pts[k]
				var p1: Vector3 = pts[k + 1]
				var e0 := Vector3(p0.x * side, 0, p0.z)
				var e1 := Vector3(p1.x * side, 0, p1.z)
				# Interior del ala en color y borde oscuro fino
				var m0 := center.lerp(e0, 0.8)
				var m1 := center.lerp(e1, 0.8)
				_tri(st, root, m0, m1, wing)
				_tri(st, m0, e0, e1, dark)
				_tri(st, m0, e1, m1, dark)
			# Mancha oscura en el ala
			var spot := center.lerp(Vector3(pts[2].x * side, 0, pts[2].z), 0.4)
			_tri(st, spot + Vector3(0.006 * side, 0.0005, 0), spot + Vector3(-0.004 * side, 0.0005, 0.006), spot + Vector3(-0.004 * side, 0.0005, -0.006), dark)
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)
