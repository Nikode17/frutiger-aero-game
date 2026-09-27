@tool
class_name ExteriorCity
extends Node3D
## Ciudad lejana de rascacielos de cristal genéricos, agrupados a un lado del horizonte y
## más altos en el centro del grupo. Torres de planta redondeada o elíptica (normales
## suaves para que el reflejo del cielo recorra las esquinas), escalonadas, ahusadas o con
## la cubierta en bisel, con remates: bandas de coronación, cúpulas de cristal y agujas.
## Todo va en una sola malla con dos superficies (cristal y remates); las UV del cristal
## son metros a lo largo de la fachada y de altura para dibujar los montantes.

@export_tool_button("Reconstruir ciudad") var rebuild_action: Callable = _build

@export var terrain_path: NodePath = ^"../Terrain"
@export var random_seed: int = 2004
@export var glass_material: Material
@export var trim_material: Material
@export_range(0.0, 360.0, 0.5) var center_angle_deg: float = 333.0
@export var distance: float = 620.0
@export var cluster_radius: float = 100.0
@export_range(1, 80) var tower_count: int = 22
@export var height_range: Vector2 = Vector2(55.0, 240.0)
@export var footprint_range: Vector2 = Vector2(16.0, 40.0)   # Anchura de planta (m)
@export_range(0.0, 0.5) var tint_variation: float = 0.12

const META_GENERATED := &"exterior_city_generated"
const TINTS: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.88, 1.0, 1.06), Color(1.06, 1.02, 0.94), Color(0.84, 0.94, 1.1)]

var _rng := RandomNumberGenerator.new()
var _glass: SurfaceTool
var _trim: SurfaceTool
var _tint: Color = Color.WHITE


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var terrain := get_node_or_null(terrain_path) as ExteriorTerrain
	_rng.seed = random_seed
	_glass = SurfaceTool.new()
	_glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trim = SurfaceTool.new()
	_trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var th := deg_to_rad(center_angle_deg)
	var center := Vector2(cos(th), sin(th)) * distance
	# Reparto sin solapes, más denso y alto hacia el centro del grupo
	var towers: Array = []   # [posición, radio, distancia al centro]
	var tries := 0
	while towers.size() < tower_count and tries < tower_count * 80:
		tries += 1
		var a := _rng.randf() * TAU
		var d := pow(_rng.randf(), 0.8) * cluster_radius
		var pos := center + (Vector2(cos(a), sin(a)) * Vector2(d * 1.4, d * 0.8)).rotated(th)
		var rad := _rng.randf_range(footprint_range.x, footprint_range.y) * 0.5
		var ok := true
		for t in towers:
			if pos.distance_to(t[0]) < rad + t[1] + 6.0:
				ok = false
				break
		if ok:
			towers.append([pos, rad, d])
	for t in towers:
		var pos: Vector2 = t[0]
		var rad: float = t[1]
		var closeness := 1.0 - clampf(float(t[2]) / cluster_radius, 0.0, 1.0)
		var h := lerpf(height_range.x, height_range.y, pow(closeness, 1.3)) * _rng.randf_range(0.7, 1.1)
		var base := (terrain.height_at(pos.x, pos.y) - 3.0) if terrain else 0.0
		var base_tint: Color = TINTS[_rng.randi() % TINTS.size()]
		var v := 1.0 + _rng.randf_range(-tint_variation, tint_variation)
		_tint = Color(base_tint.r * v, base_tint.g * v, base_tint.b * v)
		match _rng.randi() % 5:
			0: _tower_rounded(pos, rad, base, h)
			1: _tower_elliptic(pos, rad, base, h)
			2: _tower_stepped(pos, rad, base, h)
			3: _tower_slanted(pos, rad, base, h)
			4: _tower_tapered(pos, rad, base, h)
	var mesh := ArrayMesh.new()
	_glass.commit(mesh)
	_trim.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Towers"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if glass_material:
		mi.set_surface_override_material(0, glass_material)
	if trim_material:
		mi.set_surface_override_material(1, trim_material)
	mi.set_meta(META_GENERATED, true)
	add_child(mi)


