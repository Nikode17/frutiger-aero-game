@tool
class_name DropPendant
extends Node3D
## Colgante de gota de cristal: florón en el techo, cable fino de cromo, casquillo y una
## gota de cristal (superficie de revolución, punta arriba) con un núcleo de brillo suave
## dentro (glow_soft, aditivo). Origen en el techo; todo cuelga hacia -Y.

@export_tool_button("Reconstruir colgante") var rebuild_action: Callable = build

@export_group("Forma")
## Distancia del techo a la punta de la gota (m)
@export var cable_length: float = 2.3
@export var drop_height: float = 0.38
@export var drop_radius: float = 0.14
## Afilado de la punta (más alto = punta más larga y fina)
@export_range(0.5, 3.0, 0.05) var tip_sharpness: float = 1.3
@export var cable_radius: float = 0.003
@export var canopy_radius: float = 0.07
@export var cap_height: float = 0.035
@export_range(12, 64) var radial_segments: int = 40
@export_range(8, 64) var profile_segments: int = 32

@export_group("Materiales")
@export var glass_material: Material = preload("res://assets/materials/glass_cyan.tres")
@export var metal_material: Material = preload("res://assets/materials/chrome_bezel.tres")
@export var canopy_material: Material = preload("res://assets/materials/white_lacquer.tres")
@export var glow_material: Material = preload("res://assets/materials/glow_soft.tres")

@export_group("Brillo")
@export var glow_color: Color = Color(0.4, 0.85, 1.0)
@export var glow_energy: float = 0.7
## Tamaño del núcleo respecto a la gota
@export_range(0.2, 0.9, 0.01) var glow_scale: float = 0.62
## Luz real opcional (0 = sin luz); se apaga en calidad Baja como las de los LED
@export var light_energy: float = 0.0
@export var light_range: float = 1.8

@export_group("Colisión")
@export var collision_enabled: bool = true

const META_GENERATED := &"drop_pendant_generated"


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var tip_y := -cable_length
	var center_y := tip_y - drop_height * 0.62   # zona más ancha, algo por debajo de la mitad

	var canopy := CylinderMesh.new()
	canopy.top_radius = canopy_radius * 0.8
	canopy.bottom_radius = canopy_radius
	canopy.height = 0.025
	canopy.radial_segments = 32
	canopy.rings = 1
	_add_mesh("Canopy", canopy, canopy_material, Vector3(0.0, -0.0125 + 0.005, 0.0))

	var cable := CylinderMesh.new()
	cable.top_radius = cable_radius
	cable.bottom_radius = cable_radius
	cable.height = cable_length - cap_height * 0.5
	cable.radial_segments = 8
	cable.rings = 1
	_add_mesh("Cable", cable, metal_material, Vector3(0.0, -cable.height * 0.5, 0.0))

	var cap := CylinderMesh.new()
	cap.top_radius = cable_radius * 3.0
	cap.bottom_radius = drop_radius * 0.22
	cap.height = cap_height
	cap.radial_segments = 24
	cap.rings = 1
	_add_mesh("Cap", cap, metal_material, Vector3(0.0, tip_y + cap_height * 0.25, 0.0))

	_add_mesh("Drop", _drop_mesh(1.0), glass_material, Vector3(0.0, tip_y, 0.0))

	if glow_material and glow_energy > 0.0:
		var core := _add_mesh("Glow", _drop_mesh(glow_scale), glow_material,
				Vector3(0.0, tip_y - drop_height * (1.0 - glow_scale) * 0.62, 0.0))
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.set_instance_shader_parameter("glow_color", glow_color)
		core.set_instance_shader_parameter("glow_energy", glow_energy)

	if light_energy > 0.0:
		var light := OmniLight3D.new()
		light.name = "DropLight"
		light.position = Vector3(0.0, center_y, 0.0)
		light.light_color = glow_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.light_specular = 0.2
		light.shadow_enabled = false
		LedStrip.setup_light(light)
		_add_generated(light)

	if collision_enabled:
		var body := StaticBody3D.new()
		body.name = "DropBody"
		var shape := CapsuleShape3D.new()
		shape.radius = drop_radius
		shape.height = maxf(drop_height, drop_radius * 2.0)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(0.0, tip_y - drop_height * 0.5, 0.0)
		body.add_child(col)
		_add_generated(body)


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


func _add_mesh(node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_add_generated(mi)
	return mi


## Gota como superficie de revolución con la punta en el origen y el cuerpo hacia -Y.
## Curva clásica de lágrima: x = sin(t)·sin(t/2)^m, y = cos(t), t de 0 (punta) a PI (base).
func _drop_mesh(s: float) -> ArrayMesh:
	# Anchura máxima de la curva para normalizar al radio pedido
	var max_x := 0.0
	for k in 200:
		var t := PI * float(k) / 199.0
		max_x = maxf(max_x, sin(t) * pow(sin(t * 0.5), tip_sharpness))
	var h := drop_height * s
	var r := drop_radius * s
	var profile: Array[Vector2] = []
	for k in profile_segments + 1:
		# Más densidad cerca de la punta
		var u := float(k) / float(profile_segments)
		var t := PI * u * u * (3.0 - 2.0 * u) * 0.5 + PI * u * 0.5
		var x := sin(t) * pow(sin(t * 0.5), tip_sharpness) / max_x * r
		var y := -(1.0 - cos(t)) * 0.5 * h
		profile.append(Vector2(x, y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	for k in n:
		var a := profile[maxi(k - 1, 0)]
		var b := profile[mini(k + 1, n - 1)]
		var tan2 := (b - a).normalized()
		var n2 := Vector2(-tan2.y, tan2.x)   # hacia fuera del eje
		if n2.x < 0.0:
			n2 = -n2
		if k == 0:
			n2 = Vector2(0.0, 1.0)
		elif k == n - 1:
			n2 = Vector2(0.0, -1.0)
		for m in radial_segments + 1:
			var ang := TAU * float(m) / float(radial_segments)
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			st.set_normal((dir * n2.x + Vector3.UP * n2.y).normalized())
			st.add_vertex(dir * profile[k].x + Vector3.UP * profile[k].y)
	var row := radial_segments + 1
	for k in n - 1:
		for m in radial_segments:
			var i0 := k * row + m
			var i1 := i0 + 1
			var i2 := i0 + row
			var i3 := i2 + 1
			# Visto desde fuera, en sentido horario
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)
	return st.commit()
