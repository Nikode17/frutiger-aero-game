@tool
class_name RoomShell
extends Node3D
## Cáscara orgánica de la habitación: un superelipsoide interior (suelo, paredes y techo
## sin esquinas vivas) generado por código, más el borde del tragaluz y los marcos de
## ventana como tubos. Los huecos se recortan en aero_wall.gdshader; este script le pasa
## los mismos parámetros para que marcos y huecos coincidan.

enum Wall { NEG_Z, POS_Z, POS_X, NEG_X }

@export_tool_button("Reconstruir habitación") var rebuild_action: Callable = _build

@export_group("Dimensiones")
@export var half_width: float = 6.0        # Semieje en X (12 m de ancho)
@export var half_depth: float = 5.0        # Semieje en Z (10 m de fondo)
@export var height: float = 4.4            # Altura total
@export_range(2.0, 12.0) var plan_exponent: float = 4.0       # Redondez de las esquinas en planta
@export_range(2.0, 24.0) var profile_exponent: float = 12.0   # Redondez suelo-pared-techo
@export var floor_split_height: float = 0.12   # Hasta esta altura se aplica el material de suelo
@export var shadow_shell_thickness: float = 0.35   # Grosor de la cáscara exterior que solo proyecta sombras

@export_group("Resolución")
@export_range(16, 256) var segments_around: int = 112
@export_range(8, 128) var segments_profile: int = 64
@export_range(6, 32) var tube_segments: int = 14

@export_group("Materiales")
@export var floor_material: Material
@export var wall_material: Material
@export var rim_material: Material
@export var frame_material: Material

@export_group("Tragaluz")
@export var skylight_enabled: bool = true
@export var skylight_center: Vector2 = Vector2(0.6, -0.4)
@export var skylight_radius: Vector2 = Vector2(2.3, 1.6)
@export var skylight_wave1: Vector2 = Vector2(0.18, 0.4)   # amplitud, fase (3 lóbulos)
@export var skylight_wave2: Vector2 = Vector2(0.08, 1.9)   # amplitud, fase (5 lóbulos)
@export var skylight_rim_radius: float = 0.18
@export_range(24, 256) var skylight_rim_points: int = 128

@export_group("Ventana A")
@export var window_a_enabled: bool = true
@export var window_a_wall: Wall = Wall.NEG_Z
@export var window_a_offset: float = -2.0      # Posición a lo largo de la pared
@export var window_a_height: float = 1.7       # Altura del centro
@export var window_a_radius: Vector2 = Vector2(0.7, 1.0)
@export var window_a_frame_radius: float = 0.22

@export_group("Ventana B")
@export var window_b_enabled: bool = true
@export var window_b_wall: Wall = Wall.POS_X
@export var window_b_offset: float = 1.0
@export var window_b_height: float = 1.7
@export var window_b_radius: Vector2 = Vector2(0.75, 1.05)
@export var window_b_frame_radius: float = 0.22

const META_GENERATED := &"room_shell_generated"


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
	if window_a_enabled:
		_build_window_frame("WindowFrameA", window_a_wall, window_a_offset, window_a_height,
				window_a_radius, window_a_frame_radius)
	if window_b_enabled:
		_build_window_frame("WindowFrameB", window_b_wall, window_b_offset, window_b_height,
				window_b_radius, window_b_frame_radius)

	_update_wall_shader()


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()


# --- Geometría del superelipsoide -------------------------------------------------

## Perfil vertical: devuelve (escala horizontal, altura) para la fila j.
func _profile(j: int) -> Vector2:
	var psi := -PI * 0.5 + PI * float(j) / float(segments_profile)
	var cp := cos(psi)
	var sp := sin(psi)
	var n := profile_exponent
	var t := pow(pow(absf(cp), n) + pow(absf(sp), n), -1.0 / n)
	var half_h := height * 0.5
	return Vector2(maxf(t * cp, 0.0), half_h + half_h * t * sp)


## Contorno en planta a escala 1 (superelipse) para el ángulo theta.
func _plan_point(theta: float) -> Vector2:
	var ct := cos(theta)
	var st := sin(theta)
	var n := plan_exponent
	var t := pow(pow(absf(ct) / half_width, n) + pow(absf(st) / half_depth, n), -1.0 / n)
	return Vector2(t * ct, t * st)


func _grid_point(i: int, j: int) -> Vector3:
	var prof := _profile(j)
	var plan := _plan_point(TAU * float(i) / float(segments_around))
	return Vector3(plan.x * prof.x, prof.y, plan.y * prof.x)


## Normal de la superficie apuntando hacia el interior de la sala.
func _interior_normal(p: Vector3) -> Vector3:
	var a := half_width
	var c := half_depth
	var b := height * 0.5
	var nh := plan_exponent
	var nv := profile_exponent
	var ux := absf(p.x) / a
	var uz := absf(p.z) / c
	var uy := (p.y - b) / b
	var rho := pow(pow(ux, nh) + pow(uz, nh), 1.0 / nh)
	var g := Vector3.ZERO
	if rho > 1e-5:
		var common := nv * pow(rho, nv - nh)
		g.x = common * pow(ux, nh - 1.0) * signf(p.x) / a
		g.z = common * pow(uz, nh - 1.0) * signf(p.z) / c
	g.y = nv * pow(absf(uy), nv - 1.0) * signf(uy) / b
	if g.length_squared() < 1e-12:
		return Vector3.UP
	return -g.normalized()


