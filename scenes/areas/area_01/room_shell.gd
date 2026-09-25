@tool
class_name RoomShell
extends Node3D
## Cáscara orgánica de la habitación generada por código: suelo, paredes y techo sin
## esquinas vivas. La planta es una superelipse más un lóbulo suave (la alcoba del
## living); el perfil vertical es un rectángulo redondeado. Genera además la colisión,
## una copia exterior solo para sombras, el borde del tragaluz y los marcos de ventana.
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

@export_group("Alcoba (living)")
@export var alcove_enabled: bool = true
@export_range(0.0, 360.0, 0.5) var alcove_angle_deg: float = 225.0   # Dirección del lóbulo
@export_range(0.0, 1.0, 0.01) var alcove_depth: float = 0.38         # Cuánto sobresale (fracción del radio)
@export_range(5.0, 90.0, 0.5) var alcove_width_deg: float = 26.0     # Anchura angular del lóbulo

@export_group("Resolución")
@export_range(16, 512) var segments_around: int = 176
@export_range(8, 128) var segments_profile: int = 64
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

const META_GENERATED := &"room_shell_generated"
const MAX_WINDOWS := 4
const EPS := 1e-3


func _ready() -> void:
	_build()


func _build() -> void:
	_clear_generated()

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


# --- Superficie paramétrica -----------------------------------------------------------
# theta: ángulo en planta (0 = +X, PI/2 = +Z). psi: ángulo del perfil vertical
# (-PI/2 = centro del suelo, 0 = media altura de la pared, PI/2 = centro del techo).

## Radio en planta para el ángulo theta (superelipse + lóbulo de la alcoba).
func _plan_radius(theta: float) -> float:
	var ct := cos(theta)
	var st := sin(theta)
	var n := plan_exponent
	var r := pow(pow(absf(ct) / half_width, n) + pow(absf(st) / half_depth, n), -1.0 / n)
	if alcove_enabled and alcove_depth > 0.0:
		var d := angle_difference(deg_to_rad(alcove_angle_deg), theta)
		var w := deg_to_rad(alcove_width_deg)
		r *= 1.0 + alcove_depth * exp(-(d * d) / (w * w))
	return r


## Perfil vertical: devuelve (escala horizontal, altura) para el ángulo psi.
func _profile(psi: float) -> Vector2:
	var cp := cos(psi)
	var sp := sin(psi)
	var n := profile_exponent
	var t := pow(pow(absf(cp), n) + pow(absf(sp), n), -1.0 / n)
	var half_h := height * 0.5
	return Vector2(maxf(t * cp, 0.0), half_h + half_h * t * sp)


func _surface_point(theta: float, psi: float) -> Vector3:
	var prof := _profile(psi)
	var r := _plan_radius(theta) * prof.x
	return Vector3(r * cos(theta), prof.y, r * sin(theta))


## Normal de la superficie apuntando hacia el interior (derivadas numéricas).
func _interior_normal(theta: float, psi: float) -> Vector3:
	var p := _surface_point(theta, psi)
	var dt := _surface_point(theta + EPS, psi) - _surface_point(theta - EPS, psi)
	var dp := _surface_point(theta, minf(psi + EPS, PI * 0.5)) - _surface_point(theta, maxf(psi - EPS, -PI * 0.5))
	var n := dt.cross(dp)
	if n.length_squared() < 1e-14:
		return Vector3.DOWN if psi > 0.0 else Vector3.UP
	n = n.normalized()
	var to_center := Vector3(0.0, height * 0.5, 0.0) - p
	if n.dot(to_center) < 0.0:
		n = -n
	return n


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

func _row_psi(j: int) -> float:
	return -PI * 0.5 + PI * float(j) / float(segments_profile)


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
		var psi := _row_psi(j)
		for i in n:
			var theta := TAU * float(i) / float(n)
			var p := _surface_point(theta, psi)
			var nrm := _interior_normal(theta, psi)
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
