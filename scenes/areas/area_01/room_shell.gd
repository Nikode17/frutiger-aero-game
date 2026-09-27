@tool
class_name RoomShell
extends Node3D
## Cáscara orgánica de la habitación generada por código: suelo, paredes y techo sin
## esquinas vivas. La planta es una B-spline cúbica cerrada que sigue una superelipse y,
## en una esquina, forma un entrante con cuello (la zona de ordenadores). El perfil
## vertical es un rectángulo redondeado. En algunos tramos la pared forma una "ola"
## (saliente redondeado hacia dentro a media altura). Genera además la colisión, una
## copia exterior solo para sombras, el borde del tragaluz y los marcos de ventana.
## Los huecos se recortan en aero_wall.gdshader con los mismos parámetros.

@export_tool_button("Reconstruir habitación") var rebuild_action: Callable = _build

@export_group("Dimensiones")
@export var half_width: float = 8.0        # Semieje en X
@export var half_depth: float = 6.5        # Semieje en Z
@export var height: float = 4.8            # Altura total
@export_range(2.0, 12.0) var plan_exponent: float = 4.0       # Redondez de las esquinas en planta
@export_range(2.0, 24.0) var profile_exponent: float = 12.0   # Redondez suelo-pared-techo
@export var floor_split_height: float = 0.12   # Hasta esta altura se aplica el material de suelo
@export var shadow_shell_thickness: float = 0.35   # Grosor de la cáscara exterior que solo proyecta sombras

@export_group("Entrante (ordenadores)")
@export var pocket_enabled: bool = true
@export_range(0.0, 360.0, 0.5) var pocket_angle_deg: float = 225.0   # Dirección del entrante
@export_range(5.0, 60.0, 0.5) var pocket_gap_deg: float = 24.0       # Semiapertura en la pared base
@export var pocket_entrance_half_width: float = 3.0   # Semianchura justo al entrar
@export var pocket_neck_half_width: float = 2.3       # Semianchura del cuello
@export var pocket_neck_distance: float = 1.5         # Distancia del cuello a la pared base
@export var pocket_half_width: float = 3.4            # Semianchura máxima del interior
@export var pocket_widest_distance: float = 3.6       # Distancia de la parte más ancha
@export var pocket_depth: float = 5.6                 # Profundidad total desde la pared base

@export_group("Resolución")
@export_range(32, 1024) var segments_around: int = 288
@export_range(8, 160) var segments_profile: int = 96   # más filas para que las olas queden suaves
@export_range(6, 32) var tube_segments: int = 14

@export_group("Materiales")
@export var floor_material: Material
@export var wall_material: Material
@export var rim_material: Material
@export var frame_material: Material

@export_group("Tragaluz")
@export var skylight_enabled: bool = true
@export var skylight_center: Vector2 = Vector2(0.0, 0.3)
@export var skylight_radius: Vector2 = Vector2(3.2, 2.2)
@export var skylight_wave1: Vector2 = Vector2(0.18, 0.4)   # amplitud, fase (3 lóbulos)
@export var skylight_wave2: Vector2 = Vector2(0.08, 1.9)   # amplitud, fase (5 lóbulos)
@export var skylight_rim_radius: float = 0.2
@export_range(24, 256) var skylight_rim_points: int = 160

@export_group("Ventanas")
@export var windows: Array[RoomWindow] = []

@export_group("Olas")
@export var waves: Array[RoomWave] = []

const META_GENERATED := &"room_shell_generated"
const MAX_WINDOWS := 4
const EPS := 1e-3

# Contorno en planta remuestreado por longitud de arco (segments_around puntos)
var _plan: PackedVector2Array = PackedVector2Array()
# Ángulo de cada punto de la planta (para las olas)
var _plan_theta: PackedFloat32Array = PackedFloat32Array()
# Signo para que las normales apunten al interior (se calcula una vez por construcción)
var _normal_sign: float = 1.0


func _ready() -> void:
	_build()


