@tool
class_name AquariumScreen
extends Node3D
## Pantalla grande del fondo del entrante: superficie curvada que sigue la pared real
## (se calcula a partir de RoomShell), esquinas muy redondeadas, marco tubular (aro exterior
## metálico y aro fino interior de color) y unas luces azules suaves que iluminan la mesa y
## el suelo. El contenido sale del
## SubViewport hijo (escena del acuario).

@export_tool_button("Reconstruir pantalla") var rebuild_action: Callable = _build

@export var room_shell_path: NodePath = ^"../RoomShell"
@export var viewport_path: NodePath = ^"AquariumViewport"

@export_group("Geometría")
@export_range(0.0, 360.0, 0.5) var center_angle_deg: float = 225.0   # Dirección del centro de la pantalla
@export var width: float = 5.0            # Ancho a lo largo de la pared (m)
@export var bottom_height: float = 1.28    # Altura del borde inferior (m)
@export var top_height: float = 3.18       # Altura del borde superior (m)
@export var wall_offset: float = 0.06     # Separación de la pared (m)
@export var corner_radius: float = 0.4   # Radio de las esquinas (m)
@export_range(8, 256) var segments_x: int = 72
@export_range(2, 64) var segments_y: int = 12

@export_group("Marco")
@export var frame_radius: float = 0.035
@export var frame_material: Material
## Aro fino interior, pegado al borde interior del marco (0 = sin aro)
@export var accent_radius: float = 0.012
@export var accent_material: Material
@export_range(24, 400) var frame_points: int = 160

@export_group("Imagen")
@export var screen_shader: Shader = preload("res://assets/shaders/aquarium_screen.gdshader")
@export var brightness: float = 1.0
## Veces por segundo que se vuelve a renderizar el acuario (0 = cada fotograma)
@export var viewport_fps: float = 30.0

@export_group("Luz")
@export var light_color: Color = Color(0.45, 0.75, 1.0)
@export var light_energy: float = 0.55
@export var light_range: float = 3.2
@export_range(0, 6) var light_count: int = 3
@export var light_distance: float = 0.9   # Cuánto se separan de la pantalla (m)
@export var light_pulse: float = 0.06     # Variación lenta de intensidad en juego

const META_GENERATED := &"aquarium_screen_generated"

var _shell: RoomShell
var _theta_samples: PackedFloat32Array = PackedFloat32Array()
var _s_samples: PackedFloat32Array = PackedFloat32Array()
var _s_start: float = 0.0
var _lights: Array[OmniLight3D] = []
var _time: float = 0.0
var _since_render: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	# Renderizar el acuario a un ritmo limitado para no cargar la GPU
	var vp := get_node_or_null(viewport_path) as SubViewport
	if vp:
		_since_render += delta
		if viewport_fps <= 0.0:
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif _since_render >= 1.0 / viewport_fps:
			_since_render = 0.0
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if light_pulse <= 0.0:
		return
	for k in _lights.size():
		_lights[k].light_energy = light_energy * (1.0 + light_pulse * sin(_time * 0.8 + float(k) * 2.1))


func _build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	_lights.clear()
	_shell = get_node_or_null(room_shell_path) as RoomShell
	if _shell == null:
		push_warning("AquariumScreen: no se encontró RoomShell en '%s'." % room_shell_path)
		return
	if _shell._plan.is_empty():
		_shell._build()
	_sample_wall()

	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = _build_screen_mesh()
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.material_override = _make_screen_material()
	_add_generated(screen)

	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = _build_frame_mesh(0.0, frame_radius, 0.0)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if frame_material:
		frame.material_override = frame_material
	_add_generated(frame)

	if accent_material and accent_radius > 0.0:
		var accent := MeshInstance3D.new()
		accent.name = "FrameAccent"
		# Medio metido bajo el borde interior del marco y un poco por delante de la imagen
		accent.mesh = _build_frame_mesh(frame_radius + accent_radius * 0.6, accent_radius, accent_radius * 0.4)
		accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		accent.material_override = accent_material
		_add_generated(accent)

	for k in light_count:
		var light := OmniLight3D.new()
		light.name = "ScreenLight%d" % k
		var s := width * (float(k) + 0.5) / float(light_count)
		var y := lerpf(bottom_height, top_height, 0.35)
		light.position = _point(s, y, wall_offset + light_distance)
		light.light_color = light_color
		light.light_energy = light_energy
		light.light_specular = 0.0
		light.omni_range = light_range
		_add_generated(light)
		_lights.append(light)


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


# --- Geometría sobre la pared -------------------------------------------------------

## Muestrea la pared del fondo a media altura para poder recorrerla por longitud de arco.
func _sample_wall() -> void:
	_theta_samples = PackedFloat32Array()
	_s_samples = PackedFloat32Array()
	var psi := _shell._wall_psi((bottom_height + top_height) * 0.5)
	var c := deg_to_rad(center_angle_deg)
	var span := deg_to_rad(14.0)
	var steps := 400
	var prev := Vector3.ZERO
	var total := 0.0
	var s_center := 0.0
	for k in steps + 1:
		var th := c - span + 2.0 * span * float(k) / float(steps)
		var p := _shell._surface_point(th, psi)
		if k > 0:
			total += p.distance_to(prev)
		prev = p
		_theta_samples.append(th)
		_s_samples.append(total)
		if k == steps / 2:
			s_center = total
	_s_start = s_center - width * 0.5


