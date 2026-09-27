@tool
class_name ExteriorCity
extends Node3D
## Ciudad lejana de rascacielos de cristal genéricos: torres de distintas alturas agrupadas
## a un lado del horizonte, más altas en el centro del grupo. Todo va en una sola malla
## (una llamada de dibujo); las UV son metros a lo largo de la fachada y de altura para
## que el shader dibuje montantes y forjados.

@export_tool_button("Reconstruir ciudad") var rebuild_action: Callable = _build

@export var terrain_path: NodePath = ^"../Terrain"
@export var random_seed: int = 2004
@export var glass_material: Material
@export_range(0.0, 360.0, 0.5) var center_angle_deg: float = 333.0
@export var distance: float = 620.0
@export var cluster_radius: float = 100.0
@export_range(1, 80) var tower_count: int = 22
@export var height_range: Vector2 = Vector2(55.0, 240.0)
@export var footprint_range: Vector2 = Vector2(16.0, 40.0)   # Radio de planta (m)

const META_GENERATED := &"exterior_city_generated"

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var terrain := get_node_or_null(terrain_path) as ExteriorTerrain
	_rng.seed = random_seed
	var th := deg_to_rad(center_angle_deg)
	var center := Vector2(cos(th), sin(th)) * distance
	# Reparto sin solapes (más cerca del centro, más probable)
	var towers: Array = []   # [pos, radio]
	var tries := 0
	while towers.size() < tower_count and tries < tower_count * 60:
		tries += 1
		var a := _rng.randf() * TAU
		var d := pow(_rng.randf(), 0.8) * cluster_radius
		var pos := center + Vector2(cos(a), sin(a)) * Vector2(d * 1.4, d * 0.8).rotated(th)
		var rad := _rng.randf_range(footprint_range.x, footprint_range.y) * 0.5
		var ok := true
		for t in towers:
			if pos.distance_to(t[0]) < rad + t[1] + 6.0:
				ok = false
				break
		if ok:
			towers.append([pos, rad, d])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in towers:
		var pos: Vector2 = t[0]
		var rad: float = t[1]
		var closeness := 1.0 - clampf(float(t[2]) / cluster_radius, 0.0, 1.0)
		var h := lerpf(height_range.x, height_range.y, pow(closeness, 1.3)) * _rng.randf_range(0.7, 1.1)
		var base := terrain.height_at(pos.x, pos.y) - 2.0 if terrain else 0.0
		var kind := _rng.randi() % 3
		var rot := _rng.randf() * TAU
		var p3 := Vector3(pos.x, base, pos.y)
		match kind:
			0:   # Prisma achaflanado (octógono irregular)
				_prism(st, p3, rad, 8, base, base + h, rot, 0.0)
				_top(st, p3 + Vector3(0, h, 0), rad, 8, rot)
			1:   # Cilindro con cúpula
				_prism(st, p3, rad * 0.85, 20, base, base + h, rot, 0.0)
				_dome(st, p3 + Vector3(0, h, 0), rad * 0.85, 20, rad * 0.5)
			2:   # Torre escalonada (dos o tres tramos)
				var tiers := 2 + _rng.randi() % 2
				var y0 := base
				var r := rad
				for k in tiers:
					var y1 := base + h * float(k + 1) / float(tiers)
					_prism(st, p3, r, 4, y0, y1, rot, r * 0.25)
					y0 = y1
					if k < tiers - 1:
						_top(st, p3 + Vector3(0, y1 - base, 0), r, 8, rot + PI / 8.0)
					r *= 0.72
				_top(st, p3 + Vector3(0, h, 0), r / 0.72, 8, rot + PI / 8.0)
		# Algunas torres llevan aguja
		if _rng.randf() < 0.35:
			_prism(st, p3 + Vector3(0, 0, 0), 0.8, 6, base + h, base + h + h * 0.18, 0.0, 0.0)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Towers"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if glass_material:
		mi.material_override = glass_material
	mi.set_meta(META_GENERATED, true)
	add_child(mi)


## Prisma vertical de `sides` caras. Si chamfer > 0 con 4 lados, se achaflanan las esquinas.
func _prism(st: SurfaceTool, c: Vector3, r: float, sides: int, y0: float, y1: float, rot: float, chamfer: float) -> void:
	var ring: Array[Vector2] = []
	if sides == 4 and chamfer > 0.0:
		for k in 4:
			var a := rot + PI * 0.5 * float(k) + PI * 0.25
			var corner := Vector2(cos(a), sin(a)) * r * 1.41421
			var prev := Vector2(cos(a - PI * 0.25), sin(a - PI * 0.25)) * r
			var next := Vector2(cos(a + PI * 0.25), sin(a + PI * 0.25)) * r
			ring.append(corner.lerp(prev, chamfer / r))
			ring.append(corner.lerp(next, chamfer / r))
	else:
		for k in sides:
			var a := rot + TAU * float(k) / float(sides)
			ring.append(Vector2(cos(a), sin(a)) * r)
	var u := 0.0
	for k in ring.size():
		var a2: Vector2 = ring[k]
		var b2: Vector2 = ring[(k + 1) % ring.size()]
		var w := a2.distance_to(b2)
		var p0 := Vector3(c.x + a2.x, y0, c.z + a2.y)
		var p1 := Vector3(c.x + b2.x, y0, c.z + b2.y)
		var p2 := Vector3(c.x + b2.x, y1, c.z + b2.y)
		var p3 := Vector3(c.x + a2.x, y1, c.z + a2.y)
		# Orden horario visto desde fuera
		_v(st, p0, Vector2(u, y0)); _v(st, p2, Vector2(u + w, y1)); _v(st, p1, Vector2(u + w, y0))
		_v(st, p0, Vector2(u, y0)); _v(st, p3, Vector2(u, y1)); _v(st, p2, Vector2(u + w, y1))
		u += w


func _top(st: SurfaceTool, c: Vector3, r: float, sides: int, rot: float) -> void:
	for k in sides:
		var a0 := rot + TAU * float(k) / float(sides)
		var a1 := rot + TAU * float(k + 1) / float(sides)
		_v(st, c, Vector2.ZERO)
		_v(st, c + Vector3(cos(a0), 0, sin(a0)) * r, Vector2.ZERO)
		_v(st, c + Vector3(cos(a1), 0, sin(a1)) * r, Vector2.ZERO)


func _dome(st: SurfaceTool, c: Vector3, r: float, sides: int, h: float) -> void:
	var rings := 4
	for j in rings:
		var t0 := float(j) / float(rings)
		var t1 := float(j + 1) / float(rings)
		var r0 := r * cos(t0 * PI * 0.5)
		var r1 := r * cos(t1 * PI * 0.5)
		var y0 := h * sin(t0 * PI * 0.5)
		var y1 := h * sin(t1 * PI * 0.5)
		for k in sides:
			var a0 := TAU * float(k) / float(sides)
			var a1 := TAU * float(k + 1) / float(sides)
			var q0 := c + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var q1 := c + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var q2 := c + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var q3 := c + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			_v(st, q0, Vector2.ZERO); _v(st, q2, Vector2.ZERO); _v(st, q1, Vector2.ZERO)
			_v(st, q0, Vector2.ZERO); _v(st, q3, Vector2.ZERO); _v(st, q2, Vector2.ZERO)


func _v(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_uv(uv)
	st.add_vertex(p)