func _build() -> void:
	_clear_generated()
	_build_plan()

	var mesh := _build_shell_mesh(0.0)
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	# La cáscara visible no proyecta sombras: lo hace una copia exterior más gruesa,
	# así el sol no se cuela por las paredes (que no tienen grosor real).
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if floor_material:
		shell.set_surface_override_material(0, floor_material)
	if wall_material:
		shell.set_surface_override_material(1, wall_material)
	_add_generated(shell)

	if shadow_shell_thickness > 0.0:
		var shadow_shell := MeshInstance3D.new()
		shadow_shell.name = "ShadowShell"
		shadow_shell.mesh = _build_shell_mesh(shadow_shell_thickness)
		shadow_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if wall_material:
			# Mismo shader con los huecos para que la luz pase por tragaluz y ventanas
			shadow_shell.set_surface_override_material(0, wall_material)
			shadow_shell.set_surface_override_material(1, wall_material)
		_add_generated(shadow_shell)

	var body := StaticBody3D.new()
	body.name = "ShellBody"
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	_add_generated(body)

	if skylight_enabled:
		_build_skylight_rim()
	for i in windows.size():
		var w := windows[i]
		if w and w.enabled:
			_build_window_frame("WindowFrame%d" % i, w)

	_update_wall_shader()


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()


# --- Planta -------------------------------------------------------------------------

## Punto de la superelipse base para el ángulo theta.
func _base_point(theta: float) -> Vector2:
	var ct := cos(theta)
	var st := sin(theta)
	var n := plan_exponent
	var r := pow(pow(absf(ct) / half_width, n) + pow(absf(st) / half_depth, n), -1.0 / n)
	return Vector2(r * ct, r * st)


## Polígono de control: superelipse densa más los puntos del entrante en su hueco.
func _control_polygon() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var theta0 := deg_to_rad(pocket_angle_deg)
	var gap := deg_to_rad(pocket_gap_deg)
	var step := deg_to_rad(2.5)
	var count := int(round(TAU / step))
	var inserted := false
	for k in count:
		# Recorremos desde el borde del hueco para que el entrante quede contiguo
		var theta := theta0 + gap + step * float(k)
		var d := angle_difference(theta0, theta)
		if pocket_enabled and absf(d) < gap:
			if not inserted:
				pts.append_array(_pocket_points(theta0))
				inserted = true
			continue
		pts.append(_base_point(theta))
	return pts


## Puntos del entrante en coordenadas locales (b = a lo largo de la pared, a = hacia fuera).
func _pocket_points(theta0: float) -> PackedVector2Array:
	var n := Vector2(cos(theta0), sin(theta0))       # hacia fuera
	var t := Vector2(-sin(theta0), cos(theta0))      # sentido de theta creciente
	var w := _base_point(theta0)
	var local := [
		Vector2(-pocket_entrance_half_width, 0.5),
		Vector2(-pocket_neck_half_width, pocket_neck_distance),
		Vector2(-pocket_half_width, pocket_widest_distance),
		Vector2(-pocket_half_width * 0.75, pocket_depth - 0.8),
		Vector2(-pocket_half_width * 0.3, pocket_depth),
		Vector2(pocket_half_width * 0.3, pocket_depth),
		Vector2(pocket_half_width * 0.75, pocket_depth - 0.8),
		Vector2(pocket_half_width, pocket_widest_distance),
		Vector2(pocket_neck_half_width, pocket_neck_distance),
		Vector2(pocket_entrance_half_width, 0.5),
	]
	var pts := PackedVector2Array()
	for l: Vector2 in local:
		pts.append(w + t * l.x + n * l.y)
	return pts


## Construye la planta: B-spline cúbica cerrada y remuestreo uniforme por longitud.
func _build_plan() -> void:
	var ctrl := _control_polygon()
	var m := ctrl.size()
	var dense := PackedVector2Array()
	var sub := 12
	for k in m:
		var p0 := ctrl[(k - 1 + m) % m]
		var p1 := ctrl[k]
		var p2 := ctrl[(k + 1) % m]
		var p3 := ctrl[(k + 2) % m]
		for s in sub:
			var u := float(s) / float(sub)
			var u2 := u * u
			var u3 := u2 * u
			var b0 := (1.0 - u) * (1.0 - u) * (1.0 - u) / 6.0
			var b1 := (3.0 * u3 - 6.0 * u2 + 4.0) / 6.0
			var b2 := (-3.0 * u3 + 3.0 * u2 + 3.0 * u + 1.0) / 6.0
			var b3 := u3 / 6.0
			dense.append(p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3)
	# Longitud acumulada
	var total := 0.0
	var lengths := PackedFloat32Array()
	lengths.append(0.0)
	for k in dense.size():
		total += dense[k].distance_to(dense[(k + 1) % dense.size()])
		lengths.append(total)
	# Remuestreo
	_plan = PackedVector2Array()
	var seg := 0
	for i in segments_around:
		var target := total * float(i) / float(segments_around)
		while seg < dense.size() - 1 and lengths[seg + 1] < target:
			seg += 1
		var a := dense[seg]
		var b := dense[(seg + 1) % dense.size()]
		var span := lengths[seg + 1] - lengths[seg]
		var f := 0.0 if span <= 0.0 else (target - lengths[seg]) / span
		_plan.append(a.lerp(b, f))
	_plan_theta = PackedFloat32Array()
	for p in _plan:
		_plan_theta.append(atan2(p.y, p.x))
	_normal_sign = 1.0
	var probe := _grid_normal_raw(0, segments_profile / 2)
	var to_center := -Vector3(_plan[0].x, 0.0, _plan[0].y)
	if probe.dot(to_center) < 0.0:
		_normal_sign = -1.0