# --- Tipos de torre -----------------------------------------------------------------

func _tower_rounded(c: Vector2, rad: float, y0: float, h: float) -> void:
	var fp := _rounded_rect(Vector2(rad, rad * _rng.randf_range(0.6, 1.0)), rad * _rng.randf_range(0.12, 0.35), 6)
	var rot := _rng.randf() * TAU
	_wall(_glass, fp, c, rot, 1.0, 1.0, y0, y0 + h, 0.0)
	_crown_band(fp, c, rot, 1.0, y0 + h - 2.5, 3.0)
	if _rng.randf() < 0.4:
		_spire(c, y0 + h + 0.5, h * _rng.randf_range(0.12, 0.2), rad * 0.06)


func _tower_elliptic(c: Vector2, rad: float, y0: float, h: float) -> void:
	var fp := _ellipse(Vector2(rad, rad * _rng.randf_range(0.7, 1.0)), 40)
	var rot := _rng.randf() * TAU
	_wall(_glass, fp, c, rot, 1.0, 1.0, y0, y0 + h, 0.0)
	if _rng.randf() < 0.5:
		_crown_band(fp, c, rot, 1.0, y0 + h - 1.5, 1.8)
		_dome(fp, c, rot, y0 + h + 0.3, rad * _rng.randf_range(0.35, 0.6))
	else:
		_crown_band(fp, c, rot, 1.0, y0 + h - 3.0, 3.5)
		_spire(c, y0 + h + 0.5, h * _rng.randf_range(0.15, 0.25), rad * 0.05)


func _tower_stepped(c: Vector2, rad: float, y0: float, h: float) -> void:
	var fp := _rounded_rect(Vector2(rad, rad * _rng.randf_range(0.7, 1.0)), rad * _rng.randf_range(0.2, 0.4), 6)
	var rot := _rng.randf() * TAU
	var splits := [0.0, 0.52, 0.8, 1.0]
	var scales := [1.0, 0.78, 0.58]
	for k in 3:
		var ya: float = y0 + h * splits[k]
		var yb: float = y0 + h * splits[k + 1]
		_wall(_glass, fp, c, rot, scales[k], scales[k], ya, yb, 0.0)
		_crown_band(fp, c, rot, scales[k], yb - 0.8, 1.2)
	if _rng.randf() < 0.7:
		_spire(c, y0 + h + 0.4, h * _rng.randf_range(0.12, 0.22), rad * 0.05)


func _tower_slanted(c: Vector2, rad: float, y0: float, h: float) -> void:
	var elliptic := _rng.randf() < 0.5
	var fp := _ellipse(Vector2(rad, rad * 0.8), 40) if elliptic else _rounded_rect(Vector2(rad, rad * _rng.randf_range(0.6, 0.9)), rad * 0.25, 6)
	var rot := _rng.randf() * TAU
	var slope := _rng.randf_range(0.35, 0.6)
	_wall(_glass, fp, c, rot, 1.0, 1.0, y0, y0 + h, slope)
	# Remate: borde blanco que sigue la cubierta inclinada
	_wall(_trim, _offset_fp(fp, 0.35), c, rot, 1.0, 1.0, y0 + h - 1.2, y0 + h + 0.35, slope, true)


func _tower_tapered(c: Vector2, rad: float, y0: float, h: float) -> void:
	var fp := _rounded_rect(Vector2(rad, rad * _rng.randf_range(0.75, 1.0)), rad * 0.4, 6)
	var rot := _rng.randf() * TAU
	var top := _rng.randf_range(0.6, 0.78)
	_wall(_glass, fp, c, rot, 1.0, top, y0, y0 + h, 0.0)
	_crown_band(fp, c, rot, top, y0 + h - 2.0, 2.4)
	if _rng.randf() < 0.6:
		_spire(c, y0 + h + 0.4, h * _rng.randf_range(0.15, 0.25), rad * 0.05)


# --- Plantas (centradas en el origen, sentido antihorario) -------------------------