## Altura del techo sobre el punto (x, z).
func _ceiling_y(x: float, z: float) -> float:
	var nh := plan_exponent
	var nv := profile_exponent
	var rho := minf(pow(pow(absf(x) / half_width, nh) + pow(absf(z) / half_depth, nh), 1.0 / nh), 1.0)
	var yhat := pow(maxf(1.0 - pow(rho, nv), 0.0), 1.0 / nv)
	return height * 0.5 + height * 0.5 * yhat


## Punto sobre una pared: u es la coordenada a lo largo de la pared y v la altura.
func _wall_point(wall: Wall, u: float, v: float) -> Vector3:
	var nh := plan_exponent
	var nv := profile_exponent
	var b := height * 0.5
	var uy := clampf((v - b) / b, -0.999, 0.999)
	var rho := pow(1.0 - pow(absf(uy), nv), 1.0 / nv)
	match wall:
		Wall.NEG_Z, Wall.POS_Z:
			var rem := maxf(pow(rho, nh) - pow(absf(u) / half_width, nh), 0.0)
			var z := half_depth * pow(rem, 1.0 / nh)
			return Vector3(u, v, -z if wall == Wall.NEG_Z else z)
		_:
			var rem := maxf(pow(rho, nh) - pow(absf(u) / half_depth, nh), 0.0)
			var x := half_width * pow(rem, 1.0 / nh)
			return Vector3(x if wall == Wall.POS_X else -x, v, u)


# --- Construcción de mallas ---------------------------------------------------------

## Malla de la cáscara; con offset > 0 se desplaza hacia fuera (para la copia de sombras).
func _build_shell_mesh(offset: float) -> ArrayMesh:
	# Fila más alta que sigue por debajo de floor_split_height: límite suelo/pared
	var split_row := 1
	for j in range(1, segments_profile):
		if _profile(j).y <= floor_split_height:
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
			var nrm := _interior_normal(p)
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
func _build_tube(node_name: String, points: PackedVector3Array, radius: float, mat: Material) -> void:
	var count := points.size()
	var rs := tube_segments
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for k in count:
		var p := points[k]
		var tangent := (points[(k + 1) % count] - points[(k - 1 + count) % count]).normalized()
		var surface_normal := _interior_normal(p)
		var n1 := tangent.cross(surface_normal).normalized()
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
	for k in skylight_rim_points:
		var ang := TAU * float(k) / float(skylight_rim_points)
		var limit := 1.0 + skylight_wave1.x * sin(3.0 * ang + skylight_wave1.y) \
				+ skylight_wave2.x * sin(5.0 * ang + skylight_wave2.y)
		var x := skylight_center.x + skylight_radius.x * limit * cos(ang)
		var z := skylight_center.y + skylight_radius.y * limit * sin(ang)
		points.append(Vector3(x, _ceiling_y(x, z), z))
	_build_tube("SkylightRim", points, skylight_rim_radius, rim_material)


func _build_window_frame(node_name: String, wall: Wall, offset: float, center_height: float,
		radius: Vector2, frame_radius: float) -> void:
	var points := PackedVector3Array()
	var steps := 64
	for k in steps:
		var ang := TAU * float(k) / float(steps)
		var u := offset + radius.x * cos(ang)
		var v := center_height + radius.y * sin(ang)
		points.append(_wall_point(wall, u, v))
	_build_tube(node_name, points, frame_radius, frame_material)


# --- Sincronización con el shader de pared -----------------------------------------

func _window_shader_center(wall: Wall, offset: float, center_height: float) -> Vector3:
	match wall:
		Wall.NEG_Z:
			return Vector3(offset, center_height, -half_depth)
		Wall.POS_Z:
			return Vector3(offset, center_height, half_depth)
		Wall.POS_X:
			return Vector3(half_width, center_height, offset)
		_:
			return Vector3(-half_width, center_height, offset)


func _window_shader_axis(wall: Wall) -> int:
	return 2 if wall == Wall.NEG_Z or wall == Wall.POS_Z else 0


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
	sm.set_shader_parameter("window_a_enabled", window_a_enabled)
	sm.set_shader_parameter("window_a_axis", _window_shader_axis(window_a_wall))
	sm.set_shader_parameter("window_a_center", _window_shader_center(window_a_wall, window_a_offset, window_a_height))
	sm.set_shader_parameter("window_a_radius", window_a_radius)
	sm.set_shader_parameter("window_b_enabled", window_b_enabled)
	sm.set_shader_parameter("window_b_axis", _window_shader_axis(window_b_wall))
	sm.set_shader_parameter("window_b_center", _window_shader_center(window_b_wall, window_b_offset, window_b_height))
	sm.set_shader_parameter("window_b_radius", window_b_radius)