## Punto de la planta más lejano en la dirección theta (intersección rayo-polígono).
func _plan_hit(theta: float) -> Vector2:
	var d := Vector2(cos(theta), sin(theta))
	var best_t := 0.0
	var best := Vector2.ZERO
	var n := _plan.size()
	for k in n:
		var a := _plan[k]
		var b := _plan[(k + 1) % n]
		var e := b - a
		var denom := d.cross(e)
		if absf(denom) < 1e-9:
			continue
		var t := a.cross(e) / denom       # distancia a lo largo del rayo
		var s := a.cross(d) / denom       # posición en el segmento
		if s >= 0.0 and s <= 1.0 and t > best_t:
			best_t = t
			best = a + e * s
	return best


func _plan_radius(theta: float) -> float:
	return _plan_hit(theta).length()


# --- Superficie paramétrica ---------------------------------------------------------
# psi: ángulo del perfil vertical (-PI/2 = centro del suelo, 0 = media altura de la
# pared, PI/2 = centro del techo).

## Perfil vertical: devuelve (escala horizontal, altura) para el ángulo psi.
func _profile(psi: float) -> Vector2:
	var cp := cos(psi)
	var sp := sin(psi)
	var n := profile_exponent
	var t := pow(pow(absf(cp), n) + pow(absf(sp), n), -1.0 / n)
	var half_h := height * 0.5
	return Vector2(maxf(t * cp, 0.0), half_h + half_h * t * sp)


func _row_psi(j: int) -> float:
	return -PI * 0.5 + PI * float(j) / float(segments_profile)


func _grid_point(i: int, j: int) -> Vector3:
	var prof := _profile(_row_psi(j))
	var k := i % segments_around
	var p := _apply_waves(_plan[k] * prof.x, _plan_theta[k], prof.y)
	return Vector3(p.x, prof.y, p.y)


# --- Olas ---------------------------------------------------------------------------

## Desplaza el punto de la planta hacia dentro (en dirección radial) según las olas.
func _apply_waves(p: Vector2, theta: float, y: float) -> Vector2:
	var off := _wave_offset(theta, y)
	if off <= 0.0:
		return p
	var r := p.length()
	if r < EPS:
		return p
	return p * maxf(r - off, 0.0) / r


## Suma de lo que sale la pared por todas las olas en (theta, altura).
func _wave_offset(theta: float, y: float) -> float:
	var total := 0.0
	for w in waves:
		if w == null or not w.enabled or w.depth <= 0.0:
			continue
		var half := deg_to_rad(w.half_width_deg)
		var d := angle_difference(deg_to_rad(w.angle_deg), theta)
		if absf(d) >= half:
			continue
		# Entrada y salida laterales: núcleo plano y transición suave (1 - u²)²
		var taper := minf(deg_to_rad(w.taper_deg), half)
		var u := clampf((absf(d) - (half - taper)) / taper, 0.0, 1.0)
		var side := (1.0 - u * u) * (1.0 - u * u)
		# La cresta ondula un poco a lo largo del tramo
		var crest := w.crest_height + w.crest_variation * sin(PI * d / half)
		# Perfil vertical asimétrico: sube suave desde abajo y vuelve antes hacia el techo
		var v := 0.0
		if y < crest:
			v = (crest - y) / maxf(w.lower_extent, EPS)
		else:
			v = (y - crest) / maxf(w.upper_extent, EPS)
		if v >= 1.0:
			continue
		var vertical := (1.0 - v * v) * (1.0 - v * v)
		total += w.depth * side * vertical
	return total


