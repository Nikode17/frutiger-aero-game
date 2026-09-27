@tool
class_name WaterColumn
extends Node3D
## Escultura central: tubo de cristal con agua cian luminosa y burbujas subiendo,
## base y remate redondeados, luz cian y cáusticas en el suelo. Todo se construye
## por código a partir de los parámetros exportados.

@export_tool_button("Reconstruir columna") var rebuild_action: Callable = _build

@export_group("Geometría")
@export var column_height: float = 4.8      # De suelo a techo
@export var radius: float = 0.65            # Radio exterior del cristal
@export var glass_thickness: float = 0.04
@export var cap_height: float = 0.3         # Altura de base y remate
@export var cap_overhang: float = 0.1       # Cuánto sobresale la base respecto al cristal

@export_group("Materiales")
@export var glass_material: Material
@export var water_material: Material
@export var bubble_material: Material
@export var cap_material: Material
@export var glow_material: Material
@export var caustics_material: Material

@export_group("Colores")
@export var water_color: Color = Color(0.22, 0.72, 1.0)
@export var glow_color: Color = Color(0.3, 0.9, 1.0)

@export_group("Burbujas")
@export_range(0, 600) var bubble_amount: int = 150
@export_range(0.05, 3.0, 0.01) var bubble_speed: float = 0.45       # m/s de las más lentas
@export_range(0.0, 0.9, 0.01) var bubble_speed_variation: float = 0.3
@export var bubble_min_size: float = 0.05                            # diámetro (m)
@export var bubble_max_size: float = 0.14
@export var bubble_wobble_amplitude: float = 0.04                    # bamboleo lateral (m)
@export var bubble_wobble_frequency: float = 1.5                     # rad/s
@export var bubble_fade_in: float = 0.3                              # m desde la base
@export var bubble_fade_out: float = 0.5                             # m antes del tope
@export var bubble_process_shader: Shader                            # bubble_process.gdshader

@export_group("Luz")
@export var light_energy: float = 0.7
@export var light_range: float = 7.0
@export var base_glow_energy: float = 1.2
@export_range(0.0, 3.0, 0.05) var caustics_intensity: float = 0.55
@export var caustics_radius: float = 1.8

const META_GENERATED := &"water_column_generated"


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()

	var rt := cap_height * 0.5                       # radio del tubo del toro de los remates
	var cap_outer := radius + cap_overhang + rt      # radio exterior de base y remate
	var y0 := cap_height * 0.6                       # inicio del cristal
	var y1 := column_height - cap_height * 0.6       # final del cristal
	var glass_h := y1 - y0
	var glass_center := (y0 + y1) * 0.5

	# Cristal (abierto arriba y abajo, cubierto por los remates)
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = radius
	glass_mesh.bottom_radius = radius
	glass_mesh.height = glass_h
	glass_mesh.radial_segments = 48
	glass_mesh.rings = 1
	glass_mesh.cap_top = false
	glass_mesh.cap_bottom = false
	_add_mesh("Glass", glass_mesh, glass_material, Vector3(0, glass_center, 0), false)

	# Agua interior
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = radius - glass_thickness
	water_mesh.bottom_radius = radius - glass_thickness
	water_mesh.height = glass_h - 0.02
	water_mesh.radial_segments = 48
	water_mesh.rings = 8
	_add_mesh("Water", water_mesh, water_material, Vector3(0, glass_center, 0), false)
	var wm := water_material as ShaderMaterial
	if wm:
		wm.set_shader_parameter("water_color", Vector3(water_color.r, water_color.g, water_color.b))

	# Burbujas
	# Las burbujas viven entre la base del agua y un poco por debajo del remate superior
	_build_bubbles(y0 + 0.05, y1 - 0.06 - bubble_max_size * 0.5, radius - glass_thickness)

	# Base y remate: toro + disco de relleno
	_build_cap("BaseCap", rt, cap_outer, rt)
	_build_cap("TopCap", rt, cap_outer, column_height - rt)

	# Anillo emisivo cian en la base
	var glow_mesh := TorusMesh.new()
	glow_mesh.inner_radius = cap_outer - 0.01
	glow_mesh.outer_radius = cap_outer + 0.09
	glow_mesh.rings = 48
	glow_mesh.ring_segments = 12
	_add_mesh("GlowRing", glow_mesh, glow_material, Vector3(0, 0.05, 0), false)
	var gm := glow_material as StandardMaterial3D
	if gm:
		gm.emission = glow_color
		gm.albedo_color = glow_color

	# Luces
	var mid_light := OmniLight3D.new()
	mid_light.name = "WaterLight"
	mid_light.light_color = glow_color
	mid_light.light_energy = light_energy
	mid_light.omni_range = light_range
	mid_light.light_specular = 0.3
	mid_light.position = Vector3(0, column_height * 0.5, 0)
	_add_generated(mid_light)

	var base_light := OmniLight3D.new()
	base_light.name = "BaseLight"
	base_light.light_color = glow_color
	base_light.light_energy = base_glow_energy
	base_light.omni_range = 3.0
	base_light.light_specular = 0.0
	base_light.position = Vector3(0, 0.25, 0)
	_add_generated(base_light)

	# Cáusticas en el suelo (plano aditivo)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (cap_outer + caustics_radius + 0.4) * 2.0
	_add_mesh("Caustics", plane, caustics_material, Vector3(0, 0.012, 0), false)
	var cm := caustics_material as ShaderMaterial
	if cm:
		cm.set_shader_parameter("inner_radius", cap_outer + 0.05)
		cm.set_shader_parameter("outer_radius", cap_outer + caustics_radius)
		cm.set_shader_parameter("intensity", caustics_intensity)
		cm.set_shader_parameter("caustic_color", Vector3(glow_color.r, glow_color.g, glow_color.b))

	# Colisión cilíndrica
	var body := StaticBody3D.new()
	body.name = "ColumnBody"
	var shape := CylinderShape3D.new()
	shape.radius = cap_outer
	shape.height = column_height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, column_height * 0.5, 0)
	body.add_child(col)
	_add_generated(body)


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