## Devuelve [puntos, normales] de un rectángulo de esquinas redondeadas.
func _rounded_rect(half: Vector2, radius: float, segs: int) -> Array:
	var pts := PackedVector2Array()
	var nrm := PackedVector2Array()
	var r := minf(radius, minf(half.x, half.y) - 0.05)
	var corners := [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	for c in 4:
		var a0 := PI * 0.5 * float(c)
		for k in segs + 1:
			var a := a0 + PI * 0.5 * float(k) / float(segs)
			var n := Vector2(cos(a), sin(a))
			pts.append(corners[c] + n * r)
			nrm.append(n)
	return [pts, nrm]


func _ellipse(half: Vector2, segs: int) -> Array:
	var pts := PackedVector2Array()
	var nrm := PackedVector2Array()
	for k in segs:
		var a := TAU * float(k) / float(segs)
		pts.append(Vector2(cos(a) * half.x, sin(a) * half.y))
		nrm.append(Vector2(cos(a) / half.x, sin(a) / half.y).normalized())
	return [pts, nrm]


## Misma planta desplazada `d` metros hacia fuera.
func _offset_fp(fp: Array, d: float) -> Array:
	var pts := PackedVector2Array()
	var src: PackedVector2Array = fp[0]
	var nrm: PackedVector2Array = fp[1]
	for i in src.size():
		pts.append(src[i] + nrm[i] * d)
	return [pts, nrm]


# --- Piezas --------------------------------------------------------------------------

## Fachada extruida de y0 a y1 con escala de planta s0 abajo y s1 arriba (ahusado) y, si
## slope > 0, cubierta inclinada (la altura superior varía slope m por m a lo largo de X
## local). La cubierta se cierra con el material de remates. is_rim: pieza de remate que
## sigue también la inclinación por abajo y se cierra por debajo.
func _wall(st: SurfaceTool, fp: Array, c: Vector2, rot: float, s0: float, s1: float, y0: float, y1: float,
		slope: float, is_rim: bool = false) -> void:
	var pts: PackedVector2Array = fp[0]
	var nrm: PackedVector2Array = fp[1]
	var n := pts.size()
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	var normals := PackedVector3Array()
	var us := PackedFloat32Array()
	var acc := 0.0
	for i in n:
		var pl0 := pts[i] * s0
		var pl1 := pts[i] * s1
		var yt := y1 + slope * pl1.x
		var yb := y0 + (slope * pl0.x if is_rim else 0.0)
		var p0 := pl0.rotated(rot) + c
		var p1 := pl1.rotated(rot) + c
		bottom.append(Vector3(p0.x, yb, p0.y))
		top.append(Vector3(p1.x, yt, p1.y))
		# Normal con la inclinación del ahusado
		var n2 := nrm[i].rotated(rot)
		var inward := (s0 - s1) * pts[i].dot(nrm[i])
		var tilt := atan2(inward, maxf(y1 - y0, 0.01))
		normals.append(Vector3(n2.x * cos(tilt), sin(tilt), n2.y * cos(tilt)).normalized())
		if i > 0:
			acc += (pts[i] - pts[i - 1]).length() * s0
		us.append(acc)
	var closing := acc + (pts[0] - pts[n - 1]).length() * s0
	for i in n:
		var j := (i + 1) % n
		var uj := us[j] if j > 0 else closing
		_tri(st, [bottom[i], bottom[j], top[j]], [normals[i], normals[j], normals[j]],
				[Vector2(us[i], bottom[i].y - y0), Vector2(uj, bottom[j].y - y0), Vector2(uj, top[j].y - y0)])
		_tri(st, [bottom[i], top[j], top[i]], [normals[i], normals[j], normals[i]],
				[Vector2(us[i], bottom[i].y - y0), Vector2(uj, top[j].y - y0), Vector2(us[i], top[i].y - y0)])
	# Cubierta en abanico desde el centro, en el plano de la cubierta
	var grad := Vector2(slope, 0.0).rotated(rot)
	var up := Vector3(-grad.x, 1.0, -grad.y).normalized()
	var ctop := Vector3(c.x, y1, c.y)
	for i in n:
		var j := (i + 1) % n
		_tri(_trim, [ctop, top[i], top[j]], [up, up, up], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	if is_rim:
		var down := Vector3(grad.x, -1.0, grad.y).normalized()
		var cb := Vector3(c.x, y0, c.y)
		for i in n:
			var j := (i + 1) % n
			_tri(st, [cb, bottom[j], bottom[i]], [down, down, down], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


## Banda de coronación: anillo blanco algo más ancho que la fachada, con su cubierta.
func _crown_band(fp: Array, c: Vector2, rot: float, s: float, y: float, height: float) -> void:
	var off := _offset_fp(fp, 0.35 / maxf(s, 0.1))
	_wall(_trim, off, c, rot, s, s, y, y + height, 0.0, true)


## Cúpula de cristal sobre la planta.
func _dome(fp: Array, c: Vector2, rot: float, y: float, dome_h: float) -> void:
	var pts: PackedVector2Array = fp[0]
	var nrm: PackedVector2Array = fp[1]
	var n := pts.size()
	var rings := 6
	var perimeter := 0.0
	for i in n:
		perimeter += (pts[(i + 1) % n] - pts[i]).length()
	var prev := PackedVector3Array()
	var prev_n := PackedVector3Array()
	var prev_v := 0.0
	var arc := 0.0
	for r in rings + 1:
		var t := float(r) / float(rings)
		var sc := cos(t * PI * 0.5)
		var yy := y + dome_h * sin(t * PI * 0.5)
		var ring := PackedVector3Array()
		var ring_n := PackedVector3Array()
		for i in n:
			var p := (pts[i] * maxf(sc, 0.001)).rotated(rot) + c
			ring.append(Vector3(p.x, yy, p.y))
			var n2 := nrm[i].rotated(rot)
			ring_n.append(Vector3(n2.x * sc, sin(t * PI * 0.5), n2.y * sc).normalized())
		if r > 0:
			arc += prev[0].distance_to(ring[0])
			for i in n:
				var j := (i + 1) % n
				# UV: meridianos como montantes (se juntan hacia arriba) y altura por el arco
				var u0 := perimeter * float(i) / float(n)
				var u1 := perimeter * float(i + 1) / float(n)
				var a0 := Vector2(u0, prev_v)
				var a1 := Vector2(u1, prev_v)
				var b0 := Vector2(u0, arc)
				var b1 := Vector2(u1, arc)
				_tri(_glass, [prev[i], prev[j], ring[j]], [prev_n[i], prev_n[j], ring_n[j]], [a0, a1, b1])
				_tri(_glass, [prev[i], ring[j], ring[i]], [prev_n[i], ring_n[j], ring_n[i]], [a0, b1, b0])
		prev = ring
		prev_n = ring_n
		prev_v = arc


## Aguja cónica blanca.
func _spire(c: Vector2, y: float, height: float, radius: float) -> void:
	var segs := 8
	var tip := Vector3(c.x, y + height, c.y)
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		var p0 := Vector3(c.x + cos(a0) * radius, y, c.y + sin(a0) * radius)
		var p1 := Vector3(c.x + cos(a1) * radius, y, c.y + sin(a1) * radius)
		var n0 := Vector3(cos(a0), 0.1, sin(a0)).normalized()
		var n1 := Vector3(cos(a1), 0.1, sin(a1)).normalized()
		_tri(_trim, [p0, p1, tip], [n0, n1, (n0 + n1).normalized()], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


## Triángulo orientado según las normales (en Godot las caras frontales van en sentido horario).
func _tri(st: SurfaceTool, v: Array, n: Array, uv: Array) -> void:
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var cc: Vector3 = v[2]
	var geo := (b - a).cross(cc - a)
	if geo.length_squared() < 1e-10:
		return
	var order := [0, 2, 1] if geo.dot(n[0] + n[1] + n[2]) > 0.0 else [0, 1, 2]
	for k in order:
		st.set_color(_tint)
		st.set_normal(n[k])
		st.set_uv(uv[k])
		st.add_vertex(v[k])