func _grid_normal_raw(i: int, j: int) -> Vector3:
	var n := segments_around
	var du := _grid_point((i + 1) % n, j) - _grid_point((i - 1 + n) % n, j)
	var jm := maxi(j - 1, 0)
	var jp := mini(j + 1, segments_profile)
	var dv := _grid_point(i, jp) - _grid_point(i, jm)
	var nrm := dv.cross(du)
	if nrm.length_squared() < 1e-14:
		return Vector3.UP if j < segments_profile / 2 else Vector3.DOWN
	return nrm.normalized()


func _grid_normal(i: int, j: int) -> Vector3:
	var nrm := _grid_normal_raw(i, j)
	if absf(nrm.y) > 0.999:
		# Polos: hacia dentro es arriba en el suelo y abajo en el techo
		return Vector3.UP if j < segments_profile / 2 else Vector3.DOWN
	return nrm * _normal_sign


## Punto de la superficie en la dirección theta (para tubos y marcos).
func _surface_point(theta: float, psi: float) -> Vector3:
	var prof := _profile(psi)
	var p := _apply_waves(_plan_hit(theta) * prof.x, theta, prof.y)
	return Vector3(p.x, prof.y, p.y)


func _interior_normal(theta: float, psi: float) -> Vector3:
	var dt := _surface_point(theta + EPS, psi) - _surface_point(theta - EPS, psi)
	var dp := _surface_point(theta, minf(psi + EPS, PI * 0.5)) - _surface_point(theta, maxf(psi - EPS, -PI * 0.5))
	var n := dp.cross(dt)
	if n.length_squared() < 1e-14:
		return Vector3.DOWN if psi > 0.0 else Vector3.UP
	return n.normalized() * _normal_sign


## psi del techo sobre el punto (x, z).
func _ceiling_psi(x: float, z: float) -> float:
	var theta := atan2(z, x)
	var rho := clampf(Vector2(x, z).length() / _plan_radius(theta), 0.0, 1.0)
	var yhat := pow(maxf(1.0 - pow(rho, profile_exponent), 0.0), 1.0 / profile_exponent)
	return atan2(yhat, rho)


## psi de la pared a la altura v.
func _wall_psi(v: float) -> float:
	var b := height * 0.5
	var yhat := clampf((v - b) / b, -0.999, 0.999)
	var s := pow(1.0 - pow(absf(yhat), profile_exponent), 1.0 / profile_exponent)
	return atan2(yhat, s)


# --- Construcción de mallas ---------------------------------------------------------

## Malla de la cáscara; con offset > 0 se desplaza hacia fuera (para la copia de sombras).
func _build_shell_mesh(offset: float) -> ArrayMesh:
	# Fila más alta que sigue por debajo de floor_split_height: límite suelo/pared
	var split_row := 1
	for j in range(1, segments_profile):
		if _profile(_row_psi(j)).y <= floor_split_height:
			split_row = j
	var mesh := ArrayMesh.new()
	_add_shell_band(mesh, 0, split_row, offset)                  # superficie 0: suelo
	_add_shell_band(mesh, split_row, segments_profile, offset)   # superficie 1: paredes y techo
	return mesh