## Ángulo de la pared para una distancia s medida a lo largo de la pantalla.
func _theta_at(s: float) -> float:
	var target := _s_start + s
	var n := _s_samples.size()
	for k in range(1, n):
		if _s_samples[k] >= target:
			var f := (target - _s_samples[k - 1]) / maxf(_s_samples[k] - _s_samples[k - 1], 1e-6)
			return lerpf(_theta_samples[k - 1], _theta_samples[k], f)
	return _theta_samples[n - 1]


## Punto sobre la pared (en coordenadas de este nodo) separado `offset` hacia dentro.
func _point(s: float, y: float, offset: float) -> Vector3:
	var th := _theta_at(s)
	var psi := _shell._wall_psi(y)
	var p := _shell._surface_point(th, psi) + _shell._interior_normal(th, psi) * offset
	return to_local(_shell.to_global(p))


func _normal(s: float, y: float) -> Vector3:
	var th := _theta_at(s)
	var n := _shell._interior_normal(th, _shell._wall_psi(y))
	return (global_transform.basis.inverse() * (_shell.global_transform.basis * n)).normalized()


func _build_screen_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := top_height - bottom_height
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for j in segments_y + 1:
		var v := float(j) / float(segments_y)
		var y := bottom_height + v * h
		for i in segments_x + 1:
			var u := float(i) / float(segments_x)
			var p := _point(u * width, y, wall_offset)
			var n := _normal(u * width, y)
			verts.append(p)
			norms.append(n)
			st.set_normal(n)
			st.set_uv(Vector2(u, 1.0 - v))
			st.add_vertex(p)
	var row := segments_x + 1
	for j in segments_y:
		for i in segments_x:
			var a := j * row + i
			_add_tri(st, verts, norms, a, a + 1, a + row + 1)
			_add_tri(st, verts, norms, a, a + row + 1, a + row)
	return st.commit()


## Tubo de radio `radius` que sigue el contorno redondeado de la pantalla, encogido
## `inset` metros y separado `offset` metros de la pantalla hacia la sala.
func _build_frame_mesh(inset: float, radius: float, offset: float) -> ArrayMesh:
	var h := top_height - bottom_height
	var rc0 := minf(corner_radius, minf(width, h) * 0.5)
	var rc := maxf(rc0 - inset, 0.01)
	# Contorno en (s, y): cuatro esquinas redondeadas unidas por tramos rectos
	var outline: Array[Vector2] = []
	var lo := inset + rc
	var corners := [
		[Vector2(width - lo, h - lo), 0.0], [Vector2(lo, h - lo), PI * 0.5],
		[Vector2(lo, lo), PI], [Vector2(width - lo, lo), PI * 1.5],
	]
	var per_corner := maxi(frame_points / 8, 4)
	var per_side := maxi(frame_points / 8, 4)
	for c in 4:
		var center: Vector2 = corners[c][0]
		var a0: float = corners[c][1]
		for k in per_corner:
			var a := a0 + PI * 0.5 * float(k) / float(per_corner)
			outline.append(center + Vector2(cos(a), sin(a)) * rc)
		var next_center: Vector2 = corners[(c + 1) % 4][0]
		var end := center + Vector2(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5)) * rc
		var start_next := next_center + Vector2(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5)) * rc
		for k in per_side:
			outline.append(end.lerp(start_next, float(k) / float(per_side)))
	var points := PackedVector3Array()
	var surf_normals := PackedVector3Array()
	for q in outline:
		points.append(_point(q.x, bottom_height + q.y, wall_offset + offset))
		surf_normals.append(_normal(q.x, bottom_height + q.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rs := 12
	var count := points.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for k in count:
		var tangent := (points[(k + 1) % count] - points[(k - 1 + count) % count]).normalized()
		var n1 := tangent.cross(surf_normals[k]).normalized()
		var n2 := n1.cross(tangent).normalized()
		for m in rs:
			var beta := TAU * float(m) / float(rs)
			var radial := n1 * cos(beta) + n2 * sin(beta)
			verts.append(points[k] + radial * radius)
			norms.append(radial)
			st.set_normal(radial)
			st.add_vertex(points[k] + radial * radius)
	for k in count:
		var k2 := (k + 1) % count
		for m in rs:
			var m2 := (m + 1) % rs
			_add_tri(st, verts, norms, k * rs + m, k * rs + m2, k2 * rs + m2)
			_add_tri(st, verts, norms, k * rs + m, k2 * rs + m2, k2 * rs + m)
	return st.commit()


## Triángulo orientado según las normales (en Godot las caras frontales van en sentido horario).
func _add_tri(st: SurfaceTool, verts: PackedVector3Array, norms: PackedVector3Array, a: int, b: int, c: int) -> void:
	var geo := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if geo.length_squared() < 1e-12:
		return
	st.add_index(a)
	if geo.dot(norms[a] + norms[b] + norms[c]) > 0.0:
		st.add_index(c)
		st.add_index(b)
	else:
		st.add_index(b)
		st.add_index(c)


func _make_screen_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = screen_shader
	var h := top_height - bottom_height
	mat.set_shader_parameter("aspect", width / h)
	mat.set_shader_parameter("corner_radius", minf(corner_radius, minf(width, h) * 0.5) / h)
	mat.set_shader_parameter("brightness", brightness)
	var vp := get_node_or_null(viewport_path) as SubViewport
	if vp:
		mat.set_shader_parameter("screen_tex", vp.get_texture())
	else:
		push_warning("AquariumScreen: no se encontró el SubViewport '%s'." % viewport_path)
	return mat