func _add_mesh(node_name: String, mesh: Mesh, mat: Material, pos: Vector3, casts_shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	if not casts_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(mi)
	return mi


func _build_cap(node_name: String, rt: float, outer: float, y: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = outer - 2.0 * rt
	torus.outer_radius = outer
	torus.rings = 64
	torus.ring_segments = 16
	_add_mesh(node_name + "Torus", torus, cap_material, Vector3(0, y, 0), true)
	var disc := CylinderMesh.new()
	disc.top_radius = outer - rt
	disc.bottom_radius = outer - rt
	disc.height = 2.0 * rt
	disc.radial_segments = 48
	_add_mesh(node_name + "Disc", disc, cap_material, Vector3(0, y, 0), true)


func _build_bubbles(y_bottom: float, y_top: float, inner_radius: float) -> void:
	var travel := maxf(y_top - y_bottom, 0.1)
	var particles := GPUParticles3D.new()
	particles.name = "Bubbles"
	# Coordenadas locales: las burbujas siguen a la columna y el shader trabaja
	# respecto al eje del tubo, con el origen en la base del agua
	particles.local_coords = true
	particles.position = Vector3(0, y_bottom, 0)
	particles.amount = bubble_amount
	# El ciclo real (subida y renacimiento) lo gestiona el shader de proceso con la
	# altura y la velocidad; la vida del sistema se deja enorme y se emite todo a la vez
	particles.lifetime = 36000.0
	particles.explosiveness = 1.0
	particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	particles.visibility_aabb = AABB(Vector3(-inner_radius, -0.1, -inner_radius),
			Vector3(inner_radius * 2.0, travel + 0.2, inner_radius * 2.0))

	# Radio de nacimiento: interior menos la burbuja más grande y el bamboleo
	var emit_radius := maxf(inner_radius - bubble_max_size * 0.5 - bubble_wobble_amplitude - 0.01, 0.05)
	var pm := ShaderMaterial.new()
	pm.shader = bubble_process_shader
	pm.set_shader_parameter("travel", travel)
	pm.set_shader_parameter("base_speed", bubble_speed)
	pm.set_shader_parameter("speed_variation", bubble_speed_variation)
	pm.set_shader_parameter("emit_radius", emit_radius)
	pm.set_shader_parameter("inner_radius", inner_radius)
	pm.set_shader_parameter("size_min", bubble_min_size)
	pm.set_shader_parameter("size_max", bubble_max_size)
	pm.set_shader_parameter("wobble_amplitude", bubble_wobble_amplitude)
	pm.set_shader_parameter("wobble_frequency", bubble_wobble_frequency)
	pm.set_shader_parameter("fade_in", bubble_fade_in)
	pm.set_shader_parameter("fade_out", bubble_fade_out)
	particles.process_material = pm

	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 7
	particles.draw_pass_1 = sphere
	if bubble_material:
		particles.material_override = bubble_material
		var bm := bubble_material as ShaderMaterial
		if bm:
			# Recorte de seguridad en el shader de la malla, justo en el tope de subida
			bm.set_shader_parameter("clip_top", global_position.y + y_top + 0.01)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(particles)