func _add_shell_band(mesh: ArrayMesh, j0: int, j1: int, offset: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var n := segments_around
	for j in range(j0, j1 + 1):
		for i in n:
			var p := _grid_point(i, j)
			var nrm := _grid_normal(i, j)
			if offset > 0.0:
				# Copia exterior: caras hacia fuera para que la luz las vea de frente
				p -= nrm * offset
				nrm = -nrm
			verts.append(p)
			norms.append(nrm)
			st.set_normal(nrm)
			st.add_vertex(p)
	for j in range(j0, j1):
		var ra := (j - j0) * n
		var rb := ra + n
		for i in n:
			var i2 := (i + 1) % n
			_add_tri(st, verts, norms, ra + i, ra + i2, rb + i2)
			_add_tri(st, verts, norms, ra + i, rb + i2, rb + i)
	st.commit(mesh)


## Añade un triángulo orientado según las normales (descarta los degenerados).
func _add_tri(st: SurfaceTool, verts: PackedVector3Array, norms: PackedVector3Array,
		a: int, b: int, c: int) -> void:
	var geo := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if geo.length_squared() < 1e-12:
		return
	# Godot usa orden horario para las caras frontales: el producto vectorial
	# de un triángulo bien orientado apunta en contra de su normal.
	var wanted := norms[a] + norms[b] + norms[c]
	st.add_index(a)
	if geo.dot(wanted) > 0.0:
		st.add_index(c)
		st.add_index(b)
	else:
		st.add_index(b)
		st.add_index(c)


## Tubo cerrado que sigue una lista de puntos apoyados en la superficie.
func _build_tube(node_name: String, points: PackedVector3Array, surface_normals: PackedVector3Array,
		radius: float, mat: Material) -> void:
	var count := points.size()
	var rs := tube_segments
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for k in count:
		var p := points[k]
		var tangent := (points[(k + 1) % count] - points[(k - 1 + count) % count]).normalized()
		var n1 := tangent.cross(surface_normals[k]).normalized()
		var n2 := n1.cross(tangent).normalized()
		for m in rs:
			var beta := TAU * float(m) / float(rs)
			var radial := n1 * cos(beta) + n2 * sin(beta)
			verts.append(p + radial * radius)
			norms.append(radial)
			st.set_normal(radial)
			st.add_vertex(p + radial * radius)
	for k in count:
		var k2 := (k + 1) % count
		for m in rs:
			var m2 := (m + 1) % rs
			_add_tri(st, verts, norms, k * rs + m, k * rs + m2, k2 * rs + m2)
			_add_tri(st, verts, norms, k * rs + m, k2 * rs + m2, k2 * rs + m)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	if mat:
		mi.material_override = mat
	_add_generated(mi)


func _build_skylight_rim() -> void:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for k in skylight_rim_points:
		var ang := TAU * float(k) / float(skylight_rim_points)
		var limit := 1.0 + skylight_wave1.x * sin(3.0 * ang + skylight_wave1.y) \
				+ skylight_wave2.x * sin(5.0 * ang + skylight_wave2.y)
		var x := skylight_center.x + skylight_radius.x * limit * cos(ang)
		var z := skylight_center.y + skylight_radius.y * limit * sin(ang)
		var theta := atan2(z, x)
		var psi := _ceiling_psi(x, z)
		points.append(_surface_point(theta, psi))
		normals.append(_interior_normal(theta, psi))
	_build_tube("SkylightRim", points, normals, skylight_rim_radius, rim_material)


func _build_window_frame(node_name: String, w: RoomWindow) -> void:
	var theta0 := deg_to_rad(w.angle_deg)
	var wall_r := _plan_radius(theta0)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var steps := 72
	for k in steps:
		var ang := TAU * float(k) / float(steps)
		var theta := theta0 + w.radius.x * cos(ang) / wall_r
		var psi := _wall_psi(w.center_height + w.radius.y * sin(ang))
		points.append(_surface_point(theta, psi))
		normals.append(_interior_normal(theta, psi))
	_build_tube(node_name, points, normals, w.frame_radius, frame_material)


# --- Sincronización con el shader de pared -----------------------------------------

func _update_wall_shader() -> void:
	var sm := wall_material as ShaderMaterial
	if sm == null:
		return
	sm.set_shader_parameter("gradient_end", height)
	sm.set_shader_parameter("skylight_enabled", skylight_enabled)
	sm.set_shader_parameter("skylight_center", skylight_center)
	sm.set_shader_parameter("skylight_radius", skylight_radius)
	sm.set_shader_parameter("skylight_wave1", skylight_wave1)
	sm.set_shader_parameter("skylight_wave2", skylight_wave2)
	sm.set_shader_parameter("skylight_min_height", height * 0.6)
	var pos_list: Array[Vector4] = []
	var size_list: Array[Vector2] = []
	for i in MAX_WINDOWS:
		var w: RoomWindow = windows[i] if i < windows.size() else null
		if w and w.enabled:
			var theta0 := deg_to_rad(w.angle_deg)
			pos_list.append(Vector4(theta0, w.center_height, _plan_radius(theta0), 1.0))
			size_list.append(w.radius)
		else:
			pos_list.append(Vector4.ZERO)
			size_list.append(Vector2.ZERO)
	sm.set_shader_parameter("window_pos", pos_list)
	sm.set_shader_parameter("window_size", size_list)
