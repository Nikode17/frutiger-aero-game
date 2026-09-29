@tool
class_name LedStrip
extends Node3D
## Tira LED: tubo fino emisivo a lo largo de una línea de puntos (coordenadas locales),
## suavizada con Catmull-Rom y, si se quiere, unas luces pequeñas sin sombra repartidas a
## lo largo que bañan de color el suelo o la pared cercana. Los puntos los pone la escena
## o un script (por ejemplo RoomLeds).

@export_tool_button("Reconstruir tira") var rebuild_action: Callable = build

@export var points: PackedVector3Array = PackedVector3Array()
@export var closed: bool = false
@export var smooth: bool = true
@export var radius: float = 0.012
@export_range(3, 24) var sides: int = 8
@export var spacing: float = 0.05          # distancia entre anillos del tubo (m)
@export var material: Material

@export_group("Luces")
@export_range(0, 32) var light_count: int = 0
@export var light_color: Color = Color(0.3, 0.85, 1.0)
@export var light_energy: float = 0.8
@export var light_range: float = 1.0
@export var light_attenuation: float = 1.5
@export var light_specular: float = 0.3
@export var light_offset: Vector3 = Vector3.ZERO   # desplazamiento de cada luz respecto a la tira

const META_GENERATED := &"led_strip_generated"
## Grupo de las luces pequeñas de las tiras (el selector de calidad las apaga en Baja)
const LIGHT_GROUP := &"led_lights"
## Distancia a la cámara a partir de la cual las luces se apagan (el tubo sigue brillando)
const LIGHT_FADE_BEGIN := 12.0
const LIGHT_FADE_LENGTH := 4.0


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var path := _sample_path()
	if path.size() < 2:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Tube"
	mi.mesh = _build_tube(path)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material:
		mi.material_override = material
	_add_generated(mi)
	if light_count > 0:
		_build_lights(path)


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


# --- Recorrido ----------------------------------------------------------------------

## Puntos del recorrido remuestreados a distancia constante (spacing).
func _sample_path() -> PackedVector3Array:
	var n := points.size()
	if n < 2:
		return PackedVector3Array()
	var dense := PackedVector3Array()
	var segs := n if closed else n - 1
	for k in segs:
		var p1 := points[k]
		var p2 := points[(k + 1) % n]
		if not smooth:
			dense.append(p1)
			continue
		var p0 := points[(k - 1 + n) % n] if (closed or k > 0) else p1 * 2.0 - p2
		var p3 := points[(k + 2) % n] if (closed or k + 2 < n) else p2 * 2.0 - p1
		var steps := maxi(int(ceil(p1.distance_to(p2) / (spacing * 0.5))), 1)
		for s in steps:
			var t := float(s) / float(steps)
			dense.append(_catmull_rom(p0, p1, p2, p3, t))
	dense.append(points[0] if closed else points[n - 1])
	# Remuestreo por longitud
	var total := 0.0
	var acc := PackedFloat32Array([0.0])
	for k in range(1, dense.size()):
		total += dense[k].distance_to(dense[k - 1])
		acc.append(total)
	var count := maxi(int(round(total / spacing)), 1)
	var out := PackedVector3Array()
	var seg := 0
	var last := count if not closed else count - 1
	for i in last + 1:
		var target := total * float(i) / float(count)
		while seg < dense.size() - 2 and acc[seg + 1] < target:
			seg += 1
		var span := acc[seg + 1] - acc[seg]
		var f := 0.0 if span <= 0.0 else (target - acc[seg]) / span
		out.append(dense[seg].lerp(dense[seg + 1], clampf(f, 0.0, 1.0)))
	return out


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


# --- Malla ----------------------------------------------------------------------------

func _build_tube(path: PackedVector3Array) -> ArrayMesh:
	var count := path.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	# Marco con transporte paralelo para que el tubo no se retuerza
	var normal := Vector3.ZERO
	for k in count:
		var tangent := _tangent(path, k)
		if k == 0:
			normal = tangent.cross(Vector3.UP)
			if normal.length_squared() < 1e-6:
				normal = tangent.cross(Vector3.RIGHT)
			normal = normal.normalized()
		else:
			normal = (normal - tangent * normal.dot(tangent)).normalized()
		var binormal := tangent.cross(normal).normalized()
		for m in sides:
			var a := TAU * float(m) / float(sides)
			var radial := normal * cos(a) + binormal * sin(a)
			verts.append(path[k] + radial * radius)
			norms.append(radial)
	var rings := count if closed else count - 1
	for k in rings:
		var k2 := (k + 1) % count
		for m in sides:
			var m2 := (m + 1) % sides
			_add_tri(verts, norms, indices, k * sides + m, k * sides + m2, k2 * sides + m2)
			_add_tri(verts, norms, indices, k * sides + m, k2 * sides + m2, k2 * sides + m)
	# Tapas planas en los extremos de las tiras abiertas
	if not closed:
		for end in [0, count - 1]:
			var t := _tangent(path, end) * (-1.0 if end == 0 else 1.0)
			var c := verts.size()
			verts.append(path[end])
			norms.append(t)
			for m in sides:
				verts.append(verts[end * sides + m])
				norms.append(t)
			for m in sides:
				_add_tri(verts, norms, indices, c, c + 1 + m, c + 1 + (m + 1) % sides)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _tangent(path: PackedVector3Array, k: int) -> Vector3:
	var n := path.size()
	var a := path[(k - 1 + n) % n] if (closed or k > 0) else path[k]
	var b := path[(k + 1) % n] if (closed or k < n - 1) else path[k]
	var t := b - a
	return t.normalized() if t.length_squared() > 1e-12 else Vector3.FORWARD


## Triángulo orientado según las normales (en Godot las caras frontales van en sentido horario).
func _add_tri(verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array, a: int, b: int, c: int) -> void:
	var geo := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if geo.length_squared() < 1e-14:
		return
	indices.append(a)
	if geo.dot(norms[a] + norms[b] + norms[c]) > 0.0:
		indices.append(c)
		indices.append(b)
	else:
		indices.append(b)
		indices.append(c)


# --- Luces ----------------------------------------------------------------------------

func _build_lights(path: PackedVector3Array) -> void:
	var total := 0.0
	var acc := PackedFloat32Array([0.0])
	for k in range(1, path.size()):
		total += path[k].distance_to(path[k - 1])
		acc.append(total)
	for i in light_count:
		var f := (float(i) + (0.0 if closed else 0.5)) / float(light_count)
		var target := total * f
		var k := 0
		while k < path.size() - 2 and acc[k + 1] < target:
			k += 1
		var span := acc[k + 1] - acc[k]
		var pos := path[k].lerp(path[k + 1], 0.0 if span <= 0.0 else (target - acc[k]) / span)
		var light := OmniLight3D.new()
		light.name = "LedLight%d" % i
		light.position = pos + light_offset
		light.light_color = light_color
		light.light_energy = light_energy
		light.light_specular = light_specular
		light.omni_range = light_range
		light.omni_attenuation = light_attenuation
		light.shadow_enabled = false
		setup_light(light)
		_add_generated(light)


## Ajustes comunes de las luces LED: sin niebla volumétrica (no se ven y encarecen la
## niebla), apagado por distancia y grupo para el selector de calidad.
static func setup_light(light: Light3D) -> void:
	light.light_volumetric_fog_energy = 0.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = LIGHT_FADE_BEGIN
	light.distance_fade_length = LIGHT_FADE_LENGTH
	light.add_to_group(LIGHT_GROUP)
